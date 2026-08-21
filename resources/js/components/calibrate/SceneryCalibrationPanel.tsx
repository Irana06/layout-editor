import { CheckCircleIcon, LockIcon, LockOpenIcon, UploadSimpleIcon, WarningCircleIcon } from '@phosphor-icons/react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { apiFetch } from '@/lib/api';
import { gameAssetUrl } from '@/lib/game-assets';
import { defaultCamera, GRID_N_PRESETS, isoToScreen   } from '@/lib/iso-grid';
import type {Camera, GridCalibration} from '@/lib/iso-grid';
import sceneryRoutes from '@/routes/sceneries';
import type { Scenery } from '@/types/game';

const CANVAS_W = 760;
const CANVAS_H = 560;

type Draft = GridCalibration;

function draftFrom(scenery: Scenery): Draft {
    return { originX: scenery.origin_x, originY: scenery.origin_y, tileW: scenery.tile_w, tileH: scenery.tile_h, n: scenery.grid_n };
}

/** Owns the canvas + calibration form for exactly one scenery. Mounted with `key={scenery.id}`
 * by the parent so switching scenery gives it a clean slate via lazy initial state, instead of
 * an effect resetting state on prop change. */
function SceneryDetailPanel({ scenery, onSaved }: { scenery: Scenery; onSaved: (scenery: Scenery) => void }) {
    const [mode, setMode] = useState<'view' | 'grid'>('view');
    const [draft, setDraft] = useState<Draft>(() => draftFrom(scenery));
    const [camera, setCamera] = useState<Camera>(defaultCamera());
    const [saving, setSaving] = useState(false);

    const canvasRef = useRef<HTMLCanvasElement>(null);
    const imageRef = useRef<HTMLImageElement | null>(null);
    const dragState = useRef<{ dragging: boolean; moved: boolean; lastX: number; lastY: number }>({ dragging: false, moved: false, lastX: 0, lastY: 0 });

    useEffect(() => {
        const img = new Image();
        img.onload = () => {
            imageRef.current = img;
            const fit = Math.min(CANVAS_W / img.naturalWidth, CANVAS_H / img.naturalHeight, 1);
            setCamera({ x: img.naturalWidth / 2, y: img.naturalHeight / 2, zoom: fit || 1 });
        };
        img.src = gameAssetUrl(scenery.file_path);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    const draw = useCallback(() => {
        const canvas = canvasRef.current;
        const ctx = canvas?.getContext('2d');

        if (!canvas || !ctx) {
return;
}

        ctx.fillStyle = '#000';
        ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

        const img = imageRef.current;

        if (img?.complete && img.naturalWidth) {
            const s = camera.zoom;
            const topLeftScreen = { x: CANVAS_W / 2 + (0 - camera.x) * s, y: CANVAS_H / 2 + (0 - camera.y) * s };
            ctx.drawImage(img, topLeftScreen.x, topLeftScreen.y, img.naturalWidth * s, img.naturalHeight * s);
        }

        ctx.strokeStyle = mode === 'grid' ? 'rgba(255,182,72,0.55)' : 'rgba(255,255,255,0.28)';
        ctx.lineWidth = Math.max(1, camera.zoom * 0.6);

        for (let gx = 0; gx <= draft.n; gx++) {
            const p1 = isoToScreen(draft, camera, CANVAS_W, CANVAS_H, gx, 0);
            const p2 = isoToScreen(draft, camera, CANVAS_W, CANVAS_H, gx, draft.n);
            ctx.beginPath();
            ctx.moveTo(p1.x, p1.y);
            ctx.lineTo(p2.x, p2.y);
            ctx.stroke();
        }

        for (let gy = 0; gy <= draft.n; gy++) {
            const p1 = isoToScreen(draft, camera, CANVAS_W, CANVAS_H, 0, gy);
            const p2 = isoToScreen(draft, camera, CANVAS_W, CANVAS_H, draft.n, gy);
            ctx.beginPath();
            ctx.moveTo(p1.x, p1.y);
            ctx.lineTo(p2.x, p2.y);
            ctx.stroke();
        }

        if (mode === 'grid') {
            const origin = isoToScreen(draft, camera, CANVAS_W, CANVAS_H, 0, 0);
            ctx.beginPath();
            ctx.arc(origin.x, origin.y, 5, 0, Math.PI * 2);
            ctx.fillStyle = '#ffb648';
            ctx.fill();
        }
    }, [camera, draft, mode]);

    useEffect(() => {
        draw();
    }, [draw]);

    const locked = scenery.locked;

    const onMouseDown = (e: React.MouseEvent<HTMLCanvasElement>) => {
        dragState.current = { dragging: true, moved: false, lastX: e.clientX, lastY: e.clientY };
    };

    const onMouseMove = (e: React.MouseEvent<HTMLCanvasElement>) => {
        const drag = dragState.current;

        if (!drag.dragging) {
return;
}

        const dx = e.clientX - drag.lastX;
        const dy = e.clientY - drag.lastY;

        if (Math.abs(dx) > 2 || Math.abs(dy) > 2) {
drag.moved = true;
}

        if (!drag.moved) {
return;
}

        const s = camera.zoom;

        if (mode === 'grid' && !locked) {
            setDraft((d) => ({ ...d, originX: d.originX + dx / s, originY: d.originY + dy / s }));
        } else if (mode === 'view') {
            setCamera((c) => ({ ...c, x: c.x - dx / s, y: c.y - dy / s }));
        }

        drag.lastX = e.clientX;
        drag.lastY = e.clientY;
    };

    const onMouseUp = () => {
        dragState.current.dragging = false;
    };

    const onWheel = (e: React.WheelEvent<HTMLCanvasElement>) => {
        e.preventDefault();
        const factor = e.deltaY < 0 ? 1.15 : 1 / 1.15;
        setCamera((c) => ({ ...c, zoom: Math.min(10, Math.max(0.1, c.zoom * factor)) }));
    };

    const updateDraftField = (field: keyof Draft, value: number) => {
        setDraft((d) => ({ ...d, [field]: value }));
    };

    const save = async () => {
        setSaving(true);

        try {
            const { scenery: updated } = await apiFetch<{ scenery: Scenery }>(sceneryRoutes.update(scenery.id), {
                origin_x: draft.originX,
                origin_y: draft.originY,
                tile_w: draft.tileW,
                tile_h: draft.tileH,
                grid_n: draft.n,
                calibrated: true,
            });
            onSaved(updated);
        } finally {
            setSaving(false);
        }
    };

    const toggleLock = async () => {
        const { scenery: updated } = await apiFetch<{ scenery: Scenery }>(sceneryRoutes.update(scenery.id), { locked: !scenery.locked });
        onSaved(updated);

        if (!scenery.locked) {
setMode('view');
}
    };

    return (
        <>
            <div className="space-y-3">
                <div className="border-border/60 bg-card overflow-hidden rounded-xl border">
                    <canvas
                        ref={canvasRef}
                        width={CANVAS_W}
                        height={CANVAS_H}
                        className={mode === 'grid' ? 'cursor-move' : 'cursor-crosshair'}
                        onMouseDown={onMouseDown}
                        onMouseMove={onMouseMove}
                        onMouseUp={onMouseUp}
                        onMouseLeave={onMouseUp}
                        onWheel={onWheel}
                    />
                </div>
                <p className="text-muted-foreground text-xs">
                    Resolusi: {scenery.image_width} × {scenery.image_height}px
                </p>
            </div>

            <div className="space-y-4">
                <div className="flex items-center justify-between">
                    <div className="flex gap-1 rounded-lg border p-1">
                        <Button size="sm" variant={mode === 'view' ? 'default' : 'ghost'} onClick={() => setMode('view')} className="rounded-md">
                            Lihat
                        </Button>
                        <Button size="sm" variant={mode === 'grid' ? 'default' : 'ghost'} disabled={locked} onClick={() => setMode('grid')} className="rounded-md">
                            Kalibrasi
                        </Button>
                    </div>
                    <button
                        type="button"
                        onClick={() => void toggleLock()}
                        className={`flex items-center gap-1 rounded-full border px-2.5 py-1 text-xs font-medium ${locked ? 'border-amber-500 text-amber-500' : 'border-emerald-500 text-emerald-500'}`}
                    >
                        {locked ? <LockIcon className="size-3.5" /> : <LockOpenIcon className="size-3.5" />}
                        {locked ? 'Terkunci' : 'Terbuka'}
                    </button>
                </div>

                <fieldset disabled={locked} className="space-y-3 disabled:opacity-40">
                    <div className="grid grid-cols-2 gap-3">
                        <div className="space-y-1">
                            <Label className="text-xs">Origin X</Label>
                            <Input type="number" value={draft.originX} onChange={(e) => updateDraftField('originX', Number(e.target.value))} />
                        </div>
                        <div className="space-y-1">
                            <Label className="text-xs">Origin Y</Label>
                            <Input type="number" value={draft.originY} onChange={(e) => updateDraftField('originY', Number(e.target.value))} />
                        </div>
                        <div className="space-y-1">
                            <Label className="text-xs">Tile W</Label>
                            <Input type="number" value={draft.tileW} onChange={(e) => updateDraftField('tileW', Number(e.target.value))} />
                        </div>
                        <div className="space-y-1">
                            <Label className="text-xs">Tile H</Label>
                            <Input type="number" value={draft.tileH} onChange={(e) => updateDraftField('tileH', Number(e.target.value))} />
                        </div>
                        <div className="col-span-2 space-y-1">
                            <Label className="text-xs">Grid N</Label>
                            <Input type="number" value={draft.n} onChange={(e) => updateDraftField('n', Number(e.target.value))} />
                        </div>
                    </div>
                    <div className="flex flex-wrap gap-1.5">
                        {GRID_N_PRESETS.map((n) => (
                            <Button key={n} type="button" size="sm" variant="outline" className="h-7 px-2 text-xs" onClick={() => updateDraftField('n', n)}>
                                {n}×{n}
                            </Button>
                        ))}
                    </div>
                </fieldset>

                <p className="text-muted-foreground text-xs leading-relaxed">
                    Klik &quot;Kalibrasi&quot; lalu drag di kanvas buat geser origin. Scroll buat zoom. Kunci grid kalau udah pas biar nggak kegeser nggak sengaja.
                </p>

                <div className="flex items-center gap-2 pt-2">
                    <Switch checked={locked} onCheckedChange={() => void toggleLock()} />
                    <Label className="text-xs">Kunci grid</Label>
                </div>

                <Button className="w-full rounded-full" disabled={locked || saving} onClick={() => void save()}>
                    {saving ? 'Menyimpan...' : 'Simpan kalibrasi'}
                </Button>
            </div>
        </>
    );
}

export function SceneryCalibrationPanel({ initialSceneries }: { initialSceneries: Scenery[] }) {
    const [sceneries, setSceneries] = useState(initialSceneries);
    const [selectedId, setSelectedId] = useState<number | null>(initialSceneries[0]?.id ?? null);
    const selected = useMemo(() => sceneries.find((s) => s.id === selectedId) ?? null, [sceneries, selectedId]);
    const [uploading, setUploading] = useState(false);

    const uploadScenery = async (file: File) => {
        setUploading(true);

        try {
            const form = new FormData();
            form.append('name', file.name.replace(/\.[^.]+$/, ''));
            form.append('image', file);
            const { scenery } = await apiFetch<{ scenery: Scenery }>(sceneryRoutes.store(), form);
            setSceneries((list) => [...list, scenery]);
            setSelectedId(scenery.id);
        } finally {
            setUploading(false);
        }
    };

    const handleSaved = (updated: Scenery) => {
        setSceneries((list) => list.map((s) => (s.id === updated.id ? updated : s)));
    };

    return (
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-[240px_1fr_280px]">
            <div className="space-y-3">
                <div className="flex items-center justify-between">
                    <h3 className="text-sm font-semibold">Scenery</h3>
                    <label className="text-primary cursor-pointer text-xs font-medium hover:underline">
                        <UploadSimpleIcon className="mr-1 inline size-3.5" />
                        Upload
                        <input
                            type="file"
                            accept="image/*"
                            className="hidden"
                            disabled={uploading}
                            onChange={(e) => {
                                const file = e.target.files?.[0];

                                if (file) {
void uploadScenery(file);
}

                                e.target.value = '';
                            }}
                        />
                    </label>
                </div>
                <div className="grid max-h-[600px] grid-cols-2 gap-2 overflow-y-auto pr-1">
                    {sceneries.map((s) => (
                        <button
                            key={s.id}
                            type="button"
                            onClick={() => setSelectedId(s.id)}
                            className={`border-border/60 relative overflow-hidden rounded-lg border text-left transition-colors ${selectedId === s.id ? 'border-primary ring-primary/40 ring-2' : 'hover:border-primary/50'}`}
                        >
                            <img src={gameAssetUrl(s.file_path)} alt={s.name} loading="lazy" className="h-16 w-full object-cover" />
                            <div className="bg-card/90 flex items-center gap-1 px-1.5 py-1 text-[10px] font-medium">
                                {s.calibrated ? (
                                    <CheckCircleIcon weight="fill" className="size-3 shrink-0 text-emerald-500" />
                                ) : (
                                    <WarningCircleIcon weight="fill" className="text-muted-foreground size-3 shrink-0" />
                                )}
                                <span className="truncate">{s.name}</span>
                            </div>
                        </button>
                    ))}
                </div>
            </div>

            {selected ? (
                <SceneryDetailPanel key={selected.id} scenery={selected} onSaved={handleSaved} />
            ) : (
                <div className="border-border/60 text-muted-foreground col-span-2 flex items-center justify-center rounded-xl border border-dashed p-16 text-sm">
                    Upload scenery pertama buat mulai kalibrasi.
                </div>
            )}
        </div>
    );
}
