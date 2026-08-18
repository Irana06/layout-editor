import { Head, Link } from '@inertiajs/react';
import { Grid3X3, Minus, MousePointer2, RotateCcw, Search, Trash2, ZoomIn } from 'lucide-react';
import { type PointerEvent, useEffect, useMemo, useRef, useState, type WheelEvent } from 'react';

const CANVAS_WIDTH = 1000;
const CANVAS_HEIGHT = 760;
const GRID = { bgW: 3705, bgH: 2545, tileW: 56, tileH: 42, originX: 1895, originY: 250, n: 44 };
const ASSET_ROOT = '/game-assets/';

type ManifestBuilding = { id: string; name: string; file: string };
type Manifest = { buildings: ManifestBuilding[] };
type BuildingType = { id: string; name: string; size: number; file: string };
type PlacedBuilding = { gx: number; gy: number; size: number; type: BuildingType };
type Point = { x: number; y: number };

const paletteDefinition = [
    { id: 'th', name: 'Town Hall', size: 4, matcher: /town-hall\/Town Hall18\.png$/ },
    { id: 'gm', name: 'Gold Mine', size: 3, matcher: /gold-mine\/Gold Mine\d+\.png$/ },
    { id: 'at', name: 'Archer Tower', size: 3, matcher: /archer-tower\/Archer Tower\d+\.png$/ },
    { id: 'cn', name: 'Cannon', size: 3, matcher: /cannon\/Cannon\d+\.png$/ },
    { id: 'inf', name: 'Inferno Tower', size: 4, matcher: /inferno-tower\/Inferno Tower\d+\.png$/ },
] as const;

function tileKey(gx: number, gy: number) {
    return `${gx},${gy}`;
}

