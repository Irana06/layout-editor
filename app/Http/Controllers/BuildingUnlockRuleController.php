<?php

namespace App\Http\Controllers;

use App\Models\BuildingUnlockRule;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * No frontend UI this phase (per spec) — the table starts empty and `maxLevelFor()` falls
 * back to `th_level` when no rule exists. These endpoints exist so overrides can be added
 * later without another migration-adjacent change.
 */
class BuildingUnlockRuleController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(['unlockRules' => BuildingUnlockRule::all()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'building_type_id' => ['required', 'exists:building_types,id'],
            'th_level' => ['required', 'integer', 'min:1', 'max:30'],
            'max_building_level' => ['required', 'integer', 'min:1', 'max:250'],
        ]);

        $rule = BuildingUnlockRule::updateOrCreate(
            ['building_type_id' => $data['building_type_id'], 'th_level' => $data['th_level']],
            ['max_building_level' => $data['max_building_level']],
        );

        return response()->json(['unlockRule' => $rule], 201);
    }

    public function update(Request $request, BuildingUnlockRule $buildingUnlockRule): JsonResponse
    {
        $data = $request->validate([
            'max_building_level' => ['required', 'integer', 'min:1', 'max:250'],
        ]);

        $buildingUnlockRule->update($data);

        return response()->json(['unlockRule' => $buildingUnlockRule->fresh()]);
    }

    public function destroy(BuildingUnlockRule $buildingUnlockRule): JsonResponse
    {
        $buildingUnlockRule->delete();

        return response()->json(status: 204);
    }
}
