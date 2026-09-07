<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\ValidatesLayoutPayload;
use App\Http\Controllers\Controller;
use App\Models\Layout;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Sharing takes a snapshot rather than publishing a live document.
 *
 * The phone keeps the original; sharing copies it to the server under its own
 * code and the two never speak again. Editing the layout afterwards leaves the
 * shared link showing exactly what was sent, which is what a link handed to
 * someone else should do — sharing the newer version means sharing again and
 * getting a new link.
 */
class SharedLayoutController extends Controller
{
    use ValidatesLayoutPayload;

    /** Codes read aloud or retyped, so no 0/O or 1/l to confuse. */
    private const ALPHABET = '23456789abcdefghjkmnpqrstuvwxyz';

    private const CODE_LENGTH = 6;

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);

        $layout = Layout::create([
            ...$data,
            'share_enabled' => true,
            'share_slug' => $this->generateCode(),
        ]);

        return response()->json([
            'data' => [
                'code' => $layout->share_slug,
                'url' => $this->shareUrl($layout->share_slug),
            ],
        ], 201);
    }

    public function show(string $code): JsonResponse
    {
        $layout = Layout::query()
            ->where('share_slug', $code)
            ->where('share_enabled', true)
            ->firstOrFail();

        return response()->json([
            'data' => [
                'code' => $layout->share_slug,
                'title' => $layout->title,
                'th_level' => $layout->th_level,
                'scenery_id' => $layout->scenery_id,
                'data' => $layout->data ?? [],
                'shared_at' => $layout->created_at?->toIso8601String(),
            ],
        ]);
    }

    private function shareUrl(string $code): string
    {
        return rtrim((string) config('app.url'), '/')."/l/{$code}";
    }

    private function generateCode(): string
    {
        do {
            $code = '';
            for ($i = 0; $i < self::CODE_LENGTH; $i++) {
                $code .= self::ALPHABET[random_int(0, strlen(self::ALPHABET) - 1)];
            }
        } while (Layout::query()->where('share_slug', $code)->exists());

        return $code;
    }
}
