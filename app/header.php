<?php
// Shared page header. Set $pageTitle before including this file.
// The page must have already loaded auth.php.

// Formats a number as money, e.g. 1220000 -> "UGX 1,220,000"
function money($amount): string
{
    return 'UGX ' . number_format((float) $amount);
}

$pageTitle = $pageTitle ?? 'RentTrack';
$home = ($_SESSION['role'] ?? '') === 'landlord' ? 'landlord_dashboard.php' : 'tenant_dashboard.php';
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($pageTitle) ?> - RentTrack</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<nav>
    <a class="brand" href="<?= e($home) ?>">RentTrack</a>
    <div class="user">
        <?php if ($_SESSION['role'] === 'landlord'): ?>
            <a href="record_payment.php">Record payment</a>
        <?php endif; ?>
        <?= e($_SESSION['username']) ?> (<?= e($_SESSION['role']) ?>)
        <a href="logout.php">Log out</a>
    </div>
</nav>
<main>
<?php if (!empty($_SESSION['flash'])): ?>
    <div class="flash"><?= e($_SESSION['flash']) ?></div>
    <?php unset($_SESSION['flash']); ?>
<?php endif; ?>
