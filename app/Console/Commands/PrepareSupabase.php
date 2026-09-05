<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Throwable;

class PrepareSupabase extends Command
{
    protected $signature = 'supabase:prepare {--check : Verify the connection without changing the database}';

    protected $description = 'Verify Supabase PostgreSQL and prepare the private shiclash schema';

    public function handle(): int
    {
        if (config('database.default') !== 'pgsql'
            || config('database.connections.pgsql.search_path') !== 'shiclash'
            || ! str_ends_with((string) config('database.connections.pgsql.host'), '.pooler.supabase.com')
            || config('database.connections.pgsql.sslmode') !== 'require') {
            $this->error('Use the Supabase environment with pgsql, a Supabase pooler host, DB_SCHEMA=shiclash and DB_SSLMODE=require.');

            return self::FAILURE;
        }

        try {
            DB::select('select 1');
            // pg_stat_ssl describes the pooler's internal database connection,
            // not this client's TLS link. libpq enforces sslmode=require here.
            $this->info('Supabase PostgreSQL connection verified with sslmode=require.');

            if (! $this->option('check')) {
                DB::transaction(function (): void {
                    DB::statement('CREATE SCHEMA IF NOT EXISTS shiclash');
                    DB::statement('REVOKE ALL ON SCHEMA shiclash FROM PUBLIC, anon, authenticated');
                });
                $this->info('Private shiclash schema ready. Run artisan migrate --env=supabase.');
            }

            return self::SUCCESS;
        } catch (Throwable) {
            // Do not echo exception details that may contain connection credentials.
            $this->error('Connection/setup failed. Check the database password, pooler endpoint, network and database privileges.');

            return self::FAILURE;
        }
    }
}
