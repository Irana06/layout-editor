<?php

use App\Http\Controllers\LayoutController;
use Illuminate\Support\Facades\Route;

Route::inertia('/', 'welcome')->name('home');
Route::inertia('/editor', 'editor')->name('editor');
Route::get('/layouts/drafts', [LayoutController::class, 'index'])->name('layouts.index');
Route::post('/layouts', [LayoutController::class, 'store'])->name('layouts.store');
Route::put('/layouts/{layout}', [LayoutController::class, 'update'])->name('layouts.update');
Route::patch('/layouts/{layout}/share', [LayoutController::class, 'share'])->name('layouts.share');
Route::get('/layouts/{layout}', [LayoutController::class, 'show'])->name('layouts.show');
Route::get('/layouts/{layout}/view', function (\App\Models\Layout $layout) {
    abort_unless($layout->share_enabled, 404);

    return \Inertia\Inertia::render('editor', ['sharedLayout' => $layout]);
})->name('layouts.view');

Route::middleware(['auth', 'verified'])->group(function () {
    Route::inertia('dashboard', 'dashboard')->name('dashboard');
});

require __DIR__.'/settings.php';
