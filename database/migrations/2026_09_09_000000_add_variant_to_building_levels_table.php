<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Some buildings have more than one artwork per level because the player
     * picks a mode: an Inferno Tower is Single or Multi, an X-Bow covers ground
     * or air. Until now the importer kept one file per level and threw the rest
     * away, so those choices never reached the catalogue at all.
     *
     * `variant` is null for the ordinary case of one artwork per level, which
     * leaves every existing row untouched.
     */
    public function up(): void
    {
        Schema::table('building_levels', function (Blueprint $table): void {
            $table->string('variant', 32)->nullable()->after('level');
            $table->dropUnique(['building_type_id', 'level']);
            $table->unique(['building_type_id', 'level', 'variant']);
        });
    }

    public function down(): void
    {
        Schema::table('building_levels', function (Blueprint $table): void {
            $table->dropUnique(['building_type_id', 'level', 'variant']);
            $table->unique(['building_type_id', 'level']);
            $table->dropColumn('variant');
        });
    }
};
