<?php

namespace App\Http\Controllers;

use App\Models\BuildingLevel;
use App\Models\BuildingType;
use App\Support\GameAssetUploader;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BuildingLevelController extends Controller
{
    public function __construct(private readonly GameAssetUploader $uploader) {}

    public function store(Request $request, BuildingType $buildingType): JsonResponse
    {
        $data = $request->validate([
            'level' => ['required', 'integer', 'min:1', 'max:250'],
            'image' => ['required', 'image', 'max:10240'],
        ]);

        $file = $request->file('image');
        $extension = $file->getClientOriginalExtension();
        $destination = sprintf(
            'buildings/%s/%s/%d.%s',
            $buildingType->category,
            $buildingType->subfolder ?? 'misc',
            $data['level'],
            $extension,
        );
        $this->uploader->copyToPublicGame($file->getRealPath(), $destination, force: true);

        $level = BuildingLevel::updateOrCreate(
            ['building_type_id' => $buildingType->id, 'level' => $data['level']],
            ['file_path' => $destination],
        );

        return response()->json(['buildingLevel' => $level], 201);
    }

    public function update(Request $request, BuildingLevel $buildingLevel): JsonResponse
    {
        $data = $request->validate([
            'grid_width' => ['sometimes', 'nullable', 'integer', 'min:1', 'max:20'],
            'grid_height' => ['sometimes', 'nullable', 'integer', 'min:1', 'max:20'],
            'scale' => ['sometimes', 'numeric', 'min:0.1', 'max:5'],
            'offset_x' => ['sometimes', 'numeric', 'min:-500', 'max:500'],
            'offset_y' => ['sometimes', 'numeric', 'min:-500', 'max:500'],
        ]);

        $buildingLevel->update($data);

        return response()->json(['buildingLevel' => $buildingLevel->fresh()]);
    }

    public function destroy(BuildingLevel $buildingLevel): JsonResponse
    {
        $buildingLevel->delete();

        return response()->json(status: 204);
    }
}
