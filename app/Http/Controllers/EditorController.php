<?php

namespace App\Http\Controllers;

use App\Models\BuildingType;
use App\Models\BuildingUnlockRule;
use App\Models\Scenery;
use Inertia\Inertia;
use Inertia\Response;

class EditorController extends Controller
{
    public function index(): Response
    {
        return Inertia::render('editor', [
            'sceneries' => Scenery::query()->where('calibrated', true)->orderBy('name')->get(),
            'buildingTypes' => BuildingType::query()
                ->with(['levels' => fn ($query) => $query->orderBy('level')])
                ->orderBy('category')
                ->orderBy('subfolder')
                ->orderBy('name')
                ->get(),
            'unlockRules' => BuildingUnlockRule::all(),
            'sharedLayout' => null,
            'readOnly' => false,
        ]);
    }
}
