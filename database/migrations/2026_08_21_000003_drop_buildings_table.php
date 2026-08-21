<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('buildings');
    }

    public function down(): void
    {
        Schema::create('buildings', function (Blueprint $table): void {
            $table->id();
            $table->string('name');
            $table->string('category', 32);
            $table->string('subfolder')->nullable();
            $table->string('file_path')->unique();
            $table->unsignedTinyInteger('grid_width')->default(1);
            $table->unsignedTinyInteger('grid_height')->default(1);
            $table->float('scale')->default(1);
            $table->float('offset_x')->default(0);
            $table->float('offset_y')->default(0);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });
    }
};
