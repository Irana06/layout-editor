export type BuildingCategory = 'resource' | 'defense' | 'town-hall';
export type TargetMode = 'none' | 'ground' | 'air-and-ground';

export type TownHallLimit = {
    townHall: number;
    maximum: number;
};

export type BuildingLevel = {
    level: number;
    townHallRequired: number;
    assetPath: string;
    hitpoints: number | null;
    dps: number | null;
    range: number | null;
    targetMode: TargetMode;
};

export type BuildingDefinition = {
    id: string;
    name: string;
    category: BuildingCategory;
    footprint: { width: number; height: number };
    townHallLimits: TownHallLimit[];
    levels: BuildingLevel[];
};

const everyTownHall = (maximum: number): TownHallLimit[] =>
    Array.from({ length: 18 }, (_, index) => ({ townHall: index + 1, maximum }));

const limits = (values: number[]): TownHallLimit[] =>
    values.map((maximum, index) => ({ townHall: index + 1, maximum }));

/**
 * Curated Home Village seed catalog.
 *
 * Asset files live in public/game. Each game update can append a level entry
 * without changing editor rendering or saved-layout data.
 */
export const gameCatalog = {
    version: '2026.08-seed',
    village: 'home',
    buildings: [
        {
            id: 'town-hall',
            name: 'Town Hall',
            category: 'town-hall',
            footprint: { width: 4, height: 4 },
            townHallLimits: everyTownHall(1),
            levels: [{ level: 18, townHallRequired: 18, assetPath: 'buildings-source/resource/town-hall/Town Hall18.png', hitpoints: null, dps: null, range: null, targetMode: 'none' }],
        },
        {
            id: 'gold-mine',
            name: 'Gold Mine',
            category: 'resource',
            footprint: { width: 3, height: 3 },
            townHallLimits: limits([1, 2, 3, 4, 5, 5, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6]),
            levels: [{ level: 1, townHallRequired: 1, assetPath: 'buildings-source/resource/gold-mine/Gold Mine1.png', hitpoints: 400, dps: null, range: null, targetMode: 'none' }],
        },
        {
            id: 'archer-tower',
            name: 'Archer Tower',
            category: 'defense',
            footprint: { width: 3, height: 3 },
            townHallLimits: limits([0, 1, 1, 1, 3, 3, 4, 5, 6, 6, 7, 7, 7, 8, 8, 8, 8, 8]),
            levels: [{ level: 1, townHallRequired: 2, assetPath: 'buildings-source/defensive/archer-tower/Archer Tower1.png', hitpoints: 380, dps: 11, range: 10, targetMode: 'air-and-ground' }],
        },
        {
            id: 'cannon',
            name: 'Cannon',
            category: 'defense',
            footprint: { width: 3, height: 3 },
            townHallLimits: limits([1, 1, 2, 2, 3, 3, 5, 5, 6, 6, 7, 7, 7, 7, 7, 7, 7, 7]),
            levels: [{ level: 1, townHallRequired: 1, assetPath: 'buildings-source/defensive/cannon/Cannon1.png', hitpoints: 420, dps: 9, range: 9, targetMode: 'ground' }],
        },
        {
            id: 'inferno-tower',
            name: 'Inferno Tower',
            category: 'defense',
            footprint: { width: 4, height: 4 },
            townHallLimits: limits([0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 3, 3, 3, 3, 3, 3, 3]),
            levels: [{ level: 1, townHallRequired: 10, assetPath: 'buildings-source/defensive/inferno-tower/Inferno Tower1 Multi.png', hitpoints: 1500, dps: 30, range: 10, targetMode: 'air-and-ground' }],
        },
    ] satisfies BuildingDefinition[],
} as const;

export type EditorPaletteBuilding = {
    id: string;
    name: string;
    size: number;
    file: string;
    level: BuildingLevel;
    definition: BuildingDefinition;
};

export function getEditorPalette(townHall = 18): EditorPaletteBuilding[] {
    return gameCatalog.buildings.flatMap((definition) => {
        const limit = definition.townHallLimits.find((entry) => entry.townHall === townHall);
        const level = [...definition.levels].reverse().find((entry) => entry.townHallRequired <= townHall);

        if (!limit?.maximum || !level) return [];

        return [{
            id: definition.id,
            name: definition.name,
            size: definition.footprint.width,
            file: level.assetPath,
            level,
            definition,
        }];
    });
}
