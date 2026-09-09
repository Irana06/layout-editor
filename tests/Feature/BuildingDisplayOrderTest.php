<?php

namespace Tests\Feature;

use App\Models\BuildingType;
use App\Support\BuildingDisplayOrder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BuildingDisplayOrderTest extends TestCase
{
    use RefreshDatabase;

    private function type(string $name, string $category): BuildingType
    {
        return BuildingType::create([
            'name' => $name,
            'category' => $category,
            'default_grid_width' => 3,
            'default_grid_height' => 3,
        ]);
    }

    public function test_library_follows_the_order_a_base_is_built_in(): void
    {
        $this->type('Cannon', 'defensive');
        $this->type('Wall', 'defensive');
        $this->type('Town Hall', 'resource');
        $this->type('Clan Castle', 'resource');
        $this->type('Gold Mine', 'resource');
        $this->type('Barracks', 'army');
        $this->type('Bomb', 'traps');
        $this->type('Boat', 'other');
        $this->type('Builders Hut', 'other');
        $this->type('Hero Banner Empty', 'army');

        $order = BuildingDisplayOrder::sort(BuildingType::all())
            ->pluck('name')
            ->all();

        $this->assertSame([
            'Town Hall',
            'Wall',
            'Clan Castle',
            'Cannon',
            'Hero Banner Empty',
            'Builders Hut',
            'Gold Mine',
            'Barracks',
            'Bomb',
            'Boat',
        ], $order);
    }

    public function test_defences_and_traps_keep_the_order_seen_in_the_game(): void
    {
        // Observed in game at TH12, in this order. It matches no rule we could
        // find — not the unlock level, and not the allowance except by accident
        // among the traps — so it is asserted literally.
        foreach (['Mortar', 'Cannon', 'Air Defense', 'Archer Tower', 'Wizard Tower'] as $name) {
            $this->type($name, 'defensive');
        }
        foreach (['Giant Bomb', 'Bomb', 'Air Bomb', 'Spring Trap'] as $name) {
            $this->type($name, 'traps');
        }

        $order = BuildingDisplayOrder::sort(BuildingType::all())
            ->pluck('name')
            ->all();

        $this->assertSame([
            'Cannon',
            'Archer Tower',
            'Wizard Tower',
            'Air Defense',
            'Mortar',
            'Bomb',
            'Spring Trap',
            'Giant Bomb',
            'Air Bomb',
        ], $order);
    }

    public function test_unlisted_buildings_fall_behind_the_verified_sequence(): void
    {
        $this->type('Cannon', 'defensive');
        // Neither appears in the observed list, so they follow it rather than
        // pushing into the middle of positions taken from the game.
        $this->type('Monolith', 'defensive');
        $this->type('Firespitter', 'defensive');

        $order = BuildingDisplayOrder::sort(BuildingType::all())
            ->pluck('name')
            ->all();

        $this->assertSame(['Cannon', 'Firespitter', 'Monolith'], $order);
    }

    public function test_a_building_without_modes_sends_an_object_not_a_list(): void
    {
        $this->type('Cannon', 'defensive');

        // An empty PHP array serialises as `[]`, which is a list. Clients read
        // `modes` as a map, so that shape crashed them on the first building
        // without modes — which is nearly every building.
        $this->assertStringContainsString(
            '"modes":{}',
            $this->getJson('/api/v1/bootstrap')->assertOk()->getContent(),
        );
    }

    public function test_the_catalog_endpoint_hands_the_order_to_every_client(): void
    {
        $this->type('Cannon', 'defensive');
        $this->type('Town Hall', 'resource');

        $response = $this->getJson('/api/v1/bootstrap')->assertOk();

        $this->assertSame('Town Hall', $response->json('data.building_types.0.name'));
        $this->assertLessThan(
            $response->json('data.building_types.1.display_order'),
            $response->json('data.building_types.0.display_order'),
        );
    }
}
