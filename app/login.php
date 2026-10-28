<?php
require __DIR__ . '/auth.php';
require __DIR__ . '/db.php';

// Already logged in? Skip the form.
if (isset($_SESSION['user_id'])) {
    redirect_to_dashboard();
}

$error = '';

// The form was submitted
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';

    // Prepared statement: the username is sent separately from the query (stops SQL injection)
    $stmt = $pdo->prepare('SELECT user_id, username, password_hash, role FROM users WHERE username = ?');
    $stmt->execute([$username]);
    $user = $stmt->fetch();

    // password_verify hashes what was typed and compares it with the stored hash
    if ($user && password_verify($password, $user['password_hash'])) {
        session_regenerate_id(true);   // new session ID after login (stops session fixation)
        $_SESSION['user_id']  = (int) $user['user_id'];
        $_SESSION['username'] = $user['username'];
        $_SESSION['role']     = $user['role'];
        redirect_to_dashboard();
    }

    // Same message whether the username or the password was wrong, so attackers learn nothing
    $error = 'Invalid username or password.';
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>RentTrack - Login</title>
    <style>
        body { font-family: sans-serif; background: #f2f4f7; display: flex; justify-content: center; padding-top: 80px; }
        form { background: #fff; padding: 30px; border-radius: 8px; width: 300px; box-shadow: 0 2px 8px rgba(0,0,0,.1); }
        h1 { margin-top: 0; font-size: 1.4em; }
        label { display: block; margin-top: 12px; }
        input { width: 100%; padding: 8px; margin-top: 4px; box-sizing: border-box; }
        button { margin-top: 18px; width: 100%; padding: 10px; cursor: pointer; }
        .error { color: #b00020; margin-top: 12px; }
    </style>
</head>
<body>
    <form method="post" action="login.php">
        <h1>RentTrack Login</h1>
        <?php if ($error !== ''): ?>
            <div class="error"><?= e($error) ?></div>
        <?php endif; ?>
        <label>Username
            <input type="text" name="username" value="<?= e($_POST['username'] ?? '') ?>" required autofocus>
        </label>
        <label>Password
            <input type="password" name="password" required>
        </label>
        <button type="submit">Log in</button>
    </form>
</body>
</html>
