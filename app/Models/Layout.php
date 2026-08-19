<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Layout extends Model
{
    use HasUuids;

    protected $fillable = [
        'title', 'town_hall', 'payload', 'data', 'thumbnail_data', 'share_enabled', 'is_public', 'share_slug', 'user_id', 'scenery_id',
    ];

    protected function casts(): array
    {
        return [
            'payload' => 'array',
            'data' => 'array',
            'share_enabled' => 'boolean',
            'is_public' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function scenery(): BelongsTo
    {
        return $this->belongsTo(Scenery::class);
    }
}
