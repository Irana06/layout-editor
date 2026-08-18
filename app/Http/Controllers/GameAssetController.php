<?php

namespace App\Http\Controllers;

use Symfony\Component\HttpFoundation\BinaryFileResponse;

class GameAssetController extends Controller
{
    /** Serve the source asset pack without duplicating it into public/. */
    public function show(string $path): BinaryFileResponse
    {
        $relativePath = str_replace('\\', '/', $path);

        if (str_contains($relativePath, '..')) {
            abort(404);
        }

        $root = realpath(base_path('basecode_layout-editor/assets/game'));
        $file = $root === false ? false : realpath($root.DIRECTORY_SEPARATOR.$relativePath);

        if ($root === false || $file === false || ! str_starts_with($file, $root.DIRECTORY_SEPARATOR) || ! is_file($file)) {
            abort(404);
        }

        return response()->file($file, [
            'Cache-Control' => 'public, max-age=604800, immutable',
        ]);
    }
}
