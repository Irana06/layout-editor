<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('building_levels', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('building_type_id')->constrained()->cascadeOnDelete();
            $table->unsignedTinyInteger('level');
            $table->string('file_path');
            $table->unsignedTinyInteger('grid_width')->nullable();
            $table->unsignedTinyInteger('grid_height')->nullable();
            $table->float('scale')->default(1);
            $table->float('offset_x')->default(0);
            $table->float('offset_y')->default(0);
            $table->timestamps();
            $table->unique(['building_type_id', 'level']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('building_levels');
    }
};
