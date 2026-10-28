<?php
// One-time setup script: gives the sample users real (hashed) passwords.
// Run it from the terminal:  php set_passwords.php
// These are DEMO passwords for the sample data only.
// Run it again any time you re-run seed.sql.

if (PHP_SAPI !== 'cli') {
    exit('Run this script from the command line.');
}

require __DIR__ . '/db.php';

$demoPasswords = [
    'jkato'     => 'landlord123',
    'snakato'   => 'landlord123',
    'amukasa'   => 'tenant123',
    'bnamubiru' => 'tenant123',
    'cokello'   => 'tenant123',
];

$stmt = $pdo->prepare('UPDATE users SET password_hash = ? WHERE username = ?');

foreach ($demoPasswords as $username => $password) {
    // password_hash adds a random salt, so the same password gives a different hash each time
    $hash = password_hash($password, PASSWORD_DEFAULT);
    $stmt->execute([$hash, $username]);
    echo "Updated $username\n";
}

echo "Done.\n";
