<?php
require __DIR__ . '/auth.php';
require_login('landlord');
require __DIR__ . '/db.php';

// landlord_id in the database is the same number as the logged-in user's ID.
// Every query below filters on it, so a landlord only ever sees their own data.
$landlordId = $_SESSION['user_id'];

// Small helper: runs a query with the landlord ID filled into the "?" and returns the result.
$query = function (string $sql) use ($pdo, $landlordId) {
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$landlordId]);
    return $stmt;
};

// ---- Summary numbers for the cards ----
$outstanding = $query('SELECT COALESCE(SUM(balance), 0) FROM v_lease_balances WHERE landlord_id = ?')->fetchColumn();

$overdue = $query('SELECT COUNT(*) AS n, COALESCE(SUM(balance_remaining), 0) AS total
                   FROM v_overdue_invoices WHERE landlord_id = ?')->fetch();

$occ = $query('SELECT COALESCE(SUM(total_units), 0) AS total, COALESCE(SUM(occupied_units), 0) AS occupied
               FROM v_property_occupancy WHERE landlord_id = ?')->fetch();
$occupancyRate = $occ['total'] > 0 ? round(100 * $occ['occupied'] / $occ['total']) : 0;

$collected = $query("SELECT COALESCE(SUM(total_collected), 0) FROM v_monthly_collections
                     WHERE landlord_id = ? AND month = DATE_FORMAT(CURDATE(), '%Y-%m')")->fetchColumn();

// ---- Tables ----
$properties  = $query('SELECT * FROM v_property_occupancy WHERE landlord_id = ? ORDER BY property_name')->fetchAll();
$balances    = $query('SELECT * FROM v_lease_balances WHERE landlord_id = ? ORDER BY balance DESC, tenant_name')->fetchAll();
$overdueRows = $query('SELECT * FROM v_overdue_invoices WHERE landlord_id = ? ORDER BY days_overdue DESC')->fetchAll();

$pageTitle = 'Landlord dashboard';
require __DIR__ . '/header.php';
?>

<h1>Landlord dashboard</h1>

<div class="cards">
    <div class="card">
        <div class="label">Collected this month</div>
        <div class="value"><?= money($collected) ?></div>
    </div>
    <div class="card <?= $outstanding > 0 ? 'alert' : '' ?>">
        <div class="label">Total outstanding</div>
        <div class="value"><?= money($outstanding) ?></div>
    </div>
    <div class="card <?= $overdue['n'] > 0 ? 'alert' : '' ?>">
        <div class="label">Overdue invoices</div>
        <div class="value"><?= (int) $overdue['n'] ?> (<?= money($overdue['total']) ?>)</div>
    </div>
    <div class="card">
        <div class="label">Occupancy</div>
        <div class="value"><?= (int) $occ['occupied'] ?> of <?= (int) $occ['total'] ?> units (<?= $occupancyRate ?>%)</div>
    </div>
</div>

<h2>Overdue invoices</h2>
<?php if (count($overdueRows) === 0): ?>
    <div class="empty">No overdue invoices. Everyone is up to date.</div>
<?php else: ?>
<div class="table-wrap">
<table>
    <tr>
        <th>Tenant</th><th>Phone</th><th>Property</th><th>Unit</th>
        <th>Month</th><th>Due date</th><th class="num">Days overdue</th><th class="num">Balance</th>
    </tr>
    <?php foreach ($overdueRows as $row): ?>
    <tr>
        <td><?= e($row['tenant_name']) ?></td>
        <td><?= e($row['tenant_phone']) ?></td>
        <td><?= e($row['property_name']) ?></td>
        <td><?= e($row['unit_number']) ?></td>
        <td><?= e(date('F Y', strtotime($row['billing_month']))) ?></td>
        <td><?= e($row['due_date']) ?></td>
        <td class="num"><?= (int) $row['days_overdue'] ?></td>
        <td class="num owes"><?= money($row['balance_remaining']) ?></td>
    </tr>
    <?php endforeach; ?>
</table>
</div>
<?php endif; ?>

<h2>Tenant balances</h2>
<div class="table-wrap">
<table>
    <tr>
        <th>Tenant</th><th>Property</th><th>Unit</th><th>Lease</th>
        <th class="num">Charged</th><th class="num">Paid</th><th class="num">Balance</th>
    </tr>
    <?php foreach ($balances as $row): ?>
    <tr>
        <td><?= e($row['tenant_name']) ?></td>
        <td><?= e($row['property_name']) ?></td>
        <td><?= e($row['unit_number']) ?></td>
        <td><?= e($row['lease_status']) ?></td>
        <td class="num"><?= money($row['total_charged']) ?></td>
        <td class="num"><?= money($row['total_paid']) ?></td>
        <td class="num <?= $row['balance'] > 0 ? 'owes' : 'ok' ?>"><?= money($row['balance']) ?></td>
    </tr>
    <?php endforeach; ?>
</table>
</div>

<h2>Properties and occupancy</h2>
<div class="table-wrap">
<table>
    <tr>
        <th>Property</th><th>District</th><th class="num">Units</th>
        <th class="num">Occupied</th><th class="num">Vacant</th><th class="num">Maintenance</th><th class="num">Occupancy</th>
    </tr>
    <?php foreach ($properties as $row): ?>
    <tr>
        <td><?= e($row['property_name']) ?></td>
        <td><?= e($row['district']) ?></td>
        <td class="num"><?= (int) $row['total_units'] ?></td>
        <td class="num"><?= (int) $row['occupied_units'] ?></td>
        <td class="num"><?= (int) $row['vacant_units'] ?></td>
        <td class="num"><?= (int) $row['maintenance_units'] ?></td>
        <td class="num"><?= e((string) $row['occupancy_rate_pct']) ?>%</td>
    </tr>
    <?php endforeach; ?>
</table>
</div>

<?php require __DIR__ . '/footer.php'; ?>
