<?php

namespace App\Console\Commands;

use App\Models\BuildingLevel;
use App\Models\BuildingType;
use App\Models\Scenery;
use App\Support\BuildingVariants;
use App\Support\GameAssetUploader;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Str;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use SplFileInfo;

/**
 * @phpstan-type Candidate array{file: SplFileInfo, category: string, subfolder: string|null, typeName: string, level: int, variantSuffix: string, mode: string|null, metadata: array<string, mixed>}
 */
class ImportLegacyAssets extends Command
{
    protected $signature = 'import:legacy-assets
                            {--force : Replace files that have already been imported}
                            {--prune : Delete imported images no building level points at any more}';

    protected $description = 'Import basecode editor building and scenery assets into building_types/building_levels/sceneries.';

    /** Highest level number treated as a real building level; above this it's a naming artifact. */
    private const MAX_PLAUSIBLE_LEVEL = 60;

    /** @var array<string, array<string, mixed>> */
    private array $buildingManifest = [];

    /** @var array<string, array<string, mixed>> */
    private array $sceneryManifest = [];

    /**
     * Level rows this run wrote, per building type. Anything else belonging to
     * a mode-carrying type is left over from an earlier run under different
     * rules, and would otherwise keep showing up as a stale extra choice.
     *
     * @var array<int, list<int>>
     */
    private array $writtenLevelIds = [];

    public function __construct(private readonly GameAssetUploader $uploader)
    {
        parent::__construct();
    }

    public function handle(): int
    {
        $legacyRoot = base_path('basecode_layout-editor/assets/game');
        $buildingsRoot = $legacyRoot.'/buildings-source';
        $sceneriesRoot = $legacyRoot.'/scenery';

        if (! is_dir($buildingsRoot) || ! is_dir($sceneriesRoot)) {
            $this->error('Legacy assets were not found. Keep basecode_layout-editor in the project until this import is complete.');

            return self::FAILURE;
        }

        $this->loadManifest($buildingsRoot.'/manifest.json');

        $importedLevels = $this->importBuildings($buildingsRoot);
        $importedSceneries = $this->importSceneries($sceneriesRoot);

        $this->newLine();
        $this->info("Imported or updated {$importedLevels} building levels and {$importedSceneries} sceneries.");

        if ($this->option('prune')) {
            $this->pruneOrphanedImages();
        }

        return self::SUCCESS;
    }

    private function loadManifest(string $manifestPath): void
    {
        if (! is_file($manifestPath)) {
            $this->warn('No manifest.json found; default calibration values will be used.');

            return;
        }

        $manifest = json_decode((string) File::get($manifestPath), true);

        if (! is_array($manifest)) {
            $this->warn('manifest.json could not be parsed; default calibration values will be used.');

            return;
        }

        foreach ($manifest['buildings'] ?? [] as $building) {
            if (isset($building['file'])) {
                $this->buildingManifest[$this->normalisePath($building['file'])] = $building;
            }
        }

        foreach ($manifest['scenery'] ?? [] as $scenery) {
            if (isset($scenery['file'])) {
                $this->sceneryManifest[$this->normalisePath($scenery['file'])] = $scenery;
            }
        }
    }

