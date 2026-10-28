<?php
require __DIR__ . '/auth.php';
require_login('landlord');
require __DIR__ . '/db.php';
require __DIR__ . '/csrf.php';

$landlordId = $_SESSION['user_id'];

$methods = [
    'cash'          => 'Cash',
    'mobile_money'  => 'Mobile money',
    'bank_transfer' => 'Bank transfer',
];

$error = '';
$input = [
    'lease_id'     => '',
    'amount'       => '',
    'payment_date' => date('Y-m-d'),
    'method'       => 'mobile_money',
    'reference'    => '',
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Keep what was typed so the form is not wiped if there is an error
    foreach ($input as $key => $default) {
        $input[$key] = trim((string) ($_POST[$key] ?? ''));
    }

    $leaseId = filter_var($input['lease_id'], FILTER_VALIDATE_INT);
    $amount  = filter_var($input['amount'], FILTER_VALIDATE_FLOAT);
    $date    = DateTime::createFromFormat('Y-m-d', $input['payment_date']);
    $dateOk  = $date && $date->format('Y-m-d') === $input['payment_date']
               && $input['payment_date'] <= date('Y-m-d');

    // 1. Validate the form (the database checks again, but friendly messages come first)
    if (!csrf_valid()) {
        $error = 'Your session expired. Please try again.';
    } elseif ($leaseId === false) {
        $error = 'Choose a tenant.';
    } elseif ($amount === false || $amount <= 0) {
        $error = 'Enter an amount greater than zero.';
    } elseif (!$dateOk) {
        $error = 'Enter a valid payment date (today or earlier).';
    } elseif (!isset($methods[$input['method']])) {
        $error = 'Choose a payment method.';
    } elseif (strlen($input['reference']) > 100) {
        $error = 'The reference is too long (100 characters at most).';
    } else {
        // 2. Authorization: the lease must belong to THIS landlord.
        // Without this check, a landlord could edit the form and pay into someone else's lease.
        $check = $pdo->prepare('SELECT COUNT(*) FROM v_lease_balances WHERE lease_id = ? AND landlord_id = ?');
        $check->execute([$leaseId, $landlordId]);
        if ((int) $check->fetchColumn() === 0) {
            http_response_code(403);
            exit('Access denied.');
        }

        // 3. Call the stored procedure. It does everything in one transaction.
        try {
            $stmt = $pdo->prepare('CALL sp_record_payment(?, ?, ?, ?, ?, ?, @payment_id)');
            $stmt->execute([
                $leaseId,
                round($amount, 2),
                $input['payment_date'],
                $input['method'],
                $input['reference'] === '' ? null : $input['reference'],
                $landlordId,
            ]);
            $stmt->closeCursor();
            $paymentId = $pdo->query('SELECT @payment_id')->fetchColumn();

            $_SESSION['flash'] = 'Payment of ' . number_format($amount) . ' UGX recorded (payment #' . (int) $paymentId . ').';
            header('Location: landlord_dashboard.php');
            exit;
        } catch (PDOException $e) {
            if ($e->getCode() === '45000') {
                // A rule in the procedure rejected it, e.g. "Payment exceeds the outstanding invoice balance"
                $error = $e->errorInfo[2] ?? 'The payment was rejected.';
            } elseif ($e->getCode() === '23000') {
                $error = 'That reference has already been used for another payment.';
            } else {
                error_log('Record payment failed: ' . $e->getMessage());
                $error = 'Something went wrong. The payment was not recorded.';
            }
        }
    }
}

// Tenants who currently owe something (these are the ones a payment can go to)
$stmt = $pdo->prepare('SELECT lease_id, tenant_name, property_name, unit_number, balance
                       FROM v_lease_balances
                       WHERE landlord_id = ? AND balance > 0
                       ORDER BY tenant_name');
$stmt->execute([$landlordId]);
$leases = $stmt->fetchAll();

$pageTitle = 'Record payment';
require __DIR__ . '/header.php';
?>

<h1>Record a payment</h1>

<?php if ($error !== ''): ?>
    <div class="form-error"><?= e($error) ?></div>
<?php endif; ?>

<?php if (count($leases) === 0): ?>
    <div class="empty">No tenant currently owes anything, so there is nothing to record a payment against.</div>
<?php else: ?>
<form class="form-box" method="post" action="record_payment.php">
    <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">

    <label>Tenant
        <select name="lease_id" required>
            <option value="">Choose a tenant...</option>
            <?php foreach ($leases as $lease): ?>
                <option value="<?= (int) $lease['lease_id'] ?>"
                    <?= (string) $lease['lease_id'] === $input['lease_id'] ? 'selected' : '' ?>>
                    <?= e($lease['tenant_name']) ?> - <?= e($lease['property_name']) ?> <?= e($lease['unit_number']) ?>
                    (owes <?= money($lease['balance']) ?>)
                </option>
            <?php endforeach; ?>
        </select>
    </label>

    <label>Amount (UGX)
        <input type="number" name="amount" min="1" step="any" value="<?= e($input['amount']) ?>" required>
    </label>

    <label>Payment date
        <input type="date" name="payment_date" max="<?= e(date('Y-m-d')) ?>" value="<?= e($input['payment_date']) ?>" required>
    </label>

    <label>Method
        <select name="method">
            <?php foreach ($methods as $value => $label): ?>
                <option value="<?= e($value) ?>" <?= $value === $input['method'] ? 'selected' : '' ?>><?= e($label) ?></option>
            <?php endforeach; ?>
        </select>
    </label>

    <label>Reference <span class="hint">(optional, e.g. mobile money transaction ID)</span>
        <input type="text" name="reference" maxlength="100" value="<?= e($input['reference']) ?>">
    </label>

    <button type="submit">Record payment</button>
</form>
<?php endif; ?>

<?php require __DIR__ . '/footer.php'; ?>
