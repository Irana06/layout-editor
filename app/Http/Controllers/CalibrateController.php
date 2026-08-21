<?php

namespace App\Http\Controllers;

use App\Models\BuildingType;
use App\Models\Scenery;
use Inertia\Inertia;
use Inertia\Response;

class CalibrateController extends Controller
{
    public function index(): Response
    {
        return Inertia::render('calibrate', [
            'sceneries' => Scenery::query()->orderBy('name')->get(),
            'buildingTypes' => BuildingType::query()
                ->with(['levels' => fn ($query) => $query->orderBy('level')])
                ->orderBy('category')
                ->orderBy('subfolder')
                ->orderBy('name')
                ->get(),
        ]);
    }
}
