<?php

namespace App\Support;

use Firebase\JWT\JWK;
use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use UnexpectedValueException;

class GoogleIdTokenVerifier
{
    /** @return array<string, mixed> */
    public function verify(string $token): array
    {
        $clientId = config('services.google.client_id');
        abort_unless(is_string($clientId) && $clientId !== '', 503, 'Login Google server belum dikonfigurasi.');

        $keys = Cache::remember('google-oidc-jwks', 3600, function (): array {
            return Http::timeout(10)->get('https://www.googleapis.com/oauth2/v3/certs')->throw()->json();
        });
        $claims = (array) JWT::decode($token, JWK::parseKeySet($keys, 'RS256'));

        if (! in_array($claims['iss'] ?? null, ['accounts.google.com', 'https://accounts.google.com'], true)
            || ($claims['aud'] ?? null) !== $clientId
            || ! is_numeric($claims['exp'] ?? null) || $claims['exp'] <= time()
            || ! is_string($claims['sub'] ?? null) || $claims['sub'] === ''
            || ($claims['email_verified'] ?? false) !== true
            || ! is_string($claims['email'] ?? null)
            || ! filter_var($claims['email'], FILTER_VALIDATE_EMAIL)) {
            throw new UnexpectedValueException('Invalid Google identity.');
        }

        // Google must be authoritative for the email before linking an existing account.
        if (! str_ends_with(strtolower($claims['email']), '@gmail.com') && empty($claims['hd'])) {
            throw new UnexpectedValueException('Google is not authoritative for this email.');
        }

        return $claims;
    }
}
