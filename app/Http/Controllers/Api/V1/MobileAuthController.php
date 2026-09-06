<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\GoogleIdTokenVerifier;
use App\Support\MobileSessionToken;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use UnexpectedValueException;

class MobileAuthController extends Controller
{
    public function store(
        Request $request,
        GoogleIdTokenVerifier $google,
        MobileSessionToken $sessions,
    ): JsonResponse {
        $token = $request->bearerToken();
        abort_unless($token && strlen($token) < 16384, 401, 'Token Google diperlukan.');

        try {
            $claims = $google->verify($token);
        } catch (UnexpectedValueException|\InvalidArgumentException) {
            abort(401, 'Login Google tidak valid. Silakan coba lagi.');
        } catch (ConnectionException|RequestException) {
            abort(503, 'Verifikasi Google belum tersedia. Coba lagi sebentar.');
        }

        $email = strtolower(trim((string) $claims['email']));

        return response()->json([
            'token' => $sessions->issue($claims),
            'token_type' => 'Bearer',
            'expires_in' => MobileSessionToken::LIFETIME_SECONDS,
            'data' => [
                'name' => mb_substr((string) ($claims['name'] ?? $email), 0, 255),
                'email' => $email,
                'photo_url' => isset($claims['picture']) ? (string) $claims['picture'] : null,
                'is_admin' => User::isConfiguredAdminEmail($email),
            ],
        ]);
    }
}
