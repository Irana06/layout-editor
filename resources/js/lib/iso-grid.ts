/**
 * Isometric grid projection math shared between the Calibrate page's live-preview
 * canvases and the Editor's placement canvas. Ported 1:1 from the proven prototype at
 * basecode_layout-editor/calibrate.html — grid formulas were validated there first.
 */

export type GridCalibration = {
    originX: number;
    originY: number;
    tileW: number;
    tileH: number;
    n: number;
};

export type Camera = {
    x: number;
    y: number;
    zoom: number;
};

/** World-space point (pixels in the scenery image's own coordinate space, before camera/zoom). */
export type WorldPoint = { x: number; y: number };
/** Screen-space point (canvas pixels). */
export type ScreenPoint = { x: number; y: number };

/** Grid-space tile coordinate (gx, gy) — integer tile indices, not necessarily clamped to the grid. */
export type TilePoint = { gx: number; gy: number };

export function isoToWorld(grid: GridCalibration, gx: number, gy: number): WorldPoint {
    return {
        x: grid.originX + (gx - gy) * (grid.tileW / 2),
        y: grid.originY + (gx + gy) * (grid.tileH / 2),
    };
}

export function worldToIso(grid: GridCalibration, wx: number, wy: number): TilePoint {
    const px = wx - grid.originX;
    const py = wy - grid.originY;
    const gx = (px / (grid.tileW / 2) + py / (grid.tileH / 2)) / 2;
    const gy = (py / (grid.tileH / 2) - px / (grid.tileW / 2)) / 2;

    return { gx: Math.floor(gx), gy: Math.floor(gy) };
}

export function worldToScreen(camera: Camera, canvasWidth: number, canvasHeight: number, wx: number, wy: number): ScreenPoint {
    const s = camera.zoom;

    return {
        x: canvasWidth / 2 + (wx - camera.x) * s,
        y: canvasHeight / 2 + (wy - camera.y) * s,
    };
}

export function screenToWorld(camera: Camera, canvasWidth: number, canvasHeight: number, sx: number, sy: number): WorldPoint {
    const s = camera.zoom;

    return {
        x: camera.x + (sx - canvasWidth / 2) / s,
        y: camera.y + (sy - canvasHeight / 2) / s,
    };
}

export function isoToScreen(grid: GridCalibration, camera: Camera, canvasWidth: number, canvasHeight: number, gx: number, gy: number): ScreenPoint {
    const world = isoToWorld(grid, gx, gy);

    return worldToScreen(camera, canvasWidth, canvasHeight, world.x, world.y);
}

/** Four screen-space corners of tile (gx, gy), in draw order for a closed diamond path. */
export function tileDiamondCorners(grid: GridCalibration, camera: Camera, canvasWidth: number, canvasHeight: number, gx: number, gy: number): ScreenPoint[] {
    return [
        isoToScreen(grid, camera, canvasWidth, canvasHeight, gx, gy),
        isoToScreen(grid, camera, canvasWidth, canvasHeight, gx + 1, gy),
        isoToScreen(grid, camera, canvasWidth, canvasHeight, gx + 1, gy + 1),
        isoToScreen(grid, camera, canvasWidth, canvasHeight, gx, gy + 1),
    ];
}

export function canPlace(
    occupied: Map<string, unknown>,
    gx: number,
    gy: number,
    width: number,
    height: number,
    gridN: number,
): boolean {
    if (gx < 0 || gy < 0 || gx + width > gridN || gy + height > gridN) {
return false;
}

    for (let y = gy; y < gy + height; y++) {
        for (let x = gx; x < gx + width; x++) {
            if (occupied.has(tileKey(x, y))) {
return false;
}
        }
    }

    return true;
}

export function tileKey(gx: number, gy: number): string {
    return `${gx},${gy}`;
}

export function defaultCamera(): Camera {
    return { x: 0, y: 0, zoom: 1 };
}

export const GRID_N_PRESETS = [25, 33, 40, 44, 47] as const;
