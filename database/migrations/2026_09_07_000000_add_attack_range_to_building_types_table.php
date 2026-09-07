<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Attack range, in tiles, measured outward from the building's edge tiles:
     * a range of 1 covers the ring of tiles immediately around the footprint.
     * Zero means the building has no range and draws no ring — the default,
     * since most buildings are not defences.
     *
     * `attack_range_min` gives mortars and similar their blind spot; when it is
     * zero only the outer ring is drawn.
     */
    public function up(): void
    {
        Schema::table('building_types', function (Blueprint $table): void {
            $table->unsignedTinyInteger('attack_range_min')->default(0)->after('default_grid_height');
            $table->unsignedTinyInteger('attack_range_max')->default(0)->after('attack_range_min');
        });
    }

    public function down(): void
    {
        Schema::table('building_types', function (Blueprint $table): void {
            $table->dropColumn(['attack_range_min', 'attack_range_max']);
        });
    }
};
