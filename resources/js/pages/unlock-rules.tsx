import { Head, Link } from '@inertiajs/react';
import {
    CheckCircleIcon,
    CopySimpleIcon,
    DiamondIcon,
    MoonIcon,
    SunIcon,
} from '@phosphor-icons/react';
import { useMemo, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useAppearance } from '@/hooks/use-appearance';
import { apiFetch } from '@/lib/api';
import { gameAssetUrl } from '@/lib/game-assets';
import { calibrate, editor, home } from '@/routes';
import buildingUnlockRules from '@/routes/building-unlock-rules';
import type { BuildingType, BuildingUnlockRule } from '@/types/game';

type Props = {
    buildingTypes: BuildingType[];
    unlockRules: BuildingUnlockRule[];
    townHallLevels: number[];
};

/** Editable state for one building row: '' means unset/unlimited rather than 0. */
type Draft = { maxLevel: number; maxCount: number | '' };

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

function buildDrafts(
    buildingTypes: BuildingType[],
    rules: BuildingUnlockRule[],
    thLevel: number,
): Record<number, Draft> {
    const drafts: Record<number, Draft> = {};

    for (const type of buildingTypes) {
        const rule = rules.find(
            (r) => r.building_type_id === type.id && r.th_level === thLevel,
        );
        drafts[type.id] = {
            maxLevel: rule?.max_building_level ?? 0,
            maxCount: rule?.max_count ?? '',
        };
    }

    return drafts;
}

