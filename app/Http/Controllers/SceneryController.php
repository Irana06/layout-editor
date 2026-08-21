<?php

namespace App\Http\Controllers;

use App\Models\Scenery;
use App\Support\GameAssetUploader;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class SceneryController extends Controller
{
    public function __construct(private readonly GameAssetUploader $uploader) {}

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'image' => ['required', 'image', 'max:10240'],
        ]);

        $file = $request->file('image');
        $filename = Str::slug(pathinfo($file->getClientOriginalName(), PATHINFO_FILENAME)).'-'.Str::random(6).'.'.$file->getClientOriginalExtension();
        $destination = 'sceneries/'.$filename;
        $this->uploader->copyToPublicGame($file->getRealPath(), $destination, force: true);

        $imageSize = @getimagesize($file->getRealPath()) ?: [0, 0];

        $scenery = Scenery::create([
            'name' => $data['name'],
            'file_path' => $destination,
            'image_width' => (int) $imageSize[0],
            'image_height' => (int) $imageSize[1],
            'created_by' => $request->user()?->id,
        ]);

        return response()->json(['scenery' => $scenery], 201);
    }

    public function update(Request $request, Scenery $scenery): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:120'],
            'tile_w' => ['sometimes', 'numeric', 'min:4'],
            'tile_h' => ['sometimes', 'numeric', 'min:4'],
            'origin_x' => ['sometimes', 'numeric'],
            'origin_y' => ['sometimes', 'numeric'],
            'grid_n' => ['sometimes', 'integer', 'min:4', 'max:200'],
            'calibrated' => ['sometimes', 'boolean'],
            'locked' => ['sometimes', 'boolean'],
        ]);

        $gridFields = ['tile_w', 'tile_h', 'origin_x', 'origin_y', 'grid_n'];
        $changesGrid = count(array_intersect(array_keys($data), $gridFields)) > 0;

        abort_if($scenery->locked && $changesGrid, 422, 'Scenery grid terkunci — buka kunci dulu sebelum mengubah kalibrasi.');

        $scenery->update($data);

        return response()->json(['scenery' => $scenery->fresh()]);
    }

    public function destroy(Scenery $scenery): JsonResponse
    {
        $scenery->delete();

        return response()->json(status: 204);
    }
}
