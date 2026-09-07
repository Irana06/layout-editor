<?php

use App\Http\Controllers\Api\V1\BootstrapController;
use App\Http\Controllers\Api\V1\MobileAuthController;
use App\Http\Controllers\Api\V1\SharedLayoutController;
use App\Http\Controllers\BuildingLevelController;
use App\Http\Controllers\BuildingTypeController;
use App\Http\Controllers\BuildingUnlockRuleController;
use App\Http\Controllers\SceneryController;
use App\Http\Middleware\AuthenticateGoogleApi;
use App\Http\Middleware\EnsureUserIsAdmin;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('/', fn () => response()->json([
        'name' => 'Shiclash API',
        'status' => 'ok',
        'version' => 'v1',
        'endpoints' => [
            'bootstrap' => rtrim((string) config('app.url'), '/').'/api/v1/bootstrap',
        ],
    ]))->name('api.v1.index');

    Route::get('/bootstrap', BootstrapController::class)->name('api.v1.bootstrap');

    // Sharing needs no account: the snapshot belongs to whoever holds the link.
    Route::post('/layouts/share', [SharedLayoutController::class, 'store'])
        ->middleware('throttle:20,1')
        ->name('api.v1.layouts.share');
    Route::get('/layouts/shared/{code}', [SharedLayoutController::class, 'show'])
        ->middleware('throttle:120,1')
        ->name('api.v1.layouts.shared');

    Route::post('/auth/google', [MobileAuthController::class, 'store'])
        ->middleware('throttle:10,1');

    Route::middleware(['throttle:60,1', AuthenticateGoogleApi::class])->group(function (): void {
        Route::get('/auth/me', fn (Request $request) => response()->json([
            'data' => [
                'name' => $request->user()->name,
                'email' => $request->user()->email,
                'is_admin' => $request->user()->isAdmin(),
            ],
        ]));
        Route::prefix('admin')->middleware(EnsureUserIsAdmin::class)->group(function (): void {
            Route::get('/calibration', [BootstrapController::class, 'calibration']);
            Route::patch('/sceneries/{scenery}', [SceneryController::class, 'update']);
            Route::patch('/building-types/{buildingType}', [BuildingTypeController::class, 'update']);
            Route::patch('/building-types/{buildingType}/footprint', [BuildingTypeController::class, 'updateFootprint']);
            Route::patch('/building-levels/{buildingLevel}', [BuildingLevelController::class, 'update']);
            Route::patch('/unlock-rules', [BuildingUnlockRuleController::class, 'bulkUpdate']);
        });
    });
});
