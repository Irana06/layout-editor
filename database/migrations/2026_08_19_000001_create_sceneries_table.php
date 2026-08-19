<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sceneries', function (Blueprint $table): void {
            $table->id(); $table->string('name'); $table->string('file_path')->unique();
            $table->unsignedInteger('image_width'); $table->unsignedInteger('image_height');
            $table->float('tile_w')->default(56); $table->float('tile_h')->default(42);
            $table->float('origin_x')->default(0); $table->float('origin_y')->default(0);
            $table->unsignedTinyInteger('grid_n')->default(44);
            $table->boolean('calibrated')->default(false); $table->boolean('locked')->default(false);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete(); $table->timestamps();
        });
    }
    public function down(): void { Schema::dropIfExists('sceneries'); }
};
