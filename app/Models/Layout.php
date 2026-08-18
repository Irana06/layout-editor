<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Layout extends Model
{
    use HasUuids;

    protected $fillable = [
        'title', 'town_hall', 'payload', 'thumbnail_data', 'share_enabled', 'user_id',
    ];

    protected function casts(): array
    {
        return [
            'payload' => 'array',
            'share_enabled' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
