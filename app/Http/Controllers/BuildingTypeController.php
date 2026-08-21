<?php

namespace App\Http\Controllers;

use App\Models\BuildingType;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

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

    public function destroy(BuildingType $buildingType): JsonResponse
    {
        $buildingType->delete();

        return response()->json(status: 204);
    }
}
