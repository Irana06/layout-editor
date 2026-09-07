<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\DB;

class BuildingType extends Model
{
    protected $fillable = [
        'name', 'category', 'subfolder', 'is_town_hall', 'default_grid_width', 'default_grid_height', 'shows_deployment_ring',
    ];

    protected function casts(): array
    {
        return ['is_town_hall' => 'boolean', 'shows_deployment_ring' => 'boolean'];
    }

    /** @return HasMany<BuildingLevel, $this> */
    public function levels(): HasMany
    {
        return $this->hasMany(BuildingLevel::class)->orderBy('level');
    }

    /** @return HasMany<BuildingUnlockRule, $this> */
    public function unlockRules(): HasMany
    {
        return $this->hasMany(BuildingUnlockRule::class);
    }

    /**
     * Adopt one footprint for the whole type.
     *
     * A footprint is a property of the building, not of a level's artwork: a
     * Cannon occupies 3x3 tiles at level 1 and at level 21 alike. Only the
     * visual scale and offsets differ per level, so setting the footprint here
     * and clearing every per-level override keeps a single source of truth and
     * spares the operator from re-entering the same tile size on each level.
     */
    public function applyFootprint(int $width, int $height): self
    {
        return DB::transaction(function () use ($width, $height): self {
            $type = static::query()
                ->whereKey($this->getKey())
                ->lockForUpdate()
                ->firstOrFail();

            $type->update([
                'default_grid_width' => $width,
                'default_grid_height' => $height,
            ]);

            $type->levels()->update(['grid_width' => null, 'grid_height' => null]);

            return $type->fresh('levels');
        });
    }
}
