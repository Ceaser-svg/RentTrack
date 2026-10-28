<?php
require __DIR__ . '/auth.php';
require_login('tenant');
require __DIR__ . '/db.php';

// Every query filters on the logged-in user's ID, which comes from the session.
// There is no ID in the URL or a form, so a tenant cannot ask for someone else's data.
$userId = $_SESSION['user_id'];
$today  = date('Y-m-d');

$leases = $pdo->prepare('SELECT * FROM v_lease_balances WHERE tenant_user_id = ? ORDER BY lease_id DESC');
$leases->execute([$userId]);
$leases = $leases->fetchAll();

$invoices = $pdo->prepare(
    'SELECT s.*, p.name AS property_name, u.unit_number
     FROM v_invoice_summary s
     JOIN leases     l ON l.lease_id    = s.lease_id
     JOIN tenants    t ON t.tenant_id   = l.tenant_id
     JOIN units      u ON u.unit_id     = l.unit_id
     JOIN properties p ON p.property_id = u.property_id
     WHERE t.user_id = ?
     ORDER BY s.billing_month DESC'
);
$invoices->execute([$userId]);
$invoices = $invoices->fetchAll();

$statement = $pdo->prepare('SELECT * FROM v_tenant_statement WHERE tenant_user_id = ? ORDER BY lease_id, entry_date, ledger_id');
$statement->execute([$userId]);
$statement = $statement->fetchAll();

// ---- Summary numbers ----
$balanceOwed = array_sum(array_column($leases, 'balance'));
$totalPaid   = array_sum(array_column($leases, 'total_paid'));
$overdueAmount = 0;
foreach ($invoices as $inv) {
    if ($inv['balance_remaining'] > 0 && $inv['due_date'] < $today) {
        $overdueAmount += $inv['balance_remaining'];
    }
}

// Works out the label for an invoice from today's date and what has been paid.
// (More reliable than the stored status column, which only changes when a procedure runs.)
function invoice_label(array $inv, string $today): array
{
    if ($inv['balance_remaining'] <= 0) {
        return ['Paid', 'paid'];
    }
    if ($inv['due_date'] < $today) {
        return ['Overdue', 'overdue'];
    }
    if ($inv['amount_paid'] > 0) {
        return ['Part paid', 'partial'];
    }
    return ['Unpaid', 'unpaid'];
}

$pageTitle = 'My account';
require __DIR__ . '/header.php';
?>

<h1>My account</h1>

<?php if (count($leases) === 0): ?>
    <div class="empty">You do not have a lease on record yet. Please contact your landlord.</div>
<?php else: ?>

<div class="cards">
    <div class="card <?= $balanceOwed > 0 ? 'alert' : '' ?>">
        <div class="label">Balance owed</div>
        <div class="value"><?= money($balanceOwed) ?></div>
    </div>
    <div class="card <?= $overdueAmount > 0 ? 'alert' : '' ?>">
        <div class="label">Overdue</div>
        <div class="value"><?= money($overdueAmount) ?></div>
    </div>
    <div class="card">
        <div class="label">Total paid</div>
        <div class="value"><?= money($totalPaid) ?></div>
    </div>
</div>

<h2>My lease</h2>
<div class="table-wrap">
<table>
    <tr>
        <th>Property</th><th>Unit</th><th>Lease</th>
        <th class="num">Charged</th><th class="num">Paid</th><th class="num">Balance</th>
    </tr>
    <?php foreach ($leases as $row): ?>
    <tr>
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

<h2>My invoices</h2>
<div class="table-wrap">
<table>
    <tr>
        <th>Month</th><th>Unit</th><th>Due date</th>
        <th class="num">Total due</th><th class="num">Paid</th><th class="num">Remaining</th><th>Status</th>
    </tr>
    <?php foreach ($invoices as $inv): ?>
        <?php [$label, $class] = invoice_label($inv, $today); ?>
    <tr>
        <td><?= e(date('F Y', strtotime($inv['billing_month']))) ?></td>
        <td><?= e($inv['unit_number']) ?></td>
        <td><?= e($inv['due_date']) ?></td>
        <td class="num"><?= money($inv['total_due']) ?></td>
        <td class="num"><?= money($inv['amount_paid']) ?></td>
        <td class="num"><?= money($inv['balance_remaining']) ?></td>
        <td><span class="badge <?= e($class) ?>"><?= e($label) ?></span></td>
    </tr>
    <?php endforeach; ?>
</table>
</div>

<h2>Statement</h2>
<div class="table-wrap">
<table>
    <tr>
        <th>Date</th><th>Description</th>
        <th class="num">Charged</th><th class="num">Paid</th><th class="num">Balance</th>
    </tr>
    <?php foreach ($statement as $line): ?>
    <tr>
        <td><?= e($line['entry_date']) ?></td>
        <td><?= e((string) $line['description']) ?></td>
        <td class="num"><?= $line['debit'] > 0 ? money($line['debit']) : '' ?></td>
        <td class="num"><?= $line['credit'] > 0 ? money($line['credit']) : '' ?></td>
        <td class="num"><?= money($line['running_balance']) ?></td>
    </tr>
    <?php endforeach; ?>
</table>
</div>

<?php endif; ?>

<?php require __DIR__ . '/footer.php'; ?>
