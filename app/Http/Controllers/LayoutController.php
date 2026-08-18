<?php

namespace App\Http\Controllers;

use App\Models\Layout;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

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
        $layout = Layout::create([
            ...$this->validated($request),
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

    public function share(Request $request, Layout $layout): JsonResponse
    {
        $this->authorizeOwner($request, $layout);
        $layout->update(['share_enabled' => $request->boolean('share_enabled')]);

        return response()->json([
            'layout' => $layout->fresh(),
            'share_url' => $layout->share_enabled ? route('layouts.view', $layout) : null,
        ]);
    }

    public function show(Layout $layout): JsonResponse
    {
        abort_unless($layout->share_enabled, 404);

        return response()->json(['layout' => $layout]);
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'title' => ['required', 'string', 'max:120'],
            'town_hall' => ['required', 'integer', 'min:1', 'max:18'],
            'payload' => ['required', 'array'],
            'payload.buildings' => ['required', 'array'],
            'payload.walls' => ['required', 'array'],
            'thumbnail_data' => ['nullable', 'string', 'max:2000000'],
        ]);
    }

    private function remember(Request $request, Layout $layout): void
    {
        $ids = collect($request->session()->get('layout_ids', []))->push($layout->id)->unique()->values()->all();
        $request->session()->put('layout_ids', $ids);
    }

    private function authorizeOwner(Request $request, Layout $layout): void
    {
        $isSessionOwner = in_array($layout->id, $request->session()->get('layout_ids', []), true);
        $isUserOwner = $request->user() && $layout->user_id === $request->user()->id;

        abort_unless($isSessionOwner || $isUserOwner, 403);
    }
}
