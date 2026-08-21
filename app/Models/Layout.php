<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * @property array<int, array{building_type_id: int, level: int, gx: int, gy: int}> $data
 */
class Layout extends Model
{
    use HasUuids;

    protected $fillable = [
        'title', 'th_level', 'data', 'thumbnail_data', 'share_enabled', 'share_slug', 'user_id', 'scenery_id',
    ];

    protected function casts(): array
    {
        return [
            'share_enabled' => 'boolean',
        ];
    }

    /** Placements array `[{building_type_id, level, gx, gy}, ...]`. `data` is nullable at the DB level.
     *
     * @return Attribute<array<int, array{building_type_id: int, level: int, gx: int, gy: int}>, array<int, array{building_type_id: int, level: int, gx: int, gy: int}>>
     */
    protected function data(): Attribute
    {
        return Attribute::make(
            get: fn (?string $value) => $value === null ? [] : json_decode($value, true),
            set: fn (array $value) => json_encode($value),
        );
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** @return BelongsTo<Scenery, $this> */
    public function scenery(): BelongsTo
    {
        return $this->belongsTo(Scenery::class);
    }
}
