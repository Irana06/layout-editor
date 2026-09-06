<?php

namespace App\Http\Controllers;

use App\Models\BuildingLevel;
use App\Models\BuildingType;
use App\Models\BuildingUnlockRule;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
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
        $request->validate([
            'th_level' => ['required', 'integer', 'min:1', 'max:30'],
            'rules' => ['present', 'array'],
            'rules.*.building_type_id' => ['required', 'integer', 'distinct'],
            'rules.*.max_building_level' => ['required', 'integer', 'min:0', 'max:250'],
            'rules.*.max_count' => ['nullable', 'integer', 'min:0', 'max:1000'],
        ]);

        $rules = $request->collect('rules')->map(function (mixed $rule): array {
            if (! is_array($rule)
                || ! isset($rule['building_type_id'], $rule['max_building_level'])
                || ! is_int($rule['building_type_id'])
                || ! is_int($rule['max_building_level'])
                || (isset($rule['max_count']) && ! is_int($rule['max_count']))) {
                throw ValidationException::withMessages([
                    'rules' => 'Format aturan building tidak valid.',
                ]);
            }

            return [
                'building_type_id' => $rule['building_type_id'],
                'max_building_level' => $rule['max_building_level'],
                'max_count' => $rule['max_count'] ?? null,
            ];
        });

        $typeIds = $rules->pluck('building_type_id');
        $existingTypeIds = BuildingType::query()
            ->whereIn('id', $typeIds)
            ->pluck('id');

        if ($existingTypeIds->count() !== $typeIds->count()) {
            throw ValidationException::withMessages([
                'rules' => 'Satu atau lebih building tidak ditemukan. Muat ulang katalog lalu coba lagi.',
            ]);
        }

        $thLevel = $request->integer('th_level');
        $now = now();
        BuildingUnlockRule::query()->upsert(
            $rules->map(fn (array $rule): array => [
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

        // Rules are inherited forward once. Editing a later TH writes its own
        // row, and this insert-ignore deliberately preserves that override.
        // Keeping copies in the table (rather than resolving inheritance at
        // read time) lets every TH be adjusted independently in the calibrator.
        $futureTownHallLevels = BuildingLevel::query()
            ->whereHas('type', fn ($query) => $query->where('is_town_hall', true))
            ->where('level', '>', $thLevel)
            ->orderBy('level')
            ->pluck('level')
            ->unique()
            ->values();
        if ($futureTownHallLevels->isNotEmpty()) {
            DB::table('building_unlock_rules')->insertOrIgnore(
                $futureTownHallLevels->flatMap(fn (int $futureLevel) => $rules->map(
                    fn (array $rule): array => [
                        'building_type_id' => $rule['building_type_id'],
                        'th_level' => $futureLevel,
                        'max_building_level' => $rule['max_building_level'],
                        'max_count' => $rule['max_count'],
                        'created_at' => $now,
                        'updated_at' => $now,
                    ],
                ))->all(),
            );
        }

        $affectedTownHallLevels = $futureTownHallLevels->prepend($thLevel);

        return response()->json([
            'unlockRules' => BuildingUnlockRule::query()
                ->whereIn('th_level', $affectedTownHallLevels)
                ->whereIn('building_type_id', $typeIds)
                ->orderBy('th_level')
                ->orderBy('building_type_id')
                ->get(),
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
