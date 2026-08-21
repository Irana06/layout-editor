import { Head } from '@inertiajs/react';
import { useCallback, useEffect, useState } from 'react';
import { BuildingPalette } from '@/components/editor/BuildingPalette';
import { EditorProvider, useEditor } from '@/components/editor/EditorProvider';
import { EditorToolbar } from '@/components/editor/EditorToolbar';
import { IsometricCanvas } from '@/components/editor/IsometricCanvas';
import { LayoutManagerDrawer } from '@/components/editor/LayoutManagerDrawer';
import { ScenerySelector } from '@/components/editor/ScenerySelector';
import { SelectedBuildingPanel } from '@/components/editor/SelectedBuildingPanel';
import { TownHallLevelSelector } from '@/components/editor/TownHallLevelSelector';
import { apiFetch } from '@/lib/api';
import { uid } from '@/lib/uid';
import layoutRoutes from '@/routes/layouts';
import type { BuildingType, BuildingUnlockRule, Scenery, ServerLayout } from '@/types/game';

type Props = {
    sceneries: Scenery[];
    buildingTypes: BuildingType[];
    unlockRules: BuildingUnlockRule[];
    sharedLayout: ServerLayout | null;
    readOnly: boolean;
};

function EditorWorkspace({ sceneries, buildingTypes, unlockRules }: Omit<Props, 'readOnly' | 'sharedLayout'>) {
    const { state, dispatch } = useEditor();
    const [drawerOpen, setDrawerOpen] = useState(false);
    const [saving, setSaving] = useState(false);

    const loadLayout = useCallback(
        (layout: ServerLayout) => {
            dispatch({
                type: 'LOAD_LAYOUT',
                layoutId: layout.id,
                layoutTitle: layout.title,
                thLevel: layout.th_level,
                sceneryId: layout.scenery_id,
                placements: layout.data.map((p) => ({
                    uid: uid(),
                    buildingTypeId: p.building_type_id,
                    level: p.level,
                    gx: p.gx,
                    gy: p.gy,
                })),
                shareEnabled: layout.share_enabled,
                shareSlug: layout.share_slug,
            });
            dispatch({ type: 'SET_STATUS', status: `Layout "${layout.title}" dimuat.` });
            setDrawerOpen(false);
        },
        [dispatch],
    );

    const save = useCallback(async (): Promise<ServerLayout | null> => {
        if (!state.sceneryId) {
            dispatch({ type: 'SET_STATUS', status: 'Pilih scenery dulu sebelum menyimpan.' });

            return null;
        }

        setSaving(true);

        try {
            const payload = {
                title: state.layoutTitle,
                th_level: state.thLevel,
                scenery_id: state.sceneryId,
                data: state.placements.map((p) => ({ building_type_id: p.buildingTypeId, level: p.level, gx: p.gx, gy: p.gy })),
            };
            const route = state.layoutId ? layoutRoutes.update(state.layoutId) : layoutRoutes.store();
            const { layout } = await apiFetch<{ layout: ServerLayout }>(route, payload);
            dispatch({ type: 'SET_LAYOUT_ID', layoutId: layout.id });
            dispatch({ type: 'SET_STATUS', status: 'Layout tersimpan.' });

            return layout;
        } catch (error) {
            dispatch({ type: 'SET_STATUS', status: error instanceof Error ? error.message : 'Gagal menyimpan layout.' });

            return null;
        } finally {
            setSaving(false);
        }
    }, [state.sceneryId, state.layoutTitle, state.thLevel, state.placements, state.layoutId, dispatch]);

    const share = useCallback(async () => {
        const layout = state.layoutId ? { id: state.layoutId } : await save();

        if (!layout) {
return;
}

        try {
            const { share_url: shareUrl } = await apiFetch<{ share_url: string | null }>(layoutRoutes.share(layout.id), { share_enabled: true });

            if (shareUrl) {
                await navigator.clipboard.writeText(shareUrl);
                dispatch({ type: 'SET_STATUS', status: 'Link publik disalin ke clipboard.' });
            }
        } catch (error) {
            dispatch({ type: 'SET_STATUS', status: error instanceof Error ? error.message : 'Gagal membuat link share.' });
        }
    }, [state.layoutId, save, dispatch]);

    useEffect(() => {
        const onKey = (e: KeyboardEvent) => {
            if (e.target instanceof HTMLInputElement || state.readOnly) {
return;
}

            if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') {
                e.preventDefault();
                dispatch({ type: e.shiftKey ? 'REDO' : 'UNDO' });
            }

            if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'y') {
                e.preventDefault();
                dispatch({ type: 'REDO' });
            }

            if ((e.key === 'Delete' || e.key === 'Backspace') && state.selectedIds.length) {
                dispatch({ type: 'COMMIT_PLACEMENTS', placements: state.placements.filter((p) => !state.selectedIds.includes(p.uid)) });
                dispatch({ type: 'SELECT', ids: [] });
            }

            if (e.key === 'Escape') {
                dispatch({ type: 'DISARM' });
                dispatch({ type: 'SELECT', ids: [] });
            }
        };
        window.addEventListener('keydown', onKey);

        return () => window.removeEventListener('keydown', onKey);
    }, [state.placements, state.selectedIds, state.readOnly, dispatch]);

    return (
        <div className="bg-background text-foreground min-h-screen">
            <EditorToolbar onSave={() => void save()} onOpenLayouts={() => setDrawerOpen(true)} onShare={() => void share()} saving={saving} />

            <div className="mx-auto grid max-w-[1600px] gap-4 px-5 py-4 lg:grid-cols-[260px_minmax(0,1fr)_260px]">
                <aside className="space-y-5 lg:order-1">
                    <ScenerySelector sceneries={sceneries} />
                    <TownHallLevelSelector buildingTypes={buildingTypes} />
                    <BuildingPalette buildingTypes={buildingTypes} unlockRules={unlockRules} />
                </aside>

                <div className="space-y-2 lg:order-2">
                    <div className="text-muted-foreground flex items-center justify-between text-xs">
                        <span>{state.status}</span>
                        <span>{state.placements.length} bangunan</span>
                    </div>
                    <IsometricCanvas buildingTypes={buildingTypes} sceneries={sceneries} />
                </div>

                <aside className="lg:order-3">
                    <SelectedBuildingPanel buildingTypes={buildingTypes} />
                </aside>
            </div>

            <LayoutManagerDrawer open={drawerOpen} onOpenChange={setDrawerOpen} onOpenLayout={loadLayout} />
        </div>
    );
}

