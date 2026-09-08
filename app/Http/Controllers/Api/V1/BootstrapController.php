<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\BuildingLevel;
use App\Models\BuildingType;
use App\Models\BuildingUnlockRule;
use App\Models\Scenery;
use App\Support\BuildingDisplayOrder;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Collection;

class BootstrapController extends Controller
{
    public function __invoke(): JsonResponse
    {
        return $this->catalog(false);
    }

    public function calibration(): JsonResponse
    {
        return $this->catalog(true);
    }

    /**
     * Fingerprint of everything an offline copy would have to re-download:
     * which files exist and where, plus the calibration that decides how they
     * are drawn. Deliberately not the whole payload — a changed `generated_at`
     * or a renamed unlock rule should not tell a phone to fetch 500 images.
     *
     * @param  Collection<int, Scenery>  $sceneries
     * @param  Collection<int, BuildingType>  $buildingTypes
     */
    private function catalogVersion(Collection $sceneries, Collection $buildingTypes): string
    {
        $material = [
            $sceneries->map(fn (Scenery $scenery): array => [
                $scenery->id, $scenery->file_path,
                $scenery->tile_w, $scenery->tile_h,
                $scenery->origin_x, $scenery->origin_y, $scenery->grid_n,
            ])->all(),
            $buildingTypes->map(fn (BuildingType $type): array => [
                $type->id,
                $type->default_grid_width, $type->default_grid_height,
                $type->attack_range_min, $type->attack_range_max,
                $type->levels->map(fn (BuildingLevel $level): array => [
                    $level->id, $level->file_path, $level->level,
                    $level->scale, $level->offset_x, $level->offset_y,
                    $level->grid_width, $level->grid_height,
                ])->all(),
            ])->all(),
        ];

        return substr(
            hash('sha256', json_encode($material, JSON_THROW_ON_ERROR)),
            0,
            16,
        );
    }

    private function catalog(bool $includeUncalibrated): JsonResponse
    {
        $baseUrl = rtrim((string) config('app.url'), '/');
        $assetUrl = fn (string $path): string => $baseUrl.'/game/'.ltrim($path, '/');

        $sceneryModels = Scenery::query()
            ->when(! $includeUncalibrated, fn ($query) => $query->where('calibrated', true))
            ->orderBy('name')
            ->get();

        // Library order is a property of how a base gets built, not of the
        // catalogue, so the server decides it once and every client follows.
        $typeModels = BuildingDisplayOrder::sort(
            BuildingType::query()
                ->with(['levels' => fn ($query) => $query->orderBy('level')])
                ->get()
        );

        $sceneries = $sceneryModels
            ->map(fn (Scenery $scenery): array => [
                ...$scenery->toArray(),
                'image_url' => $assetUrl($scenery->file_path),
            ]);

        $buildingTypes = $typeModels
            ->map(fn (BuildingType $type): array => [
                ...$type->only([
                    'id', 'name', 'category', 'subfolder', 'is_town_hall',
                    'default_grid_width', 'default_grid_height', 'shows_deployment_ring',
                    'attack_range_min', 'attack_range_max',
                ]),
                'display_order' => BuildingDisplayOrder::for($type),
                'levels' => $type->levels->map(fn (BuildingLevel $level): array => [
                    ...$level->toArray(),
                    'image_url' => $assetUrl($level->file_path),
                ])->values(),
            ]);

        return response()->json([
            'data' => [
                'sceneries' => $sceneries,
                'building_types' => $buildingTypes,
                'unlock_rules' => BuildingUnlockRule::query()
                    ->orderBy('th_level')
                    ->orderBy('building_type_id')
                    ->get(),
            ],
            'meta' => [
                'api_version' => 'v1',
                'generated_at' => now()->toIso8601String(),
                // Changes only when the catalogue itself changes, unlike
                // generated_at which moves on every request. An offline copy
                // compares this to know whether it is stale — without it the
                // app could only guess, and would either nag or never update.
                'catalog_version' => $this->catalogVersion($sceneryModels, $typeModels),
            ],
        ]);
    }
}
