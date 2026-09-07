import { Head, Link } from '@inertiajs/react';
import { DiamondIcon, MoonIcon, SunIcon } from '@phosphor-icons/react';
import { useMemo, useState } from 'react';
import { BuildingLevelCalibrationPanel } from '@/components/calibrate/BuildingLevelCalibrationPanel';
import { BuildingTypeAccordion } from '@/components/calibrate/BuildingTypeAccordion';
import { SceneryCalibrationPanel } from '@/components/calibrate/SceneryCalibrationPanel';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { useAppearance } from '@/hooks/use-appearance';
import { apiFetch } from '@/lib/api';
import { home } from '@/routes';
import buildingLevelRoutes from '@/routes/building-levels';
import type { BuildingLevel, BuildingType, Scenery } from '@/types/game';

type Props = {
    sceneries: Scenery[];
    buildingTypes: BuildingType[];
};

function ThemeToggle() {
    const { resolvedAppearance, updateAppearance } = useAppearance();
    const isDark = resolvedAppearance === 'dark';

    return (
        <button
            type="button"
            onClick={() => updateAppearance(isDark ? 'light' : 'dark')}
            className="flex size-9 items-center justify-center rounded-full border border-border/60 bg-card/60"
            aria-label="Ganti tema terang/gelap"
        >
            {isDark ? (
                <SunIcon className="size-4" />
            ) : (
                <MoonIcon className="size-4" />
            )}
        </button>
    );
}

export default function Calibrate({
    sceneries,
    buildingTypes: initialBuildingTypes,
}: Props) {
    const [calibratedSceneries, setCalibratedSceneries] = useState(sceneries);
    const [buildingTypes, setBuildingTypes] = useState(initialBuildingTypes);
    const [selectedTypeId, setSelectedTypeId] = useState<number | null>(null);
    const [selectedLevelId, setSelectedLevelId] = useState<number | null>(null);

    const selectedType = useMemo(
        () => buildingTypes.find((t) => t.id === selectedTypeId) ?? null,
        [buildingTypes, selectedTypeId],
    );
    const selectedLevel = useMemo(
        () =>
            selectedType?.levels.find((l) => l.id === selectedLevelId) ?? null,
        [selectedType, selectedLevelId],
    );

    /** `type` is present when the save also changed the shared footprint, in which
     * case every sibling level inherits the new tile size too. */
    const handleLevelUpdated = (
        updated: BuildingLevel,
        type: BuildingType | null,
    ) => {
        setBuildingTypes((types) =>
            types.map((t) =>
                t.id !== updated.building_type_id
                    ? t
                    : {
                          ...t,
                          default_grid_width:
                              type?.default_grid_width ?? t.default_grid_width,
                          default_grid_height:
                              type?.default_grid_height ??
                              t.default_grid_height,
                          levels: t.levels.map((l) =>
                              l.id === updated.id
                                  ? updated
                                  : type
                                    ? {
                                          ...l,
                                          grid_width: null,
                                          grid_height: null,
                                      }
                                    : l,
                          ),
                      },
            ),
        );
    };

    const handleAddLevel = async (
        typeId: number,
        level: number,
        file: File,
    ) => {
        const form = new FormData();
        form.append('level', String(level));
        form.append('image', file);
        const { buildingLevel } = await apiFetch<{
            buildingLevel: BuildingLevel;
        }>(buildingLevelRoutes.store(typeId), form);
        setBuildingTypes((types) =>
            types.map((t) => {
                if (t.id !== typeId) {
                    return t;
                }

                const withoutExisting = t.levels.filter(
                    (l) => l.level !== buildingLevel.level,
                );

                return {
                    ...t,
                    levels: [...withoutExisting, buildingLevel].sort(
                        (a, b) => a.level - b.level,
                    ),
                };
            }),
        );
        setSelectedLevelId(buildingLevel.id);
    };

    return (
        <>
            <Head title="Calibrate" />
            <div className="min-h-screen bg-background text-foreground">
                <header className="sticky top-0 z-40 border-b border-border/60 bg-background/80 backdrop-blur-md">
                    <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-4">
                        <Link href={home()} className="flex items-center gap-2">
                            <span className="flex size-8 items-center justify-center rounded-lg bg-primary text-primary-foreground">
                                <DiamondIcon weight="fill" className="size-4" />
                            </span>
                            <span className="text-lg font-bold tracking-tight">
                                Calibrate
                            </span>
                        </Link>
                        <ThemeToggle />
                    </div>
                </header>

                <main className="mx-auto max-w-7xl px-6 py-8">
                    <Tabs defaultValue="scenery">
                        <TabsList className="mb-6">
                            <TabsTrigger value="scenery">Scenery</TabsTrigger>
                            <TabsTrigger value="buildings">
                                Building Types & Levels
                            </TabsTrigger>
                        </TabsList>

                        <TabsContent value="scenery">
                            <SceneryCalibrationPanel
                                sceneries={calibratedSceneries}
                                onChange={setCalibratedSceneries}
                            />
                        </TabsContent>

                        <TabsContent value="buildings">
                            <div className="grid grid-cols-1 gap-6 lg:grid-cols-[280px_1fr]">
                                <BuildingTypeAccordion
                                    buildingTypes={buildingTypes}
                                    selectedTypeId={selectedTypeId}
                                    selectedLevelId={selectedLevelId}
                                    onSelectLevel={(typeId, levelId) => {
                                        setSelectedTypeId(typeId);
                                        setSelectedLevelId(levelId);
                                    }}
                                />
                                {selectedType && selectedLevel ? (
                                    <BuildingLevelCalibrationPanel
                                        key={selectedLevel.id}
                                        type={selectedType}
                                        level={selectedLevel}
                                        sceneries={calibratedSceneries}
                                        onUpdated={handleLevelUpdated}
                                        onAddLevel={handleAddLevel}
                                    />
                                ) : (
                                    <div className="flex items-center justify-center rounded-xl border border-dashed border-border/60 p-16 text-sm text-muted-foreground">
                                        Pilih building di sebelah kiri buat
                                        mulai kalibrasi.
                                    </div>
                                )}
                            </div>
                        </TabsContent>
                    </Tabs>
                </main>
            </div>
        </>
    );
}
