import { Link } from '@inertiajs/react';
import {
    ArrowCounterClockwiseIcon,
    ArrowUUpLeftIcon,
    ArrowUUpRightIcon,
    DiamondIcon,
    FolderOpenIcon,
    FloppyDiskIcon,
    MinusIcon,
    PlusIcon,
    ShareNetworkIcon,
} from '@phosphor-icons/react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Slider } from '@/components/ui/slider';
import { home } from '@/routes';
import { useEditor } from './EditorProvider';

type Props = {
    onSave: () => void;
    onOpenLayouts: () => void;
    onShare: () => void;
    saving: boolean;
};

export function EditorToolbar({
    onSave,
    onOpenLayouts,
    onShare,
    saving,
}: Props) {
    const { state, dispatch, zoomDisplay, zoomActionsRef } = useEditor();

    return (
        <header className="coc-topbar">
            <div className="coc-topbar-inner">
                <Link href={home()} className="coc-studio-brand">
                    <span className="coc-brand-mark">
                        <DiamondIcon weight="duotone" />
                    </span>
                    <span className="coc-brand-copy">
                        <strong>Base Atelier</strong>
                        <small>Clash Layout Studio</small>
                    </span>
                </Link>

                <Input
                    value={state.layoutTitle}
                    onChange={(e) =>
                        dispatch({ type: 'SET_TITLE', title: e.target.value })
                    }
                    disabled={state.readOnly}
                    className="coc-title-input"
                    aria-label="Judul layout"
                />

                {!state.readOnly && (
                    <div className="coc-top-actions">
                        <Button
                            size="sm"
                            variant="outline"
                            onClick={onOpenLayouts}
                            className="coc-btn-secondary"
                        >
                            <FolderOpenIcon className="size-3.5" />
                            Buka
                        </Button>
                        <Button
                            size="sm"
                            onClick={onSave}
                            disabled={saving}
                            className="coc-btn-primary"
                        >
                            <FloppyDiskIcon className="size-3.5" />
                            {saving ? 'Menyimpan...' : 'Simpan'}
                        </Button>
                        <Button
                            size="sm"
                            variant="outline"
                            onClick={onShare}
                            className="coc-btn-secondary"
                        >
                            <ShareNetworkIcon className="size-3.5" />
                            Bagikan
                        </Button>
                        <span className="coc-toolbar-divider" />
                        <Button
                            size="sm"
                            variant="ghost"
                            disabled={state.historyIndex <= 0}
                            onClick={() => dispatch({ type: 'UNDO' })}
                            className="coc-icon-button"
                            title="Undo"
                        >
                            <ArrowUUpLeftIcon className="size-3.5" />
                        </Button>
                        <Button
                            size="sm"
                            variant="ghost"
                            disabled={
                                state.historyIndex >= state.history.length - 1
                            }
                            onClick={() => dispatch({ type: 'REDO' })}
                            className="coc-icon-button"
                            title="Redo"
                        >
                            <ArrowUUpRightIcon className="size-3.5" />
                        </Button>
                        <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => dispatch({ type: 'RESET' })}
                            className="coc-icon-button"
                            title="Reset layout"
                        >
                            <ArrowCounterClockwiseIcon className="size-3.5" />
                        </Button>
                    </div>
                )}

                <div className="coc-topbar-right">
                    <div className="coc-zoom-control">
                        <Button
                            size="icon"
                            variant="ghost"
                            onClick={() =>
                                zoomActionsRef.current?.setZoomPercent(
                                    zoomDisplay - 25,
                                )
                            }
                        >
                            <MinusIcon className="size-3.5" />
                        </Button>
                        <Slider
                            min={100}
                            max={1000}
                            step={10}
                            value={[zoomDisplay]}
                            onValueChange={([v]) =>
                                zoomActionsRef.current?.setZoomPercent(v)
                            }
                            className="coc-zoom-slider"
                        />
                        <Button
                            size="icon"
                            variant="ghost"
                            onClick={() =>
                                zoomActionsRef.current?.setZoomPercent(
                                    zoomDisplay + 25,
                                )
                            }
                        >
                            <PlusIcon className="size-3.5" />
                        </Button>
                        <span>{zoomDisplay}%</span>
                    </div>
                </div>
            </div>
        </header>
    );
}
