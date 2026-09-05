import { CaretDownIcon, CrownIcon } from '@phosphor-icons/react';
import { useMemo, useState } from 'react';
import {
    Collapsible,
    CollapsibleContent,
    CollapsibleTrigger,
} from '@/components/ui/collapsible';
import { gameAssetUrl } from '@/lib/game-assets';
import type { BuildingType } from '@/types/game';

type Props = {
    buildingTypes: BuildingType[];
    selectedTypeId: number | null;
    selectedLevelId: number | null;
    onSelectLevel: (typeId: number, levelId: number) => void;
};

export function BuildingTypeAccordion({
    buildingTypes,
    selectedTypeId,
    selectedLevelId,
    onSelectLevel,
}: Props) {
    const [search, setSearch] = useState('');

    const grouped = useMemo(() => {
        const filtered = search.trim()
            ? buildingTypes.filter((t) =>
                  t.name.toLowerCase().includes(search.trim().toLowerCase()),
              )
            : buildingTypes;

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

    return (
        <div className="space-y-3">
            <input
                type="text"
                placeholder="Cari building..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="w-full rounded-md border border-input bg-background px-3 py-1.5 text-sm"
            />
            <div className="max-h-[640px] space-y-1 overflow-y-auto pr-1">
                {[...grouped.entries()].map(([category, bySub]) => (
                    <Collapsible key={category} defaultOpen>
                        <CollapsibleTrigger className="flex w-full items-center justify-between py-1.5 text-xs font-semibold tracking-wide text-muted-foreground uppercase hover:text-foreground">
                            {category}
                            <CaretDownIcon className="size-3.5" />
                        </CollapsibleTrigger>
                        <CollapsibleContent className="space-y-2 pl-2">
                            {[...bySub.entries()].map(([sub, types]) => (
                                <Collapsible key={sub || '(root)'} defaultOpen>
                                    <CollapsibleTrigger className="flex w-full items-center justify-between py-1 text-xs text-muted-foreground hover:text-foreground">
                                        {sub || '(tanpa subfolder)'}
                                        <CaretDownIcon className="size-3" />
                                    </CollapsibleTrigger>
                                    <CollapsibleContent>
                                        <div className="grid grid-cols-2 gap-1.5 py-1 pl-2">
                                            {types.map((type) => (
                                                <div key={type.id}>
                                                    <button
                                                        type="button"
                                                        onClick={() =>
                                                            type.levels[0] &&
                                                            onSelectLevel(
                                                                type.id,
                                                                type.levels[0]
                                                                    .id,
                                                            )
                                                        }
                                                        className={`flex w-full items-center gap-1.5 rounded-md border px-2 py-1 text-left text-xs transition-colors ${
                                                            selectedTypeId ===
                                                            type.id
                                                                ? 'border-primary bg-accent/60'
                                                                : 'border-border/60 hover:border-primary/50'
                                                        }`}
                                                    >
                                                        {type.is_town_hall && (
                                                            <CrownIcon
                                                                weight="fill"
                                                                className="size-3 shrink-0 text-primary"
                                                            />
                                                        )}
                                                        <span className="truncate">
                                                            {type.name}
                                                        </span>
                                                        <span className="ml-auto shrink-0 text-muted-foreground">
                                                            {type.levels.length}
                                                        </span>
                                                    </button>
                                                    {selectedTypeId ===
                                                        type.id && (
                                                        <div className="mt-1 flex flex-wrap gap-1 pl-1">
                                                            {type.levels.map(
                                                                (level) => (
                                                                    <button
                                                                        key={
                                                                            level.id
                                                                        }
                                                                        type="button"
                                                                        onClick={() =>
                                                                            onSelectLevel(
                                                                                type.id,
                                                                                level.id,
                                                                            )
                                                                        }
                                                                        className={`overflow-hidden rounded border text-[10px] ${
                                                                            selectedLevelId ===
                                                                            level.id
                                                                                ? 'border-primary'
                                                                                : 'border-border/60'
                                                                        }`}
                                                                        title={`Level ${level.level}`}
                                                                    >
                                                                        <img
                                                                            src={gameAssetUrl(
                                                                                level.file_path,
                                                                            )}
                                                                            alt=""
                                                                            loading="lazy"
                                                                            className="size-8 object-contain"
                                                                        />
                                                                    </button>
                                                                ),
                                                            )}
                                                        </div>
                                                    )}
                                                </div>
                                            ))}
                                        </div>
                                    </CollapsibleContent>
                                </Collapsible>
                            ))}
                        </CollapsibleContent>
                    </Collapsible>
                ))}
            </div>
        </div>
    );
}
