import { useCallback, useEffect, useMemo, useRef } from 'react';
import { gameAssetUrl } from '@/lib/game-assets';
import { canPlace, isoToScreen, tileDiamondCorners, tileKey, worldToIso  } from '@/lib/iso-grid';
import type {GridCalibration} from '@/lib/iso-grid';
import { levelFootprint   } from '@/types/game';
import type {BuildingType, Scenery} from '@/types/game';
import type { Placement } from './editor-state';
import { useEditor } from './EditorProvider';

const CW = 1040;
const CH = 720;

type Props = {
    buildingTypes: BuildingType[];
    sceneries: Scenery[];
};

function loadImage(cache: Map<string, HTMLImageElement>, url: string, onLoad: () => void): HTMLImageElement {
    let img = cache.get(url);

    if (!img) {
        img = new Image();
        img.onload = onLoad;
        img.src = url;
        cache.set(url, img);
    }

    return img;
}

export function IsometricCanvas({ buildingTypes, sceneries }: Props) {
    const { state, dispatch, cameraRef, baseFitRef, zoomActionsRef, imageCache, setZoomDisplay } = useEditor();
    const canvasRef = useRef<HTMLCanvasElement>(null);

    const typeMap = useMemo(() => new Map(buildingTypes.map((t) => [t.id, t])), [buildingTypes]);
    const levelMap = useMemo(() => {
        const map = new Map<string, { type: BuildingType; level: BuildingType['levels'][number] }>();
        buildingTypes.forEach((type) => type.levels.forEach((level) => map.set(`${type.id}:${level.level}`, { type, level })));

        return map;
    }, [buildingTypes]);

    const scenery = useMemo(() => sceneries.find((s) => s.id === state.sceneryId) ?? null, [sceneries, state.sceneryId]);
    const grid: GridCalibration | null = useMemo(
        () => (scenery ? { originX: scenery.origin_x, originY: scenery.origin_y, tileW: scenery.tile_w, tileH: scenery.tile_h, n: scenery.grid_n } : null),
        [scenery],
    );

    const footprintOf = useCallback(
        (placement: Placement) => {
            const found = levelMap.get(`${placement.buildingTypeId}:${placement.level}`);

            if (!found) {
return { width: 1, height: 1 };
}

            return levelFootprint(found.type, found.level);
        },
        [levelMap],
    );

    const occupied = useMemo(() => {
        const map = new Map<string, Placement>();

        for (const placement of state.placements) {
            const { width, height } = footprintOf(placement);

            for (let y = placement.gy; y < placement.gy + height; y++) {
                for (let x = placement.gx; x < placement.gx + width; x++) {
                    map.set(tileKey(x, y), placement);
                }
            }
        }

        return map;
    }, [state.placements, footprintOf]);

    // Interaction refs (imperative, not reducer state — per-frame concerns).
    const pointer = useRef({
        down: false,
        moved: false,
        x: 0,
        y: 0,
        moving: null as Placement | null,
        painting: false,
        paintedThisDrag: new Set<string>(),
        pendingPlacements: null as Placement[] | null,
    });
    const selectionStart = useRef<{ gx: number; gy: number } | null>(null);

    // Stable indirection so image onLoad callbacks (created inside `draw` itself, and in the
    // preload effect below) can trigger a redraw without closing over `draw` before it's declared.
    const drawRef = useRef<() => void>(() => {});
    const requestDraw = useCallback(() => drawRef.current(), []);

    const draw = useCallback(() => {
        const canvas = canvasRef.current;
        const ctx = canvas?.getContext('2d', { alpha: false });

        if (!canvas || !ctx) {
return;
}

        const dpr = Math.min(window.devicePixelRatio || 1, 3);

        if (canvas.width !== CW * dpr) {
            canvas.width = CW * dpr;
            canvas.height = CH * dpr;
        }

        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        ctx.fillStyle = 'oklch(0.2 0 0)';
        ctx.fillRect(0, 0, CW, CH);

        if (!grid || !scenery) {
return;
}

        const camera = cameraRef.current;

        const sceneryImg = loadImage(imageCache.current, gameAssetUrl(scenery.file_path), requestDraw);

        if (sceneryImg.complete && sceneryImg.naturalWidth) {
            const topLeft = { x: CW / 2 + (0 - camera.x) * camera.zoom, y: CH / 2 + (0 - camera.y) * camera.zoom };
            ctx.drawImage(sceneryImg, topLeft.x, topLeft.y, sceneryImg.naturalWidth * camera.zoom, sceneryImg.naturalHeight * camera.zoom);
        }

        if (state.showGrid) {
            ctx.strokeStyle = 'rgba(255,255,255,0.28)';
            ctx.lineWidth = Math.max(1, camera.zoom * 0.6);

            for (let gx = 0; gx <= grid.n; gx++) {
                const p1 = isoToScreen(grid, camera, CW, CH, gx, 0);
                const p2 = isoToScreen(grid, camera, CW, CH, gx, grid.n);
                ctx.beginPath();
                ctx.moveTo(p1.x, p1.y);
                ctx.lineTo(p2.x, p2.y);
                ctx.stroke();
            }

            for (let gy = 0; gy <= grid.n; gy++) {
                const p1 = isoToScreen(grid, camera, CW, CH, 0, gy);
                const p2 = isoToScreen(grid, camera, CW, CH, grid.n, gy);
                ctx.beginPath();
                ctx.moveTo(p1.x, p1.y);
                ctx.lineTo(p2.x, p2.y);
                ctx.stroke();
            }
        }

        const drawDiamond = (gx: number, gy: number, fill?: string, stroke?: string, dashed?: boolean) => {
            const corners = tileDiamondCorners(grid, camera, CW, CH, gx, gy);
            ctx.beginPath();
            corners.forEach((c, i) => (i === 0 ? ctx.moveTo(c.x, c.y) : ctx.lineTo(c.x, c.y)));
            ctx.closePath();

            if (fill) {
                ctx.fillStyle = fill;
                ctx.fill();
            }

            if (stroke) {
                ctx.strokeStyle = stroke;
                ctx.lineWidth = Math.max(1, camera.zoom * 0.5);

                if (dashed) {
ctx.setLineDash([4, 3]);
}

                ctx.stroke();
                ctx.setLineDash([]);
            }
        };

        if (state.selectionBox) {
            const { start, end } = state.selectionBox;
            const minX = Math.min(start.gx, end.gx);
            const maxX = Math.max(start.gx, end.gx);
            const minY = Math.min(start.gy, end.gy);
            const maxY = Math.max(start.gy, end.gy);

            for (let y = minY; y <= maxY; y++) {
                for (let x = minX; x <= maxX; x++) {
                    drawDiamond(x, y, 'rgba(255,255,255,0.1)');
                }
            }
        }

        const sorted = [...state.placements].sort((a, b) => a.gx + a.gy - (b.gx + b.gy));

        for (const placement of sorted) {
            const found = levelMap.get(`${placement.buildingTypeId}:${placement.level}`);
            const { width, height } = footprintOf(placement);
            const isSelected = state.selectedIds.includes(placement.uid);

            if (state.showFootprint || isSelected) {
                for (let y = placement.gy; y < placement.gy + height; y++) {
                    for (let x = placement.gx; x < placement.gx + width; x++) {
                        drawDiamond(x, y, undefined, isSelected ? '#ffb648' : 'rgba(255,255,255,0.35)', true);
                    }
                }
            }

            if (!found) {
continue;
}

            const img = loadImage(imageCache.current, gameAssetUrl(found.level.file_path), requestDraw);

            if (!img.complete || !img.naturalWidth) {
continue;
}

            const topLeft = isoToScreen(grid, camera, CW, CH, placement.gx, placement.gy);
            const bottomRight = isoToScreen(grid, camera, CW, CH, placement.gx + width, placement.gy + height);
            const footH = height * grid.tileH * camera.zoom;
            const aspect = img.naturalHeight / img.naturalWidth;
            const drawW = width * grid.tileW * camera.zoom * found.level.scale;
            const drawH = drawW * aspect;
            const centerX = (topLeft.x + bottomRight.x) / 2 + found.level.offset_x * camera.zoom;
            const baseY = (topLeft.y + bottomRight.y) / 2 + footH / 2 + found.level.offset_y * camera.zoom;
            ctx.drawImage(img, centerX - drawW / 2, baseY - drawH, drawW, drawH);
        }
    }, [cameraRef, footprintOf, grid, imageCache, levelMap, requestDraw, scenery, state.placements, state.selectedIds, state.selectionBox, state.showFootprint, state.showGrid]);

    useEffect(() => {
        drawRef.current = draw;
        draw();
    }, [draw]);

    // Preload every building level image referenced by the palette once, so first placement doesn't flash blank.
    useEffect(() => {
        buildingTypes.forEach((type) => type.levels.forEach((level) => loadImage(imageCache.current, gameAssetUrl(level.file_path), requestDraw)));
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [buildingTypes]);

    const pointToCanvas = (e: React.PointerEvent<HTMLCanvasElement>) => {
        const rect = e.currentTarget.getBoundingClientRect();

        return { x: ((e.clientX - rect.left) * CW) / rect.width, y: ((e.clientY - rect.top) * CH) / rect.height };
    };

    const pointToCell = (p: { x: number; y: number }) => {
        const camera = cameraRef.current;
        const world = { x: camera.x + (p.x - CW / 2) / camera.zoom, y: camera.y + (p.y - CH / 2) / camera.zoom };

        return worldToIso(grid!, world.x, world.y);
    };

    const isWallType = (buildingTypeId: number) => typeMap.get(buildingTypeId)?.subfolder === 'wall';

    const onPointerDown = (e: React.PointerEvent<HTMLCanvasElement>) => {
        if (state.readOnly || !grid) {
return;
}

        e.currentTarget.setPointerCapture(e.pointerId);
        const p = pointToCanvas(e);
        const cell = pointToCell(p);
        const hit = occupied.get(tileKey(cell.gx, cell.gy));

        pointer.current = { down: true, moved: false, x: p.x, y: p.y, moving: null, painting: false, paintedThisDrag: new Set(), pendingPlacements: null };

        if (state.tool === 'place' && state.armed) {
            if (isWallType(state.armed.buildingTypeId)) {
                pointer.current.painting = true;
                pointer.current.pendingPlacements = [...state.placements];

                if (!hit && canPlace(occupied, cell.gx, cell.gy, 1, 1, grid.n)) {
                    const placement: Placement = { uid: crypto.randomUUID(), buildingTypeId: state.armed.buildingTypeId, level: state.armed.level, gx: cell.gx, gy: cell.gy };
                    pointer.current.pendingPlacements.push(placement);
                    pointer.current.paintedThisDrag.add(tileKey(cell.gx, cell.gy));
                }
            }

            return;
        }

        if (state.tool === 'select') {
            if (hit) {
                pointer.current.moving = hit;
            } else if (e.shiftKey) {
                selectionStart.current = cell;
                dispatch({ type: 'SET_SELECTION_BOX', box: { start: cell, end: cell } });
            }
        }
    };

    const onPointerMove = (e: React.PointerEvent<HTMLCanvasElement>) => {
        const d = pointer.current;

        if (!d.down || !grid) {
return;
}

        const p = pointToCanvas(e);
        const dx = p.x - d.x;
        const dy = p.y - d.y;

        if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
d.moved = true;
}

        const camera = cameraRef.current;
        const cell = pointToCell(p);

        if (d.painting && d.pendingPlacements) {
            const k = tileKey(cell.gx, cell.gy);

            if (!d.paintedThisDrag.has(k)) {
                d.paintedThisDrag.add(k);

                if (e.shiftKey) {
                    const hit = occupied.get(k);

                    if (hit && isWallType(hit.buildingTypeId)) {
                        d.pendingPlacements = d.pendingPlacements.filter((pl) => pl.uid !== hit.uid);
                    }
                } else if (!occupied.get(k) && canPlace(occupied, cell.gx, cell.gy, 1, 1, grid.n) && state.armed) {
                    d.pendingPlacements.push({ uid: crypto.randomUUID(), buildingTypeId: state.armed.buildingTypeId, level: state.armed.level, gx: cell.gx, gy: cell.gy });
                }
            }

            d.x = p.x;
            d.y = p.y;
            draw();

            return;
        }

        if (selectionStart.current) {
            dispatch({ type: 'SET_SELECTION_BOX', box: { start: selectionStart.current, end: cell } });

            return;
        }

        if (d.moving) {
            d.x = p.x;
            d.y = p.y;

            return;
        }

        if (d.moved) {
            camera.x -= dx / camera.zoom;
            camera.y -= dy / camera.zoom;
            d.x = p.x;
            d.y = p.y;
            draw();
        }
    };

    const onPointerUp = (e: React.PointerEvent<HTMLCanvasElement>) => {
        const d = pointer.current;

        if (!d.down || !grid) {
return;
}

        d.down = false;

        const p = pointToCanvas(e);
        const cell = pointToCell(p);

        if (d.painting && d.pendingPlacements) {
            dispatch({ type: 'COMMIT_PLACEMENTS', placements: d.pendingPlacements });
            dispatch({ type: 'SET_STATUS', status: 'Wall diperbarui. Tahan Shift saat drag untuk menghapus.' });

            return;
        }

        if (selectionStart.current) {
            const start = selectionStart.current;
            const minX = Math.min(start.gx, cell.gx);
            const maxX = Math.max(start.gx, cell.gx);
            const minY = Math.min(start.gy, cell.gy);
            const maxY = Math.max(start.gy, cell.gy);
            const ids = state.placements.filter((pl) => pl.gx >= minX && pl.gx <= maxX && pl.gy >= minY && pl.gy <= maxY).map((pl) => pl.uid);
            dispatch({ type: 'SELECT', ids });
            dispatch({ type: 'SET_SELECTION_BOX', box: null });
            dispatch({ type: 'SET_STATUS', status: `${ids.length} bangunan dipilih.` });
            selectionStart.current = null;

            return;
        }

        if (d.moving) {
            const moving = d.moving;
            const { width, height } = footprintOf(moving);

            if (d.moved) {
                const withoutSelf = new Map(occupied);

                for (let y = moving.gy; y < moving.gy + height; y++) {
for (let x = moving.gx; x < moving.gx + width; x++) {
withoutSelf.delete(tileKey(x, y));
}
}

                if (canPlace(withoutSelf, cell.gx, cell.gy, width, height, grid.n)) {
                    dispatch({
                        type: 'COMMIT_PLACEMENTS',
                        placements: state.placements.map((pl) => (pl.uid === moving.uid ? { ...pl, gx: cell.gx, gy: cell.gy } : pl)),
                    });
                    dispatch({ type: 'SET_STATUS', status: 'Bangunan dipindahkan.' });
                }
            } else {
                dispatch({ type: 'SELECT', ids: e.shiftKey ? [...state.selectedIds, moving.uid] : [moving.uid] });
            }

            return;
        }

        if (!d.moved && state.tool === 'place' && state.armed) {
            const found = levelMap.get(`${state.armed.buildingTypeId}:${state.armed.level}`);

            if (!found) {
return;
}

            const { width, height } = levelFootprint(found.type, found.level);

            if (canPlace(occupied, cell.gx, cell.gy, width, height, grid.n)) {
                const placement: Placement = { uid: crypto.randomUUID(), buildingTypeId: state.armed.buildingTypeId, level: state.armed.level, gx: cell.gx, gy: cell.gy };
                dispatch({ type: 'COMMIT_PLACEMENTS', placements: [...state.placements, placement] });
                dispatch({ type: 'SET_STATUS', status: `${found.type.name} ditambahkan.` });
            } else {
                dispatch({ type: 'SET_STATUS', status: 'Tidak bisa menempatkan di sana — sudah terisi atau di luar grid.' });
            }
        } else if (!d.moved && state.tool === 'select') {
            dispatch({ type: 'SELECT', ids: [] });
        }
    };

    const onWheel = (e: React.WheelEvent<HTMLCanvasElement>) => {
        if (!grid) {
return;
}

        e.preventDefault();
        const rect = e.currentTarget.getBoundingClientRect();
        const p = { x: ((e.clientX - rect.left) * CW) / rect.width, y: ((e.clientY - rect.top) * CH) / rect.height };
        const camera = cameraRef.current;
        const before = { x: camera.x + (p.x - CW / 2) / camera.zoom, y: camera.y + (p.y - CH / 2) / camera.zoom };
        const factor = e.deltaY < 0 ? 1.15 : 1 / 1.15;
        const fit = baseFitRef.current;
        camera.zoom = Math.min(fit * 10, Math.max(fit, camera.zoom * factor));
        const after = { x: camera.x + (p.x - CW / 2) / camera.zoom, y: camera.y + (p.y - CH / 2) / camera.zoom };
        camera.x += before.x - after.x;
        camera.y += before.y - after.y;
        setZoomDisplay(Math.round((camera.zoom / fit) * 100));
        draw();
    };

    useEffect(() => {
        if (!scenery) {
return;
}

        const camera = cameraRef.current;
        const fit = Math.min(CW / scenery.image_width, CH / scenery.image_height, 1) || 1;
        baseFitRef.current = fit;
        camera.x = scenery.image_width / 2;
        camera.y = scenery.image_height / 2;
        camera.zoom = fit;
        setZoomDisplay(100);
        draw();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [scenery?.id]);

    useEffect(() => {
        zoomActionsRef.current = {
            setZoomPercent: (percent) => {
                const fit = baseFitRef.current;
                const camera = cameraRef.current;
                camera.zoom = Math.min(fit * 10, Math.max(fit, fit * (percent / 100)));
                setZoomDisplay(Math.round((camera.zoom / fit) * 100));
                draw();
            },
        };

        return () => {
            zoomActionsRef.current = null;
        };
    }, [baseFitRef, cameraRef, draw, setZoomDisplay, zoomActionsRef]);

    return (
        <canvas
            ref={canvasRef}
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerUp}
            onPointerLeave={onPointerUp}
            onWheel={onWheel}
            className="bg-background block w-full touch-none rounded-2xl"
            style={{
                aspectRatio: `${CW}/${CH}`,
                cursor: state.tool === 'place' ? 'copy' : 'grab',
            }}
        />
    );
}
