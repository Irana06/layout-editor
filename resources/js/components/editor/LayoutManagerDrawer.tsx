import { CopySimpleIcon, TrashIcon } from '@phosphor-icons/react';
import { useEffect, useState } from 'react';
import { Button } from '@/components/ui/button';
import {
    Sheet,
    SheetContent,
    SheetHeader,
    SheetTitle,
} from '@/components/ui/sheet';
import { apiFetch } from '@/lib/api';
import layoutRoutes from '@/routes/layouts';
import type { ServerLayout } from '@/types/game';

type Props = {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    onOpenLayout: (layout: ServerLayout) => void;
};

export function LayoutManagerDrawer({
    open,
    onOpenChange,
    onOpenLayout,
}: Props) {
    const [layouts, setLayouts] = useState<ServerLayout[] | null>(null);
    const [busyId, setBusyId] = useState<string | null>(null);

    useEffect(() => {
        if (!open) {
            return;
        }

        apiFetch<{ layouts: ServerLayout[] }>(layoutRoutes.index()).then(
            (res) => setLayouts(res.layouts),
        );
    }, [open]);

    const remove = async (layout: ServerLayout) => {
        setBusyId(layout.id);

        try {
            await apiFetch(layoutRoutes.destroy(layout.id));
            setLayouts(
                (list) => list?.filter((l) => l.id !== layout.id) ?? null,
            );
        } finally {
            setBusyId(null);
        }
    };

    const duplicate = async (layout: ServerLayout) => {
        setBusyId(layout.id);

        try {
            const { layout: copy } = await apiFetch<{ layout: ServerLayout }>(
                layoutRoutes.duplicate(layout.id),
            );
            setLayouts((list) => (list ? [copy, ...list] : [copy]));
        } finally {
            setBusyId(null);
        }
    };

    return (
        <Sheet open={open} onOpenChange={onOpenChange}>
            <SheetContent>
                <SheetHeader>
                    <SheetTitle>Layout Tersimpan</SheetTitle>
                </SheetHeader>
                <div className="flex-1 space-y-2 overflow-y-auto px-4">
                    {layouts === null && (
                        <p className="text-sm text-muted-foreground">
                            Memuat...
                        </p>
                    )}
                    {layouts?.length === 0 && (
                        <p className="text-sm text-muted-foreground">
                            Belum ada layout tersimpan di sesi ini.
                        </p>
                    )}
                    {layouts?.map((layout) => (
                        <div
                            key={layout.id}
                            className="rounded-lg border border-border/60 p-3"
                        >
                            <div className="flex items-start justify-between gap-2">
                                <button
                                    type="button"
                                    onClick={() => onOpenLayout(layout)}
                                    className="min-w-0 flex-1 text-left"
                                >
                                    <p className="truncate text-sm font-semibold">
                                        {layout.title}
                                    </p>
                                    <p className="text-xs text-muted-foreground">
                                        TH{layout.th_level} ·{' '}
                                        {layout.data.length} bangunan
                                    </p>
                                </button>
                                <div className="flex shrink-0 gap-1">
                                    <Button
                                        size="icon"
                                        variant="ghost"
                                        disabled={busyId === layout.id}
                                        onClick={() => void duplicate(layout)}
                                    >
                                        <CopySimpleIcon className="size-3.5" />
                                    </Button>
                                    <Button
                                        size="icon"
                                        variant="ghost"
                                        disabled={busyId === layout.id}
                                        onClick={() => void remove(layout)}
                                    >
                                        <TrashIcon className="size-3.5" />
                                    </Button>
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            </SheetContent>
        </Sheet>
    );
}
