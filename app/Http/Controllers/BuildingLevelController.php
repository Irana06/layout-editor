<?php

namespace App\Http\Controllers;

use App\Models\BuildingLevel;
use App\Models\BuildingType;
use App\Support\GameAssetUploader;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Validation\ValidationException;

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
            // Per-mode reach: an Inferno Tower carries a different range on
            // Single than on Multi. Null hands the question back to the type.
            'attack_range_min' => ['sometimes', 'nullable', 'integer', 'min:0', 'max:60'],
            'attack_range_max' => ['sometimes', 'nullable', 'integer', 'min:0', 'max:60'],
        ]);

        $min = $data['attack_range_min'] ?? $buildingLevel->attack_range_min;
        $max = $data['attack_range_max'] ?? $buildingLevel->attack_range_max;
        if ($min !== null && $max !== null && $min > 0 && $min >= $max) {
            throw ValidationException::withMessages([
                'attack_range_min' => 'Jarak minimal harus lebih kecil dari jarak maksimal.',
            ]);
        }

        $type = $buildingLevel->type;

        // A tile size typed while calibrating one level is a statement about the
        // building itself, so it is promoted to the type's default and shared by
        // every level rather than being stored as a one-level override.
        $width = $data['grid_width'] ?? null;
        $height = $data['grid_height'] ?? null;
        $footprint = $width !== null || $height !== null
            ? $type->applyFootprint(
                $width ?? $type->default_grid_width,
                $height ?? $type->default_grid_height,
            )
            : null;

        $buildingLevel->update(Arr::except($data, ['grid_width', 'grid_height']));

        return response()->json([
            'buildingLevel' => $buildingLevel->fresh(),
            'buildingType' => $footprint,
        ]);
    }

    public function destroy(BuildingLevel $buildingLevel): JsonResponse
    {
        $buildingLevel->delete();

        return response()->json(status: 204);
    }
}
