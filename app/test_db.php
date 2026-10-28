<?php
// Temporary test page: proves PHP can read from the renttrack database.
// Delete it once the real pages work.
require __DIR__ . '/db.php';

$rows = $pdo->query('SELECT * FROM v_lease_balances')->fetchAll();
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Database test</title>
</head>
<body>
    <h1>Database connection works</h1>
    <table border="1" cellpadding="6">
        <tr>
            <th>Tenant</th><th>Property</th><th>Unit</th><th>Balance (UGX)</th>
        </tr>
        <?php foreach ($rows as $row): ?>
        <tr>
            <td><?= htmlspecialchars($row['tenant_name']) ?></td>
            <td><?= htmlspecialchars($row['property_name']) ?></td>
            <td><?= htmlspecialchars($row['unit_number']) ?></td>
            <td><?= number_format($row['balance']) ?></td>
        </tr>
        <?php endforeach; ?>
    </table>
</body>
</html>
