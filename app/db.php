<?php
// Creates one database connection ($pdo) that every page can use.
// Pages load it with:  require __DIR__ . '/db.php';

$config = require __DIR__ . '/config.php';

$dsn = "mysql:host={$config['host']};dbname={$config['name']};charset=utf8mb4";

try {
    $pdo = new PDO($dsn, $config['user'], $config['pass'], [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,  // throw errors instead of hiding them
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,        // rows come back as ['column' => value]
        PDO::ATTR_EMULATE_PREPARES   => false,                   // real prepared statements
    ]);
} catch (PDOException $e) {
    // The real reason goes to the terminal log; visitors only see a generic message.
    error_log('Database connection failed: ' . $e->getMessage());
    http_response_code(500);
    exit('Could not connect to the database.');
}
