<?php

namespace App\Http\Controllers;

use App\Models\BuildingUnlockRule;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Manages which buildings unlock at each Town Hall level, and to what level/count.
 * Gating is deny-by-default (see App\Support\BuildingLevelRules), so a building only
 * becomes placeable once a rule with max_building_level > 0 exists for that Town Hall.
 */
class BuildingUnlockRuleController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $rules = BuildingUnlockRule::query()
            ->when($request->integer('th_level'), fn ($query, $thLevel) => $query->where('th_level', $thLevel))
            ->get();

        return response()->json(['unlockRules' => $rules]);
    }

    /**
     * Replaces every rule for one Town Hall level in a single request — the /unlock-rules
     * page edits a whole Town Hall at a time (~83 buildings), so per-row requests would be
     * far too chatty.
     */
    public function bulkUpdate(Request $request): JsonResponse
    {
        $data = $request->validate([
            'th_level' => ['required', 'integer', 'min:1', 'max:30'],
            'rules' => ['present', 'array'],
            'rules.*.building_type_id' => ['required', 'integer', 'exists:building_types,id'],
            'rules.*.max_building_level' => ['required', 'integer', 'min:0', 'max:250'],
            'rules.*.max_count' => ['nullable', 'integer', 'min:0', 'max:1000'],
        ]);

        $thLevel = $data['th_level'];

        DB::transaction(function () use ($data, $thLevel): void {
            foreach ($data['rules'] as $rule) {
                BuildingUnlockRule::updateOrCreate(
                    ['building_type_id' => $rule['building_type_id'], 'th_level' => $thLevel],
                    [
                        'max_building_level' => $rule['max_building_level'],
                        'max_count' => $rule['max_count'] ?? null,
                    ],
                );
            }
        });

        return response()->json([
            'unlockRules' => BuildingUnlockRule::query()->where('th_level', $thLevel)->get(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'building_type_id' => ['required', 'exists:building_types,id'],
            'th_level' => ['required', 'integer', 'min:1', 'max:30'],
            'max_building_level' => ['required', 'integer', 'min:0', 'max:250'],
            'max_count' => ['nullable', 'integer', 'min:0', 'max:1000'],
        ]);

        $rule = BuildingUnlockRule::updateOrCreate(
            ['building_type_id' => $data['building_type_id'], 'th_level' => $data['th_level']],
            ['max_building_level' => $data['max_building_level'], 'max_count' => $data['max_count'] ?? null],
        );

        return response()->json(['unlockRule' => $rule], 201);
    }

    public function update(Request $request, BuildingUnlockRule $buildingUnlockRule): JsonResponse
    {
        $data = $request->validate([
            'max_building_level' => ['sometimes', 'integer', 'min:0', 'max:250'],
            'max_count' => ['sometimes', 'nullable', 'integer', 'min:0', 'max:1000'],
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
