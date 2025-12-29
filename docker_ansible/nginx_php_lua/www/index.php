<?php
header('Content-Type: application/json');

// Отримуємо всі заголовки
$headers = getallheaders();

echo json_encode([
    "message" => "PHP отримав запит",
    "received_headers" => $headers,
    "raw_post" => file_get_contents('php://input')
], JSON_PRETTY_PRINT);
?>

