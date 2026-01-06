<?php
header('Content-Type: application/json');

$headers = getallheaders();

echo json_encode([
    "timestamp" => microtime(true),
    "uri" => $_SERVER['REQUEST_URI'],
   // "received_headers" => $headers,
    "raw_post" => file_get_contents('php://input')
], JSON_PRETTY_PRINT);

?>

