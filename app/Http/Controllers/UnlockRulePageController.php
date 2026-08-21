<?php

namespace App\Http\Controllers;

use App\Models\BuildingType;
use App\Models\BuildingUnlockRule;
use Inertia\Inertia;
use Inertia\Response;

class UnlockRulePageController extends Controller
{
    public function index(): Response
    {
        return Inertia::render('unlock-rules', [
            'buildingTypes' => BuildingType::query()
                ->with(['levels' => fn ($query) => $query->orderBy('level')])
                ->orderBy('category')
                ->orderBy('subfolder')
                ->orderBy('name')
                ->get(),
            'unlockRules' => BuildingUnlockRule::all(),
            'townHallLevels' => BuildingType::query()
                ->where('is_town_hall', true)
                ->with(['levels' => fn ($query) => $query->orderBy('level')])
                ->first()
                ?->levels
                ->pluck('level')
                ->values() ?? [],
        ]);
    }
}
