import { useMemo } from 'react';
import { Switch } from '@/components/ui/switch';
import { levelFootprint  } from '@/types/game';
import type {BuildingType} from '@/types/game';
import { useEditor } from './EditorProvider';

export function SelectedBuildingPanel({ buildingTypes }: { buildingTypes: BuildingType[] }) {
    const { state, dispatch } = useEditor();

    const typeMap = useMemo(() => new Map(buildingTypes.map((t) => [t.id, t])), [buildingTypes]);

    const selected = state.selectedIds.length === 1 ? state.placements.find((p) => p.uid === state.selectedIds[0]) : null;
    const selectedType = selected ? typeMap.get(selected.buildingTypeId) : null;
    const selectedLevel = selectedType?.levels.find((l) => l.level === selected?.level);

    return (
        <div className="space-y-4">
            <div>
                <p className="text-muted-foreground mb-2 text-xs font-semibold tracking-wide uppercase">Detail</p>
                {selected && selectedType && selectedLevel ? (
                    <div className="border-border/60 bg-accent/30 rounded-lg border p-3 text-sm">
                        <p className="font-semibold">{selectedType.name}</p>
                        <p className="text-muted-foreground text-xs">
                            Level {selectedLevel.level} · {(() => {
                                const { width, height } = levelFootprint(selectedType, selectedLevel);

                                return `${width}×${height}`;
                            })()}{' '}
                            tile
                        </p>
                    </div>
                ) : state.selectedIds.length > 1 ? (
                    <p className="text-muted-foreground text-xs">{state.selectedIds.length} bangunan dipilih.</p>
                ) : (
                    <p className="text-muted-foreground text-xs">Klik bangunan di grid untuk lihat detail.</p>
                )}
            </div>

            <div className="space-y-2">
                <p className="text-muted-foreground text-xs font-semibold tracking-wide uppercase">Tampilan</p>
                <label className="flex items-center justify-between text-sm">
                    Grid
                    <Switch checked={state.showGrid} onCheckedChange={() => dispatch({ type: 'TOGGLE_GRID' })} />
                </label>
                <label className="flex items-center justify-between text-sm">
                    Footprint
                    <Switch checked={state.showFootprint} onCheckedChange={() => dispatch({ type: 'TOGGLE_FOOTPRINT' })} />
                </label>
            </div>
        </div>
    );
}
