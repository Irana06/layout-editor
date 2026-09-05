<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Throwable;

class TransferGameCatalog extends Command
{
    protected $signature = 'catalog:transfer
                            {mode : export or import}
                            {path : Local JSON file}
                            {--scenery=Classic : Exact scenery name included during export}';

    protected $description = 'Transfer game catalog and calibration only, preserving IDs; import requires empty tables';

    private const TABLES = ['building_types', 'building_levels', 'building_unlock_rules', 'sceneries'];

    public function handle(): int
    {
        $path = (string) $this->argument('path');

        try {
            if ($this->argument('mode') === 'export') {
                if (File::exists($path)) {
                    $this->error('Export file already exists; choose a new path.');

                    return self::FAILURE;
                }
                $tables = [];
                foreach (self::TABLES as $table) {
                    $query = DB::table($table)->orderBy('id');
                    if ($table === 'sceneries') {
                        $query->whereRaw('LOWER(name) = LOWER(?)', [(string) $this->option('scenery')]);
                    }
                    $tables[$table] = $query->get()->map(function ($row): array {
                        $values = (array) $row;
                        if (array_key_exists('created_by', $values)) {
                            $values['created_by'] = null;
                        }

                        return $values;
                    })->all();
                }
                if ($tables['sceneries'] === []) {
                    $this->error('The requested scenery was not found; nothing was exported.');

                    return self::FAILURE;
                }
                File::ensureDirectoryExists(dirname($path));
                File::put($path, json_encode(['version' => 1, 'tables' => $tables], JSON_THROW_ON_ERROR));
            } elseif ($this->argument('mode') === 'import') {
                if (config('database.default') !== 'pgsql'
                    || config('database.connections.pgsql.search_path') !== 'shiclash') {
                    $this->error('Import must target the shiclash PostgreSQL schema.');

                    return self::FAILURE;
                }
                $document = json_decode(File::get($path), true, 512, JSON_THROW_ON_ERROR);
                if (($document['version'] ?? null) !== 1) {
                    $this->error('Unsupported catalog file version.');

                    return self::FAILURE;
                }
                $tables = $document['tables'];
                DB::transaction(function () use ($tables): void {
                    foreach (self::TABLES as $table) {
                        if (DB::table($table)->exists()) {
                            throw new \RuntimeException('Destination catalog is not empty.');
                        }
                        foreach (array_chunk($tables[$table], 100) as $rows) {
                            DB::table($table)->insert($rows);
                        }
                        $max = DB::table($table)->max('id');
                        if ($max !== null) {
                            DB::select('select setval(pg_get_serial_sequence(?, ?), ?, true)', ["shiclash.{$table}", 'id', $max]);
                        }
                    }
                });
            } else {
                $this->error('Choose export or import.');

                return self::FAILURE;
            }

            foreach (self::TABLES as $table) {
                $this->info($table.': '.count($tables[$table]));
            }

            return self::SUCCESS;
        } catch (Throwable) {
            $this->error('Catalog transfer failed. Verify the file, database connection and empty destination tables.');

            return self::FAILURE;
        }
    }
}
