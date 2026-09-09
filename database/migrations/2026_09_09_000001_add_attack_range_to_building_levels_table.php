<?php

use App\Models\BuildingLevel;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * An Inferno Tower reaches further on Single than on Multi, so range cannot
     * live on the building type once modes exist — it belongs beside the
     * artwork that the mode selects.
     *
     * Null means "use the type's value", which keeps every building that has no
     * mode working exactly as before and lets the type stay the place a range is
     * entered once for all levels.
     */
    public function up(): void
    {
        Schema::table('building_levels', function (Blueprint $table): void {
            $table->unsignedTinyInteger('attack_range_min')->nullable()->after('offset_y');
            $table->unsignedTinyInteger('attack_range_max')->nullable()->after('attack_range_min');
        });

        // Modes start from whatever the type already had, so nothing visibly
        // changes until someone calibrates them apart.
        BuildingLevel::query()->whereNotNull('variant')->update([
            'attack_range_min' => null,
            'attack_range_max' => null,
        ]);
    }

    public function down(): void
    {
        Schema::table('building_levels', function (Blueprint $table): void {
            $table->dropColumn(['attack_range_min', 'attack_range_max']);
        });
    }
};
