<?php

use App\Http\Controllers\Api\V1\BootstrapController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('/bootstrap', BootstrapController::class)->name('api.v1.bootstrap');
});
