<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('building_types', function (Blueprint $table): void {
            $table->id();
            $table->string('name');
            $table->string('category', 32);
            $table->string('subfolder')->nullable();
            $table->boolean('is_town_hall')->default(false);
            $table->unsignedTinyInteger('default_grid_width')->default(1);
            $table->unsignedTinyInteger('default_grid_height')->default(1);
            $table->timestamps();
            $table->unique(['category', 'subfolder', 'name']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('building_types');
    }
};
