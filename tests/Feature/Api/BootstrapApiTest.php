<?php

namespace Tests\Feature\Api;

use App\Models\BuildingLevel;
use App\Models\BuildingType;
use App\Models\BuildingUnlockRule;
use App\Models\Scenery;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BootstrapApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_mobile_bootstrap_returns_calibrated_catalog(): void
    {
        Scenery::create([
            'name' => 'Classic',
            'file_path' => 'sceneries/classic.jpg',
            'image_width' => 1000,
            'image_height' => 1000,
            'grid_n' => 44,
            'calibrated' => true,
        ]);

        $cannon = BuildingType::create([
            'name' => 'Cannon',
            'category' => 'defensive',
            'subfolder' => 'cannon',
            'default_grid_width' => 3,
            'default_grid_height' => 3,
        ]);

        BuildingLevel::create([
            'building_type_id' => $cannon->id,
            'level' => 1,
            'file_path' => 'buildings/defensive/cannon/1.png',
        ]);

        BuildingUnlockRule::create([
            'building_type_id' => $cannon->id,
            'th_level' => 1,
            'max_building_level' => 1,
            'max_count' => 2,
        ]);

        $this->getJson('/api/v1/bootstrap')
            ->assertOk()
            ->assertJsonPath('meta.api_version', 'v1')
            ->assertJsonPath('data.sceneries.0.name', 'Classic')
            ->assertJsonPath('data.building_types.0.name', 'Cannon')
            ->assertJsonPath('data.building_types.0.levels.0.level', 1)
            ->assertJsonPath('data.unlock_rules.0.max_count', 2)
            ->assertJsonStructure([
                'data' => [
                    'sceneries' => [['image_url']],
                    'building_types' => [['levels' => [['image_url']]]],
                    'unlock_rules',
                ],
                'meta' => ['api_version', 'generated_at'],
            ]);
    }
}
