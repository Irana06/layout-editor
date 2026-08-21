<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class BuildingUnlockRule extends Model
{
    protected $fillable = [
        'building_type_id', 'th_level', 'max_building_level', 'max_count',
    ];

    /** @return BelongsTo<BuildingType, $this> */
    public function type(): BelongsTo
    {
        return $this->belongsTo(BuildingType::class, 'building_type_id');
    }
}
