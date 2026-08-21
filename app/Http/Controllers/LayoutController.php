<?php

namespace App\Http\Controllers;

use App\Models\BuildingLevel;
use App\Models\BuildingType;
use App\Models\Layout;
use App\Models\Scenery;
use App\Support\BuildingLevelRules;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class LayoutController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $ids = $request->session()->get('layout_ids', []);
        $layouts = Layout::query()->whereIn('id', $ids)->latest()->get();

        return response()->json(['layouts' => $layouts]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);

        $layout = Layout::create([
            ...$data,
            'user_id' => $request->user()?->id,
        ]);
        $this->remember($request, $layout);

        return response()->json(['layout' => $layout], 201);
    }

    public function update(Request $request, Layout $layout): JsonResponse
    {
        $this->authorizeOwner($request, $layout);
        $layout->update($this->validated($request));

        return response()->json(['layout' => $layout->fresh()]);
    }

    public function destroy(Request $request, Layout $layout): JsonResponse
    {
        $this->authorizeOwner($request, $layout);
        $layout->delete();

        return response()->json(status: 204);
    }

    public function duplicate(Request $request, Layout $layout): JsonResponse
    {
        $this->authorizeOwner($request, $layout);

        $copy = Layout::create([
            'title' => $layout->title.' (copy)',
            'th_level' => $layout->th_level,
            'scenery_id' => $layout->scenery_id,
            'data' => $layout->data,
            'thumbnail_data' => $layout->thumbnail_data,
            'share_enabled' => false,
            'share_slug' => null,
            'user_id' => $request->user()?->id,
        ]);
        $this->remember($request, $copy);

        return response()->json(['layout' => $copy], 201);
    }

    public function share(Request $request, Layout $layout): JsonResponse
    {
        $this->authorizeOwner($request, $layout);
        $shareEnabled = $request->boolean('share_enabled');

        $layout->share_enabled = $shareEnabled;
        if ($shareEnabled && ! $layout->share_slug) {
            $layout->share_slug = $this->generateSlug($layout->title);
        }
        $layout->save();

        return response()->json([
            'layout' => $layout->fresh(),
            'share_url' => $layout->share_enabled ? url("/s/{$layout->share_slug}") : null,
        ]);
    }

    public function show(Layout $layout): JsonResponse
    {
        abort_unless($layout->share_enabled, 404);

        return response()->json(['layout' => $layout]);
    }

    private function generateSlug(string $title): string
    {
        $base = Str::slug($title) ?: 'layout';

        do {
            $slug = $base.'-'.Str::lower(Str::random(6));
        } while (Layout::query()->where('share_slug', $slug)->exists());

        return $slug;
    }

    /** @return array{title: string, th_level: int, scenery_id: int, data: list<array{building_type_id: int, level: int, gx: int, gy: int}>, thumbnail_data: string|null} */
    private function validated(Request $request): array
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'max:120'],
            'th_level' => ['required', 'integer', 'min:1', 'max:30'],
            'scenery_id' => ['required', 'integer', 'exists:sceneries,id'],
            'data' => ['required', 'array'],
            'data.*.building_type_id' => ['required', 'integer', 'exists:building_types,id'],
            'data.*.level' => ['required', 'integer', 'min:1'],
            'data.*.gx' => ['required', 'integer', 'min:0'],
            'data.*.gy' => ['required', 'integer', 'min:0'],
            'thumbnail_data' => ['nullable', 'string', 'max:2000000'],
        ]);

        $this->validateThLevelCap($data['th_level'], $data['data']);
        $this->validateGridBounds($data['scenery_id'], $data['data']);

        return $data;
    }

    /**
     * Server-side TH-level gating — never trust the frontend-only check.
     *
     * @param  list<array{building_type_id: int, level: int, gx: int, gy: int}>  $placements
     */
    private function validateThLevelCap(int $thLevel, array $placements): void
    {
        foreach ($placements as $index => $placement) {
            $maxLevel = BuildingLevelRules::maxLevelFor($placement['building_type_id'], $thLevel);

            if ($placement['level'] > $maxLevel) {
                throw ValidationException::withMessages([
                    "data.{$index}.level" => "Level {$placement['level']} melebihi batas yang diizinkan (maks {$maxLevel}) untuk Town Hall level {$thLevel}.",
                ]);
            }
        }
    }

    /**
     * Server-side bounds/collision re-check against the scenery grid and each placement's footprint.
     *
     * @param  list<array{building_type_id: int, level: int, gx: int, gy: int}>  $placements
     */
    private function validateGridBounds(int $sceneryId, array $placements): void
    {
        $scenery = Scenery::query()->find($sceneryId);
        if (! $scenery) {
            return;
        }

        $typeIds = array_values(array_unique(array_column($placements, 'building_type_id')));
        $types = BuildingType::query()->whereIn('id', $typeIds)->get()->keyBy('id');
        $levels = BuildingLevel::query()
            ->whereIn('building_type_id', $types->keys())
            ->get()
            ->groupBy('building_type_id')
            ->map(fn ($group) => $group->keyBy('level'));

        $occupied = [];

        foreach ($placements as $index => $placement) {
            $type = $types->get($placement['building_type_id']);
            $level = $levels->get($placement['building_type_id'])?->get($placement['level']);
            if (! $type) {
                continue;
            }

            $width = $level?->grid_width ?? $type->default_grid_width;
            $height = $level?->grid_height ?? $type->default_grid_height;

            if ($scenery->grid_n < $placement['gx'] + $width || $scenery->grid_n < $placement['gy'] + $height) {
                throw ValidationException::withMessages([
                    "data.{$index}" => 'Penempatan bangunan berada di luar batas grid.',
                ]);
            }

            for ($y = $placement['gy']; $y < $placement['gy'] + $height; $y++) {
                for ($x = $placement['gx']; $x < $placement['gx'] + $width; $x++) {
                    $key = "{$x},{$y}";
                    if (isset($occupied[$key])) {
                        throw ValidationException::withMessages([
                            "data.{$index}" => 'Penempatan bangunan bertabrakan dengan bangunan lain.',
                        ]);
                    }
                    $occupied[$key] = true;
                }
            }
        }
    }

    private function remember(Request $request, Layout $layout): void
    {
        $ids = array_values(array_unique([...$request->session()->get('layout_ids', []), $layout->id]));
        $request->session()->put('layout_ids', $ids);
    }

    private function authorizeOwner(Request $request, Layout $layout): void
    {
        $isSessionOwner = in_array($layout->id, $request->session()->get('layout_ids', []), true);
        $isUserOwner = $request->user() && $layout->user_id === $request->user()->id;

        abort_unless($isSessionOwner || $isUserOwner, 403);
    }
}
