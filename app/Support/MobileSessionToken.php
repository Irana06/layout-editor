<?php

namespace App\Support;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use UnexpectedValueException;

class MobileSessionToken
{
    public const PREFIX = 'shiclash_';

    public const LIFETIME_SECONDS = 60 * 60 * 24 * 90;

    /** @param array<string, mixed> $googleClaims */
    public function issue(array $googleClaims): string
    {
        $now = time();
        $token = JWT::encode([
            'iss' => 'shiclash-api',
            'aud' => 'shiclash-mobile',
            'typ' => 'shiclash_session',
            'sub' => $googleClaims['sub'],
            'email' => strtolower(trim((string) $googleClaims['email'])),
            'name' => (string) ($googleClaims['name'] ?? $googleClaims['email']),
            'picture' => isset($googleClaims['picture']) ? (string) $googleClaims['picture'] : null,
            'iat' => $now,
            'exp' => $now + self::LIFETIME_SECONDS,
        ], $this->key(), 'HS256');

        return self::PREFIX.$token;
    }

    /** @return array<string, mixed> */
    public function verify(string $token): array
    {
        if (! str_starts_with($token, self::PREFIX)) {
            throw new UnexpectedValueException('Not a Shiclash session token.');
        }

        $claims = (array) JWT::decode(
            substr($token, strlen(self::PREFIX)),
            new Key($this->key(), 'HS256'),
        );

        if (($claims['iss'] ?? null) !== 'shiclash-api'
            || ($claims['aud'] ?? null) !== 'shiclash-mobile'
            || ($claims['typ'] ?? null) !== 'shiclash_session'
            || ! is_string($claims['sub'] ?? null) || $claims['sub'] === ''
            || ! is_string($claims['email'] ?? null)
            || ! filter_var($claims['email'], FILTER_VALIDATE_EMAIL)
            || ! is_numeric($claims['exp'] ?? null) || $claims['exp'] <= time()) {
            throw new UnexpectedValueException('Invalid Shiclash session.');
        }

        return $claims;
    }

    private function key(): string
    {
        $key = config('app.key');
        if (! is_string($key) || $key === '') {
            throw new UnexpectedValueException('Application key is not configured.');
        }

        return hash('sha256', $key, true);
    }
}
