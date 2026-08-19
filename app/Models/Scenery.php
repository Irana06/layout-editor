<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Scenery extends Model
{
    protected $fillable = [
        'name', 'file_path', 'image_width', 'image_height', 'tile_w', 'tile_h',
        'origin_x', 'origin_y', 'grid_n', 'calibrated', 'locked', 'created_by',
    ];

    protected function casts(): array
    {
        return ['calibrated' => 'boolean', 'locked' => 'boolean'];
    }

    public function creator(): BelongsTo { return $this->belongsTo(User::class, 'created_by'); }
    public function layouts(): HasMany { return $this->hasMany(Layout::class); }
}
