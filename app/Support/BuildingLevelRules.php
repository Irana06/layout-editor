<?php

namespace App\Support;

use App\Models\BuildingUnlockRule;

/**
 * Mirrored in resources/js/lib/building-level-rules.ts for palette greying / level-picker
 * capping on the frontend. This is the authoritative copy — always re-validated here on
 * layout save, never trusting the frontend-only check.
 */
class BuildingLevelRules
{
    public static function maxLevelFor(int $buildingTypeId, int $thLevel): int
    {
        return BuildingUnlockRule::query()
            ->where('building_type_id', $buildingTypeId)
            ->where('th_level', $thLevel)
            ->value('max_building_level') ?? $thLevel;
    }
}
