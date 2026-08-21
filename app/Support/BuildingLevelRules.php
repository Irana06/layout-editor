<?php

namespace App\Support;

use App\Models\BuildingUnlockRule;
use Illuminate\Support\Collection;

/**
 * Mirrored in resources/js/lib/building-level-rules.ts for palette greying / level-picker
 * capping on the frontend. This is the authoritative copy — always re-validated here on
 * layout save, never trusting the frontend-only check.
 *
 * Gating is deny-by-default: a (building_type, th_level) pair with no configured rule is
 * treated as NOT unlocked (max level 0). Rules are managed on the /unlock-rules page.
 */
class BuildingLevelRules
{
    /**
     * All rules for one Town Hall level, keyed by building_type_id.
     * Load once per request rather than querying per placement.
     *
     * @return Collection<int, BuildingUnlockRule>
     */
    public static function forThLevel(int $thLevel): Collection
    {
        return BuildingUnlockRule::query()
            ->where('th_level', $thLevel)
            ->get()
            ->keyBy('building_type_id');
    }

    /** Highest placeable level, or 0 when the building is not unlocked at this Town Hall. */
    public static function maxLevelFor(int $buildingTypeId, int $thLevel): int
    {
        return (int) BuildingUnlockRule::query()
            ->where('building_type_id', $buildingTypeId)
            ->where('th_level', $thLevel)
            ->value('max_building_level');
    }

    /** Maximum number placeable, or null when unlimited. */
    public static function maxCountFor(int $buildingTypeId, int $thLevel): ?int
    {
        $count = BuildingUnlockRule::query()
            ->where('building_type_id', $buildingTypeId)
            ->where('th_level', $thLevel)
            ->value('max_count');

        return $count === null ? null : (int) $count;
    }
}
