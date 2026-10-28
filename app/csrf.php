<?php
// CSRF protection: stops another website from submitting a form on the user's behalf.
// Add a hidden input named "csrf" holding the value of csrf_token() to every form,
// and check csrf_valid() before acting on a POST request.
// Needs auth.php to be loaded first (it starts the session).

function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf'];
}

function csrf_valid(): bool
{
    return isset($_POST['csrf'], $_SESSION['csrf'])
        && hash_equals($_SESSION['csrf'], (string) $_POST['csrf']);
}
