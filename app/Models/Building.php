<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Building extends Model
{
    protected $fillable = [
        'name', 'category', 'subfolder', 'file_path', 'grid_width', 'grid_height',
        'scale', 'offset_x', 'offset_y', 'created_by',
    ];

    protected function casts(): array
    {
        return ['scale' => 'float', 'offset_x' => 'float', 'offset_y' => 'float'];
    }

    public function creator(): BelongsTo { return $this->belongsTo(User::class, 'created_by'); }
}
