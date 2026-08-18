<?php

use App\Http\Controllers\GameAssetController;
use Illuminate\Support\Facades\Route;

Route::inertia('/', 'welcome')->name('home');
Route::inertia('/editor', 'editor')->name('editor');
Route::get('/game-assets/{path}', [GameAssetController::class, 'show'])
    ->where('path', '.*')
    ->name('game-assets.show');

Route::middleware(['auth', 'verified'])->group(function () {
    Route::inertia('dashboard', 'dashboard')->name('dashboard');
});

require __DIR__.'/settings.php';
