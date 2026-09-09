<?php

namespace Tests\Feature;

use App\Models\BuildingLevel;
use App\Models\BuildingType;
use App\Models\BuildingUnlockRule;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\File;
use Tests\TestCase;

class SyncCatalogTest extends TestCase
{
    use RefreshDatabase;

    private string $path = 'storage/framework/testing/catalog.json';

    protected function tearDown(): void
    {
        File::delete(base_path($this->path));
        parent::tearDown();
    }

    public function test_a_catalogue_survives_a_round_trip_with_its_calibration(): void
    {
        $type = BuildingType::create([
            'name' => 'Inferno Tower', 'category' => 'defensive', 'subfolder' => 'inferno-tower',
            'default_grid_width' => 2, 'default_grid_height' => 2, 'attack_range_max' => 9,
        ]);
        BuildingLevel::create([
            'building_type_id' => $type->id, 'level' => 1, 'variant' => 'single',
            'file_path' => 'single.png', 'scale' => 0.86, 'offset_y' => -11, 'attack_range_max' => 10,
        ]);
        BuildingUnlockRule::create([
            'building_type_id' => $type->id, 'th_level' => 10,
            'max_building_level' => 1, 'max_count' => 2,
        ]);

        $this->artisan("catalog:sync export --path={$this->path}")->assertSuccessful();

        // Wipe it the way a fresh production database would look.
        BuildingType::query()->delete();
        $this->assertSame(0, BuildingLevel::count());

        $this->artisan("catalog:sync import --path={$this->path}")->assertSuccessful();

        $restored = BuildingType::where('name', 'Inferno Tower')->firstOrFail();
        $level = $restored->levels()->firstOrFail();
        $this->assertSame(9, $restored->attack_range_max);
        $this->assertSame('single', $level->variant);
        // Calibration is the part that cannot be re-derived from the images.
        $this->assertSame(0.86, $level->scale);
        $this->assertSame(-11.0, $level->offset_y);
        $this->assertSame(10, $level->attack_range_max);
        $this->assertSame(2, BuildingUnlockRule::firstOrFail()->max_count);
    }

    public function test_importing_removes_levels_the_export_no_longer_has(): void
    {
        $type = BuildingType::create([
            'name' => 'Super Wizard Tower', 'category' => 'defensive',
            'subfolder' => 'super-wizard-tower', 'default_grid_width' => 3, 'default_grid_height' => 3,
        ]);
        BuildingLevel::create(['building_type_id' => $type->id, 'level' => 1, 'file_path' => '1.png']);

        $this->artisan("catalog:sync export --path={$this->path}")->assertSuccessful();

        // A level that only ever existed as Clan Capital art, added after the
        // export: importing must take it back out rather than leave it.
        BuildingLevel::create(['building_type_id' => $type->id, 'level' => 5, 'file_path' => '5.png']);

        $this->artisan("catalog:sync import --path={$this->path}")->assertSuccessful();

        $this->assertSame([1], $type->levels()->pluck('level')->all());
    }
}