    /**
     * Two-pass import: first walk every source file and group candidate files by
     * (category, subfolder, type name, level) — several legacy files often resolve to the
     * same logical level (event skins, "pre <date>" historical snapshots, depleted states).
     * Second pass picks one deterministic winner per group and writes the DB rows.
     */
    private function importBuildings(string $sourceRoot): int
    {
        $files = $this->imageFiles($sourceRoot);
        /** @var array<string, list<Candidate>> $groups */
        $groups = [];

        foreach ($files as $file) {
            $relative = $this->relativePath($sourceRoot, $file->getPathname());
            $manifestKey = 'buildings-source/'.$relative;
            $metadata = $this->buildingManifest[$this->normalisePath($manifestKey)] ?? [];
            $segments = explode('/', $relative);
            $category = (string) ($metadata['category'] ?? $segments[0]);
            $subfolder = isset($metadata['subfolder']) ? (string) $metadata['subfolder'] : ($segments[1] ?? null);

            $basename = pathinfo($file->getFilename(), PATHINFO_FILENAME);
            [$typeName, $level, $variantSuffix] = $this->parseLevel($basename);

            if ($level === null) {
                $this->warn("Could not parse a level number from '{$basename}', defaulting to level 1.");
                $level = 1;
            }

            // Some legacy files are seasonal skins named with a year (e.g. "Air Defense2012"),
            // which parses as an absurd level. Real levels top out around 21, so anything past
            // the plausibility cap is a naming artifact rather than a level — skip it and let
            // the operator add it deliberately from the Calibrate page if they want it.
            if ($level > self::MAX_PLAUSIBLE_LEVEL) {
                $this->warn("Skipping '{$basename}' — parsed level {$level} exceeds the plausible maximum (".self::MAX_PLAUSIBLE_LEVEL.'), likely a year or naming artifact.');

                continue;
            }

            // The gear-up building is a separate entry in the library, with its
            // own count and its own artwork, so its files are split off into
            // their own type before anything else looks at them.
            if (BuildingVariants::gearOwnerFor($subfolder, $variantSuffix) === 'gear') {
                $subfolder .= '-gear';
                $typeName .= ' Gear Up';
            }

            // A mode is a separate artwork the player chooses between, so it gets
            // its own group and its own row. Every other suffix — depleted,
            // unarmed, historical art — still competes for one slot.
            $mode = BuildingVariants::modeFor($subfolder, $variantSuffix);

            $key = implode('|', [$category, $subfolder, Str::lower($typeName), $level, $mode ?? '']);
            $groups[$key][] = [
                'file' => $file,
                'category' => $category,
                'subfolder' => $subfolder,
                'typeName' => $typeName,
                'level' => $level,
                'variantSuffix' => $variantSuffix,
                'mode' => $mode,
                'metadata' => $metadata,
            ];
        }

        $groups = $this->demoteSingleModeLevels($groups);

        $bar = $this->output->createProgressBar(count($groups));
        $bar->start();
        $count = 0;

        foreach ($groups as $candidates) {
            $chosen = $this->pickCandidate($candidates);

            foreach ($candidates as $candidate) {
                if ($candidate !== $chosen) {
                    $this->warn(sprintf(
                        "Skipping duplicate level file '%s' — level %d of '%s' already resolved to '%s'.",
                        $candidate['file']->getFilename(),
                        $candidate['level'],
                        $candidate['typeName'],
                        $chosen['file']->getFilename(),
                    ));
                }
            }

            $isTownHall = $chosen['category'] === 'resource' && $chosen['subfolder'] === 'town-hall';
            $gridSize = $chosen['subfolder'] === 'wall'
                ? 1
                : max(1, (int) ($chosen['metadata']['gridSize'] ?? $this->defaultGridSize($chosen['category'])));

            $type = BuildingType::query()->firstOrNew([
                'category' => $chosen['category'],
                'subfolder' => $chosen['subfolder'],
                'name' => $chosen['typeName'],
            ]);

            // The manifest's grid size is a guess — it only ever says 1, 2 or 3,
            // so it has Town Hall at 3x3 and every trap at 2x2. A footprint
            // corrected in the Calibrator is worth more than that, and must
            // survive a re-import.
            if (! $type->exists) {
                $type->default_grid_width = $gridSize;
                $type->default_grid_height = $gridSize;
            }
            $type->is_town_hall = $isTownHall;
            $type->save();

            $extension = $chosen['file']->getExtension();
            $destination = sprintf(
                'buildings/%s/%s/%d%s.%s',
                $chosen['category'],
                $chosen['subfolder'] ?? 'misc',
                $chosen['level'],
                $chosen['mode'] === null ? '' : '-'.$chosen['mode'],
                $extension,
            );
            $this->uploader->copyToPublicGame($chosen['file']->getPathname(), $destination, (bool) $this->option('force'));

            $calibration = $chosen['metadata']['calibration'] ?? [];

            $levelRow = BuildingLevel::query()->firstOrNew([
                'building_type_id' => $type->id,
                'level' => $chosen['level'],
                'variant' => $chosen['mode'],
            ]);

            // Same reasoning as the footprint: every calibration value in the
            // manifest is a placeholder (scale 1, offset 0), so re-importing
            // must not undo work done by hand in the Calibrator.
            if (! $levelRow->exists) {
                $levelRow->scale = (float) ($calibration['scale'] ?? 1);
                $levelRow->offset_x = (float) ($calibration['offsetX'] ?? 0);
                $levelRow->offset_y = (float) ($calibration['offsetY'] ?? 0);
            }
            $levelRow->file_path = $destination;
            $levelRow->save();
            $this->writtenLevelIds[$type->id][] = $levelRow->id;

            $count++;
            $bar->advance();
        }

        $bar->finish();
        $this->retireSupersededLevels();

        return $count;
    }

