<?php
require __DIR__ . '/auth.php';

if (isset($_SESSION['user_id'])) {
    redirect_to_dashboard();
}

header('Location: login.php');
exit;
