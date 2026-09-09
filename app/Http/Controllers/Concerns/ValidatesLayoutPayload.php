<?php

namespace App\Http\Controllers\Concerns;

use App\Models\BuildingLevel;
use App\Models\BuildingType;
use App\Models\Scenery;
use App\Support\BuildingLevelRules;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Validation for an incoming layout payload.
 *
 * Shared by the web editor and the public share endpoint: a shared layout is
 * accepted straight from a phone, so it has to clear the same Town Hall caps
 * and grid bounds as anything saved through the site.
 */
trait ValidatesLayoutPayload
{
    /** @return array{title: string, th_level: int, scenery_id: int, data: list<array{building_type_id: int, level: int, gx: int, gy: int}>, thumbnail_data: string|null} */
    protected function validated(Request $request): array
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
            // Which mode a building is set to, for the ones that offer a
            // choice. Absent for everything else, which is most of them.
            'data.*.variant' => ['sometimes', 'nullable', 'string', 'max:32'],
            'thumbnail_data' => ['nullable', 'string', 'max:2000000'],
        ]);

        $this->validateThLevelCap($data['th_level'], $data['data']);
        $this->validateGridBounds($data['scenery_id'], $data['data']);

        return $data;
    }

    /**
     * Server-side TH gating — never trust the frontend-only check. Enforces both the
     * unlocked level cap and the per-Town-Hall placement count. Deny-by-default: a
     * building with no configured rule at this Town Hall cannot be placed at all.
     *
     * @param  list<array{building_type_id: int, level: int, gx: int, gy: int}>  $placements
     */
    protected function validateThLevelCap(int $thLevel, array $placements): void
    {
        $rules = BuildingLevelRules::forThLevel($thLevel);
        $types = BuildingType::query()
            ->whereIn('id', array_values(array_unique(array_column($placements, 'building_type_id'))))
            ->with('levels:id,building_type_id,level')
            ->get()
            ->keyBy('id');
        $counts = [];

        foreach ($placements as $index => $placement) {
            $typeId = $placement['building_type_id'];
            $type = $types->get($typeId);
            $name = $type->name;

            if (! $type->levels->contains('level', $placement['level'])) {
                throw ValidationException::withMessages([
                    "data.{$index}.level" => "Aset {$name} level {$placement['level']} tidak tersedia.",
                ]);
            }

            // Town Hall is the base's selected level.  It has no unlock-rule
            // row, but it is always permitted once when its exact sprite is
            // present in the catalog.
            if ($type->is_town_hall) {
                if ($placement['level'] !== $thLevel) {
                    throw ValidationException::withMessages([
                        "data.{$index}.level" => "{$name} harus memakai level Town Hall {$thLevel}.",
                    ]);
                }

                $counts[$typeId] = ($counts[$typeId] ?? 0) + 1;
                if ($counts[$typeId] > 1) {
                    throw ValidationException::withMessages([
                        "data.{$index}" => "Jumlah {$name} melebihi batas yang diizinkan (maks 1) untuk Town Hall level {$thLevel}.",
                    ]);
                }

                continue;
            }

            $maxLevel = (int) ($rules[$typeId]->max_building_level ?? 0);

            if ($maxLevel === 0) {
                throw ValidationException::withMessages([
                    "data.{$index}.level" => "{$name} belum terbuka di Town Hall level {$thLevel}.",
                ]);
            }

            if ($placement['level'] > $maxLevel) {
                throw ValidationException::withMessages([
                    "data.{$index}.level" => "{$name} level {$placement['level']} melebihi batas yang diizinkan (maks {$maxLevel}) untuk Town Hall level {$thLevel}.",
                ]);
            }

            $counts[$typeId] = ($counts[$typeId] ?? 0) + 1;
            $maxCount = $rules[$typeId]->max_count ?? null;

            if ($maxCount !== null && $counts[$typeId] > $maxCount) {
                throw ValidationException::withMessages([
                    "data.{$index}" => "Jumlah {$name} melebihi batas yang diizinkan (maks {$maxCount}) untuk Town Hall level {$thLevel}.",
                ]);
            }
        }
    }

    /**
     * Server-side bounds/collision re-check against the scenery grid and each placement's footprint.
     *
     * @param  list<array{building_type_id: int, level: int, gx: int, gy: int}>  $placements
     */
    protected function validateGridBounds(int $sceneryId, array $placements): void
    {
        $scenery = Scenery::query()->find($sceneryId);
        if (! $scenery) {
            return;
        }

        $typeIds = array_values(array_unique(array_column($placements, 'building_type_id')));
        $types = BuildingType::query()->whereIn('id', $typeIds)->get()->keyBy('id');

        // Flat "typeId:level" => footprint map. A nested grouped collection confuses static
        // analysis about nullability, and the lookup below reads better this way.
        $footprints = [];
        foreach (BuildingLevel::query()->whereIn('building_type_id', $typeIds)->get() as $buildingLevel) {
            $footprints["{$buildingLevel->building_type_id}:{$buildingLevel->level}"] = [
                'width' => $buildingLevel->grid_width,
                'height' => $buildingLevel->grid_height,
            ];
        }

        $occupied = [];

        foreach ($placements as $index => $placement) {
            $type = $types->get($placement['building_type_id']);
            if (! $type) {
                continue;
            }

            $footprint = $footprints["{$placement['building_type_id']}:{$placement['level']}"] ?? null;
            $width = $footprint['width'] ?? $type->default_grid_width;
            $height = $footprint['height'] ?? $type->default_grid_height;

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
}
