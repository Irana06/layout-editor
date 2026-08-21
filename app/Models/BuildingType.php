<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class BuildingType extends Model
{
    protected $fillable = [
        'name', 'category', 'subfolder', 'is_town_hall', 'default_grid_width', 'default_grid_height',
    ];

    protected function casts(): array
    {
        return ['is_town_hall' => 'boolean'];
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
}
