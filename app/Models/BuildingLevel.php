<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class BuildingLevel extends Model
{
    protected $fillable = [
        'building_type_id', 'level', 'variant', 'file_path', 'grid_width', 'grid_height', 'scale', 'offset_x', 'offset_y',
    ];

    protected function casts(): array
    {
        return ['scale' => 'float', 'offset_x' => 'float', 'offset_y' => 'float'];
    }

    /** @return BelongsTo<BuildingType, $this> */
    public function type(): BelongsTo
    {
        return $this->belongsTo(BuildingType::class, 'building_type_id');
    }
}