export default function Editor({ sceneries, buildingTypes, unlockRules, sharedLayout, readOnly }: Props) {
    // Computed once up front (not in a post-mount effect) so the reducer's initial state
    // already reflects the shared/loaded layout or a sensible default scenery.
    const initial = sharedLayout
        ? {
              readOnly,
              layoutId: sharedLayout.id,
              layoutTitle: sharedLayout.title,
              thLevel: sharedLayout.th_level,
              sceneryId: sharedLayout.scenery_id,
              placements: sharedLayout.data.map((p) => ({
                  uid: uid(),
                  buildingTypeId: p.building_type_id,
                  level: p.level,
                  gx: p.gx,
                  gy: p.gy,
              })),
              shareEnabled: sharedLayout.share_enabled,
              shareSlug: sharedLayout.share_slug,
              status: 'Menampilkan layout publik (read-only).',
          }
        : {
              readOnly,
              sceneryId: sceneries[0]?.id ?? null,
              status: 'Pilih bangunan untuk mulai membangun.',
          };

    return (
        <>
            <Head title={readOnly ? `${sharedLayout?.title ?? 'Layout'} — Base Layout Editor` : 'Editor'} />
            <EditorProvider initial={initial}>
                <EditorWorkspace sceneries={sceneries} buildingTypes={buildingTypes} unlockRules={unlockRules} />
            </EditorProvider>
        </>
    );
}
