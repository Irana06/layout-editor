<?php

namespace App\Support;

use Illuminate\Support\Facades\File;

/**
 * Copies a game asset (building sprite or scenery image) into public_path('game/...'),
 * the single tree the frontend reads from at runtime (see resources/js/lib/game-assets.ts).
 * Shared between the `import:legacy-assets` command and the Calibrate page's upload endpoints
 * so both write to the exact same destination convention.
 */
class GameAssetUploader
{
    /**
     * @param  string  $source  Absolute path to the source file.
     * @param  string  $destination  Path relative to public_path('game'), e.g. "buildings/defensive/cannon/1.png".
     */
    public function copyToPublicGame(string $source, string $destination, bool $force = false): string
    {
        $fullDestination = public_path('game/'.$destination);

        if ($force || ! File::exists($fullDestination)) {
            File::ensureDirectoryExists(dirname($fullDestination));
            File::copy($source, $fullDestination);
        }

        return $destination;
    }
}
