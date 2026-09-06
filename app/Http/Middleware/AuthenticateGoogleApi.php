<?php

namespace App\Http\Middleware;

use App\Models\User;
use App\Support\GoogleIdTokenVerifier;
use App\Support\MobileSessionToken;
use Closure;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use UnexpectedValueException;

class AuthenticateGoogleApi
{
    public function __construct(
        private readonly GoogleIdTokenVerifier $googleVerifier,
        private readonly MobileSessionToken $sessionVerifier,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken();
        abort_unless($token && strlen($token) < 16384, 401, 'Silakan login Google kembali.');
        if (str_starts_with($token, MobileSessionToken::PREFIX)) {
            try {
                $claims = $this->sessionVerifier->verify($token);
            } catch (UnexpectedValueException|\InvalidArgumentException) {
                abort(401, 'Sesi Shiclash berakhir atau tidak valid. Silakan login kembali.');
            }
        } else {
            try {
                $claims = $this->googleVerifier->verify($token);
            } catch (UnexpectedValueException|\InvalidArgumentException) {
                abort(401, 'Sesi Google kedaluwarsa atau tidak valid. Silakan login kembali.');
            } catch (ConnectionException|RequestException) {
                abort(503, 'Verifikasi Google belum tersedia. Coba lagi sebentar.');
            }
        }

        $email = strtolower(trim($claims['email']));
        // Mobile calibration only needs a verified request identity. Keeping it
        // transient avoids mutating or linking website accounts during API use.
        $user = new User([
            'email' => $email,
            'name' => mb_substr((string) ($claims['name'] ?? $email), 0, 255),
            'role' => 'user',
        ]);
        $request->setUserResolver(fn () => $user);

        return $next($request);
    }
}
