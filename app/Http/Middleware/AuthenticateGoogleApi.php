<?php

namespace App\Http\Middleware;

use App\Models\User;
use App\Support\GoogleIdTokenVerifier;
use Closure;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use UnexpectedValueException;

class AuthenticateGoogleApi
{
    public function __construct(private readonly GoogleIdTokenVerifier $verifier) {}

    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken();
        abort_unless($token && strlen($token) < 16384, 401, 'Silakan login Google kembali.');
        try {
            $claims = $this->verifier->verify($token);
        } catch (UnexpectedValueException|\InvalidArgumentException $exception) {
            abort(401, 'Sesi Google kedaluwarsa atau tidak valid. Silakan login kembali.');
        } catch (ConnectionException|RequestException $exception) {
            abort(503, 'Verifikasi Google belum tersedia. Coba lagi sebentar.');
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
