<?php
header('Content-Type: application/json');

// Get inputs
$uri = $_SERVER['REQUEST_URI'];
$raw_post = file_get_contents('php://input');
$data = json_decode($raw_post, true);

// Default logic: App Response is 200 (Cache Allowed)
$app_response_code = 200;

// Test logic: Allow client to force a bad response via JSON body for testing purposes
if (isset($data['force_error_code']) && $data['force_error_code'] == true) {
    $app_response_code = 400; // Simulate error
}
if (isset($data['simulate_missing_header']) && $data['simulate_missing_header'] == true) {
    $app_response_code = null; // Simulate missing header
}

// Set the MANDATORY header for Nginx caching logic
if ($app_response_code !== null) {
    header("x-mobile-app-http-response-code: $app_response_code");
}

$response = [
    "timestamp" => microtime(true),
    "uri" => $uri,
    "generated_app_code" => $app_response_code,
    "input" => $data
];

// Determine logic based on URI
if ($uri === '/') {
    $response['page'] = 'home';
} elseif (strpos($uri, '/product/') === 0) {
    $response['page'] = 'product_detail';
    $response['product_id'] = str_replace('/product/', '', $uri);
} elseif ($uri === '/about') {
    $response['page'] = 'about';
} else {
    $response['page'] = 'unknown';
}

echo json_encode($response, JSON_PRETTY_PRINT);
?>
