<?php

use App\Http\Controllers\BuildingLevelController;
use App\Http\Controllers\BuildingTypeController;
use App\Http\Controllers\BuildingUnlockRuleController;
use App\Http\Controllers\CalibrateController;
use App\Http\Controllers\EditorController;
use App\Http\Controllers\LayoutController;
use App\Http\Controllers\PublicLayoutController;
use App\Http\Controllers\SceneryController;
use App\Http\Controllers\UnlockRulePageController;
use Illuminate\Support\Facades\Route;

Route::inertia('/', 'welcome')->name('home');
Route::get('/editor', [EditorController::class, 'index'])->name('editor');
Route::get('/layouts/drafts', [LayoutController::class, 'index'])->name('layouts.index');
Route::post('/layouts', [LayoutController::class, 'store'])->name('layouts.store');
Route::put('/layouts/{layout}', [LayoutController::class, 'update'])->name('layouts.update');
Route::delete('/layouts/{layout}', [LayoutController::class, 'destroy'])->name('layouts.destroy');
Route::post('/layouts/{layout}/duplicate', [LayoutController::class, 'duplicate'])->name('layouts.duplicate');
Route::patch('/layouts/{layout}/share', [LayoutController::class, 'share'])->name('layouts.share');
Route::get('/layouts/{layout}', [LayoutController::class, 'show'])->name('layouts.show');
Route::get('/s/{slug}', [PublicLayoutController::class, 'show'])->name('layouts.public');

Route::middleware(['auth', 'admin'])->group(function () {
    Route::get('/calibrate', [CalibrateController::class, 'index'])->name('calibrate');
    Route::post('/sceneries', [SceneryController::class, 'store'])->name('sceneries.store');
    Route::patch('/sceneries/{scenery}', [SceneryController::class, 'update'])->name('sceneries.update');
    Route::delete('/sceneries/{scenery}', [SceneryController::class, 'destroy'])->name('sceneries.destroy');
    Route::patch('/building-types/{buildingType}', [BuildingTypeController::class, 'update'])->name('building-types.update');
    Route::delete('/building-types/{buildingType}', [BuildingTypeController::class, 'destroy'])->name('building-types.destroy');
    Route::post('/building-types/{buildingType}/levels', [BuildingLevelController::class, 'store'])->name('building-levels.store');
    Route::patch('/building-levels/{buildingLevel}', [BuildingLevelController::class, 'update'])->name('building-levels.update');
    Route::delete('/building-levels/{buildingLevel}', [BuildingLevelController::class, 'destroy'])->name('building-levels.destroy');
    Route::get('/unlock-rules', [UnlockRulePageController::class, 'index'])->name('unlock-rules');
    Route::get('/building-unlock-rules', [BuildingUnlockRuleController::class, 'index'])->name('building-unlock-rules.index');
    Route::put('/building-unlock-rules/bulk', [BuildingUnlockRuleController::class, 'bulkUpdate'])->name('building-unlock-rules.bulk');
    Route::post('/building-unlock-rules', [BuildingUnlockRuleController::class, 'store'])->name('building-unlock-rules.store');
    Route::patch('/building-unlock-rules/{buildingUnlockRule}', [BuildingUnlockRuleController::class, 'update'])->name('building-unlock-rules.update');
    Route::delete('/building-unlock-rules/{buildingUnlockRule}', [BuildingUnlockRuleController::class, 'destroy'])->name('building-unlock-rules.destroy');
});

Route::middleware(['auth', 'verified'])->group(function () {
    Route::inertia('dashboard', 'dashboard')->name('dashboard');
});

require __DIR__.'/settings.php';
