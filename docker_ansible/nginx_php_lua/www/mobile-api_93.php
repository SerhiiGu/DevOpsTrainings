<?php
// mobile-api_93.php
header('Content-Type: application/json');

// Get request method and URI
$method = $_SERVER['REQUEST_METHOD'];
$uri = $_SERVER['REQUEST_URI'];
$headers = getallheaders();
$raw_post = file_get_contents('php://input');

// Helper to normalize headers keys (nginx might send lowercase)
$headers_normalized = [];
foreach ($headers as $key => $value) {
    $headers_normalized[strtolower($key)] = $value;
}

// Logic switch based on URI
$response_data = [
    "status" => "ok",
    "timestamp" => microtime(true),
    "uri" => $uri,
    "method" => $method,
    "check_header" => isset($headers_normalized['x-mobile-app-http-response-code']) ? $headers_normalized['x-mobile-app-http-response-code'] : 'MISSING'
];

// Add specific data based on URI to verify content
switch (true) {
    case ($uri === '/'):
        $response_data['page'] = 'root';
        break;

    case ($uri === '/lang-list'):
        $response_data['page'] = 'lang-list';
        $response_data['info'] = 'This should be cached statically, ignoring body';
        break;

    case ($uri === '/about'):
        $response_data['page'] = 'about';
        // Parse input to show we received it
        $response_data['received_input'] = json_decode($raw_post, true);
        break;

    case (strpos($uri, '/product/') === 0):
        $response_data['page'] = 'product_detail';
        $response_data['product_id'] = str_replace('/product/', '', $uri);
        $response_data['received_input'] = json_decode($raw_post, true);
        break;

    case ($uri === '/no-cache-zone'):
        $response_data['page'] = 'forbidden';
        $response_data['info'] = 'This URI is not in the allowed list';
        break;

    default:
        $response_data['page'] = 'unknown';
        break;
}

echo json_encode($response_data, JSON_PRETTY_PRINT);
?>
