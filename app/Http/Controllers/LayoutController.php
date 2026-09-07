<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\ValidatesLayoutPayload;
use App\Models\Layout;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class LayoutController extends Controller
{
    use ValidatesLayoutPayload;

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
