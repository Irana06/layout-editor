import {
    ArrowsOutCardinalIcon,
    CheckCircleIcon,
    UploadSimpleIcon,
    WarningCircleIcon,
} from '@phosphor-icons/react';
import { useEffect, useMemo, useRef, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/select';
import { Slider } from '@/components/ui/slider';
import { apiFetch } from '@/lib/api';
import { gameAssetUrl } from '@/lib/game-assets';
import { isoToScreen } from '@/lib/iso-grid';
import buildingLevelRoutes from '@/routes/building-levels';
import type { BuildingLevel, BuildingType, Scenery } from '@/types/game';

const CANVAS_W = 520;
const CANVAS_H = 420;

type Props = {
    type: BuildingType;
    level: BuildingLevel;
    sceneries: Scenery[];
    onUpdated: (level: BuildingLevel, type: BuildingType | null) => void;
    onAddLevel: (typeId: number, level: number, file: File) => Promise<void>;
};

/** Rendered with `key={level.id}` by the parent, so switching levels gives a clean slate via
 * lazy initial state rather than an effect resetting state on prop change. */
export function BuildingLevelCalibrationPanel({
    type,
    level,
    sceneries,
    onUpdated,
    onAddLevel,
}: Props) {
    const [previewSceneryId, setPreviewSceneryId] = useState<number | null>(
        sceneries[0]?.id ?? null,
    );
    const previewScenery = useMemo(
        () => sceneries.find((s) => s.id === previewSceneryId) ?? null,
        [sceneries, previewSceneryId],
    );

    const [gridWidth, setGridWidth] = useState<number | ''>(
        level.grid_width ?? '',
    );
    const [gridHeight, setGridHeight] = useState<number | ''>(
        level.grid_height ?? '',
    );
    const [scale, setScale] = useState(level.scale);
    const [offsetX, setOffsetX] = useState(level.offset_x);
    const [offsetY, setOffsetY] = useState(level.offset_y);
    const [saving, setSaving] = useState(false);
    const [saveState, setSaveState] = useState<'idle' | 'saved' | 'error'>(
        'idle',
    );
    const [newLevelNumber, setNewLevelNumber] = useState(
        Math.max(...type.levels.map((l) => l.level), 0) + 1,
    );

    const canvasRef = useRef<HTMLCanvasElement>(null);
    const sceneryImgRef = useRef<HTMLImageElement | null>(null);
    const buildingImgRef = useRef<HTMLImageElement | null>(null);
    const dragRef = useRef<{ active: boolean; lastX: number; lastY: number }>({
        active: false,
        lastX: 0,
        lastY: 0,
    });

    useEffect(() => {
        const img = new Image();
        img.src = gameAssetUrl(level.file_path);
        buildingImgRef.current = img;
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    useEffect(() => {
        if (!previewScenery) {
            return;
        }

        const img = new Image();
        img.src = gameAssetUrl(previewScenery.file_path);
        sceneryImgRef.current = img;
    }, [previewScenery]);

    const footprintWidth =
        gridWidth === '' ? type.default_grid_width : gridWidth;
    const footprintHeight =
        gridHeight === '' ? type.default_grid_height : gridHeight;

    const previewFit = useMemo(() => {
        if (!previewScenery?.image_width || !previewScenery.image_height) {
            return 1;
        }

        return Math.min(
            CANVAS_W / previewScenery.image_width,
            CANVAS_H / previewScenery.image_height,
        );
    }, [previewScenery]);

    const markDirty = () => setSaveState('idle');

    useEffect(() => {
        const canvas = canvasRef.current;
        const ctx = canvas?.getContext('2d');

        if (!canvas || !ctx || !previewScenery) {
            return;
        }

        let raf = 0;
        const render = () => {
            ctx.fillStyle = '#000';
            ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

            const grid = {
                originX: previewScenery.origin_x,
                originY: previewScenery.origin_y,
                tileW: previewScenery.tile_w,
                tileH: previewScenery.tile_h,
                n: previewScenery.grid_n,
            };
            const sceneryImg = sceneryImgRef.current;

            if (sceneryImg?.complete && sceneryImg.naturalWidth) {
                const fit = Math.min(
                    CANVAS_W / sceneryImg.naturalWidth,
                    CANVAS_H / sceneryImg.naturalHeight,
                );
                const camera = {
                    x: sceneryImg.naturalWidth / 2,
                    y: sceneryImg.naturalHeight / 2,
                    zoom: fit,
                };
                const topLeft = {
                    x: CANVAS_W / 2 - camera.x * fit,
                    y: CANVAS_H / 2 - camera.y * fit,
                };
                ctx.drawImage(
                    sceneryImg,
                    topLeft.x,
                    topLeft.y,
                    sceneryImg.naturalWidth * fit,
                    sceneryImg.naturalHeight * fit,
                );

                const centerGx =
                    Math.floor(grid.n / 2) - Math.floor(footprintWidth / 2);
                const centerGy =
                    Math.floor(grid.n / 2) - Math.floor(footprintHeight / 2);

                // Dashed diamond footprint outline.
                ctx.strokeStyle = 'rgba(255,255,255,0.85)';
                ctx.setLineDash([4, 3]);
                ctx.lineWidth = 1.5;

                for (let y = centerGy; y < centerGy + footprintHeight; y++) {
                    for (let x = centerGx; x < centerGx + footprintWidth; x++) {
                        const p1 = isoToScreen(
                            grid,
                            camera,
                            CANVAS_W,
                            CANVAS_H,
                            x,
                            y,
                        );
                        const p2 = isoToScreen(
                            grid,
                            camera,
                            CANVAS_W,
                            CANVAS_H,
                            x + 1,
                            y,
                        );
                        const p3 = isoToScreen(
                            grid,
                            camera,
                            CANVAS_W,
                            CANVAS_H,
                            x + 1,
                            y + 1,
                        );
                        const p4 = isoToScreen(
                            grid,
                            camera,
                            CANVAS_W,
                            CANVAS_H,
                            x,
                            y + 1,
                        );
                        ctx.beginPath();
                        ctx.moveTo(p1.x, p1.y);
                        ctx.lineTo(p2.x, p2.y);
                        ctx.lineTo(p3.x, p3.y);
                        ctx.lineTo(p4.x, p4.y);
                        ctx.closePath();
                        ctx.stroke();
                    }
                }

                ctx.setLineDash([]);

                const buildingImg = buildingImgRef.current;

                if (buildingImg?.complete && buildingImg.naturalWidth) {
                    const footH = footprintHeight * grid.tileH * fit;
                    const aspect =
                        buildingImg.naturalHeight / buildingImg.naturalWidth;
                    const drawW = footprintWidth * grid.tileW * fit * scale;
                    const drawH = drawW * aspect;
                    const topLeftTile = isoToScreen(
                        grid,
                        camera,
                        CANVAS_W,
                        CANVAS_H,
                        centerGx,
                        centerGy,
                    );
                    const bottomRightTile = isoToScreen(
                        grid,
                        camera,
                        CANVAS_W,
                        CANVAS_H,
                        centerGx + footprintWidth,
                        centerGy + footprintHeight,
                    );
                    const centerX =
                        (topLeftTile.x + bottomRightTile.x) / 2 + offsetX * fit;
                    const baseY =
                        (topLeftTile.y + bottomRightTile.y) / 2 +
                        footH / 2 +
                        offsetY * fit;
                    ctx.drawImage(
                        buildingImg,
                        centerX - drawW / 2,
                        baseY - drawH,
                        drawW,
                        drawH,
                    );
                }
            }

            raf = requestAnimationFrame(render);
        };
        raf = requestAnimationFrame(render);

        return () => cancelAnimationFrame(raf);
    }, [
        previewScenery,
        footprintWidth,
        footprintHeight,
        scale,
        offsetX,
        offsetY,
    ]);

    const save = async () => {
        setSaving(true);
        setSaveState('idle');

        try {
            const { buildingLevel, buildingType } = await apiFetch<{
                buildingLevel: BuildingLevel;
                buildingType: BuildingType | null;
            }>(buildingLevelRoutes.update(level.id), {
                grid_width: gridWidth === '' ? null : gridWidth,
                grid_height: gridHeight === '' ? null : gridHeight,
                scale,
                offset_x: offsetX,
                offset_y: offsetY,
            });
            onUpdated(buildingLevel, buildingType);

            // The tile size now lives on the type, so clear the local inputs and
            // let them fall back to showing that shared value as placeholder.
            if (buildingType) {
                setGridWidth('');
                setGridHeight('');
            }

            setSaveState('saved');
        } catch {
            setSaveState('error');
        } finally {
            setSaving(false);
        }
    };

    const startDrag = (event: React.PointerEvent<HTMLCanvasElement>) => {
        event.currentTarget.setPointerCapture(event.pointerId);
        dragRef.current = {
            active: true,
            lastX: event.clientX,
            lastY: event.clientY,
        };
        setSaveState('idle');
    };

    const dragBuilding = (event: React.PointerEvent<HTMLCanvasElement>) => {
        const drag = dragRef.current;

        if (!drag.active) {
            return;
        }

        const dx = (event.clientX - drag.lastX) / previewFit;
        const dy = (event.clientY - drag.lastY) / previewFit;
        drag.lastX = event.clientX;
        drag.lastY = event.clientY;
        setOffsetX((value) => Math.max(-500, Math.min(500, value + dx)));
        setOffsetY((value) => Math.max(-500, Math.min(500, value + dy)));
        markDirty();
    };

    const stopDrag = () => {
        dragRef.current.active = false;
    };

    return (
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-[1fr_280px]">
            <div className="space-y-3">
                <div className="flex items-center justify-between">
                    <h3 className="text-sm font-semibold">
                        {type.name} — Level {level.level}
                    </h3>
                    <div className="flex items-center gap-2">
                        <Select
                            value={String(previewSceneryId ?? '')}
                            onValueChange={(v) =>
                                setPreviewSceneryId(Number(v))
                            }
                        >
                            <SelectTrigger size="sm" className="w-40">
                                <SelectValue placeholder="Scenery preview" />
                            </SelectTrigger>
                            <SelectContent>
                                {sceneries.map((s) => (
                                    <SelectItem key={s.id} value={String(s.id)}>
                                        {s.name}
                                    </SelectItem>
                                ))}
                            </SelectContent>
                        </Select>
                    </div>
                </div>
                <div className="overflow-hidden rounded-xl border border-border/60 bg-card">
                    <canvas
                        ref={canvasRef}
                        width={CANVAS_W}
                        height={CANVAS_H}
                        className="cursor-move touch-none"
                        onPointerDown={startDrag}
                        onPointerMove={dragBuilding}
                        onPointerUp={stopDrag}
                        onPointerCancel={stopDrag}
                    />
                </div>
                <p className="flex items-center gap-1.5 text-xs text-muted-foreground">
                    <ArrowsOutCardinalIcon className="size-3.5" />
                    Drag building di preview untuk mengatur offset. Garis
                    putus-putus adalah footprint tile yang ditempati.
                </p>
            </div>

            <div className="space-y-4">
                <div className="grid grid-cols-2 gap-3">
                    <div className="space-y-1">
                        <Label className="text-xs">Grid Width</Label>
                        <Input
                            type="number"
                            placeholder={String(type.default_grid_width)}
                            value={gridWidth}
                            onChange={(e) => {
                                setGridWidth(
                                    e.target.value === ''
                                        ? ''
                                        : Number(e.target.value),
                                );
                                markDirty();
                            }}
                        />
                    </div>
                    <div className="space-y-1">
                        <Label className="text-xs">Grid Height</Label>
                        <Input
                            type="number"
                            placeholder={String(type.default_grid_height)}
                            value={gridHeight}
                            onChange={(e) => {
                                setGridHeight(
                                    e.target.value === ''
                                        ? ''
                                        : Number(e.target.value),
                                );
                                markDirty();
                            }}
                        />
                    </div>
                </div>

                <div className="space-y-2">
                    <div className="flex items-center justify-between text-xs">
                        <Label>Scale</Label>
                        <span className="text-primary tabular-nums">
                            {Math.round(scale * 100)}%
                        </span>
                    </div>
                    <Slider
                        min={0.5}
                        max={1.5}
                        step={0.01}
                        value={[scale]}
                        onValueChange={([v]) => {
                            setScale(v);
                            markDirty();
                        }}
                    />
                </div>
                <div className="space-y-2">
                    <div className="flex items-center justify-between text-xs">
                        <Label>Geser X</Label>
                        <span className="text-primary tabular-nums">
                            {Math.round(offsetX)}px
                        </span>
                    </div>
                    <Slider
                        min={-500}
                        max={500}
                        step={1}
                        value={[offsetX]}
                        onValueChange={([v]) => {
                            setOffsetX(v);
                            markDirty();
                        }}
                    />
                </div>
                <div className="space-y-2">
                    <div className="flex items-center justify-between text-xs">
                        <Label>Geser Y</Label>
                        <span className="text-primary tabular-nums">
                            {Math.round(offsetY)}px
                        </span>
                    </div>
                    <Slider
                        min={-500}
                        max={500}
                        step={1}
                        value={[offsetY]}
                        onValueChange={([v]) => {
                            setOffsetY(v);
                            markDirty();
                        }}
                    />
                </div>

                <div className="grid grid-cols-2 gap-3">
                    <div className="space-y-1">
                        <Label className="text-xs">Offset X presisi</Label>
                        <Input
                            type="number"
                            min={-500}
                            max={500}
                            step={0.5}
                            value={Number(offsetX.toFixed(2))}
                            onChange={(e) => {
                                setOffsetX(Number(e.target.value));
                                markDirty();
                            }}
                        />
                    </div>
                    <div className="space-y-1">
                        <Label className="text-xs">Offset Y presisi</Label>
                        <Input
                            type="number"
                            min={-500}
                            max={500}
                            step={0.5}
                            value={Number(offsetY.toFixed(2))}
                            onChange={(e) => {
                                setOffsetY(Number(e.target.value));
                                markDirty();
                            }}
                        />
                    </div>
                </div>

                <Button
                    className="w-full rounded-full"
                    disabled={saving}
                    onClick={() => void save()}
                >
                    {saving ? 'Menyimpan...' : 'Simpan kalibrasi'}
                </Button>

                {saveState === 'saved' && (
                    <p className="flex items-center gap-1.5 text-xs text-emerald-500">
                        <CheckCircleIcon weight="fill" className="size-4" />
                        Kalibrasi tersimpan dan siap dipakai editor.
                    </p>
                )}
                {saveState === 'error' && (
                    <p className="flex items-center gap-1.5 text-xs text-destructive">
                        <WarningCircleIcon weight="fill" className="size-4" />
                        Kalibrasi gagal disimpan. Periksa koneksi lalu coba
                        lagi.
                    </p>
                )}

                <div className="space-y-2 border-t border-border/60 pt-4">
                    <Label className="text-xs">Tambah level baru</Label>
                    <div className="flex gap-2">
                        <Input
                            type="number"
                            className="w-20"
                            value={newLevelNumber}
                            onChange={(e) =>
                                setNewLevelNumber(Number(e.target.value))
                            }
                        />
                        <label className="flex flex-1 cursor-pointer items-center justify-center gap-1.5 rounded-md border border-input text-xs hover:bg-accent">
                            <UploadSimpleIcon className="size-3.5" />
                            Upload gambar
                            <input
                                type="file"
                                accept="image/*"
                                className="hidden"
                                onChange={(e) => {
                                    const file = e.target.files?.[0];

                                    if (file) {
                                        void onAddLevel(
                                            type.id,
                                            newLevelNumber,
                                            file,
                                        );
                                    }

                                    e.target.value = '';
                                }}
                            />
                        </label>
                    </div>
                </div>
            </div>
        </div>
    );
}
