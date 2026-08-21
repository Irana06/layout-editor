import { useMemo } from 'react';
import { gameAssetUrl } from '@/lib/game-assets';
import type { BuildingType } from '@/types/game';
import { useEditor } from './EditorProvider';

export function TownHallLevelSelector({ buildingTypes }: { buildingTypes: BuildingType[] }) {
    const { state, dispatch } = useEditor();

    const townHall = useMemo(() => buildingTypes.find((t) => t.is_town_hall) ?? null, [buildingTypes]);
    const levels = townHall?.levels ?? [];

    if (!townHall || levels.length === 0) {
        return null;
    }

    return (
        <div>
            <p className="text-muted-foreground mb-2 text-xs font-semibold tracking-wide uppercase">Town Hall</p>
            <div className="flex gap-2 overflow-x-auto pb-1">
                {levels.map((level) => {
                    const active = state.thLevel === level.level;

                    return (
                        <button
                            key={level.id}
                            type="button"
                            disabled={state.readOnly}
                            onClick={() => dispatch({ type: 'SET_TH_LEVEL', thLevel: level.level })}
                            className={`flex shrink-0 flex-col items-center gap-1 rounded-xl border p-2 transition-colors disabled:opacity-60 ${
                                active ? 'border-primary bg-accent/60 ring-primary/40 ring-2' : 'border-border/60 hover:border-primary/50'
                            }`}
                        >
                            <img src={gameAssetUrl(level.file_path)} alt={`TH${level.level}`} loading="lazy" className="size-10 object-contain" />
                            <span className="text-[10px] font-semibold">TH{level.level}</span>
                        </button>
                    );
                })}
            </div>
        </div>
    );
}