export default function Editor() {
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const cameraRef = useRef({ x: GRID.bgW / 2, y: GRID.bgH / 2, zoom: 1 });
    const imagesRef = useRef(new Map<string, HTMLImageElement>());
    const occupiedRef = useRef<Record<string, PlacedBuilding>>({});
    const dragRef = useRef({ active: false, moved: false, lastX: 0, lastY: 0 });
    const [buildingTypes, setBuildingTypes] = useState<BuildingType[]>([]);
    const [selectedType, setSelectedType] = useState<BuildingType | null>(null);
    const [placed, setPlaced] = useState<PlacedBuilding[]>([]);
    const [showGrid, setShowGrid] = useState(true);
    const [zoom, setZoom] = useState(1);
    const [status, setStatus] = useState('Memuat katalog aset…');

    useEffect(() => {
        let cancelled = false;

        fetch(`${ASSET_ROOT}buildings-source/manifest.json`)
            .then((response) => {
                if (!response.ok) throw new Error(`HTTP ${response.status}`);
                return response.json() as Promise<Manifest>;
            })
            .then((manifest) => {
                if (cancelled) return;
                const types = paletteDefinition.flatMap((item) => {
                    const asset = manifest.buildings.find((building) => item.matcher.test(building.file));
                    return asset ? [{ id: item.id, name: item.name, size: item.size, file: asset.file }] : [];
                });
                setBuildingTypes(types);
                setStatus(types.length === paletteDefinition.length ? 'Pilih bangunan, lalu klik tile untuk menempatkan.' : 'Sebagian sprite tidak ditemukan di katalog aset.');
            })
            .catch(() => setStatus('Katalog aset tidak dapat dimuat. Jalankan aplikasi melalui Laravel.'));

        return () => {
            cancelled = true;
        };
    }, []);

    const assetUrl = (file: string) => `${ASSET_ROOT}${file}`;

    useEffect(() => {
        const sources = ['scenery/classic.jpg', ...buildingTypes.map((type) => type.file)];
        let remaining = sources.length;

        sources.forEach((file) => {
            const image = new Image();
            image.onload = image.onerror = () => {
                remaining -= 1;
                if (remaining === 0) window.requestAnimationFrame(draw);
            };
            image.src = assetUrl(file);
            imagesRef.current.set(file, image);
        });
        // draw is intentionally called after source loading; it reads the live canvas state.
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [buildingTypes]);

    function draw() {
        const canvas = canvasRef.current;
        if (!canvas) return;
        const context = canvas.getContext('2d', { alpha: false });
        if (!context) return;

        const dpr = Math.min(window.devicePixelRatio || 1, 3);
        if (canvas.width !== CANVAS_WIDTH * dpr || canvas.height !== CANVAS_HEIGHT * dpr) {
            canvas.width = CANVAS_WIDTH * dpr;
            canvas.height = CANVAS_HEIGHT * dpr;
        }
        context.setTransform(dpr, 0, 0, dpr, 0, 0);
        context.imageSmoothingEnabled = true;
        context.imageSmoothingQuality = 'high';
        context.fillStyle = '#050405';
        context.fillRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);

        const camera = cameraRef.current;
        const scale = Math.min(CANVAS_WIDTH / GRID.bgW, CANVAS_HEIGHT / GRID.bgH) * camera.zoom;
        const worldToScreen = (wx: number, wy: number): Point => ({
            x: CANVAS_WIDTH / 2 + (wx - camera.x) * scale,
            y: CANVAS_HEIGHT / 2 + (wy - camera.y) * scale,
        });
        const isoToScreen = (gx: number, gy: number) =>
            worldToScreen(GRID.originX + (gx - gy) * (GRID.tileW / 2), GRID.originY + (gx + gy) * (GRID.tileH / 2));

        const scenery = imagesRef.current.get('scenery/classic.jpg');
        if (scenery?.complete && scenery.naturalWidth) {
            const topLeft = worldToScreen(0, 0);
            context.drawImage(scenery, topLeft.x, topLeft.y, GRID.bgW * scale, GRID.bgH * scale);
        }

        if (showGrid) {
            context.strokeStyle = 'rgb(249 236 223 / 0.3)';
            context.lineWidth = Math.max(1, scale * 0.6);
            for (let gx = 0; gx <= GRID.n; gx += 1) {
                const first = isoToScreen(gx, 0);
                const last = isoToScreen(gx, GRID.n);
                context.beginPath(); context.moveTo(first.x, first.y); context.lineTo(last.x, last.y); context.stroke();
            }
            for (let gy = 0; gy <= GRID.n; gy += 1) {
                const first = isoToScreen(0, gy);
                const last = isoToScreen(GRID.n, gy);
                context.beginPath(); context.moveTo(first.x, first.y); context.lineTo(last.x, last.y); context.stroke();
            }
        }

        [...placed]
            .sort((left, right) => left.gx + left.gy - (right.gx + right.gy))
            .forEach((building) => {
                const image = imagesRef.current.get(building.type.file);
                if (!image?.complete || !image.naturalWidth) return;
                const footprintHeight = building.size * GRID.tileH * scale;
                const drawWidth = building.size * GRID.tileW * scale * 1.05;
                const drawHeight = drawWidth * (image.naturalHeight / image.naturalWidth);
                const topLeft = isoToScreen(building.gx, building.gy);
                const bottomRight = isoToScreen(building.gx + building.size, building.gy + building.size);
                const centerX = (topLeft.x + bottomRight.x) / 2;
                const baseY = (topLeft.y + bottomRight.y) / 2 + footprintHeight / 2;
                context.drawImage(image, centerX - drawWidth / 2, baseY - drawHeight, drawWidth, drawHeight);
            });
    }

    useEffect(() => {
        draw();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [placed, showGrid, zoom]);

    const pointerPosition = (event: PointerEvent<HTMLCanvasElement>) => {
        const rect = event.currentTarget.getBoundingClientRect();
        return {
            x: (event.clientX - rect.left) * (CANVAS_WIDTH / rect.width),
            y: (event.clientY - rect.top) * (CANVAS_HEIGHT / rect.height),
        };
    };

    const toGrid = (screen: Point) => {
        const camera = cameraRef.current;
        const scale = Math.min(CANVAS_WIDTH / GRID.bgW, CANVAS_HEIGHT / GRID.bgH) * camera.zoom;
        const worldX = camera.x + (screen.x - CANVAS_WIDTH / 2) / scale;
        const worldY = camera.y + (screen.y - CANVAS_HEIGHT / 2) / scale;
        const pixelX = worldX - GRID.originX;
        const pixelY = worldY - GRID.originY;
        return {
            gx: Math.floor((pixelX / (GRID.tileW / 2) + pixelY / (GRID.tileH / 2)) / 2),
            gy: Math.floor((pixelY / (GRID.tileH / 2) - pixelX / (GRID.tileW / 2)) / 2),
        };
    };

    const canPlace = (gx: number, gy: number, size: number) => {
        if (gx < 0 || gy < 0 || gx + size > GRID.n || gy + size > GRID.n) return false;
        for (let y = gy; y < gy + size; y += 1) {
            for (let x = gx; x < gx + size; x += 1) {
                if (occupiedRef.current[tileKey(x, y)]) return false;
            }
        }
        return true;
    };

    const removeBuilding = (building: PlacedBuilding) => {
        for (let y = building.gy; y < building.gy + building.size; y += 1) {
            for (let x = building.gx; x < building.gx + building.size; x += 1) delete occupiedRef.current[tileKey(x, y)];
        }
        setPlaced((current) => current.filter((item) => item !== building));
    };

    const onPointerDown = (event: PointerEvent<HTMLCanvasElement>) => {
        event.currentTarget.setPointerCapture(event.pointerId);
        const point = pointerPosition(event);
        dragRef.current = { active: true, moved: false, lastX: point.x, lastY: point.y };
    };

    const onPointerMove = (event: PointerEvent<HTMLCanvasElement>) => {
        const drag = dragRef.current;
        if (!drag.active) return;
        const point = pointerPosition(event);
        const dx = point.x - drag.lastX;
        const dy = point.y - drag.lastY;
        if (Math.abs(dx) > 3 || Math.abs(dy) > 3) drag.moved = true;
        if (!drag.moved) return;
        const scale = Math.min(CANVAS_WIDTH / GRID.bgW, CANVAS_HEIGHT / GRID.bgH) * cameraRef.current.zoom;
        cameraRef.current.x -= dx / scale;
        cameraRef.current.y -= dy / scale;
        drag.lastX = point.x;
        drag.lastY = point.y;
        draw();
    };

    const onPointerUp = (event: PointerEvent<HTMLCanvasElement>) => {
        const drag = dragRef.current;
        if (!drag.active) return;
        drag.active = false;
        if (drag.moved) return;
        const { gx, gy } = toGrid(pointerPosition(event));
        const hit = occupiedRef.current[tileKey(gx, gy)];
        if (hit) {
            removeBuilding(hit);
            return;
        }
        if (selectedType && canPlace(gx, gy, selectedType.size)) {
            const building = { gx, gy, size: selectedType.size, type: selectedType };
            for (let y = gy; y < gy + building.size; y += 1) {
                for (let x = gx; x < gx + building.size; x += 1) occupiedRef.current[tileKey(x, y)] = building;
            }
            setPlaced((current) => [...current, building]);
        }
    };

    const updateZoom = (nextZoom: number, pivot: Point = { x: CANVAS_WIDTH / 2, y: CANVAS_HEIGHT / 2 }) => {
        const camera = cameraRef.current;
        const oldScale = Math.min(CANVAS_WIDTH / GRID.bgW, CANVAS_HEIGHT / GRID.bgH) * camera.zoom;
        const before = { x: camera.x + (pivot.x - CANVAS_WIDTH / 2) / oldScale, y: camera.y + (pivot.y - CANVAS_HEIGHT / 2) / oldScale };
        camera.zoom = Math.min(10, Math.max(1, nextZoom));
        const newScale = Math.min(CANVAS_WIDTH / GRID.bgW, CANVAS_HEIGHT / GRID.bgH) * camera.zoom;
        const after = { x: camera.x + (pivot.x - CANVAS_WIDTH / 2) / newScale, y: camera.y + (pivot.y - CANVAS_HEIGHT / 2) / newScale };
        camera.x += before.x - after.x;
        camera.y += before.y - after.y;
        setZoom(camera.zoom);
    };

    const onWheel = (event: WheelEvent<HTMLCanvasElement>) => {
        event.preventDefault();
        updateZoom(cameraRef.current.zoom * (event.deltaY < 0 ? 1.15 : 1 / 1.15), pointerPosition(event as unknown as PointerEvent<HTMLCanvasElement>));
    };

    const resetView = () => {
        cameraRef.current = { x: GRID.bgW / 2, y: GRID.bgH / 2, zoom: 1 };
        setZoom(1);
    };

    const resetBuildings = () => {
        occupiedRef.current = {};
        setPlaced([]);
    };

    const zoomPercentage = useMemo(() => Math.round(zoom * 100), [zoom]);

    return (
        <>
            <Head title="Layout Editor" />
            <main className="editor-shell editor-grid-pattern">
                <header className="border-b border-[#f9ecdf]/10 bg-[#050405]/80 backdrop-blur-xl">
                    <div className="mx-auto flex max-w-[1500px] items-center justify-between gap-4 px-5 py-4 lg:px-8">
                        <Link href="/" className="group flex items-center gap-3">
                            <span className="grid size-10 place-items-center rounded-xl bg-[#b9937c] text-lg font-black text-[#201818] shadow-[0_10px_28px_rgb(185_147_124_/_30%)] transition group-hover:scale-105">C</span>
                            <span><span className="block text-base font-bold tracking-tight text-[#f9ecdf]">Clash Layout</span><span className="block text-xs text-[#b9937c]">Base Editor</span></span>
                        </Link>
                        <div className="hidden items-center gap-2 text-sm text-[#f9ecdf]/55 md:flex"><MousePointer2 size={15} /> Grid isometrik · {GRID.n}×{GRID.n}</div>
                        <div className="rounded-full border border-[#b9937c]/30 bg-[#201818] px-3 py-1.5 text-xs font-semibold text-[#f9ecdf]">Prototype</div>
                    </div>
                </header>

                <section className="mx-auto grid max-w-[1500px] gap-5 px-5 py-6 lg:grid-cols-[minmax(0,1fr)_290px] lg:px-8">
                    <div className="overflow-hidden rounded-3xl border border-[#f9ecdf]/10 bg-[#201818]/80 p-3 shadow-2xl shadow-black/35">
                        <div className="mb-3 flex flex-wrap items-center justify-between gap-3 px-2 pt-1">
                            <div><p className="text-xs font-bold uppercase tracking-[0.18em] text-[#b9937c]">Editor kanvas</p><p className="mt-1 text-sm text-[#f9ecdf]/65">{status}</p></div>
                            <div className="rounded-full bg-[#050405]/75 px-3 py-1.5 text-xs font-semibold text-[#f9ecdf]/75">Terpasang: <span className="text-[#f9ecdf]">{placed.length}</span></div>
                        </div>
                        <canvas ref={canvasRef} onPointerDown={onPointerDown} onPointerMove={onPointerMove} onPointerUp={onPointerUp} onWheel={onWheel} className="block w-full touch-none rounded-2xl bg-[#050405] shadow-inner shadow-black/40" style={{ aspectRatio: `${CANVAS_WIDTH}/${CANVAS_HEIGHT}`, cursor: 'crosshair' }} />
                    </div>

                    <aside className="space-y-4">
                        <section className="rounded-3xl border border-[#f9ecdf]/10 bg-[#201818]/90 p-5 shadow-xl shadow-black/20">
                            <div className="mb-4 flex items-center justify-between"><div><p className="text-xs font-bold uppercase tracking-[0.18em] text-[#b9937c]">Bangunan</p><h1 className="mt-1 text-lg font-bold">Pilih dari palet</h1></div><Grid3X3 className="text-[#b9937c]" size={22} /></div>
                            <div className="grid grid-cols-2 gap-2">
                                {buildingTypes.map((type) => (
                                    <button key={type.id} type="button" onClick={() => setSelectedType(type)} className={`group rounded-2xl border p-2 text-left transition ${selectedType?.id === type.id ? 'border-[#b9937c] bg-[#b9937c]/20 shadow-[0_0_0_1px_rgb(185_147_124_/_20%)]' : 'border-[#f9ecdf]/10 bg-[#050405]/40 hover:border-[#b9937c]/50'}`}>
                                        <img src={assetUrl(type.file)} alt="" className="mx-auto h-14 w-full object-contain transition group-hover:scale-105" />
                                        <span className="mt-1 block truncate text-xs font-semibold text-[#f9ecdf]">{type.name}</span>
                                        <span className="block text-[10px] text-[#f9ecdf]/50">{type.size}×{type.size} tile</span>
                                    </button>
                                ))}
                            </div>
                        </section>

                        <section className="rounded-3xl border border-[#f9ecdf]/10 bg-[#201818]/90 p-5 shadow-xl shadow-black/20">
                            <p className="text-xs font-bold uppercase tracking-[0.18em] text-[#b9937c]">Tampilan</p>
                            <div className="mt-4 flex items-center gap-3"><button type="button" onClick={() => updateZoom(zoom - 0.1)} className="grid size-9 place-items-center rounded-xl bg-[#46454a] text-[#f9ecdf] transition hover:bg-[#736866]"><Minus size={16} /></button><input aria-label="Zoom" type="range" min="100" max="1000" step="10" value={zoomPercentage} onChange={(event) => updateZoom(Number(event.target.value) / 100)} className="h-1 w-full accent-[#b9937c]" /><button type="button" onClick={() => updateZoom(zoom + 0.1)} className="grid size-9 place-items-center rounded-xl bg-[#46454a] text-[#f9ecdf] transition hover:bg-[#736866]"><ZoomIn size={16} /></button></div>
                            <div className="mt-2 flex justify-between text-xs text-[#f9ecdf]/55"><span>Zoom</span><span className="font-semibold text-[#f9ecdf]">{zoomPercentage}%</span></div>
                            <label className="mt-5 flex cursor-pointer items-center justify-between rounded-xl bg-[#050405]/45 px-3 py-3 text-sm"><span className="flex items-center gap-2 text-[#f9ecdf]/75"><Grid3X3 size={16} className="text-[#b9937c]" /> Tampilkan grid</span><input type="checkbox" checked={showGrid} onChange={(event) => setShowGrid(event.target.checked)} className="size-4 accent-[#b9937c]" /></label>
                            <div className="mt-3 grid grid-cols-2 gap-2"><button type="button" onClick={resetView} className="flex items-center justify-center gap-2 rounded-xl border border-[#f9ecdf]/15 px-3 py-2.5 text-xs font-semibold transition hover:border-[#b9937c] hover:text-[#b9937c]"><RotateCcw size={14} /> Tampilan</button><button type="button" onClick={resetBuildings} className="flex items-center justify-center gap-2 rounded-xl bg-[#b9937c] px-3 py-2.5 text-xs font-bold text-[#201818] transition hover:bg-[#f9ecdf]"><Trash2 size={14} /> Reset</button></div>
                        </section>

                        <p className="rounded-2xl border border-[#b9937c]/20 bg-[#b9937c]/10 px-4 py-3 text-xs leading-relaxed text-[#f9ecdf]/70"><Search size={14} className="mr-1 inline text-[#b9937c]" /> Drag untuk menggeser kanvas. Scroll untuk zoom. Klik tile kosong untuk menempatkan bangunan; klik bangunan untuk menghapusnya.</p>
                    </aside>
                </section>
                <footer className="mx-auto max-w-[1500px] px-5 pb-6 text-center text-xs text-[#f9ecdf]/35 lg:px-8">Unofficial fan-made tool. Not endorsed by Supercell.</footer>
            </main>
        </>
    );
}
