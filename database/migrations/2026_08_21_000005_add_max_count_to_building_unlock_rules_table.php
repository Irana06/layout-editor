<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('building_unlock_rules', function (Blueprint $table): void {
            // null = tidak dibatasi. 0 tidak dipakai untuk "tidak tersedia" —
            // itu diwakili oleh max_building_level = 0.
            $table->unsignedSmallInteger('max_count')->nullable()->after('max_building_level');
        });
    }

    public function down(): void
    {
        Schema::table('building_unlock_rules', function (Blueprint $table): void {
            $table->dropColumn('max_count');
        });
    }
};
