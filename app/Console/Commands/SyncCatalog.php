<?php

namespace App\Console\Commands;

use App\Models\BuildingLevel;
use App\Models\BuildingType;
use App\Models\BuildingUnlockRule;
use App\Models\Scenery;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;

/**
 * Move the catalogue between machines without moving the source assets.
 *
 * `import:legacy-assets` reads `basecode_layout-editor/`, which is excluded
 * from the deploy — 182 MB of source art has no business on a web server. So
 * the importer can only ever run locally, and production had no way to learn
 * about a new building. This exports what the importer produced into a file
 * that ships with the code, and loads it on the other side.
 *
 * Calibration travels with it: footprints, scale, offsets, ranges and unlock
 * rules are the work that cannot be re-derived from the images.
 */
class SyncCatalog extends Command
{
    protected $signature = 'catalog:sync
                            {direction : export or import}
                            {--path=database/catalog.json : File to write or read}';

    protected $description = 'Export the building catalogue to a file, or import it into this database.';

    public function handle(): int
    {
        $path = base_path((string) $this->option('path'));

        return match ($this->argument('direction')) {
            'export' => $this->export($path),
            'import' => $this->import($path),
            default => $this->fail('Direction must be "export" or "import".'),
        };
    }

    private function export(string $path): int
    {
        $payload = [
            'version' => 1,
            'exported_at' => now()->toIso8601String(),
            'sceneries' => Scenery::query()->orderBy('id')->get()->map->only([
                'name', 'file_path', 'image_width', 'image_height',
                'tile_w', 'tile_h', 'origin_x', 'origin_y', 'grid_n',
                'calibrated', 'locked',
            ])->all(),
            'building_types' => BuildingType::query()
                ->with(['levels' => fn ($query) => $query->orderBy('level')->orderBy('variant')])
                ->orderBy('id')
                ->get()
                ->map(fn (BuildingType $type): array => [
                    ...$type->only([
                        'name', 'category', 'subfolder', 'is_town_hall',
                        'default_grid_width', 'default_grid_height',
                        'shows_deployment_ring', 'attack_range_min', 'attack_range_max',
                    ]),
                    'levels' => $type->levels->map->only([
                        'level', 'variant', 'file_path', 'grid_width', 'grid_height',
                        'scale', 'offset_x', 'offset_y',
                        'attack_range_min', 'attack_range_max',
                    ])->all(),
                ])->all(),
            'unlock_rules' => BuildingUnlockRule::query()
                ->with('type:id,name,category,subfolder')
                ->orderBy('th_level')
                ->get()
                ->map(fn (BuildingUnlockRule $rule): array => [
                    'building' => [
                        $rule->type?->category,
                        $rule->type?->subfolder,
                        $rule->type?->name,
                    ],
                    'th_level' => $rule->th_level,
                    'max_building_level' => $rule->max_building_level,
                    'max_count' => $rule->max_count,
                ])->all(),
        ];

        File::ensureDirectoryExists(dirname($path));
        File::put($path, json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR));

        $this->info(sprintf(
            'Exported %d building types, %d levels, %d sceneries and %d unlock rules to %s.',
            count($payload['building_types']),
            array_sum(array_map(fn (array $type): int => count($type['levels']), $payload['building_types'])),
            count($payload['sceneries']),
            count($payload['unlock_rules']),
            $path,
        ));

        return self::SUCCESS;
    }

    private function import(string $path): int
    {
        if (! is_file($path)) {
            $this->error("No catalogue file at {$path}. Run `catalog:sync export` first.");

            return self::FAILURE;
        }

        $payload = json_decode((string) File::get($path), true, flags: JSON_THROW_ON_ERROR);
        if (($payload['version'] ?? null) !== 1) {
            $this->error('Unsupported catalogue file version.');

            return self::FAILURE;
        }

        DB::transaction(function () use ($payload): void {
            foreach ($payload['sceneries'] as $scenery) {
                Scenery::query()->updateOrCreate(
                    ['file_path' => $scenery['file_path']],
                    $scenery,
                );
            }

            foreach ($payload['building_types'] as $type) {
                $levels = $type['levels'];
                unset($type['levels']);

                $model = BuildingType::query()->updateOrCreate(
                    [
                        'category' => $type['category'],
                        'subfolder' => $type['subfolder'],
                        'name' => $type['name'],
                    ],
                    $type,
                );

                $kept = [];
                foreach ($levels as $level) {
                    $row = BuildingLevel::query()->updateOrCreate(
                        [
                            'building_type_id' => $model->id,
                            'level' => $level['level'],
                            'variant' => $level['variant'],
                        ],
                        $level,
                    );
                    $kept[] = $row->id;
                }

                // Levels the export no longer has are gone for a reason —
                // Clan Capital art mistaken for a level, a mode since split
                // into its own building — so they must not linger here.
                $model->levels()->whereNotIn('id', $kept)->delete();
            }

            foreach ($payload['unlock_rules'] as $rule) {
                [$category, $subfolder, $name] = $rule['building'];
                $type = BuildingType::query()
                    ->where(['category' => $category, 'subfolder' => $subfolder, 'name' => $name])
                    ->first();
                if ($type === null) {
                    continue;
                }
                BuildingUnlockRule::query()->updateOrCreate(
                    ['building_type_id' => $type->id, 'th_level' => $rule['th_level']],
                    [
                        'max_building_level' => $rule['max_building_level'],
                        'max_count' => $rule['max_count'],
                    ],
                );
            }
        });

        $this->info('Catalogue imported. Building types: '.BuildingType::count().', levels: '.BuildingLevel::count().'.');

        return self::SUCCESS;
    }
}
