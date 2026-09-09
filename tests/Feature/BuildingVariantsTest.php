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
        $this->assertNull(BuildingVariants::modeFor('inferno-tower', 'Multi pre June-16-2025'));
    }

    public function test_buildings_without_a_choice_report_none(): void
    {
        $this->assertFalse(BuildingVariants::hasModes('cannon'));
        $this->assertFalse(BuildingVariants::hasModes('wall'));
        $this->assertFalse(BuildingVariants::hasModes(null));
        $this->assertSame([], BuildingVariants::labelsFor('cannon'));

        // Gear Up is deliberately absent: only one per base may be geared, so it
        // needs a count rule rather than a toggle.
        $this->assertNull(BuildingVariants::modeFor('cannon', 'G'));
        $this->assertNull(BuildingVariants::modeFor('archer-tower', 'Up'));
    }

    public function test_labels_come_in_the_order_they_should_be_offered(): void
    {
        $this->assertSame(['single' => 'Single', 'multi' => 'Multi'], BuildingVariants::labelsFor('inferno-tower'));
        $this->assertSame(['ground', 'air'], array_keys(BuildingVariants::labelsFor('x-bow')));
    }
}
