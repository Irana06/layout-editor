<?php

namespace App\Http\Controllers;

use App\Models\Layout;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;

/**
 * What a shared link does when it lands in a browser.
 *
 * On Android the App Link normally hands the URL straight to Shiclash and this
 * page is never seen. It is what remains when the app is missing, the link was
 * opened on a desktop, or verification has not happened yet — so it offers the
 * app and shows enough of the layout to prove the link works.
 *
 * The full web viewer is deliberately not built here; it follows the app once
 * the mobile side is settled.
 */
class ShareLinkController extends Controller
{
    public function show(string $code): Response
    {
        $layout = Layout::query()
            ->where('share_slug', $code)
            ->where('share_enabled', true)
            ->first();

        return response()->view('share-link', [
            'code' => $code,
            'layout' => $layout,
            'deepLink' => "shiclash://layout/{$code}",
        ], $layout ? 200 : 404);
    }

    /**
     * Digital Asset Links, which is how Android decides this site may open in
     * Shiclash rather than a browser. The fingerprint belongs to the release
     * keystore, so it comes from configuration and never from the repository.
     */
    public function assetLinks(): JsonResponse
    {
        $fingerprint = (string) config('services.android.sha256_fingerprint');

        if ($fingerprint === '') {
            return response()->json([], 404);
        }

        return response()->json([[
            'relation' => ['delegate_permission/common.handle_all_urls'],
            'target' => [
                'namespace' => 'android_app',
                'package_name' => (string) config('services.android.package', 'com.shiclash.editor'),
                'sha256_cert_fingerprints' => [$fingerprint],
            ],
        ]]);
    }
}