    /**
     * Delete imported images nothing points at any more.
     *
     * Renaming a mode, or deciding a level had no modes after all, writes the
     * artwork under a new name and leaves the old file behind — invisible in
     * the app, but still shipped and still in the repository. Opt-in, because
     * it deletes files and the operator should mean it.
     */
    private function pruneOrphanedImages(): void
    {
        $used = BuildingLevel::query()
            ->pluck('file_path')
            ->map(fn (string $path): string => $this->normalisePath(public_path('game/'.$path)))
            ->flip();

        $removed = 0;
        $bytes = 0;
        foreach (glob(public_path('game/buildings/*/*/*.*')) ?: [] as $file) {
            if ($used->has($this->normalisePath($file))) {
                continue;
            }
            $bytes += (int) filesize($file);
            unlink($file);
            $removed++;
        }

        $this->info($removed === 0
            ? 'No orphaned images to prune.'
            : sprintf('Pruned %d orphaned image(s), freeing %.1f MB.', $removed, $bytes / 1048576));
    }

    /**
     * A mode is only a mode when there is something to choose between.
     *
     * A Cannon has no lever and no geared form until level 7, so its earlier
     * levels have exactly one artwork — labelling that "Bertuas" would be
     * wrong, and writing it to `1-lever.png` would leave `1.png` behind as
     * dead weight. Levels with a single mode are collapsed back to the plain
     * unlabelled form, which is also what every building without modes uses.
     *
     * @param  array<string, list<Candidate>>  $groups
     * @return array<string, list<Candidate>>
     */
    private function demoteSingleModeLevels(array $groups): array
    {
        /** @var array<string, array<string, true>> $modesPerLevel */
        $modesPerLevel = [];
        foreach ($groups as $candidates) {
            $first = $candidates[0];
            if ($first['mode'] === null) {
                continue;
            }
            $levelKey = implode('|', [
                $first['category'],
                $first['subfolder'],
                Str::lower($first['typeName']),
                $first['level'],
            ]);
            $modesPerLevel[$levelKey][$first['mode']] = true;
        }

        $rebuilt = [];
        foreach ($groups as $key => $candidates) {
            $first = $candidates[0];
            $levelKey = implode('|', [
                $first['category'],
                $first['subfolder'],
                Str::lower($first['typeName']),
                $first['level'],
            ]);

            $modeCount = count($modesPerLevel[$levelKey] ?? []);

            // Where a level really does offer modes, its unlabelled artwork is
            // not a third choice — it is the destroyed Inferno Tower, the
            // out-of-ammo X-Bow, the unarmed trap. Those are states nobody
            // picks, so they are dropped rather than imported.
            if ($first['mode'] === null && $modeCount >= 2) {
                continue;
            }

            if ($first['mode'] !== null && $modeCount < 2) {
                // A gear-up entry with nothing to toggle is not a gear-up
                // entry: a Cannon has no lever before level 7, so its early
                // levels belong to the ordinary Cannon rather than sitting in
                // the library as a second, identical building.
                $gear = str_ends_with((string) $first['subfolder'], '-gear');
                $candidates = array_map(
                    fn (array $candidate): array => [
                        ...$candidate,
                        'mode' => null,
                        'subfolder' => $gear
                            ? substr((string) $candidate['subfolder'], 0, -5)
                            : $candidate['subfolder'],
                        'typeName' => $gear
                            ? (string) preg_replace('/ Gear Up$/', '', $candidate['typeName'])
                            : $candidate['typeName'],
                    ],
                    $candidates,
                );
                $first = $candidates[0];
                $key = implode('|', [
                    $first['category'],
                    $first['subfolder'],
                    Str::lower($first['typeName']),
                    $first['level'],
                    '',
                ]);
            }

            // Demoting can collide with an existing unlabelled group for the
            // same level; both are then artwork of the same thing and compete
            // as duplicates, which is exactly what pickCandidate is for.
            $rebuilt[$key] = [...($rebuilt[$key] ?? []), ...$candidates];
        }

        return $rebuilt;
    }

    /**
     * Drop the single unlabelled row a mode-carrying building used to have.
     *
     * Before modes existed the importer kept one artwork per level, so an
     * Inferno Tower has a variant-less row pointing at whichever of Single and
     * Multi happened to win. Now that both exist as their own rows, that leftover
     * would show up as a third, nameless choice in the library.
     */
    private function retireSupersededLevels(): void
    {
        // Driven by what this run touched rather than by what the database
        // happens to hold, so a type whose modes were all demoted still gets
        // its old mode rows cleared.
        $types = BuildingType::query()
            ->whereIn('id', array_keys($this->writtenLevelIds))
            ->get();

        foreach ($types as $type) {
            // Folders that split for gear-up count too: once "cannon" stopped
            // carrying modes, skipping it left its old mode rows in place.
            if (! BuildingVariants::hasModes($type->subfolder)
                && ! BuildingVariants::splitsForGearUp($type->subfolder)) {
                continue;
            }

            // Only rows this run produced are current. Anything else is from an
            // earlier run under different rules — a mode since renamed, or one
            // that turned out not to be a choice at all — and leaving it would
            // show the same level twice with different labels.
            $written = $this->writtenLevelIds[$type->id] ?? [];
            $removed = $type->levels()->whereNotIn('id', $written)->delete();

            if ($removed > 0) {
                $this->warn("Removed {$removed} superseded level row(s) of '{$type->name}'.");
            }
        }
    }

