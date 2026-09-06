<?php

namespace App\Http\Controllers;

use App\Models\BuildingType;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class BuildingTypeController extends Controller
{
    public function update(Request $request, BuildingType $buildingType): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:120'],
            'category' => ['sometimes', 'string', 'max:32'],
            'subfolder' => ['sometimes', 'nullable', 'string', 'max:120'],
            'default_grid_width' => ['sometimes', 'integer', 'min:1', 'max:20'],
            'default_grid_height' => ['sometimes', 'integer', 'min:1', 'max:20'],
        ]);

        $buildingType->update($data);

        return response()->json(['buildingType' => $buildingType->fresh('levels')]);
    }

    /**
     * Apply one square footprint to every level of a building type.
     *
     * A footprint belongs to the type, while visual scale and offsets belong to
     * individual level assets. Clearing the per-level width/height overrides
     * makes every level inherit this new shared value without disturbing its
     * calibrated image placement.
     */
    public function updateFootprint(Request $request, BuildingType $buildingType): JsonResponse
    {
        $data = $request->validate([
            'grid_size' => ['required', 'integer', 'min:1', 'max:20'],
        ]);

        /** @var BuildingType $updatedType */
        $updatedType = DB::transaction(function () use ($buildingType, $data): BuildingType {
            $type = BuildingType::query()
                ->whereKey($buildingType->getKey())
                ->lockForUpdate()
                ->firstOrFail();

            $type->update([
                'default_grid_width' => $data['grid_size'],
                'default_grid_height' => $data['grid_size'],
            ]);

            $type->levels()->update([
                'grid_width' => null,
                'grid_height' => null,
            ]);

            return $type->fresh('levels');
        });

        return response()->json(['buildingType' => $updatedType]);
    }

    public function destroy(BuildingType $buildingType): JsonResponse
    {
        $buildingType->delete();

        return response()->json(status: 204);
    }
}
