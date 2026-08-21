<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('building_unlock_rules', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('building_type_id')->constrained()->cascadeOnDelete();
            $table->unsignedTinyInteger('th_level');
            $table->unsignedTinyInteger('max_building_level');
            $table->timestamps();
            $table->unique(['building_type_id', 'th_level']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('building_unlock_rules');
    }
};
