<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('layouts', function (Blueprint $table): void {
            $table->renameColumn('town_hall', 'th_level');
        });

        Schema::table('layouts', function (Blueprint $table): void {
            $table->dropColumn(['payload', 'is_public']);
        });
    }

    public function down(): void
    {
        Schema::table('layouts', function (Blueprint $table): void {
            $table->json('payload')->nullable();
            $table->boolean('is_public')->default(false);
        });

        Schema::table('layouts', function (Blueprint $table): void {
            $table->renameColumn('th_level', 'town_hall');
        });
    }
};