export default function UnlockRules({
    buildingTypes,
    unlockRules: initialRules,
    townHallLevels,
}: Props) {
    const [rules, setRules] = useState(initialRules);
    const [thLevel, setThLevel] = useState(townHallLevels[0] ?? 1);
    const [saving, setSaving] = useState(false);
    const [status, setStatus] = useState<string | null>(null);

    // Town Hall itself isn't placeable from the palette, so it needs no unlock rule.
    const placeable = useMemo(
        () =>
            buildingTypes.filter((t) => !t.is_town_hall && t.levels.length > 0),
        [buildingTypes],
    );

    const [drafts, setDrafts] = useState<Record<number, Draft>>(() =>
        buildDrafts(placeable, initialRules, townHallLevels[0] ?? 1),
    );

    const switchTh = (next: number) => {
        setThLevel(next);
        setDrafts(buildDrafts(placeable, rules, next));
        setStatus(null);
    };

    const setDraft = (typeId: number, patch: Partial<Draft>) => {
        setDrafts((current) => ({
            ...current,
            [typeId]: { ...current[typeId], ...patch },
        }));
    };

    /** Progression between adjacent Town Halls is usually a small delta, so seeding from
     *  the previous level saves most of the typing. */
    const copyFromPrevious = () => {
        const previous = thLevel - 1;
        setDrafts(buildDrafts(placeable, rules, previous));
        setStatus(
            `Disalin dari TH${previous} — cek dan sesuaikan, lalu simpan.`,
        );
    };

    const unlockedCount = useMemo(
        () => Object.values(drafts).filter((d) => d.maxLevel > 0).length,
        [drafts],
    );

    const save = async () => {
        setSaving(true);
        setStatus(null);

        try {
            const payload = {
                th_level: thLevel,
                rules: placeable.map((type) => ({
                    building_type_id: type.id,
                    max_building_level: drafts[type.id]?.maxLevel ?? 0,
                    max_count:
                        drafts[type.id]?.maxCount === ''
                            ? null
                            : drafts[type.id].maxCount,
                })),
            };
            const { unlockRules: saved } = await apiFetch<{
                unlockRules: BuildingUnlockRule[];
            }>(buildingUnlockRules.bulk(), payload);

            setRules((current) => [
                ...current.filter((r) => r.th_level !== thLevel),
                ...saved,
            ]);
            setStatus(
                `Tersimpan — ${unlockedCount} bangunan terbuka di TH${thLevel}.`,
            );
        } catch (error) {
            setStatus(
                error instanceof Error
                    ? error.message
                    : 'Gagal menyimpan aturan.',
            );
        } finally {
            setSaving(false);
        }
    };

    const grouped = useMemo(() => {
        const byCategory = new Map<string, BuildingType[]>();

        for (const type of placeable) {
            if (!byCategory.has(type.category)) {
                byCategory.set(type.category, []);
            }

            byCategory.get(type.category)!.push(type);
        }

        return byCategory;
    }, [placeable]);

    const configuredThLevels = useMemo(
        () =>
            new Set(
                rules
                    .filter((r) => r.max_building_level > 0)
                    .map((r) => r.th_level),
            ),
        [rules],
    );

    return (
        <>
            <Head title="Unlock Rules" />
            <div className="min-h-screen bg-background text-foreground">
                <header className="sticky top-0 z-40 border-b border-border/60 bg-background/80 backdrop-blur-md">
                    <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
                        <Link href={home()} className="flex items-center gap-2">
                            <span className="flex size-8 items-center justify-center rounded-lg bg-primary text-primary-foreground">
                                <DiamondIcon weight="fill" className="size-4" />
                            </span>
                            <span className="text-lg font-bold tracking-tight">
                                Unlock Rules
                            </span>
                        </Link>
                        <div className="flex items-center gap-4">
                            <Link
                                href={calibrate()}
                                className="text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"
                            >
                                Calibrate
                            </Link>
                            <Link
                                href={editor()}
                                className="text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"
                            >
                                Editor
                            </Link>
                            <ThemeToggle />
                        </div>
                    </div>
                </header>

                <main className="mx-auto max-w-6xl px-6 py-8">
                    <div className="mb-6">
                        <p className="mb-2 text-xs font-semibold tracking-wide text-muted-foreground uppercase">
                            Pilih Town Hall
                        </p>
                        <div className="flex flex-wrap gap-2">
                            {townHallLevels.map((level) => (
                                <button
                                    key={level}
                                    type="button"
                                    onClick={() => switchTh(level)}
                                    className={`relative rounded-xl border px-3 py-2 text-sm font-semibold transition-colors ${
                                        thLevel === level
                                            ? 'border-primary bg-accent/60 ring-2 ring-primary/40'
                                            : 'border-border/60 hover:border-primary/50'
                                    }`}
                                >
                                    TH{level}
                                    {configuredThLevels.has(level) && (
                                        <CheckCircleIcon
                                            weight="fill"
                                            className="absolute -top-1.5 -right-1.5 size-4 text-emerald-500"
                                        />
                                    )}
                                </button>
                            ))}
                        </div>
                    </div>

                    <div className="mb-6 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-border/60 bg-card/60 p-4">
                        <div className="text-sm">
                            <span className="font-semibold">TH{thLevel}</span>
                            <span className="text-muted-foreground">
                                {' '}
                                — {unlockedCount} dari {placeable.length}{' '}
                                bangunan terbuka
                            </span>
                        </div>
                        <div className="flex items-center gap-2">
                            {thLevel > 1 && (
                                <Button
                                    variant="outline"
                                    size="sm"
                                    className="rounded-full"
                                    onClick={copyFromPrevious}
                                >
                                    <CopySimpleIcon className="size-3.5" />
                                    Salin dari TH{thLevel - 1}
                                </Button>
                            )}
                            <Button
                                size="sm"
                                className="rounded-full"
                                disabled={saving}
                                onClick={() => void save()}
                            >
                                {saving
                                    ? 'Menyimpan...'
                                    : 'Simpan TH' + thLevel}
                            </Button>
                        </div>
                    </div>

                    {status && (
                        <p className="mb-6 rounded-lg border border-border/60 bg-accent/40 px-4 py-2 text-sm">
                            {status}
                        </p>
                    )}

                    <p className="mb-4 text-xs leading-relaxed text-muted-foreground">
                        <strong className="text-foreground">Max Level 0</strong>{' '}
                        = bangunan belum terbuka di TH ini (otomatis
                        ter-grey-out di editor).
                        <strong className="text-foreground">
                            {' '}
                            Max Jumlah
                        </strong>{' '}
                        dikosongkan = tidak dibatasi.
                    </p>

                    <div className="space-y-6">
                        {[...grouped.entries()].map(([category, types]) => (
                            <section key={category}>
                                <h2 className="mb-2 text-xs font-semibold tracking-wide text-muted-foreground uppercase">
                                    {category}
                                </h2>
                                <div className="divide-y divide-border/60 overflow-hidden rounded-xl border border-border/60">
                                    {types.map((type) => {
                                        const draft = drafts[type.id] ?? {
                                            maxLevel: 0,
                                            maxCount: '' as const,
                                        };
                                        const highestLevel =
                                            type.levels[type.levels.length - 1]
                                                ?.level ?? 1;
                                        const unlocked = draft.maxLevel > 0;

                                        return (
                                            <div
                                                key={type.id}
                                                className={`flex items-center gap-3 px-3 py-2 ${unlocked ? '' : 'bg-muted/30'}`}
                                            >
                                                <img
                                                    src={gameAssetUrl(
                                                        type.levels[0]
                                                            .file_path,
                                                    )}
                                                    alt=""
                                                    loading="lazy"
                                                    className={`size-9 shrink-0 object-contain ${unlocked ? '' : 'opacity-40 grayscale'}`}
                                                />
                                                <div className="min-w-0 flex-1">
                                                    <p
                                                        className={`truncate text-sm font-medium ${unlocked ? '' : 'text-muted-foreground'}`}
                                                    >
                                                        {type.name}
                                                    </p>
                                                    <p className="text-[11px] text-muted-foreground">
                                                        {type.subfolder ?? '—'}{' '}
                                                        · tersedia s/d Lv
                                                        {highestLevel}
                                                    </p>
                                                </div>
                                                <label className="flex shrink-0 items-center gap-1.5 text-[11px]">
                                                    <span className="text-muted-foreground">
                                                        Max Lv
                                                    </span>
                                                    <Input
                                                        type="number"
                                                        min={0}
                                                        max={highestLevel}
                                                        value={draft.maxLevel}
                                                        onChange={(e) =>
                                                            setDraft(type.id, {
                                                                maxLevel:
                                                                    Number(
                                                                        e.target
                                                                            .value,
                                                                    ),
                                                            })
                                                        }
                                                        className="h-8 w-16"
                                                    />
                                                </label>
                                                <label className="flex shrink-0 items-center gap-1.5 text-[11px]">
                                                    <span className="text-muted-foreground">
                                                        Max Jml
                                                    </span>
                                                    <Input
                                                        type="number"
                                                        min={0}
                                                        placeholder="∞"
                                                        value={draft.maxCount}
                                                        onChange={(e) =>
                                                            setDraft(type.id, {
                                                                maxCount:
                                                                    e.target
                                                                        .value ===
                                                                    ''
                                                                        ? ''
                                                                        : Number(
                                                                              e
                                                                                  .target
                                                                                  .value,
                                                                          ),
                                                            })
                                                        }
                                                        className="h-8 w-16"
                                                    />
                                                </label>
                                            </div>
                                        );
                                    })}
                                </div>
                            </section>
                        ))}
                    </div>

                    <div className="mt-8 flex justify-end">
                        <Button
                            className="rounded-full"
                            disabled={saving}
                            onClick={() => void save()}
                        >
                            {saving ? 'Menyimpan...' : 'Simpan TH' + thLevel}
                        </Button>
                    </div>
                </main>
            </div>
        </>
    );
}
