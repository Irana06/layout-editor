<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('building_types', function (Blueprint $table): void {
            $table->boolean('shows_deployment_ring')->default(true)->after('default_grid_height');
        });

        // Traps are hidden during an attack. Hidden Tesla follows the same
        // placement rule even though it lives in the defensive category.
        DB::table('building_types')
            ->where('category', 'traps')
            ->orWhereIn('subfolder', ['hidden-tesla', 'hidden_tesla', 'hidden tesla'])
            ->update(['shows_deployment_ring' => false]);
    }

    public function down(): void
    {
        Schema::table('building_types', function (Blueprint $table): void {
            $table->dropColumn('shows_deployment_ring');
        });
    }
};
