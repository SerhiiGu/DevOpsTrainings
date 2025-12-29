<?php
header('Content-Type: application/json');

$headers = getallheaders();

echo json_encode([
    "message" => "PHP got request",
    "received_headers" => $headers,
    "raw_post" => file_get_contents('php://input')
], JSON_PRETTY_PRINT);
?>

