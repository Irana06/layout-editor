import { Head, Link } from '@inertiajs/react';
import {
    ArrowRightIcon,
    CaretRightIcon,
    CrosshairIcon,
    DiamondIcon,
    FloppyDiskIcon,
    GridFourIcon,
    MagnifyingGlassPlusIcon,
    MoonIcon,
    ShareNetworkIcon,
    SlidersHorizontalIcon,
    StackIcon,
    SunIcon,
} from '@phosphor-icons/react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { useAppearance } from '@/hooks/use-appearance';
import { calibrate, editor } from '@/routes';

const features = [
    {
        icon: CrosshairIcon,
        title: 'Kalibrasi grid presisi',
        description:
            'Setiap scenery dikalibrasi manual — origin dan ukuran tile disesuaikan pas ke gambar, bukan tebak-tebakan.',
    },
    {
        icon: StackIcon,
        title: 'Sprite per level',
        description:
            'Tiap level bangunan punya gambar dan kalibrasi sendiri, jadi visualnya selalu akurat dari level 1 sampai maksimal.',
    },
    {
        icon: DiamondIcon,
        title: 'Sistem Town Hall',
        description:
            'Level Balai Kota jadi batas otomatis — bangunan di atas level yang diizinkan langsung ke-grey-out.',
    },
    {
        icon: MagnifyingGlassPlusIcon,
        title: 'Zoom sampai 1000%',
        description:
            'Kamera virtual menjaga ketajaman gambar di semua level zoom, bukan cuma scale bitmap biasa.',
    },
    {
        icon: FloppyDiskIcon,
        title: 'Simpan & buka kapan saja',
        description:
            'Base yang lagi disusun otomatis tersimpan, bisa dibuka lagi atau diduplikat jadi varian baru.',
    },
    {
        icon: ShareNetworkIcon,
        title: 'Bagikan ke clan',
        description:
            'Generate link publik buat base yang udah jadi, siap dilihat siapa aja tanpa perlu akun.',
    },
];

const steps = [
    {
        number: '01',
        title: 'Pilih scenery',
        description:
            'Mulai dari lapangan yang udah dikalibrasi presisi, grid isometrik langsung nempel rapi ke gambar.',
    },
    {
        number: '02',
        title: 'Atur level Town Hall',
        description:
            'Tentukan level Balai Kota aktif — ini yang jadi batas bangunan apa aja yang bisa kamu pasang.',
    },
    {
        number: '03',
        title: 'Susun bangunan',
        description:
            'Drag dari palette, snap otomatis ke grid, collision detection mencegah bangunan numpuk.',
    },
    {
        number: '04',
        title: 'Simpan & bagikan',
        description:
            'Beri nama base kamu, simpan, dan generate link share buat ditunjukin ke clan atau komunitas.',
    },
];

function ThemeToggle() {
    const { resolvedAppearance, updateAppearance } = useAppearance();
    const isDark = resolvedAppearance === 'dark';

    return (
        <button
            type="button"
            onClick={() => updateAppearance(isDark ? 'light' : 'dark')}
            className="flex size-9 items-center justify-center rounded-full border border-border/60 bg-card/60 text-foreground backdrop-blur transition-colors hover:border-primary/50"
            aria-label="Ganti tema terang/gelap"
        >
            {isDark ? (
                <SunIcon className="size-4" />
            ) : (
                <MoonIcon className="size-4" />
            )}
        </button>
    );
}

function EditorMockup() {
    return (
        <div className="relative overflow-hidden rounded-2xl border border-border/60 bg-card/80 p-4 shadow-2xl shadow-primary/10 backdrop-blur">
            <div className="mb-3 flex items-center gap-2">
                <span className="size-2.5 rounded-full bg-destructive/60" />
                <span className="size-2.5 rounded-full bg-secondary" />
                <span className="size-2.5 rounded-full bg-primary/60" />
                <span className="ml-auto text-xs font-medium text-muted-foreground">
                    Base #1 — TH 12
                </span>
            </div>
            <div className="relative aspect-square overflow-hidden rounded-xl border border-border/60 bg-gradient-to-br from-secondary/40 to-accent/20">
                <svg
                    viewBox="0 0 200 200"
                    className="absolute inset-0 h-full w-full text-primary/25"
                >
                    {Array.from({ length: 9 }, (_, row) =>
                        Array.from({ length: 9 }, (_, col) => {
                            const x = 100 + (col - row) * 12;
                            const y = (col + row) * 6;

                            return (
                                <polygon
                                    key={`${row}-${col}`}
                                    points={`${x},${y - 6} ${x + 12},${y} ${x},${y + 6} ${x - 12},${y}`}
                                    fill="none"
                                    stroke="currentColor"
                                    strokeWidth="0.5"
                                />
                            );
                        }),
                    )}
                </svg>
                {[
                    { x: '30%', y: '35%', size: 'size-8', tone: 'bg-primary' },
                    {
                        x: '55%',
                        y: '25%',
                        size: 'size-6',
                        tone: 'bg-secondary',
                    },
                    {
                        x: '68%',
                        y: '52%',
                        size: 'size-10',
                        tone: 'bg-primary/80',
                    },
                    {
                        x: '40%',
                        y: '62%',
                        size: 'size-6',
                        tone: 'bg-secondary',
                    },
                    {
                        x: '20%',
                        y: '55%',
                        size: 'size-5',
                        tone: 'bg-primary/60',
                    },
                ].map((b, i) => (
                    <div
                        key={i}
                        className={`absolute -translate-x-1/2 -translate-y-1/2 rounded-md shadow-lg ${b.size} ${b.tone}`}
                        style={{ left: b.x, top: b.y }}
                    />
                ))}
            </div>
            <div className="absolute -bottom-5 -left-5 flex items-center gap-3 rounded-xl border border-border/60 bg-background/70 p-3 shadow-lg backdrop-blur">
                <div className="flex size-9 items-center justify-center rounded-full bg-primary/15 text-primary">
                    <GridFourIcon className="size-4" />
                </div>
                <div>
                    <p className="text-[10px] font-semibold tracking-wide text-muted-foreground uppercase">
                        Grid terkalibrasi
                    </p>
                    <p className="text-sm font-bold text-foreground">
                        44 × 44 tile
                    </p>
                </div>
            </div>
        </div>
    );
}

