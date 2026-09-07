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

    public static function for(BuildingType $type): int
    {
        if (isset(self::PINNED[$type->name])) {
            return self::PINNED[$type->name];
        }

        return (self::CATEGORIES[$type->category] ?? self::CATEGORIES['other']) + 500;
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
