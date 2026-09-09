<?php

namespace App\Support;

use Illuminate\Support\Str;

/**
 * Which filename suffixes are modes a player chooses, and which are just states
 * of the same artwork.
 *
 * The asset set carries both in the same shape. "Inferno Tower7 Multi" is a mode
 * — you decide it, and it changes what the building does. "Inferno Tower7 Multi
 * Depleted" is that same mode out of ammo, and "Cannon7 pre May-15-2023" is
 * simply older art. Only the first belongs in the catalogue as a separate
 * choice; treating the others as modes would fill the editor with buttons for
 * things nobody picks.
 *
 * Gear Up (Cannon, Mortar, Archer Tower) is deliberately absent: only one
 * building per base may be geared, so it needs a count rule rather than a
 * toggle, and is handled separately.
 */
class BuildingVariants
{
    /**
     * Modes per asset subfolder, as `suffix => [key, label]`.
     *
     * Read off the asset names rather than guessed: Multi-Gear Tower, Spell
     * Tower and Skeleton Trap turned out to carry modes too, which is why this
     * is a table and not a special case for Inferno Tower.
     *
     * @var array<string, array<string, array{string, string}>>
     */
    private const MODES = [
        'inferno-tower' => [
            'single' => ['single', 'Single'],
            'multi' => ['multi', 'Multi'],
        ],
        'x-bow' => [
            'ground' => ['ground', 'Darat'],
            'air' => ['air', 'Darat & udara'],
        ],
        'multi-gear-tower' => [
            'fastattack' => ['fast', 'Serangan cepat'],
            'longrange' => ['long', 'Jangkauan jauh'],
        ],
        'skeleton-trap' => [
            'ground' => ['ground', 'Darat'],
            'air' => ['air', 'Udara'],
        ],
        'spell-tower' => [
            'rage' => ['rage', 'Rage'],
            'poison' => ['poison', 'Poison'],
            'invisibility' => ['invisibility', 'Invisibility'],
            'earthquake' => ['earthquake', 'Earthquake'],
        ],
        // The gear-up building is its own entry in the library, so its modes
        // hang off its own subfolder rather than the ordinary building's.
        'cannon-gear' => [
            '' => ['normal', 'Normal'],
            'g' => ['geared', 'Gear Up'],
        ],
        'mortar-gear' => [
            '' => ['normal', 'Normal'],
            'g' => ['geared', 'Gear Up'],
        ],
        'archer-tower-gear' => [
            'up' => ['normal', 'Normal'],
            'g' => ['geared', 'Gear Up'],
        ],
    ];

    /**
     * Which artworks belong to the gear-up building rather than the ordinary
     * one, per asset subfolder.
     *
     * In the game these are two separate entries: six plain Cannons and one
     * that carries the lever, and only the levered one offers the Normal /
     * Gear Up toggle once placed. Modelling gear-up as a mode of the ordinary
     * Cannon made every Cannon look levered and gave the base seven of them.
     *
     * @var array<string, array<string, string>>
     */
    private const GEAR_UP = [
        // suffix => which building it belongs to
        'cannon' => ['b' => 'ordinary', '' => 'gear', 'g' => 'gear'],
        'mortar' => ['b' => 'ordinary', '' => 'gear', 'g' => 'gear'],
        'archer-tower' => ['' => 'ordinary', 'up' => 'gear', 'g' => 'gear'],
    ];

    /** True when this asset folder splits into an ordinary and a gear-up building. */
    public static function splitsForGearUp(?string $subfolder): bool
    {
        return isset(self::GEAR_UP[$subfolder ?? '']);
    }

    /**
     * Whether a file belongs to the ordinary building or the gear-up one.
     * Returns null when the folder has no gear-up split at all.
     */
    public static function gearOwnerFor(?string $subfolder, string $suffix): ?string
    {
        $map = self::GEAR_UP[$subfolder ?? ''] ?? null;
        if ($map === null) {
            return null;
        }

        $clean = Str::lower(trim((string) preg_replace('/\s*\bpre\s+.*$/i', '', trim($suffix))));

        // An unrecognised suffix is a state of the plain building, not a third
        // entry: "Cannon2 pre May-15-2023" is simply an older Cannon.
        return $map[$clean] ?? 'ordinary';
    }

    /**
     * The mode a filename suffix names, or null when the suffix is a state,
     * a skin, or historical art rather than a choice.
     *
     * A suffix only counts when it is the whole suffix: "Multi" is the mode,
     * while "Multi Depleted" is that mode's empty-ammo artwork and must not
     * displace it.
     */
    public static function modeFor(?string $subfolder, string $suffix): ?string
    {
        $modes = self::MODES[$subfolder ?? ''] ?? [];
        // Historical art is an older drawing of some mode, not a mode of its
        // own, so "Cannon7B pre May-15-2023" resolves to the same mode as
        // "Cannon7B" and simply loses to it as a duplicate.
        $clean = Str::lower(trim((string) preg_replace('/\s*\bpre\s+.*$/i', '', trim($suffix))));

        if (isset($modes[$clean])) {
            return $modes[$clean][0];
        }

        // Where the unsuffixed artwork is itself a mode — a Cannon before it is
        // geared — every other suffix is a state of that mode rather than a
        // mode of its own, so "Cannon7 pre May-15-2023" belongs with it instead
        // of forming a nameless third choice.
        return isset($modes['']) ? $modes[''][0] : null;
    }

    /** Whether this subfolder offers a mode choice at all. */
    public static function hasModes(?string $subfolder): bool
    {
        return isset(self::MODES[$subfolder ?? '']);
    }

    /**
     * Modes for a subfolder in the order they should be offered, as
     * `key => label`. Empty when the building has no choice to make.
     *
     * @return array<string, string>
     */
    public static function labelsFor(?string $subfolder): array
    {
        $labels = [];
        foreach (self::MODES[$subfolder ?? ''] ?? [] as [$key, $label]) {
            $labels[$key] = $label;
        }

        return $labels;
    }

    /**
     * True when a suffix names a mode outright, rather than falling back to the
     * default one. Used to tell a real second artwork from a state of the first.
     */
    public static function isExplicitMode(?string $subfolder, string $suffix): bool
    {
        return isset(self::MODES[$subfolder ?? ''][Str::lower(trim($suffix))]);
    }
}
