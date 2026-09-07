<?php

namespace Tests\Feature;

use App\Models\BuildingLevel;
use App\Models\BuildingType;
use App\Models\BuildingUnlockRule;
use App\Models\Layout;
use App\Models\Scenery;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SharedLayoutTest extends TestCase
{
    use RefreshDatabase;

    private function scenery(): Scenery
    {
        return Scenery::create([
            'name' => 'Classic',
            'file_path' => 'sceneries/classic.png',
            'image_width' => 1000,
            'image_height' => 800,
            'tile_width' => 50,
            'tile_height' => 25,
            'origin_x' => 500,
            'origin_y' => 100,
            'grid_n' => 44,
            'calibrated' => true,
        ]);
    }

    private function cannon(): BuildingType
    {
        $type = BuildingType::create([
            'name' => 'Cannon',
            'category' => 'defensive',
            'default_grid_width' => 3,
            'default_grid_height' => 3,
        ]);
        BuildingLevel::create([
            'building_type_id' => $type->id,
            'level' => 1,
            'file_path' => 'cannon.png',
        ]);
        // Unlocking is deny-by-default, so a rule is needed for TH 10 to place
        // this at all.
        BuildingUnlockRule::create([
            'building_type_id' => $type->id,
            'th_level' => 10,
            'max_building_level' => 1,
            'max_count' => 5,
        ]);

        return $type;
    }

    private function payload(Scenery $scenery, BuildingType $type, int $gx = 4): array
    {
        return [
            'title' => 'Base perang',
            'th_level' => 10,
            'scenery_id' => $scenery->id,
            'data' => [
                ['building_type_id' => $type->id, 'level' => 1, 'gx' => $gx, 'gy' => 6],
            ],
        ];
    }

    public function test_sharing_returns_a_code_and_link_without_an_account(): void
    {
        $scenery = $this->scenery();
        $type = $this->cannon();

        $response = $this->postJson('/api/v1/layouts/share', $this->payload($scenery, $type))
            ->assertCreated();

        $code = $response->json('data.code');
        $this->assertMatchesRegularExpression('/^[23456789abcdefghjkmnpqrstuvwxyz]{6}$/', $code);
        $this->assertStringEndsWith("/l/{$code}", $response->json('data.url'));
        $this->assertDatabaseCount('users', 0);

        $this->getJson("/api/v1/layouts/shared/{$code}")
            ->assertOk()
            ->assertJsonPath('data.title', 'Base perang')
            ->assertJsonPath('data.th_level', 10)
            ->assertJsonPath('data.data.0.gx', 4);
    }

    public function test_a_shared_snapshot_does_not_follow_later_edits(): void
    {
        $scenery = $this->scenery();
        $type = $this->cannon();

        $first = $this->postJson('/api/v1/layouts/share', $this->payload($scenery, $type, gx: 4))
            ->json('data.code');
        // Sharing again after an edit is a second snapshot with its own link,
        // so a link already handed out keeps showing what it always showed.
        $second = $this->postJson('/api/v1/layouts/share', $this->payload($scenery, $type, gx: 20))
            ->json('data.code');

        $this->assertNotSame($first, $second);
        $this->getJson("/api/v1/layouts/shared/{$first}")->assertJsonPath('data.data.0.gx', 4);
        $this->getJson("/api/v1/layouts/shared/{$second}")->assertJsonPath('data.data.0.gx', 20);
    }

    public function test_shared_layouts_face_the_same_town_hall_cap_as_the_editor(): void
    {
        $scenery = $this->scenery();
        $type = $this->cannon();

        $payload = $this->payload($scenery, $type);
        $payload['data'][0]['level'] = 40;

        $this->postJson('/api/v1/layouts/share', $payload)
            ->assertStatus(422);
        $this->assertDatabaseCount('layouts', 0);
    }

    public function test_the_link_page_offers_the_app_and_survives_a_bad_code(): void
    {
        $scenery = $this->scenery();
        $type = $this->cannon();
        $code = $this->postJson('/api/v1/layouts/share', $this->payload($scenery, $type))
            ->json('data.code');

        $this->get("/l/{$code}")
            ->assertOk()
            ->assertSee('Base perang')
            ->assertSee("shiclash://layout/{$code}", escape: false);

        $this->get('/l/zzzzzz')->assertNotFound()->assertSee('tidak ditemukan');
    }

    public function test_assetlinks_stays_absent_until_a_fingerprint_is_configured(): void
    {
        // Without it Android would verify against nothing, so the link simply
        // opens the web page instead of claiming to open the app.
        config(['services.android.sha256_fingerprint' => null]);
        $this->get('/.well-known/assetlinks.json')->assertNotFound();

        config([
            'services.android.sha256_fingerprint' => 'AA:BB:CC',
            'services.android.package' => 'com.shiclash.editor',
        ]);
        $this->get('/.well-known/assetlinks.json')
            ->assertOk()
            ->assertJsonPath('0.target.package_name', 'com.shiclash.editor')
            ->assertJsonPath('0.target.sha256_cert_fingerprints.0', 'AA:BB:CC');
    }

    public function test_unknown_or_disabled_codes_are_not_found(): void
    {
        $this->getJson('/api/v1/layouts/shared/zzzzzz')->assertNotFound();

        $scenery = $this->scenery();
        $type = $this->cannon();
        $code = $this->postJson('/api/v1/layouts/share', $this->payload($scenery, $type))
            ->json('data.code');

        Layout::query()->where('share_slug', $code)->update(['share_enabled' => false]);
        $this->getJson("/api/v1/layouts/shared/{$code}")->assertNotFound();
    }
}
