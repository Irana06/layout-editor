<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\BuildingLevel;
use App\Models\BuildingType;
use App\Models\BuildingUnlockRule;
use App\Models\Scenery;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BootstrapController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $assetUrl = fn (string $path): string => $request->getSchemeAndHttpHost().'/game/'.ltrim($path, '/');

        $sceneries = Scenery::query()
            ->where('calibrated', true)
            ->orderBy('name')
            ->get()
            ->map(fn (Scenery $scenery): array => [
                ...$scenery->toArray(),
                'image_url' => $assetUrl($scenery->file_path),
            ]);

        $buildingTypes = BuildingType::query()
            ->with(['levels' => fn ($query) => $query->orderBy('level')])
            ->orderBy('category')
            ->orderBy('subfolder')
            ->orderBy('name')
            ->get()
            ->map(fn (BuildingType $type): array => [
                ...$type->only([
                    'id', 'name', 'category', 'subfolder', 'is_town_hall',
                    'default_grid_width', 'default_grid_height',
                ]),
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
            ],
        ]);
    }
}
