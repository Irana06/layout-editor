<?php

namespace App\Http\Controllers;

use App\Models\BuildingType;
use App\Models\Layout;
use App\Models\Scenery;
use Inertia\Inertia;
use Inertia\Response;

class PublicLayoutController extends Controller
{
    public function show(string $slug): Response
    {
        $layout = Layout::query()->where('share_slug', $slug)->where('share_enabled', true)->firstOrFail();

        return Inertia::render('editor', [
            'sceneries' => Scenery::query()->where('id', $layout->scenery_id)->get(),
            'buildingTypes' => BuildingType::query()
                ->with(['levels' => fn ($query) => $query->orderBy('level')])
                ->orderBy('category')
                ->orderBy('subfolder')
                ->orderBy('name')
                ->get(),
            'unlockRules' => [],
            'sharedLayout' => $layout,
            'readOnly' => true,
        ]);
    }
}
