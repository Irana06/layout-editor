<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminCalibrationAccessTest extends TestCase
{
    use RefreshDatabase;

    public function test_guest_is_redirected_to_login(): void
    {
        $this->get(route('calibrate'))->assertRedirect(route('login'));
    }

    public function test_regular_user_cannot_open_calibration(): void
    {
        $this->actingAs(User::factory()->create(['role' => 'user']))
            ->get(route('calibrate'))
            ->assertForbidden();
    }

    public function test_admin_can_open_calibration(): void
    {
        $this->actingAs(User::factory()->create(['role' => 'admin']))
            ->get(route('calibrate'))
            ->assertOk();
    }

    public function test_configured_admin_email_is_allowed(): void
    {
        config()->set('admin.emails', ['owner@example.com']);

        $this->actingAs(User::factory()->create([
            'email' => 'OWNER@example.com',
            'role' => 'user',
        ]))->get(route('calibrate'))->assertOk();
    }
}
