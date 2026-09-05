<?php

$emails = array_map(
    static fn (string $email): string => strtolower(trim($email)),
    explode(',', (string) env('ADMIN_EMAILS', '')),
);

return [
    'emails' => array_values(array_filter($emails)),
];
