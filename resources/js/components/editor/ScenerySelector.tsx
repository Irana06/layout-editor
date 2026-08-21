import { gameAssetUrl } from '@/lib/game-assets';
import type { Scenery } from '@/types/game';
import { useEditor } from './EditorProvider';

export function ScenerySelector({ sceneries }: { sceneries: Scenery[] }) {
    const { state, dispatch } = useEditor();
    const calibrated = sceneries.filter((s) => s.calibrated);

    return (
        <div>
            <p className="text-muted-foreground mb-2 text-xs font-semibold tracking-wide uppercase">Scenery</p>
            {calibrated.length === 0 ? (
                <p className="text-muted-foreground text-xs">
                    Belum ada scenery terkalibrasi. Kalibrasi dulu lewat halaman{' '}
                    <a href="/calibrate" className="text-primary underline">
                        Calibrate
                    </a>
                    .
                </p>
            ) : (
                <div className="grid grid-cols-3 gap-2">
                    {calibrated.map((s) => (
                        <button
                            key={s.id}
                            type="button"
                            disabled={state.readOnly}
                            onClick={() => dispatch({ type: 'SET_SCENERY', sceneryId: s.id })}
                            className={`overflow-hidden rounded-lg border transition-colors disabled:opacity-60 ${
                                state.sceneryId === s.id ? 'border-primary ring-primary/40 ring-2' : 'border-border/60 hover:border-primary/50'
                            }`}
                            title={s.name}
                        >
                            <img src={gameAssetUrl(s.file_path)} alt={s.name} loading="lazy" className="h-12 w-full object-cover" />
                        </button>
                    ))}
                </div>
            )}
        </div>
    );
}