export default function Welcome() {
    return (
        <>
            <Head title="Base Layout Editor" />
            <div className="min-h-screen bg-background text-foreground">
                <header className="sticky top-0 z-40 border-b border-border/60 bg-background/80 backdrop-blur-md">
                    <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
                        <Link href="/" className="flex items-center gap-2">
                            <span className="flex size-8 items-center justify-center rounded-lg bg-primary text-primary-foreground">
                                <DiamondIcon weight="fill" className="size-4" />
                            </span>
                            <span className="text-lg font-bold tracking-tight">
                                Base Layout Editor
                            </span>
                        </Link>
                        <nav className="hidden items-center gap-8 md:flex">
                            <a
                                href="#fitur"
                                className="text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"
                            >
                                Fitur
                            </a>
                            <a
                                href="#cara-kerja"
                                className="text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"
                            >
                                Cara Kerja
                            </a>
                            <Link
                                href={calibrate()}
                                className="text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"
                            >
                                Calibrate
                            </Link>
                        </nav>
                        <div className="flex items-center gap-3">
                            <ThemeToggle />
                            <Button asChild size="sm" className="rounded-full">
                                <Link href={editor()}>Buka Editor</Link>
                            </Button>
                        </div>
                    </div>
                </header>

                <section className="relative overflow-hidden pt-16 pb-20 lg:pt-24 lg:pb-28">
                    <div className="bg-iso-pattern pointer-events-none absolute inset-0 z-0 text-primary" />
                    <div className="pointer-events-none absolute top-0 right-0 -z-10 size-96 translate-x-1/3 -translate-y-1/3 rounded-full bg-secondary/40 blur-3xl" />
                    <div className="pointer-events-none absolute bottom-0 left-0 -z-10 size-80 -translate-x-1/3 translate-y-1/3 rounded-full bg-primary/10 blur-3xl" />

                    <div className="relative mx-auto grid max-w-6xl grid-cols-1 items-center gap-12 px-6 lg:grid-cols-2 lg:gap-16">
                        <div className="text-center lg:text-left">
                            <div className="inline-flex items-center gap-2 rounded-full border border-border/60 bg-accent/60 px-3 py-1 text-xs font-semibold tracking-wide text-accent-foreground uppercase">
                                <SlidersHorizontalIcon className="size-3.5" />
                                Presisi tile demi tile
                            </div>
                            <h1 className="mt-6 text-4xl leading-[1.1] font-bold tracking-tight text-balance lg:text-6xl">
                                Susun base Clash of Clans dengan{' '}
                                <span className="text-primary">
                                    presisi grid isometrik
                                </span>
                            </h1>
                            <p className="mx-auto mt-6 max-w-xl text-lg leading-relaxed text-muted-foreground lg:mx-0">
                                Bukan cuma coret-coret bebas — tempatkan tiap
                                bangunan tile per tile di atas grid yang
                                dikalibrasi presisi ke gambar lapangan aslinya,
                                lalu simpan dan bagikan ke clan kamu.
                            </p>
                            <div className="mt-8 flex flex-col items-center justify-center gap-4 sm:flex-row lg:justify-start">
                                <Button
                                    asChild
                                    size="lg"
                                    className="w-full rounded-full sm:w-auto"
                                >
                                    <Link href={editor()}>
                                        Mulai Bikin Base
                                        <ArrowRightIcon className="size-4" />
                                    </Link>
                                </Button>
                                <Button
                                    asChild
                                    variant="outline"
                                    size="lg"
                                    className="w-full rounded-full sm:w-auto"
                                >
                                    <a href="#cara-kerja">Lihat Cara Kerja</a>
                                </Button>
                            </div>
                        </div>

                        <EditorMockup />
                    </div>
                </section>

                <section id="fitur" className="relative py-20 lg:py-28">
                    <div className="mx-auto max-w-6xl px-6">
                        <div className="mx-auto mb-16 max-w-2xl text-center">
                            <h2 className="text-3xl font-bold tracking-tight lg:text-4xl">
                                Dibangun buat presisi
                            </h2>
                            <p className="mt-4 text-lg text-muted-foreground">
                                Semua fitur dirancang biar base yang kamu susun
                                di sini semirip mungkin sama yang bakal kamu
                                bangun beneran di game.
                            </p>
                        </div>
                        <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
                            {features.map((feature) => (
                                <Card
                                    key={feature.title}
                                    className="rounded-2xl transition-shadow hover:shadow-lg"
                                >
                                    <CardHeader>
                                        <div className="mb-3 flex size-12 items-center justify-center rounded-xl bg-accent/70 text-primary">
                                            <feature.icon
                                                weight="bold"
                                                className="size-6"
                                            />
                                        </div>
                                        <CardTitle className="text-lg">
                                            {feature.title}
                                        </CardTitle>
                                    </CardHeader>
                                    <CardContent>
                                        <p className="text-sm leading-relaxed text-muted-foreground">
                                            {feature.description}
                                        </p>
                                    </CardContent>
                                </Card>
                            ))}
                        </div>
                    </div>
                </section>

                <section
                    id="cara-kerja"
                    className="relative bg-accent/30 py-20 lg:py-28"
                >
                    <div className="mx-auto max-w-5xl px-6">
                        <div className="mx-auto mb-16 max-w-2xl text-center">
                            <h2 className="text-3xl font-bold tracking-tight lg:text-4xl">
                                Cara kerjanya
                            </h2>
                            <p className="mt-4 text-lg text-muted-foreground">
                                Empat langkah sederhana dari lapangan kosong
                                sampai base siap dibagikan.
                            </p>
                        </div>
                        <div className="space-y-12">
                            {steps.map((step, i) => (
                                <div
                                    key={step.number}
                                    className={`flex flex-col items-center gap-6 lg:flex-row lg:gap-12 ${i % 2 === 1 ? 'lg:flex-row-reverse' : ''}`}
                                >
                                    <div className="flex size-24 shrink-0 items-center justify-center rounded-2xl border border-border/60 bg-card text-3xl font-bold text-primary shadow-sm">
                                        {step.number}
                                    </div>
                                    <div className="text-center lg:text-left">
                                        <h3 className="text-xl font-bold">
                                            {step.title}
                                        </h3>
                                        <p className="mt-2 max-w-md leading-relaxed text-muted-foreground">
                                            {step.description}
                                        </p>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>
                </section>

                <section className="relative overflow-hidden py-20 lg:py-28">
                    <div className="pointer-events-none absolute top-1/2 left-1/2 -z-10 size-[32rem] -translate-x-1/2 -translate-y-1/2 rounded-full bg-primary/10 blur-3xl" />
                    <div className="mx-auto max-w-3xl px-6 text-center">
                        <h2 className="text-3xl font-bold tracking-tight lg:text-5xl">
                            Siap susun base pertamamu?
                        </h2>
                        <p className="mt-6 text-lg text-muted-foreground">
                            Nggak perlu akun buat mulai — langsung buka editor
                            dan coba sekarang.
                        </p>
                        <Button
                            asChild
                            size="lg"
                            className="mt-10 rounded-full px-10"
                        >
                            <Link href={editor()}>
                                Buka Editor
                                <CaretRightIcon className="size-4" />
                            </Link>
                        </Button>
                    </div>
                </section>

                <footer className="border-t border-border/60 py-10">
                    <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 px-6 sm:flex-row">
                        <div className="flex items-center gap-2">
                            <span className="flex size-7 items-center justify-center rounded-lg bg-primary text-primary-foreground">
                                <DiamondIcon
                                    weight="fill"
                                    className="size-3.5"
                                />
                            </span>
                            <span className="text-sm font-semibold">
                                Base Layout Editor
                            </span>
                        </div>
                        <p className="text-sm text-muted-foreground">
                            © 2026 Base Layout Editor.
                        </p>
                        <div className="flex items-center gap-6 text-sm">
                            <Link
                                href={editor()}
                                className="text-muted-foreground transition-colors hover:text-foreground"
                            >
                                Editor
                            </Link>
                            <Link
                                href={calibrate()}
                                className="text-muted-foreground transition-colors hover:text-foreground"
                            >
                                Calibrate
                            </Link>
                        </div>
                    </div>
                </footer>
            </div>
        </>
    );
}
