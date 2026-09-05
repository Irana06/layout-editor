<?php

namespace Tests\Feature;

use App\Models\BuildingLevel;
use App\Models\BuildingType;
use App\Models\BuildingUnlockRule;
use App\Models\Scenery;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The palette greys out gated buildings client-side, but that is only a convenience —
 * these cover the authoritative server-side enforcement in LayoutController.
 */
class LayoutUnlockRuleTest extends TestCase
{
    use RefreshDatabase;

    private Scenery $scenery;

    private BuildingType $cannon;

    protected function setUp(): void
    {
        parent::setUp();

        $this->scenery = Scenery::create([
            'name' => 'Test Scenery',
            'file_path' => 'sceneries/test.jpg',
            'image_width' => 1000,
            'image_height' => 1000,
            'grid_n' => 44,
            'calibrated' => true,
        ]);

        $this->cannon = BuildingType::create([
            'name' => 'Cannon',
            'category' => 'defensive',
            'subfolder' => 'cannon',
            'default_grid_width' => 3,
            'default_grid_height' => 3,
        ]);

        foreach ([1, 2, 3] as $level) {
            BuildingLevel::create([
                'building_type_id' => $this->cannon->id,
                'level' => $level,
                'file_path' => "buildings/defensive/cannon/{$level}.png",
            ]);
        }
    }

    /** @param  list<array{building_type_id:int, level:int, gx:int, gy:int}>  $placements */
    private function save(array $placements, int $thLevel = 1): TestResponse
    {
        return $this->postJson(route('layouts.store'), [
            'title' => 'Test Layout',
            'th_level' => $thLevel,
            'scenery_id' => $this->scenery->id,
            'data' => $placements,
        ]);
    }

    public function test_building_without_an_unlock_rule_is_rejected(): void
    {
        // Deny-by-default: no rule configured for this Town Hall at all.
        $this->save([['building_type_id' => $this->cannon->id, 'level' => 1, 'gx' => 0, 'gy' => 0]])
            ->assertStatus(422)
            ->assertJsonValidationErrors('data.0.level');
    }

    public function test_level_above_the_configured_cap_is_rejected(): void
    {
        BuildingUnlockRule::create([
            'building_type_id' => $this->cannon->id,
            'th_level' => 1,
            'max_building_level' => 2,
        ]);

        $this->save([['building_type_id' => $this->cannon->id, 'level' => 3, 'gx' => 0, 'gy' => 0]])
            ->assertStatus(422)
            ->assertJsonValidationErrors('data.0.level');
    }

    public function test_level_within_the_configured_cap_is_accepted(): void
    {
        BuildingUnlockRule::create([
            'building_type_id' => $this->cannon->id,
            'th_level' => 1,
            'max_building_level' => 2,
        ]);

        $this->save([['building_type_id' => $this->cannon->id, 'level' => 2, 'gx' => 0, 'gy' => 0]])
            ->assertCreated();
    }

    public function test_placing_more_than_max_count_is_rejected(): void
    {
        BuildingUnlockRule::create([
            'building_type_id' => $this->cannon->id,
            'th_level' => 1,
            'max_building_level' => 1,
            'max_count' => 2,
        ]);

        $this->save([
            ['building_type_id' => $this->cannon->id, 'level' => 1, 'gx' => 0, 'gy' => 0],
            ['building_type_id' => $this->cannon->id, 'level' => 1, 'gx' => 4, 'gy' => 0],
            ['building_type_id' => $this->cannon->id, 'level' => 1, 'gx' => 8, 'gy' => 0],
        ])->assertStatus(422);
    }

    public function test_max_count_null_means_unlimited(): void
    {
        BuildingUnlockRule::create([
            'building_type_id' => $this->cannon->id,
            'th_level' => 1,
            'max_building_level' => 1,
            'max_count' => null,
        ]);

        $this->save([
            ['building_type_id' => $this->cannon->id, 'level' => 1, 'gx' => 0, 'gy' => 0],
            ['building_type_id' => $this->cannon->id, 'level' => 1, 'gx' => 4, 'gy' => 0],
            ['building_type_id' => $this->cannon->id, 'level' => 1, 'gx' => 8, 'gy' => 0],
        ])->assertCreated();
    }

    public function test_rules_are_scoped_to_their_town_hall_level(): void
    {
        // Unlocked at TH2 only — placing at TH1 must still be rejected.
        BuildingUnlockRule::create([
            'building_type_id' => $this->cannon->id,
            'th_level' => 2,
            'max_building_level' => 3,
        ]);

        $this->save([['building_type_id' => $this->cannon->id, 'level' => 1, 'gx' => 0, 'gy' => 0]], thLevel: 1)
            ->assertStatus(422);

        $this->save([['building_type_id' => $this->cannon->id, 'level' => 3, 'gx' => 0, 'gy' => 0]], thLevel: 2)
            ->assertCreated();
    }

    public function test_bulk_update_persists_rules_for_a_town_hall(): void
    {
        $this->actingAs(User::factory()->create(['role' => 'admin']));

        $this->putJson(route('building-unlock-rules.bulk'), [
            'th_level' => 5,
            'rules' => [
                ['building_type_id' => $this->cannon->id, 'max_building_level' => 4, 'max_count' => 3],
            ],
        ])->assertOk();

        $this->assertDatabaseHas('building_unlock_rules', [
            'building_type_id' => $this->cannon->id,
            'th_level' => 5,
            'max_building_level' => 4,
            'max_count' => 3,
        ]);
    }
}
