<?php
header('Content-Type: application/json');
// Додаємо мітку часу, щоб перевірити чи дані з кешу
echo json_encode([
    "status" => "success",
    "timestamp" => microtime(true),
    "received_data" => json_decode(file_get_contents('php://input'), true)
]);
?>

