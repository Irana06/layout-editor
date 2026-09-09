<?php

namespace Tests\Feature;

use App\Support\BuildingVariants;
use Tests\TestCase;

class BuildingVariantsTest extends TestCase
{
    public function test_a_mode_is_a_choice_the_player_makes(): void
    {
        $this->assertSame('single', BuildingVariants::modeFor('inferno-tower', 'Single'));
        $this->assertSame('multi', BuildingVariants::modeFor('inferno-tower', 'Multi'));
        $this->assertSame('air', BuildingVariants::modeFor('x-bow', 'Air'));
        $this->assertSame('fast', BuildingVariants::modeFor('multi-gear-tower', 'FastAttack'));
        $this->assertSame('rage', BuildingVariants::modeFor('spell-tower', 'Rage'));
    }

    public function test_a_state_of_the_same_mode_is_not_a_second_mode(): void
    {
        // "Multi Depleted" is that mode out of ammo. Treating it as a mode
        // would put an unusable choice in the editor next to the real one.
        $this->assertNull(BuildingVariants::modeFor('inferno-tower', 'Multi Depleted'));
        $this->assertNull(BuildingVariants::modeFor('x-bow', 'Air Depleted'));
        $this->assertNull(BuildingVariants::modeFor('skeleton-trap', 'unarmed'));

        // Older art of a mode does belong to it — it is the same choice, drawn
        // differently — but it is not an explicit one, so it loses to the
        // current drawing instead of replacing it.
        $this->assertSame('multi', BuildingVariants::modeFor('inferno-tower', 'Multi pre June-16-2025'));
        $this->assertFalse(BuildingVariants::isExplicitMode('inferno-tower', 'Multi pre June-16-2025'));
    }

    public function test_buildings_without_a_choice_report_none(): void
    {
        $this->assertFalse(BuildingVariants::hasModes('wall'));
        $this->assertFalse(BuildingVariants::hasModes('air-defense'));
        $this->assertFalse(BuildingVariants::hasModes(null));
        $this->assertSame([], BuildingVariants::labelsFor('wall'));
    }

    public function test_gear_up_has_three_artworks_not_two(): void
    {
        // Plain, the same building wearing the lever that switches it, and the
        // geared form. Cannon and Mortar leave the suffix off the levered one;
        // Archer Tower marks that "Up" and leaves its plain one unsuffixed.
        $this->assertSame(
            ['plain' => 'Biasa', 'lever' => 'Bertuas', 'geared' => 'Gear Up'],
            BuildingVariants::labelsFor('cannon'),
        );

        $this->assertSame('plain', BuildingVariants::modeFor('cannon', 'B'));
        $this->assertSame('lever', BuildingVariants::modeFor('cannon', ''));
        $this->assertSame('geared', BuildingVariants::modeFor('cannon', 'G'));

        $this->assertSame('plain', BuildingVariants::modeFor('archer-tower', ''));
        $this->assertSame('lever', BuildingVariants::modeFor('archer-tower', 'Up'));
        $this->assertSame('geared', BuildingVariants::modeFor('archer-tower', 'G'));
    }

    public function test_older_art_belongs_to_the_mode_it_depicts(): void
    {
        // "Cannon7B pre May-15-2023" is an old drawing of the plain cannon, so
        // it competes with the current one rather than becoming a fourth mode.
        $this->assertSame('plain', BuildingVariants::modeFor('cannon', 'B pre May-15-2023'));
        $this->assertSame('geared', BuildingVariants::modeFor('cannon', 'G pre May-15-2023'));
        $this->assertSame('lever', BuildingVariants::modeFor('cannon', 'pre May-15-2023'));

        $this->assertFalse(BuildingVariants::isExplicitMode('cannon', 'pre May-15-2023'));
        $this->assertTrue(BuildingVariants::isExplicitMode('cannon', 'G'));
    }

    public function test_labels_come_in_the_order_they_should_be_offered(): void
    {
        $this->assertSame(['single' => 'Single', 'multi' => 'Multi'], BuildingVariants::labelsFor('inferno-tower'));
        $this->assertSame(['ground', 'air'], array_keys(BuildingVariants::labelsFor('x-bow')));
    }
}
