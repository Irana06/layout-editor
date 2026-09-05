<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExampleTest extends TestCase
{
    use RefreshDatabase;

    public function test_returns_a_successful_response()
    {
        $response = $this->get(route('home'));

        $response->assertOk();
    }

    public function test_assets_use_https_behind_a_tls_terminating_proxy(): void
    {
        $response = $this
            ->withHeader('X-Forwarded-Proto', 'https')
            ->withHeader('X-Forwarded-Host', 'layout-editor.example')
            ->get('/');

        $response
            ->assertOk()
            ->assertSee('https://layout-editor.example/build/assets/', false)
            ->assertDontSee('http://layout-editor.example/build/assets/', false);
    }
}
