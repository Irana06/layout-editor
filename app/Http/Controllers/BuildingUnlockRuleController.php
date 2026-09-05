<?php

namespace App\Http\Controllers;

use App\Models\BuildingType;
use App\Models\BuildingUnlockRule;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

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
            'rules.*.building_type_id' => ['required', 'integer', 'distinct'],
            'rules.*.max_building_level' => ['required', 'integer', 'min:0', 'max:250'],
            'rules.*.max_count' => ['nullable', 'integer', 'min:0', 'max:1000'],
        ]);

        $typeIds = collect($data['rules'])->pluck('building_type_id');
        $existingTypeIds = BuildingType::query()
            ->whereIn('id', $typeIds)
            ->pluck('id');

        if ($existingTypeIds->count() !== $typeIds->count()) {
            throw ValidationException::withMessages([
                'rules' => 'Satu atau lebih building tidak ditemukan. Muat ulang katalog lalu coba lagi.',
            ]);
        }

        $thLevel = $data['th_level'];
        $now = now();
        BuildingUnlockRule::query()->upsert(
            collect($data['rules'])->map(fn (array $rule): array => [
                'building_type_id' => $rule['building_type_id'],
                'th_level' => $thLevel,
                'max_building_level' => $rule['max_building_level'],
                'max_count' => $rule['max_count'] ?? null,
                'created_at' => $now,
                'updated_at' => $now,
            ])->all(),
            ['building_type_id', 'th_level'],
            ['max_building_level', 'max_count', 'updated_at'],
        );

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
