<?php
header('Content-Type: application/json');

$headers = getallheaders();

echo json_encode([
    "message" => "PHP got request from index.php",
    "timestamp" => microtime(true),
    "received_headers" => $headers,
    "raw_post" => file_get_contents('php://input')
], JSON_PRETTY_PRINT);

?>

