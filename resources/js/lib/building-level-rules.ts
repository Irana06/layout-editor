import type { BuildingUnlockRule } from '@/types/game';

/**
 * Mirrors app/Support/BuildingLevelRules.php — used here for palette greying and
 * level-picker capping. The authoritative check happens server-side in LayoutController;
 * keep both in sync.
 *
 * Gating is deny-by-default: a (building_type, th_level) pair with no configured rule is
 * treated as NOT unlocked. Rules are managed on the /unlock-rules page.
 */
export function findRule(buildingTypeId: number, thLevel: number, unlockRules: BuildingUnlockRule[]): BuildingUnlockRule | undefined {
    return unlockRules.find((rule) => rule.building_type_id === buildingTypeId && rule.th_level === thLevel);
}

/** Highest placeable level, or 0 when the building is not unlocked at this Town Hall. */
export function maxLevelFor(buildingTypeId: number, thLevel: number, unlockRules: BuildingUnlockRule[]): number {
    return findRule(buildingTypeId, thLevel, unlockRules)?.max_building_level ?? 0;
}

/** Maximum number placeable, or null when unlimited. */
export function maxCountFor(buildingTypeId: number, thLevel: number, unlockRules: BuildingUnlockRule[]): number | null {
    return findRule(buildingTypeId, thLevel, unlockRules)?.max_count ?? null;
}
