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

    public function test_gear_up_is_a_separate_building_not_a_mode(): void
    {
        // In the game these are two entries: six plain Cannons and one that
        // carries the lever. Only the levered one toggles once placed, so the
        // ordinary Cannon must offer no modes at all.
        $this->assertSame([], BuildingVariants::labelsFor('cannon'));
        $this->assertSame(
            ['normal' => 'Normal', 'geared' => 'Gear Up'],
            BuildingVariants::labelsFor('cannon-gear'),
        );

        $this->assertSame('ordinary', BuildingVariants::gearOwnerFor('cannon', 'B'));
        $this->assertSame('gear', BuildingVariants::gearOwnerFor('cannon', ''));
        $this->assertSame('gear', BuildingVariants::gearOwnerFor('cannon', 'G'));

        // Archer Tower marks the levered one instead, keeping its plain file
        // for the ordinary tower.
        $this->assertSame('ordinary', BuildingVariants::gearOwnerFor('archer-tower', ''));
        $this->assertSame('gear', BuildingVariants::gearOwnerFor('archer-tower', 'Up'));
    }

    public function test_older_art_belongs_to_the_building_it_depicts(): void
    {
        // "Cannon7B pre May-15-2023" is an old drawing of the plain Cannon, so
        // it stays with the ordinary building rather than crossing over.
        $this->assertSame('ordinary', BuildingVariants::gearOwnerFor('cannon', 'B pre May-15-2023'));
        $this->assertSame('gear', BuildingVariants::gearOwnerFor('cannon', 'G pre May-15-2023'));
        $this->assertSame('gear', BuildingVariants::gearOwnerFor('cannon', 'pre May-15-2023'));

        $this->assertNull(BuildingVariants::gearOwnerFor('wall', 'B'));
        $this->assertFalse(BuildingVariants::splitsForGearUp('wall'));
        $this->assertTrue(BuildingVariants::splitsForGearUp('mortar'));
    }

    public function test_labels_come_in_the_order_they_should_be_offered(): void
    {
        $this->assertSame(['single' => 'Single', 'multi' => 'Multi'], BuildingVariants::labelsFor('inferno-tower'));
        $this->assertSame(['ground', 'air'], array_keys(BuildingVariants::labelsFor('x-bow')));
    }
}
