import { Link } from '@inertiajs/react';
import { useMemo, useState } from 'react';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { maxCountFor, maxLevelFor } from '@/lib/building-level-rules';
import { gameAssetUrl } from '@/lib/game-assets';
import { unlockRules as unlockRulesRoute } from '@/routes';
import type { BuildingLevel, BuildingType, BuildingUnlockRule } from '@/types/game';
import { useEditor } from './EditorProvider';
import { LevelPickerPopover } from './LevelPickerPopover';

type Props = {
    buildingTypes: BuildingType[];
    unlockRules: BuildingUnlockRule[];
};

export function BuildingPalette({ buildingTypes, unlockRules }: Props) {
    const { state, dispatch } = useEditor();
    const [search, setSearch] = useState('');

    const grouped = useMemo(() => {
        const placeable = buildingTypes.filter((t) => !t.is_town_hall && t.levels.length > 0);
        const filtered = search.trim() ? placeable.filter((t) => t.name.toLowerCase().includes(search.trim().toLowerCase())) : placeable;

        const byCategory = new Map<string, Map<string, BuildingType[]>>();

        for (const type of filtered) {
            const sub = type.subfolder ?? '';

            if (!byCategory.has(type.category)) {
byCategory.set(type.category, new Map());
}

            const bySub = byCategory.get(type.category)!;

            if (!bySub.has(sub)) {
bySub.set(sub, []);
}

            bySub.get(sub)!.push(type);
        }

        return byCategory;
    }, [buildingTypes, search]);

    /** How many of each building type are already on the grid — drives the max_count limit. */
    const placedCounts = useMemo(() => {
        const counts = new Map<number, number>();

        for (const placement of state.placements) {
            counts.set(placement.buildingTypeId, (counts.get(placement.buildingTypeId) ?? 0) + 1);
        }

        return counts;
    }, [state.placements]);

    const anyUnlocked = useMemo(
        () => buildingTypes.some((t) => !t.is_town_hall && maxLevelFor(t.id, state.thLevel, unlockRules) > 0),
        [buildingTypes, state.thLevel, unlockRules],
    );

    const arm = (type: BuildingType, level: BuildingLevel) => {
        dispatch({ type: 'SET_LAST_PICKED_LEVEL', buildingTypeId: type.id, level: level.level });
        dispatch({ type: 'ARM', buildingTypeId: type.id, level: level.level });
        dispatch({ type: 'SET_STATUS', status: `Mode tempatkan: ${type.name} (Lv${level.level}).` });
    };

    const handleClick = (type: BuildingType, maxLevel: number) => {
        const unlocked = type.levels.filter((l) => l.level <= maxLevel);

        if (unlocked.length === 0) {
return;
}

        const lastPicked = state.lastPickedLevel[type.id];
        const preferred = unlocked.find((l) => l.level === lastPicked) ?? unlocked[unlocked.length - 1];
        arm(type, preferred);
    };

    return (
        <div>
            <div className="mb-2 flex items-center justify-between">
                <p className="text-muted-foreground text-xs font-semibold tracking-wide uppercase">Bangunan</p>
            </div>
            <input
                type="text"
                placeholder="Cari bangunan..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="border-input bg-background mb-3 w-full rounded-md border px-3 py-1.5 text-sm"
            />
            {!anyUnlocked && (
                <div className="border-border/60 bg-muted/30 mb-3 rounded-lg border border-dashed p-3 text-xs leading-relaxed">
                    <p className="mb-1 font-medium">Belum ada bangunan yang terbuka di TH{state.thLevel}.</p>
                    <p className="text-muted-foreground">
                        Atur dulu di halaman{' '}
                        <Link href={unlockRulesRoute()} className="text-primary underline">
                            Unlock Rules
                        </Link>
                        .
                    </p>
                </div>
            )}
            <div className="max-h-[420px] space-y-3 overflow-y-auto pr-1">
                {[...grouped.entries()].map(([category, bySub]) => (
                    <div key={category}>
                        <p className="text-muted-foreground mb-1 text-[10px] font-semibold tracking-wide uppercase">{category}</p>
                        {[...bySub.entries()].map(([sub, types]) => (
                            <div key={sub || '(root)'} className="mb-2 grid grid-cols-3 gap-1.5">
                                {types.map((type) => {
                                    const maxLevel = maxLevelFor(type.id, state.thLevel, unlockRules);
                                    const maxCount = maxCountFor(type.id, state.thLevel, unlockRules);
                                    const unlocked = type.levels.filter((l) => l.level <= maxLevel);
                                    const placedCount = placedCounts.get(type.id) ?? 0;
                                    const atLimit = maxCount !== null && placedCount >= maxCount;
                                    const gated = unlocked.length === 0 || atLimit;
                                    const isArmed = state.armed?.buildingTypeId === type.id;
                                    const thumbLevel = unlocked[unlocked.length - 1] ?? type.levels[0];

                                    const button = (
                                        <button
                                            type="button"
                                            disabled={gated || state.readOnly}
                                            onClick={() => {
                                                if (!gated && unlocked.length <= 1) {
                                                    handleClick(type, maxLevel);
                                                }
                                                // When there's more than one unlocked level, the LevelPickerPopover
                                                // trigger below owns the click and opens the level chooser instead.
                                            }}
                                            className={`flex w-full flex-col items-center gap-1 rounded-lg border p-1.5 text-center transition-colors disabled:cursor-not-allowed disabled:opacity-40 ${
                                                isArmed ? 'border-primary bg-accent/60' : 'border-border/60 hover:border-primary/50'
                                            }`}
                                        >
                                            <img src={gameAssetUrl(thumbLevel.file_path)} alt="" loading="lazy" className="h-10 w-full object-contain" />
                                            <span className="w-full truncate text-[10px] font-medium">{type.name}</span>
                                            {unlocked.length > 0 && (
                                                <span className="text-muted-foreground text-[9px]">
                                                    s/d Lv{maxLevel}
                                                    {maxCount !== null && ` · ${placedCount}/${maxCount}`}
                                                </span>
                                            )}
                                        </button>
                                    );

                                    if (gated) {
                                        return (
                                            <Tooltip key={type.id}>
                                                <TooltipTrigger asChild>{button}</TooltipTrigger>
                                                <TooltipContent>
                                                    {atLimit
                                                        ? `Sudah mencapai batas ${maxCount} bangunan di TH${state.thLevel}`
                                                        : `Belum terbuka di Town Hall level ${state.thLevel}`}
                                                </TooltipContent>
                                            </Tooltip>
                                        );
                                    }

                                    return (
                                        <LevelPickerPopover key={type.id} type={type} maxLevel={maxLevel} onPick={(level) => arm(type, level)}>
                                            {button}
                                        </LevelPickerPopover>
                                    );
                                })}
                            </div>
                        ))}
                    </div>
                ))}
            </div>
        </div>
    );
}
