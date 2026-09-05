<?php

use App\Http\Controllers\Api\V1\BootstrapController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('/', fn () => response()->json([
        'name' => 'Shiclash API',
        'status' => 'ok',
        'version' => 'v1',
        'endpoints' => [
            'bootstrap' => url('/api/v1/bootstrap'),
        ],
    ]))->name('api.v1.index');

    Route::get('/bootstrap', BootstrapController::class)->name('api.v1.bootstrap');
});
