import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { gameAssetUrl } from '@/lib/game-assets';
import type { BuildingLevel, BuildingType } from '@/types/game';

type Props = {
    type: BuildingType;
    maxLevel: number;
    children: React.ReactNode;
    onPick: (level: BuildingLevel) => void;
};

export function LevelPickerPopover({ type, maxLevel, children, onPick }: Props) {
    const unlockedLevels = type.levels.filter((level) => level.level <= maxLevel);

    if (unlockedLevels.length <= 1) {
        // Nothing to disambiguate — clicking the palette item just arms the only available level.
        return <>{children}</>;
    }

    return (
        <Popover>
            <PopoverTrigger asChild>{children}</PopoverTrigger>
            <PopoverContent className="w-56">
                <p className="mb-2 text-xs font-semibold">Pilih level {type.name}</p>
                <div className="grid grid-cols-4 gap-1.5">
                    {unlockedLevels.map((level) => (
                        <button
                            key={level.id}
                            type="button"
                            onClick={() => onPick(level)}
                            className="border-border/60 hover:border-primary flex flex-col items-center gap-1 rounded-lg border p-1.5"
                        >
                            <img src={gameAssetUrl(level.file_path)} alt="" loading="lazy" className="size-8 object-contain" />
                            <span className="text-[10px]">Lv{level.level}</span>
                        </button>
                    ))}
                </div>
            </PopoverContent>
        </Popover>
    );
}