    /**
     * Splits a basename like "Inferno Tower10 Multi pre June 16 2025" into
     * ["Inferno Tower", 10, "Multi pre June 16 2025"]. Returns level=null when no
     * digit run can be found, in which case the caller falls back to level 1.
     *
     * @return array{0: string, 1: int|null, 2: string}
     */
    private function parseLevel(string $basename): array
    {
        if (! preg_match('/^([A-Za-z][A-Za-z\- ]*?)\s*0*(\d+)(.*)$/', trim($basename), $matches)) {
            return [trim($basename), null, ''];
        }

        return [trim($matches[1]), (int) $matches[2], trim($matches[3])];
    }

    /**
     * Deterministically picks one file per (type, level) group: prefer files without a
     * "pre <date>" historical marker, then without a "depleted" defeated-state marker,
     * then prefer an empty variant suffix, then the shortest suffix, then alphabetical.
     *
     * @param  list<Candidate>  $candidates
     * @return Candidate
     */
    private function pickCandidate(array $candidates): array
    {
        if (count($candidates) === 1) {
            return $candidates[0];
        }

        $rank = function (array $candidate): array {
            $suffix = $candidate['variantSuffix'];
            $lower = Str::lower($suffix);

            return [
                Str::contains($lower, 'pre ') ? 1 : 0,
                Str::contains($lower, 'depleted') ? 1 : 0,
                $suffix === '' ? 0 : 1,
                strlen($suffix),
                $suffix,
            ];
        };

        usort($candidates, fn ($a, $b) => $rank($a) <=> $rank($b));

        return $candidates[0];
    }

    private function importSceneries(string $sourceRoot): int
    {
        $files = $this->imageFiles($sourceRoot);
        $bar = $this->output->createProgressBar(count($files));
        $bar->start();

        foreach ($files as $file) {
            $relative = $this->relativePath($sourceRoot, $file->getPathname());
            $metadata = $this->sceneryManifest[$this->normalisePath('scenery/'.$relative)] ?? [];
            $grid = $metadata['grid'] ?? [];
            $destination = 'sceneries/'.$relative;
            $this->uploader->copyToPublicGame($file->getPathname(), $destination, (bool) $this->option('force'));

            $imageSize = @getimagesize($file->getPathname()) ?: [0, 0];

            Scenery::query()->updateOrCreate(
                ['file_path' => $destination],
                [
                    'name' => $metadata['name'] ?? Str::of(pathinfo($file->getFilename(), PATHINFO_FILENAME))->replace(['-', '_'], ' ')->title()->toString(),
                    'image_width' => (int) $imageSize[0],
                    'image_height' => (int) $imageSize[1],
                    'tile_w' => (float) ($grid['tileW'] ?? 56),
                    'tile_h' => (float) ($grid['tileH'] ?? 42),
                    'origin_x' => (float) ($grid['originX'] ?? 0),
                    'origin_y' => (float) ($grid['originY'] ?? 0),
                    'grid_n' => max(1, (int) ($grid['n'] ?? 44)),
                    'calibrated' => (bool) ($grid['calibrated'] ?? false),
                    'locked' => (bool) ($grid['locked'] ?? false),
                ],
            );

            $bar->advance();
        }

        $bar->finish();

        return count($files);
    }

    /** @return list<SplFileInfo> */
    private function imageFiles(string $directory): array
    {
        $iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($directory, RecursiveDirectoryIterator::SKIP_DOTS));
        $files = [];

        foreach ($iterator as $file) {
            if (! $file->isFile() || ! in_array(strtolower($file->getExtension()), ['png', 'jpg', 'jpeg', 'webp'], true)) {
                continue;
            }

            $files[] = $file;
        }

        return $files;
    }

    private function relativePath(string $root, string $path): string
    {
        return ltrim(str_replace('\\', '/', substr($path, strlen(rtrim($root, '/\\')))), '/');
    }

    private function normalisePath(string $path): string
    {
        return strtolower(str_replace('\\', '/', $path));
    }

    private function defaultGridSize(string $category): int
    {
        return match ($category) {
            'army', 'defensive', 'resource' => 3,
            'traps' => 2,
            default => 1,
        };
    }
}
