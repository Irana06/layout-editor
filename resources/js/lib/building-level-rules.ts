import type { BuildingUnlockRule } from '@/types/game';

/**
 * Mirrors app/Support/BuildingLevelRules.php::maxLevelFor() — used here for
 * palette greying / level-picker capping. The authoritative check happens
 * server-side in LayoutController; keep both in sync.
 */
export function maxLevelFor(buildingTypeId: number, thLevel: number, unlockRules: BuildingUnlockRule[]): number {
    const override = unlockRules.find((rule) => rule.building_type_id === buildingTypeId && rule.th_level === thLevel);

    return override?.max_building_level ?? thLevel;
}
