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

    public function test_alphabetical_order_is_only_the_tiebreak_inside_a_group(): void
    {
        $this->type('Archer Tower', 'defensive');
        $this->type('Air Defense', 'defensive');
        // Sorts after both despite starting with an earlier letter, because
        // rank comes first and this one is pinned to the very front.
        $this->type('Town Hall', 'resource');

        $order = BuildingDisplayOrder::sort(BuildingType::all())
            ->pluck('name')
            ->all();

        $this->assertSame(['Town Hall', 'Air Defense', 'Archer Tower'], $order);
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
