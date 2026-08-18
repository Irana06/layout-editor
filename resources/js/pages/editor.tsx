import { Head, Link } from '@inertiajs/react';
import {
    BoxSelect,
    FolderOpen,
    Eye,
    Grid3X3,
    Minus,
    Redo2,
    RotateCcw,
    Save,
    Share2,
    Trash2,
    Undo2,
    ZoomIn,
} from 'lucide-react';
import {
    type PointerEvent,
    useCallback,
    useEffect,
    useMemo,
    useRef,
    useState,
    type WheelEvent,
} from 'react';
import {
    getEditorPalette,
    type EditorPaletteBuilding,
} from '@/data/game-catalog';

const CW = 1000,
    CH = 760,
    ROOT = '/game/',
    STORE = 'clash-layout-editor:v1';
const G = {
    bgW: 3705,
    bgH: 2545,
    tileW: 56,
    tileH: 42,
    ox: 1895,
    oy: 250,
    n: 44,
};
const WALL = 'buildings-source/defensive/wall/Wall18.png';
const Wall = Grid3X3;
type Type = EditorPaletteBuilding;
type Building = {
    uid: string;
    id: string;
    gx: number;
    gy: number;
    size: number;
    type: Type;
};
type Raw = {
    buildings: { id: string; gx: number; gy: number }[];
    walls: { gx: number; gy: number }[];
};
type Tool = 'select' | 'place' | 'wall';
type ServerLayout = {
    id: string;
    title: string;
    town_hall: number;
    payload: Raw;
    thumbnail_data: string | null;
    share_enabled: boolean;
};
const key = (x: number, y: number) => `${x},${y}`;

