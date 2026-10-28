<?php
// Starts the session and provides helpers for login checks.
// Every page that needs to know who is logged in starts with:
//   require __DIR__ . '/auth.php';

session_set_cookie_params([
    'httponly' => true,    // JavaScript cannot read the session cookie
    'samesite' => 'Lax',   // the cookie is not sent on cross-site POST requests
]);
session_start();

// Sends a logged-in user to the dashboard that matches their role.
function redirect_to_dashboard(): void
{
    $role = $_SESSION['role'] ?? '';
    header('Location: ' . ($role === 'landlord' ? 'landlord_dashboard.php' : 'tenant_dashboard.php'));
    exit;
}

// Call at the top of a protected page.
// require_login()           -> any logged-in user
// require_login('landlord') -> only landlords
function require_login(?string $role = null): void
{
    if (!isset($_SESSION['user_id'])) {
        header('Location: login.php');
        exit;
    }
    if ($role !== null && ($_SESSION['role'] ?? '') !== $role) {
        http_response_code(403);
        exit('Access denied.');
    }
}

// Makes text safe to print inside HTML (prevents XSS).
function e(string $text): string
{
    return htmlspecialchars($text, ENT_QUOTES, 'UTF-8');
}
