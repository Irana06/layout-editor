<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('layouts', function (Blueprint $table): void {
            $table->foreignId('scenery_id')->nullable()->after('user_id')->constrained('sceneries')->nullOnDelete();
            $table->json('data')->nullable()->after('payload');
            $table->boolean('is_public')->default(false)->after('share_enabled');
            $table->string('share_slug')->nullable()->unique()->after('is_public');
        });
    }
    public function down(): void
    {
        Schema::table('layouts', function (Blueprint $table): void {
            $table->dropForeign(['scenery_id']); $table->dropUnique(['share_slug']);
            $table->dropColumn(['scenery_id', 'data', 'is_public', 'share_slug']);
        });
    }
};
