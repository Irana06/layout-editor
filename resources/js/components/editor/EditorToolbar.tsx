import { Link } from '@inertiajs/react';
import {
    ArrowCounterClockwiseIcon,
    ArrowUUpLeftIcon,
    ArrowUUpRightIcon,
    DiamondIcon,
    FolderOpenIcon,
    FloppyDiskIcon,
    MinusIcon,
    MoonIcon,
    PlusIcon,
    ShareNetworkIcon,
    SunIcon,
} from '@phosphor-icons/react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Slider } from '@/components/ui/slider';
import { useAppearance } from '@/hooks/use-appearance';
import { home } from '@/routes';
import { useEditor } from './EditorProvider';

type Props = {
    onSave: () => void;
    onOpenLayouts: () => void;
    onShare: () => void;
    saving: boolean;
};

function ThemeToggle() {
    const { resolvedAppearance, updateAppearance } = useAppearance();
    const isDark = resolvedAppearance === 'dark';

    return (
        <button
            type="button"
            onClick={() => updateAppearance(isDark ? 'light' : 'dark')}
            className="border-border/60 bg-card/60 flex size-9 items-center justify-center rounded-full border"
            aria-label="Ganti tema terang/gelap"
        >
            {isDark ? <SunIcon className="size-4" /> : <MoonIcon className="size-4" />}
        </button>
    );
}

export function EditorToolbar({ onSave, onOpenLayouts, onShare, saving }: Props) {
    const { state, dispatch, zoomDisplay, zoomActionsRef } = useEditor();

    return (
        <header className="border-border/60 bg-background/80 sticky top-0 z-40 border-b backdrop-blur-md">
            <div className="mx-auto flex max-w-[1600px] flex-wrap items-center gap-3 px-5 py-3">
                <Link href={home()} className="flex shrink-0 items-center gap-2">
                    <span className="bg-primary text-primary-foreground flex size-8 items-center justify-center rounded-lg">
                        <DiamondIcon weight="fill" className="size-4" />
                    </span>
                </Link>

                <Input
                    value={state.layoutTitle}
                    onChange={(e) => dispatch({ type: 'SET_TITLE', title: e.target.value })}
                    disabled={state.readOnly}
                    className="w-40 shrink-0"
                    aria-label="Judul layout"
                />

                {!state.readOnly && (
                    <div className="flex shrink-0 items-center gap-1.5">
                        <Button size="sm" variant="outline" onClick={onOpenLayouts} className="rounded-full">
                            <FolderOpenIcon className="size-3.5" />
                            Buka
                        </Button>
                        <Button size="sm" onClick={onSave} disabled={saving} className="rounded-full">
                            <FloppyDiskIcon className="size-3.5" />
                            {saving ? 'Menyimpan...' : 'Simpan'}
                        </Button>
                        <Button size="sm" variant="outline" onClick={onShare} className="rounded-full">
                            <ShareNetworkIcon className="size-3.5" />
                            Bagikan
                        </Button>
                        <Button
                            size="sm"
                            variant="ghost"
                            disabled={state.historyIndex <= 0}
                            onClick={() => dispatch({ type: 'UNDO' })}
                            className="rounded-full"
                        >
                            <ArrowUUpLeftIcon className="size-3.5" />
                        </Button>
                        <Button
                            size="sm"
                            variant="ghost"
                            disabled={state.historyIndex >= state.history.length - 1}
                            onClick={() => dispatch({ type: 'REDO' })}
                            className="rounded-full"
                        >
                            <ArrowUUpRightIcon className="size-3.5" />
                        </Button>
                        <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => dispatch({ type: 'RESET' })}
                            className="rounded-full"
                            title="Reset layout"
                        >
                            <ArrowCounterClockwiseIcon className="size-3.5" />
                        </Button>
                    </div>
                )}

                <div className="ml-auto flex shrink-0 items-center gap-3">
                    <div className="hidden items-center gap-2 sm:flex">
                        <Button size="icon" variant="ghost" onClick={() => zoomActionsRef.current?.setZoomPercent(zoomDisplay - 25)}>
                            <MinusIcon className="size-3.5" />
                        </Button>
                        <Slider
                            min={100}
                            max={1000}
                            step={10}
                            value={[zoomDisplay]}
                            onValueChange={([v]) => zoomActionsRef.current?.setZoomPercent(v)}
                            className="w-28"
                        />
                        <Button size="icon" variant="ghost" onClick={() => zoomActionsRef.current?.setZoomPercent(zoomDisplay + 25)}>
                            <PlusIcon className="size-3.5" />
                        </Button>
                        <span className="text-muted-foreground w-10 text-xs tabular-nums">{zoomDisplay}%</span>
                    </div>
                    <ThemeToggle />
                </div>
            </div>
        </header>
    );
}
