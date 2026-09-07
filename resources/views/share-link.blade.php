<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $layout?->title ?? 'Layout tidak ditemukan' }} · Shiclash</title>
    <style>
        :root { color-scheme: dark; }
        body {
            margin: 0; min-height: 100vh; display: grid; place-items: center;
            background: #071a35; color: #fff9ef; padding: 24px;
            font-family: system-ui, -apple-system, 'Segoe UI', sans-serif;
        }
        .card { max-width: 26rem; text-align: center; }
        h1 { font-size: 1.4rem; margin: 0 0 .35rem; }
        p { color: #e8d6b6; line-height: 1.55; margin: .5rem 0; }
        .muted { color: #9fb3c8; font-size: .85rem; }
        .code { font-family: ui-monospace, monospace; letter-spacing: .1em; }
        a.button {
            display: inline-block; margin-top: 1.1rem; padding: .7rem 1.3rem;
            background: #e8d6b6; color: #071a35; border-radius: 999px;
            font-weight: 600; text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="card">
        @if ($layout)
            <h1>{{ $layout->title }}</h1>
            <p>Town Hall {{ $layout->th_level }} · {{ count($layout->data ?? []) }} objek</p>
            <p class="muted">Buka di aplikasi Shiclash untuk melihat dan menyalin layout ini.</p>
            <a class="button" href="{{ $deepLink }}">Buka di Shiclash</a>
            <p class="muted">Kode layout: <span class="code">{{ $code }}</span></p>
        @else
            <h1>Layout tidak ditemukan</h1>
            <p class="muted">Tautan <span class="code">{{ $code }}</span> sudah tidak berlaku atau salah ketik.</p>
        @endif
    </div>
</body>
</html>
