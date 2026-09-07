<?php

return [
    'google' => [
        'client_id' => env('GOOGLE_WEB_CLIENT_ID'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Resend, Postmark, AWS, and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    // Lets Android open shared links in Shiclash instead of a browser. The
    // fingerprint is the release keystore's SHA-256, from
    // `keytool -list -v -keystore <jks> -alias <alias>`. Left unset, the
    // assetlinks endpoint 404s and links simply open the web page instead.
    'android' => [
        'package' => env('ANDROID_PACKAGE', 'com.shiclash.editor'),
        'sha256_fingerprint' => env('ANDROID_SHA256_FINGERPRINT'),
    ],

];
