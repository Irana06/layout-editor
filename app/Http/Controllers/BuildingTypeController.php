<?php

namespace App\Http\Controllers;

use App\Models\BuildingType;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

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
            'shows_deployment_ring' => ['sometimes', 'boolean'],
            'attack_range_min' => ['sometimes', 'integer', 'min:0', 'max:60'],
            'attack_range_max' => ['sometimes', 'integer', 'min:0', 'max:60'],
        ]);

        // A blind spot only means something inside a real range, and a minimum
        // that reaches past the maximum would draw the two rings inside out.
        $min = $data['attack_range_min'] ?? $buildingType->attack_range_min;
        $max = $data['attack_range_max'] ?? $buildingType->attack_range_max;
        if ($min > 0 && $min >= $max) {
            throw ValidationException::withMessages([
                'attack_range_min' => 'Jarak minimal harus lebih kecil dari jarak maksimal.',
            ]);
        }

        $buildingType->update($data);

        return response()->json(['buildingType' => $buildingType->fresh('levels')]);
    }

    /** Apply one square footprint to every level of a building type. */
    public function updateFootprint(Request $request, BuildingType $buildingType): JsonResponse
    {
        $data = $request->validate([
            'grid_size' => ['required', 'integer', 'min:1', 'max:20'],
        ]);

        return response()->json([
            'buildingType' => $buildingType->applyFootprint($data['grid_size'], $data['grid_size']),
        ]);
    }

    public function destroy(BuildingType $buildingType): JsonResponse
    {
        $buildingType->delete();

        return response()->json(status: 204);
    }
}