export default function Editor({
    sharedLayout,
}: {
    sharedLayout?: ServerLayout;
}) {
    const canvas = useRef<HTMLCanvasElement>(null),
        camera = useRef({ x: G.bgW / 2, y: G.bgH / 2, z: 1 });
    const images = useRef(new Map<string, HTMLImageElement>()),
        history = useRef<Raw[]>([{ buildings: [], walls: [] }]),
        pointer = useRef({
            down: false,
            moved: false,
            x: 0,
            y: 0,
            moving: null as Building | null,
            painted: new Set<string>(),
        });
    const types = useMemo<Type[]>(() => getEditorPalette(18), []),
        typeMap = useMemo(() => new Map(types.map((x) => [x.id, x])), [types]);
    const [buildings, setBuildings] = useState<Building[]>([]),
        [walls, setWalls] = useState<{ gx: number; gy: number }[]>([]),
        [selected, setSelected] = useState<Type | null>(null),
        [picked, setPicked] = useState<string | null>(null),
        [tool, setTool] = useState<Tool>('select'),
        [blueprint, setBlueprint] = useState(false),
        [grid, setGrid] = useState(true),
        [zoom, setZoom] = useState(1),
        [historyIndex, setHistoryIndex] = useState(0),
        [layoutId, setLayoutId] = useState<string | null>(sharedLayout?.id ?? null),
        [layoutTitle, setLayoutTitle] = useState(sharedLayout?.title ?? 'Layout tanpa judul'),
        [status, setStatus] = useState(
            'Pilih bangunan atau Wall untuk mulai membangun.',
        );
    const src = (f: string) => ROOT + f;
    const raw = useCallback(
        (bs = buildings, ws = walls): Raw => ({
            buildings: bs.map(({ id, gx, gy }) => ({ id, gx, gy })),
            walls: ws,
        }),
        [buildings, walls],
    );
    const restore = useCallback(
        (data: Raw) => {
            setBuildings(
                data.buildings.flatMap((b) => {
                    const type = typeMap.get(b.id);
                    return type
                        ? [
                              {
                                  ...b,
                                  uid: crypto.randomUUID(),
                                  size: type.size,
                                  type,
                              },
                          ]
                        : [];
                }),
            );
            setWalls(data.walls);
        },
        [typeMap],
    );
    const commit = useCallback(
        (bs: Building[], ws: { gx: number; gy: number }[]) => {
            setBuildings(bs);
            setWalls(ws);
            const next = [
                ...history.current.slice(0, historyIndex + 1),
                raw(bs, ws),
            ];
            history.current = next;
            setHistoryIndex(next.length - 1);
        },
        [historyIndex, raw],
    );
    const occupied = useCallback(
        (bs = buildings, ws = walls) => {
            const map = new Map<string, Building | 'wall'>();
            ws.forEach((w) => map.set(key(w.gx, w.gy), 'wall'));
            bs.forEach((b) => {
                for (let y = b.gy; y < b.gy + b.size; y += 1)
                    for (let x = b.gx; x < b.gx + b.size; x += 1)
                        map.set(key(x, y), b);
            });
            return map;
        },
        [buildings, walls],
    );
    const canPlace = (
        x: number,
        y: number,
        size: number,
        ignore?: Building,
    ) => {
        if (x < 0 || y < 0 || x + size > G.n || y + size > G.n) return false;
        const cells = occupied();
        for (let yy = y; yy < y + size; yy += 1)
            for (let xx = x; xx < x + size; xx += 1) {
                const hit = cells.get(key(xx, yy));
                if (hit && hit !== ignore) return false;
            }
        return true;
    };
    const point = (e: PointerEvent<HTMLCanvasElement>) => {
        const r = e.currentTarget.getBoundingClientRect();
        return {
            x: ((e.clientX - r.left) * CW) / r.width,
            y: ((e.clientY - r.top) * CH) / r.height,
        };
    };
    const toGrid = (p: { x: number; y: number }) => {
        const s = Math.min(CW / G.bgW, CH / G.bgH) * camera.current.z,
            wx = camera.current.x + (p.x - CW / 2) / s,
            wy = camera.current.y + (p.y - CH / 2) / s,
            px = wx - G.ox,
            py = wy - G.oy;
        return {
            gx: Math.floor((px / (G.tileW / 2) + py / (G.tileH / 2)) / 2),
            gy: Math.floor((py / (G.tileH / 2) - px / (G.tileW / 2)) / 2),
        };
    };
    function draw() {
        const el = canvas.current,
            ctx = el?.getContext('2d', { alpha: false });
        if (!el || !ctx) return;
        const dpr = Math.min(devicePixelRatio || 1, 3);
        if (el.width !== CW * dpr) {
            el.width = CW * dpr;
            el.height = CH * dpr;
        }
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        ctx.fillStyle = blueprint ? '#201818' : '#050405';
        ctx.fillRect(0, 0, CW, CH);
        const s = Math.min(CW / G.bgW, CH / G.bgH) * camera.current.z,
            ws = (x: number, y: number) => ({
                x: CW / 2 + (x - camera.current.x) * s,
                y: CH / 2 + (y - camera.current.y) * s,
            }),
            iso = (x: number, y: number) =>
                ws(
                    G.ox + ((x - y) * G.tileW) / 2,
                    G.oy + ((x + y) * G.tileH) / 2,
                ),
            diamond = (x: number, y: number, z = 1) => {
                const a = iso(x, y),
                    b = iso(x + z, y),
                    c = iso(x + z, y + z),
                    d = iso(x, y + z);
                ctx.beginPath();
                ctx.moveTo(a.x, a.y);
                ctx.lineTo(b.x, b.y);
                ctx.lineTo(c.x, c.y);
                ctx.lineTo(d.x, d.y);
                ctx.closePath();
            };
        const bg = images.current.get('scenery/classic.jpg');
        if (!blueprint && bg?.naturalWidth) {
            const p = ws(0, 0);
            ctx.drawImage(bg, p.x, p.y, G.bgW * s, G.bgH * s);
        }
        if (grid || blueprint) {
            ctx.strokeStyle = blueprint
                ? 'rgb(185 147 124 / .45)'
                : 'rgb(249 236 223 / .3)';
            ctx.lineWidth = Math.max(1, s * 0.6);
            for (let x = 0; x <= G.n; x += 1) {
                const a = iso(x, 0),
                    b = iso(x, G.n);
                ctx.beginPath();
                ctx.moveTo(a.x, a.y);
                ctx.lineTo(b.x, b.y);
                ctx.stroke();
            }
            for (let y = 0; y <= G.n; y += 1) {
                const a = iso(0, y),
                    b = iso(G.n, y);
                ctx.beginPath();
                ctx.moveTo(a.x, a.y);
                ctx.lineTo(b.x, b.y);
                ctx.stroke();
            }
        }
        walls.forEach((w) => {
            if (blueprint) {
                diamond(w.gx, w.gy);
                ctx.fillStyle = '#b9937c';
                ctx.fill();
                ctx.strokeStyle = '#f9ecdf';
                ctx.stroke();
                return;
            }
            const im = images.current.get(WALL);
            if (!im?.naturalWidth) return;
            const a = iso(w.gx, w.gy),
                b = iso(w.gx + 1, w.gy + 1),
                width = G.tileW * s * 1.2,
                height = (width * im.naturalHeight) / im.naturalWidth;
            ctx.drawImage(
                im,
                (a.x + b.x) / 2 - width / 2,
                (a.y + b.y) / 2 + (G.tileH * s) / 2 - height,
                width,
                height,
            );
        });
        [...buildings]
            .sort((a, b) => a.gx + a.gy - b.gx - b.gy)
            .forEach((b) => {
                if (blueprint) {
                    diamond(b.gx, b.gy, b.size);
                    ctx.fillStyle =
                        b.uid === picked
                            ? '#f9ecdf'
                            : b.type.definition.category === 'defense'
                              ? '#736866'
                              : '#46454a';
                    ctx.fill();
                    ctx.strokeStyle = b.uid === picked ? '#b9937c' : '#f9ecdf';
                    ctx.lineWidth = Math.max(1, s);
                    ctx.stroke();
                    return;
                }
                const im = images.current.get(b.type.file);
                if (!im?.naturalWidth) return;
                const a = iso(b.gx, b.gy),
                    z = iso(b.gx + b.size, b.gy + b.size),
                    width = b.size * G.tileW * s * 1.05,
                    height = (width * im.naturalHeight) / im.naturalWidth;
                ctx.drawImage(
                    im,
                    (a.x + z.x) / 2 - width / 2,
                    (a.y + z.y) / 2 + (b.size * G.tileH * s) / 2 - height,
                    width,
                    height,
                );
                if (b.uid === picked) {
                    diamond(b.gx, b.gy, b.size);
                    ctx.strokeStyle = '#f9ecdf';
                    ctx.lineWidth = Math.max(1.5, s * 2);
                    ctx.stroke();
                }
            });
    }
    useEffect(() => {
        ['scenery/classic.jpg', WALL, ...types.map((x) => x.file)].forEach(
            (file) => {
                const im = new Image();
                im.onload = () => draw();
                im.src = src(file);
                images.current.set(file, im);
            },
        ); /* eslint-disable-next-line react-hooks/exhaustive-deps */
    }, [types]);
    useEffect(() => {
        draw(); /* eslint-disable-next-line react-hooks/exhaustive-deps */
    }, [buildings, walls, grid, blueprint, picked, zoom]);
    useEffect(() => {
        try {
            const saved = localStorage.getItem(STORE);
            if (!saved) return;
            const data = JSON.parse(saved) as Raw;
            if (Array.isArray(data.buildings) && Array.isArray(data.walls)) {
                restore(data);
                history.current = [data];
                setStatus('Layout lokal dipulihkan otomatis.');
            }
        } catch {
            localStorage.removeItem(STORE);
        }
    }, [restore]);
    useEffect(() => {
        localStorage.setItem(STORE, JSON.stringify(raw()));
    }, [buildings, walls, raw]);
    const undo = useCallback(() => {
        if (!historyIndex) return;
        const i = historyIndex - 1;
        restore(history.current[i]);
        setHistoryIndex(i);
    }, [historyIndex, restore]);
    const redo = useCallback(() => {
        if (historyIndex >= history.current.length - 1) return;
        const i = historyIndex + 1;
        restore(history.current[i]);
        setHistoryIndex(i);
    }, [historyIndex, restore]);
    useEffect(() => {
        const onKey = (e: KeyboardEvent) => {
            if (e.target instanceof HTMLInputElement) return;
            if ((e.ctrlKey || e.metaKey) && e.key === 'z') {
                e.preventDefault();
                e.shiftKey ? redo() : undo();
            }
            if ((e.ctrlKey || e.metaKey) && e.key === 'y') {
                e.preventDefault();
                redo();
            }
            if (e.key === 'Delete' && picked) {
                commit(
                    buildings.filter((b) => b.uid !== picked),
                    walls,
                );
                setPicked(null);
            }
            if (e.key.toLowerCase() === 'w') {
                setTool('wall');
                setSelected(null);
            }
            if (e.key.toLowerCase() === 'v') setBlueprint((x) => !x);
        };
        addEventListener('keydown', onKey);
        return () => removeEventListener('keydown', onKey);
    }, [buildings, commit, picked, redo, undo, walls]);
    const paintWall = (gx: number, gy: number, erase: boolean) => {
        if (gx < 0 || gy < 0 || gx >= G.n || gy >= G.n) return;
        const hit = occupied().get(key(gx, gy));
        if (erase && hit === 'wall')
            commit(
                buildings,
                walls.filter((w) => key(w.gx, w.gy) !== key(gx, gy)),
            );
        else if (!erase && !hit) commit(buildings, [...walls, { gx, gy }]);
    };
    const down = (e: PointerEvent<HTMLCanvasElement>) => {
        e.currentTarget.setPointerCapture(e.pointerId);
        const p = point(e),
            cell = toGrid(p),
            hit = occupied().get(key(cell.gx, cell.gy));
        pointer.current = {
            down: true,
            moved: false,
            x: p.x,
            y: p.y,
            moving: tool === 'select' && typeof hit === 'object' ? hit : null,
            painted: new Set(),
        };
        if (tool === 'wall') {
            paintWall(cell.gx, cell.gy, e.shiftKey);
            pointer.current.painted.add(key(cell.gx, cell.gy));
        }
    };
    const move = (e: PointerEvent<HTMLCanvasElement>) => {
        const d = pointer.current;
        if (!d.down) return;
        const p = point(e),
            dx = p.x - d.x,
            dy = p.y - d.y;
        if (Math.abs(dx) > 3 || Math.abs(dy) > 3) d.moved = true;
        if (tool === 'wall') {
            const c = toGrid(p),
                k = key(c.gx, c.gy);
            if (!d.painted.has(k)) {
                paintWall(c.gx, c.gy, e.shiftKey);
                d.painted.add(k);
            }
            d.x = p.x;
            d.y = p.y;
            return;
        }
        if (d.moved && !d.moving) {
            const s = Math.min(CW / G.bgW, CH / G.bgH) * camera.current.z;
            camera.current.x -= dx / s;
            camera.current.y -= dy / s;
            d.x = p.x;
            d.y = p.y;
            draw();
        }
    };
    const up = (e: PointerEvent<HTMLCanvasElement>) => {
        const d = pointer.current;
        if (!d.down) return;
        d.down = false;
        const c = toGrid(point(e));
        if (tool === 'wall') {
            setStatus(
                'Wall ditambahkan. Tahan Shift saat drag untuk menghapus.',
            );
            return;
        }
        if (d.moving) {
            if (d.moved && canPlace(c.gx, c.gy, d.moving.size, d.moving)) {
                commit(
                    buildings.map((b) =>
                        b === d.moving ? { ...b, gx: c.gx, gy: c.gy } : b,
                    ),
                    walls,
                );
                setStatus('Bangunan dipindahkan.');
            } else if (!d.moved) setPicked(d.moving.uid);
            return;
        }
        if (
            !d.moved &&
            tool === 'place' &&
            selected &&
            canPlace(c.gx, c.gy, selected.size)
        ) {
            const b = {
                uid: crypto.randomUUID(),
                id: selected.id,
                gx: c.gx,
                gy: c.gy,
                size: selected.size,
                type: selected,
            };
            commit([...buildings, b], walls);
            setPicked(b.uid);
            setStatus(`${selected.name} ditambahkan.`);
        }
    };
    const setZ = (value: number, p = { x: CW / 2, y: CH / 2 }) => {
        const c = camera.current,
            base = Math.min(CW / G.bgW, CH / G.bgH),
            old = base * c.z,
            before = {
                x: c.x + (p.x - CW / 2) / old,
                y: c.y + (p.y - CH / 2) / old,
            };
        c.z = Math.max(1, Math.min(10, value));
        const after = {
            x: c.x + (p.x - CW / 2) / (base * c.z),
            y: c.y + (p.y - CH / 2) / (base * c.z),
        };
        c.x += before.x - after.x;
        c.y += before.y - after.y;
        setZoom(c.z);
    };
    const wheel = (e: WheelEvent<HTMLCanvasElement>) => {
        e.preventDefault();
        setZ(
            camera.current.z * (e.deltaY < 0 ? 1.15 : 1 / 1.15),
            point(e as unknown as PointerEvent<HTMLCanvasElement>),
        );
    };
    const choose = (t: Type) => {
        setSelected(t);
        setTool('place');
        setPicked(null);
        setStatus(`Mode tempatkan: ${t.name}.`);
    },
        z = Math.round(zoom * 100);

    const csrfToken = () =>
        document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')
            ?.content ?? '';

    const saveDraft = async (): Promise<string | null> => {
        setStatus('Menyimpan draft…');
        const thumbnail = canvas.current?.toDataURL('image/jpeg', 0.72) ?? null;
        const response = await fetch(layoutId ? `/layouts/${layoutId}` : '/layouts', {
            method: layoutId ? 'PUT' : 'POST',
            headers: { 'Content-Type': 'application/json', 'X-CSRF-TOKEN': csrfToken(), Accept: 'application/json' },
            body: JSON.stringify({ title: layoutTitle, town_hall: 18, payload: raw(), thumbnail_data: thumbnail }),
        });
        if (!response.ok) { setStatus('Draft gagal disimpan.'); return null; }
        const data = await response.json() as { layout: ServerLayout };
        setLayoutId(data.layout.id); setLayoutTitle(data.layout.title); setStatus('Draft tersimpan di server.'); return data.layout.id;
    };

    const loadLatestDraft = async () => {
        const response = await fetch('/layouts/drafts', { headers: { Accept: 'application/json' } });
        if (!response.ok) { setStatus('Daftar draft gagal dimuat.'); return; }
        const data = await response.json() as { layouts: ServerLayout[] };
        const draft = data.layouts[0];
        if (!draft) { setStatus('Belum ada draft tersimpan di browser ini.'); return; }
        restore(draft.payload); history.current = [draft.payload]; setHistoryIndex(0); setLayoutId(draft.id); setLayoutTitle(draft.title); setStatus(`Draft “${draft.title}” dimuat.`);
    };

    const shareDraft = async () => {
        const id = layoutId ?? await saveDraft();
        if (!id) return;
        const response = await fetch(`/layouts/${id}/share`, { method: 'PATCH', headers: { 'Content-Type': 'application/json', 'X-CSRF-TOKEN': csrfToken(), Accept: 'application/json' }, body: JSON.stringify({ share_enabled: true }) });
        if (!response.ok) { setStatus('Share link gagal dibuat.'); return; }
        const data = await response.json() as { share_url: string };
        await navigator.clipboard.writeText(data.share_url);
        setStatus('Share link disalin ke clipboard.');
    };

    useEffect(() => {
        if (!sharedLayout) return;
        restore(sharedLayout.payload); history.current = [sharedLayout.payload]; setHistoryIndex(0); setStatus(`Membuka layout publik: ${sharedLayout.title}.`);
    }, [restore, sharedLayout]);
    return (
        <>
            <Head title="Layout Editor" />
            <main className="editor-shell editor-grid-pattern">
                <header className="border-b border-[#f9ecdf]/10 bg-[#050405]/80 backdrop-blur-xl">
                    <div className="mx-auto flex max-w-[1500px] items-center justify-between gap-4 px-5 py-4 lg:px-8">
                        <Link href="/" className="flex items-center gap-3">
                            <span className="grid size-10 place-items-center rounded-xl bg-[#b9937c] text-lg font-black text-[#201818]">
                                C
                            </span>
                            <span>
                                <b className="block">Clash Layout</b>
                                <small className="text-[#b9937c]">
                                    Base Editor
                                </small>
                            </span>
                        </Link>
                        <div className="hidden items-center gap-2 md:flex">
                            <input value={layoutTitle} onChange={(event) => setLayoutTitle(event.target.value)} className="w-44 rounded-lg border border-[#f9ecdf]/15 bg-[#201818] px-3 py-2 text-xs text-[#f9ecdf] outline-none focus:border-[#b9937c]" aria-label="Judul layout" />
                            <button type="button" onClick={loadLatestDraft} className="editor-tool !h-9 !min-h-0 !w-16"><FolderOpen size={15} />Load</button>
                            <button type="button" onClick={saveDraft} className="editor-tool !h-9 !min-h-0 !w-16"><Save size={15} />Save</button>
                            <button type="button" onClick={shareDraft} className="editor-tool !h-9 !min-h-0 !w-16"><Share2 size={15} />Share</button>
                        </div>
                        <span className="flex gap-2 text-xs text-[#b9937c]">
                            <Save size={15} />
                            Autosave lokal
                        </span>
                    </div>
                </header>
                <section className="mx-auto grid max-w-[1500px] gap-5 px-5 py-6 lg:grid-cols-[minmax(0,1fr)_310px]">
                    <div className="overflow-hidden rounded-3xl border border-[#f9ecdf]/10 bg-[#201818]/80 p-3">
                        <div className="mb-3 flex justify-between px-2 text-sm">
                            <span>{status}</span>
                            <span>
                                Bangunan {buildings.length} · Wall{' '}
                                {walls.length}
                            </span>
                        </div>
                        <canvas
                            ref={canvas}
                            onPointerDown={down}
                            onPointerMove={move}
                            onPointerUp={up}
                            onWheel={wheel}
                            className="block w-full touch-none rounded-2xl bg-[#050405]"
                            style={{
                                aspectRatio: `${CW}/${CH}`,
                                cursor:
                                    tool === 'wall'
                                        ? 'cell'
                                        : tool === 'place'
                                          ? 'copy'
                                          : 'grab',
                            }}
                        />
                    </div>
                    <aside className="space-y-4">
                        <section className="rounded-3xl border border-[#f9ecdf]/10 bg-[#201818]/90 p-5">
                            <p className="text-xs font-bold tracking-widest text-[#b9937c] uppercase">
                                Tool
                            </p>
                            <div className="mt-3 grid grid-cols-3 gap-2">
                                <button
                                    className={`editor-tool ${tool === 'select' ? 'editor-tool-active' : ''}`}
                                    onClick={() => {
                                        setTool('select');
                                        setSelected(null);
                                    }}
                                >
                                    <BoxSelect size={16} />
                                    Pilih
                                </button>
                                <button
                                    className={`editor-tool ${tool === 'wall' ? 'editor-tool-active' : ''}`}
                                    onClick={() => {
                                        setTool('wall');
                                        setSelected(null);
                                    }}
                                >
                                    <Wall size={16} />
                                    Wall
                                </button>
                                <button
                                    className={`editor-tool ${blueprint ? 'editor-tool-active' : ''}`}
                                    onClick={() => setBlueprint(!blueprint)}
                                >
                                    <Eye size={16} />
                                    Blueprint
                                </button>
                                <button
                                    disabled={!historyIndex}
                                    className="editor-tool disabled:opacity-30"
                                    onClick={undo}
                                >
                                    <Undo2 size={16} />
                                    Undo
                                </button>
                                <button
                                    disabled={
                                        historyIndex ===
                                        history.current.length - 1
                                    }
                                    className="editor-tool disabled:opacity-30"
                                    onClick={redo}
                                >
                                    <Redo2 size={16} />
                                    Redo
                                </button>
                                <button
                                    className="editor-tool"
                                    onClick={() => {
                                        camera.current = {
                                            x: G.bgW / 2,
                                            y: G.bgH / 2,
                                            z: 1,
                                        };
                                        setZoom(1);
                                    }}
                                >
                                    <RotateCcw size={16} />
                                    Reset view
                                </button>
                            </div>
                        </section>
                        <section className="rounded-3xl border border-[#f9ecdf]/10 bg-[#201818]/90 p-5">
                            <div className="mb-4 flex justify-between">
                                <b>Bangunan</b>
                                <Grid3X3 className="text-[#b9937c]" />
                            </div>
                            <div className="grid grid-cols-2 gap-2">
                                {types.map((t) => (
                                    <button
                                        key={t.id}
                                        onClick={() => choose(t)}
                                        className={`rounded-2xl border p-2 text-left ${selected?.id === t.id ? 'border-[#b9937c] bg-[#b9937c]/20' : 'border-[#f9ecdf]/10 bg-[#050405]/40'}`}
                                    >
                                        <img
                                            src={src(t.file)}
                                            alt=""
                                            className="mx-auto h-14 w-full object-contain"
                                        />
                                        <b className="block truncate text-xs">
                                            {t.name}
                                        </b>
                                        <small>
                                            Lv {t.level.level} · {t.size}×
                                            {t.size}
                                        </small>
                                    </button>
                                ))}
                            </div>
                        </section>
                        <section className="rounded-3xl border border-[#f9ecdf]/10 bg-[#201818]/90 p-5">
                            <div className="flex items-center gap-3">
                                <button
                                    className="editor-tool !w-10"
                                    onClick={() => setZ(zoom - 0.1)}
                                >
                                    <Minus size={16} />
                                </button>
                                <input
                                    className="w-full accent-[#b9937c]"
                                    type="range"
                                    min="100"
                                    max="1000"
                                    step="10"
                                    value={z}
                                    onChange={(e) =>
                                        setZ(+e.target.value / 100)
                                    }
                                />
                                <button
                                    className="editor-tool !w-10"
                                    onClick={() => setZ(zoom + 0.1)}
                                >
                                    <ZoomIn size={16} />
                                </button>
                            </div>
                            <label className="mt-4 flex justify-between text-sm">
                                Grid{' '}
                                <input
                                    type="checkbox"
                                    checked={grid}
                                    onChange={(e) => setGrid(e.target.checked)}
                                />
                            </label>
                            <button
                                className="mt-4 flex w-full items-center justify-center gap-2 rounded-xl bg-[#b9937c] p-3 text-xs font-bold text-[#201818]"
                                onClick={() => {
                                    commit([], []);
                                    setPicked(null);
                                }}
                            >
                                <Trash2 size={15} />
                                Reset layout
                            </button>
                        </section>
                        <p className="rounded-2xl bg-[#b9937c]/10 p-4 text-xs text-[#f9ecdf]/70">
                            Drag bangunan untuk memindahkan. Delete menghapus
                            pilihan. Ctrl/Cmd+Z undo, Ctrl/Cmd+Y redo, W wall, V
                            blueprint. Shift+drag wall menghapus.
                        </p>
                    </aside>
                </section>
            </main>
        </>
    );
}
