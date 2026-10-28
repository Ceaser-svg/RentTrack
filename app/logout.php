<?php
require __DIR__ . '/auth.php';

$_SESSION = [];     // forget everything stored for this visitor
session_destroy();  // end the session

header('Location: login.php');
exit;
