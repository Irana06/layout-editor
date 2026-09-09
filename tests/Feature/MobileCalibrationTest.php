<?php

namespace Tests\Feature;

use App\Models\BuildingLevel;
use App\Models\BuildingType;
use App\Models\BuildingUnlockRule;
use App\Models\Scenery;
use App\Models\User;
use App\Support\MobileSessionToken;
use Firebase\JWT\JWT;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use OpenSSLAsymmetricKey;
use Tests\TestCase;

class MobileCalibrationTest extends TestCase
{
    use RefreshDatabase;

    private OpenSSLAsymmetricKey $key;

    protected function setUp(): void
    {
        parent::setUp();
        config()->set('services.google.client_id', 'test-client.apps.googleusercontent.com');
        config()->set('admin.emails', ['owner@gmail.com']);
        Cache::flush();
        Http::preventStrayRequests();
        $this->key = openssl_pkey_new(['config' => __DIR__.'/../Fixtures/openssl.cnf', 'private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
        $rsa = openssl_pkey_get_details($this->key)['rsa'];
        Http::fake(['www.googleapis.com/oauth2/v3/certs' => Http::response(['keys' => [[
            'kid' => 'test-key', 'kty' => 'RSA', 'alg' => 'RS256', 'use' => 'sig',
            'n' => JWT::urlsafeB64Encode($rsa['n']), 'e' => JWT::urlsafeB64Encode($rsa['e']),
        ]]])]);
    }

    private function token(array $changes = []): string
    {
        return JWT::encode([
            'iss' => 'https://accounts.google.com', 'aud' => config('services.google.client_id'),
            'sub' => 'google-owner', 'email' => 'owner@gmail.com', 'email_verified' => true,
            'iat' => time() - 10, 'exp' => time() + 3600, ...$changes,
        ], $this->key, 'RS256', 'test-key');
    }

    public function test_google_login_is_exchanged_for_a_long_lived_shiclash_session(): void
    {
        $response = $this->withToken($this->token([
            'name' => 'Owner',
            'picture' => 'https://example.com/avatar.png',
        ]))->postJson('/api/v1/auth/google')->assertOk()
            ->assertJsonPath('expires_in', MobileSessionToken::LIFETIME_SECONDS)
            ->assertJsonPath('data.email', 'owner@gmail.com')
            ->assertJsonPath('data.is_admin', true);

        $session = $response->json('token');
        $this->assertIsString($session);
        $this->assertStringStartsWith(MobileSessionToken::PREFIX, $session);

        $this->withToken($session)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.email', 'owner@gmail.com')
            ->assertJsonPath('data.is_admin', true);

        Http::assertSentCount(1);
        $this->assertDatabaseCount('users', 0);
    }

    public function test_forged_shiclash_session_is_rejected_without_google_lookup(): void
    {
        $session = app(MobileSessionToken::class)->issue([
            'sub' => 'google-owner',
            'email' => 'owner@gmail.com',
            'name' => 'Owner',
        ]);
        $parts = explode('.', substr($session, strlen(MobileSessionToken::PREFIX)));
        $parts[2][0] = $parts[2][0] === 'a' ? 'b' : 'a';
        $session = MobileSessionToken::PREFIX.implode('.', $parts);

        $this->withToken($session)->getJson('/api/v1/auth/me')->assertUnauthorized();
        Http::assertNothingSent();
    }

    public function test_verified_owner_can_save_and_public_catalog_contains_calibration(): void
    {
        $type = BuildingType::create(['name' => 'Cannon', 'category' => 'defensive', 'default_grid_width' => 3, 'default_grid_height' => 3]);
        $level = BuildingLevel::create(['building_type_id' => $type->id, 'level' => 1, 'file_path' => 'cannon.png']);
        $this->withToken($this->token())->getJson('/api/v1/auth/me')->assertOk()->assertJsonPath('data.is_admin', true);
        $this->patchJson("/api/v1/admin/building-levels/{$level->id}", [
            'grid_width' => 4, 'grid_height' => 3, 'offset_x' => 12.5, 'offset_y' => -8, 'scale' => 1.25,
        ])->assertOk();
        // A tile size is a property of the building, so it is stored once on the
        // type and every level inherits it instead of carrying its own copy.
        $this->getJson('/api/v1/bootstrap')->assertOk()
            ->assertJsonPath('data.building_types.0.levels.0.offset_x', 12.5)
            ->assertJsonPath('data.building_types.0.levels.0.grid_width', null)
            ->assertJsonPath('data.building_types.0.default_grid_width', 4)
            ->assertJsonPath('data.building_types.0.default_grid_height', 3);
        $this->assertDatabaseCount('users', 0);
    }

    public function test_the_longest_attack_range_in_the_game_is_accepted(): void
    {
        $type = BuildingType::create(['name' => 'Eagle Artillery', 'category' => 'defensive', 'default_grid_width' => 4, 'default_grid_height' => 4]);

        // Eagle Artillery reaches 50 tiles; an earlier ceiling of 40 refused
        // the real value.
        $this->withToken($this->token())
            ->patchJson("/api/v1/admin/building-types/{$type->id}", [
                'attack_range_min' => 7,
                'attack_range_max' => 50,
            ])->assertOk();

        $this->assertSame(50, $type->fresh()->attack_range_max);

        $this->withToken($this->token())
            ->patchJson("/api/v1/admin/building-types/{$type->id}", ['attack_range_max' => 61])
            ->assertStatus(422);
    }

    public function test_a_mode_keeps_its_own_reach_without_touching_the_building(): void
    {
        $type = BuildingType::create(['name' => 'Inferno Tower', 'category' => 'defensive', 'subfolder' => 'inferno-tower', 'default_grid_width' => 2, 'default_grid_height' => 2, 'attack_range_max' => 9]);
        $single = BuildingLevel::create(['building_type_id' => $type->id, 'level' => 1, 'variant' => 'single', 'file_path' => 'single.png']);
        $multi = BuildingLevel::create(['building_type_id' => $type->id, 'level' => 1, 'variant' => 'multi', 'file_path' => 'multi.png']);

        $this->withToken($this->token())
            ->patchJson("/api/v1/admin/building-levels/{$single->id}", ['attack_range_max' => 10])
            ->assertOk();

        $this->assertSame(10, $single->fresh()->attack_range_max);
        // The other mode and the building itself are untouched: a mode's reach
        // is its own, and null still means "ask the building".
        $this->assertNull($multi->fresh()->attack_range_max);
        $this->assertSame(9, $type->fresh()->attack_range_max);
    }

    public function test_a_blind_spot_cannot_reach_past_the_range(): void
    {
        $type = BuildingType::create(['name' => 'Mortar', 'category' => 'defensive', 'default_grid_width' => 3, 'default_grid_height' => 3]);

        $this->withToken($this->token())
            ->patchJson("/api/v1/admin/building-types/{$type->id}", [
                'attack_range_min' => 20,
                'attack_range_max' => 11,
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors('attack_range_min');
    }

    public function test_tile_size_set_on_one_level_is_shared_by_every_other_level(): void
    {
        $type = BuildingType::create(['name' => 'Town Hall', 'category' => 'resource', 'default_grid_width' => 3, 'default_grid_height' => 3]);
        $first = BuildingLevel::create(['building_type_id' => $type->id, 'level' => 1, 'file_path' => 'th1.png']);
        $second = BuildingLevel::create(['building_type_id' => $type->id, 'level' => 2, 'file_path' => 'th2.png', 'grid_width' => 7, 'grid_height' => 7]);

        $this->withToken($this->token())
            ->patchJson("/api/v1/admin/building-levels/{$first->id}", ['grid_width' => 4, 'grid_height' => 4])
            ->assertOk()
            ->assertJsonPath('buildingType.default_grid_width', 4);

        // Calibrating level 1 resizes the whole building, and the stale override
        // that level 2 was carrying is cleared rather than left to win locally.
        $this->assertSame(4, $type->fresh()->default_grid_width);
        $this->assertNull($first->fresh()->grid_width);
        $this->assertNull($second->fresh()->grid_width);
    }

    public function test_verified_admin_can_apply_one_square_footprint_to_every_level_of_a_building(): void
    {
        $type = BuildingType::create([
            'name' => 'Army Camp',
            'category' => 'army',
            'default_grid_width' => 3,
            'default_grid_height' => 2,
        ]);
        $levelOne = BuildingLevel::create([
            'building_type_id' => $type->id,
            'level' => 1,
            'file_path' => 'army-camp-1.png',
            'grid_width' => 2,
            'grid_height' => 3,
            'scale' => 1.25,
            'offset_x' => 12.5,
            'offset_y' => -8,
        ]);
        $levelTwo = BuildingLevel::create([
            'building_type_id' => $type->id,
            'level' => 2,
            'file_path' => 'army-camp-2.png',
            'grid_width' => 5,
            'grid_height' => 4,
            'scale' => .8,
            'offset_x' => -14,
            'offset_y' => 9.5,
        ]);

        $this->withToken($this->token())
            ->patchJson("/api/v1/admin/building-types/{$type->id}/footprint", ['grid_size' => 4])
            ->assertOk()
            ->assertJsonPath('buildingType.id', $type->id)
            ->assertJsonPath('buildingType.default_grid_width', 4)
            ->assertJsonPath('buildingType.default_grid_height', 4)
            ->assertJsonPath('buildingType.levels.0.grid_width', null)
            ->assertJsonPath('buildingType.levels.0.grid_height', null)
            ->assertJsonPath('buildingType.levels.1.grid_width', null)
            ->assertJsonPath('buildingType.levels.1.grid_height', null);

        $this->assertDatabaseHas('building_types', [
            'id' => $type->id,
            'default_grid_width' => 4,
            'default_grid_height' => 4,
        ]);
        $this->assertDatabaseHas('building_levels', [
            'id' => $levelOne->id,
            'grid_width' => null,
            'grid_height' => null,
            'scale' => 1.25,
            'offset_x' => 12.5,
            'offset_y' => -8,
        ]);
        $this->assertDatabaseHas('building_levels', [
            'id' => $levelTwo->id,
            'grid_width' => null,
            'grid_height' => null,
            'scale' => .8,
            'offset_x' => -14,
            'offset_y' => 9.5,
        ]);
    }

    public function test_verified_admin_can_configure_whether_a_building_shows_a_deployment_ring(): void
    {
        $type = BuildingType::create(['name' => 'Hidden Tesla', 'category' => 'defensive', 'subfolder' => 'hidden-tesla']);

        $this->withToken($this->token())
            ->patchJson("/api/v1/admin/building-types/{$type->id}", ['shows_deployment_ring' => false])
            ->assertOk()
            ->assertJsonPath('buildingType.shows_deployment_ring', false);

        $this->getJson('/api/v1/bootstrap')
            ->assertOk()
            ->assertJsonPath('data.building_types.0.shows_deployment_ring', false);
    }

    public function test_guest_and_non_admin_cannot_read_or_mutate_calibration(): void
    {
        $scenery = Scenery::create(['name' => 'Classic', 'file_path' => 'classic.png', 'image_width' => 1600, 'image_height' => 1200]);
        $type = BuildingType::create(['name' => 'Cannon', 'category' => 'defensive']);
        $this->getJson('/api/v1/admin/calibration')->assertUnauthorized();
        $this->withToken($this->token(['sub' => 'member', 'email' => 'member@gmail.com']))
            ->getJson('/api/v1/admin/calibration')->assertForbidden();
        $this->patchJson("/api/v1/admin/sceneries/{$scenery->id}", ['origin_x' => 10])->assertForbidden();
        $this->patchJson("/api/v1/admin/building-types/{$type->id}/footprint", ['grid_size' => 4])->assertForbidden();
    }

    public function test_wrong_audience_expired_unverified_and_forged_tokens_are_rejected(): void
    {
        foreach ([['aud' => 'other-client'], ['exp' => time() - 1], ['email_verified' => false], ['iss' => 'attacker'], ['email' => 'owner@example.com']] as $changes) {
            $this->withToken($this->token($changes))->getJson('/api/v1/auth/me')->assertUnauthorized();
        }
        $parts = explode('.', $this->token());
        $parts[1] = JWT::urlsafeB64Encode(json_encode(['email' => 'owner@gmail.com', 'exp' => time() + 3600]));
        $this->withToken(implode('.', $parts))->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->assertDatabaseCount('users', 0);
    }

    public function test_admin_revocation_takes_effect_with_same_google_token(): void
    {
        $this->withToken($this->token())->getJson('/api/v1/admin/calibration')->assertOk();
        config()->set('admin.emails', []);
        $this->getJson('/api/v1/admin/calibration')->assertForbidden();
    }

    public function test_locked_grid_requires_separate_unlock_and_allows_uncalibrated_admin_preview(): void
    {
        $scenery = Scenery::create(['name' => 'Classic', 'file_path' => 'classic.png', 'image_width' => 1600, 'image_height' => 1200, 'locked' => true, 'calibrated' => false]);
        $this->getJson('/api/v1/bootstrap')->assertJsonCount(0, 'data.sceneries');
        $this->withToken($this->token())->getJson('/api/v1/admin/calibration')->assertJsonCount(1, 'data.sceneries');
        $this->patchJson("/api/v1/admin/sceneries/{$scenery->id}", ['origin_x' => 500, 'locked' => false])->assertUnprocessable();
        $this->patchJson("/api/v1/admin/sceneries/{$scenery->id}", ['locked' => false])->assertOk();
        $this->patchJson("/api/v1/admin/sceneries/{$scenery->id}", ['origin_x' => 500, 'tile_w' => 56.5, 'calibrated' => true])->assertOk();
        $this->getJson('/api/v1/bootstrap')->assertJsonCount(1, 'data.sceneries');
    }

    public function test_invalid_offsets_are_not_saved_and_null_footprint_is_supported(): void
    {
        $type = BuildingType::create(['name' => 'Cannon', 'category' => 'defensive']);
        $level = BuildingLevel::create(['building_type_id' => $type->id, 'level' => 1, 'file_path' => 'cannon.png']);
        $this->withToken($this->token())->patchJson("/api/v1/admin/building-levels/{$level->id}", ['offset_x' => 501])->assertUnprocessable();
        $this->patchJson("/api/v1/admin/building-levels/{$level->id}", ['grid_width' => null, 'grid_height' => null])->assertOk();
        $this->assertDatabaseHas('building_levels', ['id' => $level->id, 'grid_width' => null, 'offset_x' => 0]);
    }

    public function test_api_identity_does_not_mutate_an_existing_website_account(): void
    {
        $user = User::factory()->create(['email' => 'owner@gmail.com', 'role' => 'user']);
        $password = $user->password;
        $verifiedAt = $user->email_verified_at;
        $this->withToken($this->token())->getJson('/api/v1/auth/me')->assertOk();
        $this->assertSame($password, $user->fresh()->password);
        $this->assertDatabaseCount('users', 1);
        $this->assertTrue($verifiedAt->equalTo($user->fresh()->email_verified_at));
    }

    public function test_verified_admin_can_save_town_hall_rules_for_the_mobile_calibrator(): void
    {
        $cannon = BuildingType::create(['name' => 'Cannon', 'category' => 'defensive']);
        BuildingLevel::create(['building_type_id' => $cannon->id, 'level' => 1, 'file_path' => 'cannon-1.png']);

        $this->withToken($this->token())->patchJson('/api/v1/admin/unlock-rules', [
            'th_level' => 1,
            'rules' => [[
                'building_type_id' => $cannon->id,
                'max_building_level' => 1,
                'max_count' => 2,
            ]],
        ])->assertOk()
            ->assertJsonPath('unlockRules.0.building_type_id', $cannon->id)
            ->assertJsonPath('unlockRules.0.max_building_level', 1)
            ->assertJsonPath('unlockRules.0.max_count', 2);

        $this->assertDatabaseHas(BuildingUnlockRule::class, [
            'building_type_id' => $cannon->id,
            'th_level' => 1,
            'max_building_level' => 1,
            'max_count' => 2,
        ]);
    }

    public function test_mobile_rule_save_uses_a_constant_number_of_database_queries(): void
    {
        $types = collect(range(1, 40))->map(fn (int $number) => BuildingType::create([
            'name' => "Building {$number}",
            'category' => 'defensive',
        ]));
        $queries = [];
        DB::listen(function ($query) use (&$queries): void {
            $queries[] = $query->sql;
        });

        $this->withToken($this->token())->patchJson('/api/v1/admin/unlock-rules', [
            'th_level' => 2,
            'rules' => $types->map(fn (BuildingType $type): array => [
                'building_type_id' => $type->id,
                'max_building_level' => 1,
                'max_count' => 1,
            ])->all(),
        ])->assertOk()->assertJsonCount(40, 'unlockRules');

        $this->assertLessThanOrEqual(4, count($queries), implode("\n", $queries));
    }

    public function test_rules_saved_for_a_town_hall_are_copied_to_future_levels_without_overwriting_them(): void
    {
        $cannon = BuildingType::create(['name' => 'Cannon', 'category' => 'defensive']);
        BuildingLevel::create(['building_type_id' => $cannon->id, 'level' => 1, 'file_path' => 'cannon-1.png']);
        $townHall = BuildingType::create(['name' => 'Town Hall', 'category' => 'resource', 'is_town_hall' => true]);
        foreach ([4, 5, 6] as $level) {
            BuildingLevel::create(['building_type_id' => $townHall->id, 'level' => $level, 'file_path' => "th-{$level}.png"]);
        }
        // TH 5 was created by an older partial sync: a reset row must be
        // treated like an empty one when TH 4 later unlocks this building.
        BuildingUnlockRule::create([
            'building_type_id' => $cannon->id,
            'th_level' => 5,
            'max_building_level' => 0,
            'max_count' => 0,
        ]);
        BuildingUnlockRule::create([
            'building_type_id' => $cannon->id,
            'th_level' => 6,
            'max_building_level' => 9,
            'max_count' => 9,
        ]);

        $this->withToken($this->token())->patchJson('/api/v1/admin/unlock-rules', [
            'th_level' => 4,
            'rules' => [[
                'building_type_id' => $cannon->id,
                'max_building_level' => 3,
                'max_count' => 2,
            ]],
        ])->assertOk();

        $this->assertDatabaseHas('building_unlock_rules', [
            'building_type_id' => $cannon->id,
            'th_level' => 4,
            'max_building_level' => 3,
            'max_count' => 2,
        ]);
        $this->assertDatabaseHas('building_unlock_rules', [
            'building_type_id' => $cannon->id,
            'th_level' => 5,
            'max_building_level' => 3,
            'max_count' => 2,
        ]);
        $this->assertDatabaseHas('building_unlock_rules', [
            'building_type_id' => $cannon->id,
            'th_level' => 6,
            'max_building_level' => 9,
            'max_count' => 9,
        ]);
    }
}
