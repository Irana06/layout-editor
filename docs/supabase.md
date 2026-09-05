# Supabase database for Shiclash

Supabase is the managed PostgreSQL database. Laravel remains the only API used by the React website and Flutter app. The clients do not receive the database password or connect directly to Supabase.

## Current project

- Supabase project: `shiclash`
- Laravel schema: `shiclash`
- Connection: Session Pooler on port `5432`, with `sslmode=require`
- Game catalog: 83 building types, 564 building levels, 82 TH unlock rules
- Published scenery: only `classic`

Laravel tables live in the dedicated `shiclash` schema. Access for the Supabase `anon` and `authenticated` roles is revoked from this schema. The public schema remains empty, so these tables are not exposed by Supabase Data API.

## Local maintenance

The real credentials are stored in `.env.supabase`, which is ignored by Git. Copy `.env.supabase.example` when configuring another machine or a hosting provider. Never add `.env.supabase` or the database password to GitHub.

Verify the connection without changing the database:

```powershell
php artisan supabase:prepare --env=supabase --check
```

Prepare the private schema and run future migrations:

```powershell
php artisan supabase:prepare --env=supabase
php artisan migrate --env=supabase --force
```

Catalog transfer intentionally excludes users, layouts, sessions, cache, and jobs. Export uses an exact scenery name and refuses to overwrite an existing file. Import only accepts an empty catalog:

```powershell
php artisan catalog:transfer export storage/app/private/supabase-catalog.json --scenery=Classic
php artisan catalog:transfer import storage/app/private/supabase-catalog.json --env=supabase
```

## Hosting variables

Add all values from `.env.supabase.example` to the Laravel hosting service and replace the placeholders. Set `APP_URL` to the public Laravel HTTPS URL. After Laravel is online, set the GitHub Actions repository variable `API_BASE_URL` to:

```text
https://YOUR-LARAVEL-HOST.example/api/v1
```

Rebuild the APK after changing `API_BASE_URL`; it is compiled into the app.

Supabase does not run PHP applications. Laravel still needs a PHP/Docker host such as Render; Supabase supplies its PostgreSQL database.
