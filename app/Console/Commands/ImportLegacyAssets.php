<?php

namespace App\Console\Commands;

use App\Models\Building;
use App\Models\Scenery;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use SplFileInfo;

class ImportLegacyAssets extends Command
{
    protected $signature = 'import:legacy-assets
                            {--force : Replace files that have already been imported}';

    protected $description = 'Import basecode editor building and scenery assets into Laravel public storage.';

    /** @var array<string, array<string, mixed>> */
    private array $buildingManifest = [];

    /** @var array<string, array<string, mixed>> */
    private array $sceneryManifest = [];

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

        $importedBuildings = $this->importBuildings($buildingsRoot);
        $importedSceneries = $this->importSceneries($sceneriesRoot);

        $this->newLine();
        $this->info("Imported or updated {$importedBuildings} building records and {$importedSceneries} sceneries.");
        $this->line('Files are stored on the public disk. Run `php artisan storage:link` once if the link does not exist.');

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

    private function importBuildings(string $sourceRoot): int
    {
        $files = $this->imageFiles($sourceRoot);
        $bar = $this->output->createProgressBar(count($files));
        $bar->start();

        foreach ($files as $file) {
            $relative = $this->relativePath($sourceRoot, $file->getPathname());
            $manifestKey = 'buildings-source/'.$relative;
            $metadata = $this->buildingManifest[$this->normalisePath($manifestKey)] ?? [];
            $segments = explode('/', $relative);
            $category = $metadata['category'] ?? $segments[0] ?? 'other';
            $subfolder = $metadata['subfolder'] ?? ($segments[1] ?? null);
            $destination = 'buildings/'.$relative;

            $this->copyToPublicDisk($file->getPathname(), $destination);

            $gridSize = max(1, (int) ($metadata['gridSize'] ?? $this->defaultGridSize($category)));
            $calibration = $metadata['calibration'] ?? [];

            Building::query()->updateOrCreate(
                ['file_path' => $destination],
                [
                    'name' => $metadata['name'] ?? Str::of($file->getFilenameWithoutExtension())->replace(['-', '_'], ' ')->title()->toString(),
                    'category' => $category,
                    'subfolder' => $subfolder,
                    'grid_width' => $gridSize,
                    'grid_height' => $gridSize,
                    'scale' => (float) ($calibration['scale'] ?? 1),
                    'offset_x' => (float) ($calibration['offsetX'] ?? 0),
                    'offset_y' => (float) ($calibration['offsetY'] ?? 0),
                ],
            );

            $bar->advance();
        }

        $bar->finish();

        return count($files);
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
            $this->copyToPublicDisk($file->getPathname(), $destination);

            $imageSize = @getimagesize($file->getPathname()) ?: [0, 0];

            Scenery::query()->updateOrCreate(
                ['file_path' => $destination],
                [
                    'name' => $metadata['name'] ?? Str::of($file->getFilenameWithoutExtension())->replace(['-', '_'], ' ')->title()->toString(),
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

    private function copyToPublicDisk(string $source, string $destination): void
    {
        $disk = Storage::disk('public');

        if ($this->option('force') || ! $disk->exists($destination)) {
            $disk->makeDirectory(dirname($destination));
            File::copy($source, $disk->path($destination));
        }
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
