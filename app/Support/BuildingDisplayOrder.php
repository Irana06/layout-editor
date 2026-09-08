<?php

namespace App\Support;

use App\Models\BuildingType;
use Illuminate\Support\Collection;

/**
 * The order buildings appear in the library, matching how a base is actually
 * built rather than any property of the data.
 *
 * Nothing in the catalogue implies "Town Hall first, then Wall" — that comes
 * from the order people place things: the Town Hall anchors the base, walls are
 * laid in bulk next, and traps go in last once everything else has a home. So
 * the sequence is stated here, computed server-side, and handed to every client
 * as `display_order`. Keeping it in one place stops the mobile app and the web
 * editor from drifting into two different opinions.
 */
class BuildingDisplayOrder
{
    /** Placed before their category, by name. */
    private const PINNED = [
        'Town Hall' => 100,
        'Wall' => 200,
        'Clan Castle' => 300,
        // Reads as a defence in the library even though the catalogue files it
        // under army.
        'Hero Banner Empty' => 2000,
        // The only `other` entries that are real, placeable buildings.
        'Builders Hut' => 3000,
        'Helper Hut' => 3010,
        'MasterBuilderHut' => 3020,
    ];

    /** Everything else follows its category. */
    private const CATEGORIES = [
        'defensive' => 1000,
        'resource' => 4000,
        'army' => 5000,
        'traps' => 6000,
        'other' => 7000,
    ];

    /**
     * Order observed in the game itself, written down rather than derived.
     *
     * No rule reproduces it: the traps happen to run from most numerous to
     * fewest, but the defences do not, and neither list follows the Town Hall
     * that unlocks each building. It is most likely the game's own internal
     * ordering, which cannot be inferred from outside — so guessing a formula
     * would be wrong in places nobody would think to check. Anything missing
     * here simply follows its category, sorted by name.
     */
    private const WITHIN_CATEGORY = [
        'defensive' => [
            'Cannon',
            'Archer Tower',
            'Wizard Tower',
            'Air Defense',
            'Mortar',
            'Hidden Tesla',
            'X-Bow',
            'Inferno Tower',
            'Air Sweeper',
            'Eagle Artillery',
            'Bomb Tower',
            'Crafting Station',
            // Limited-time defences, crafted at the station above.
            'Hot Candle',
            'Hero Hunter',
            'Cake-A-Pult',
        ],
        'traps' => [
            'Bomb',
            'Spring Trap',
            'Giant Bomb',
            'Air Bomb',
            'Seeking Air Mine',
            'SkeletonTrap',
            'Tornado Trap',
        ],
    ];

    public static function for(BuildingType $type): int
    {
        if (isset(self::PINNED[$type->name])) {
            return self::PINNED[$type->name];
        }

        $base = self::CATEGORIES[$type->category] ?? self::CATEGORIES['other'];
        $position = array_search(
            $type->name,
            self::WITHIN_CATEGORY[$type->category] ?? [],
            strict: true,
        );

        // Unlisted buildings sit after the known sequence, not among it, so a
        // newly imported asset never silently displaces a verified position.
        return $base + ($position === false ? 500 : $position);
    }

    /**
     * Sort a loaded collection into library order: by rank, then by name so
     * everything inside one category stays predictable.
     *
     * @param  Collection<int, BuildingType>  $types
     * @return Collection<int, BuildingType>
     */
    public static function sort($types)
    {
        return $types
            ->sortBy(fn (BuildingType $type) => [self::for($type), $type->name])
            ->values();
    }
}
