<?php
header('Content-Type: application/json');

// Get URI to determine the test case
$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$status_msg = "";

/**
 * Switching logic based on URI
 * All cases work only via POST as per Nginx config
 */
switch ($uri) {
    case '/cache1':
        // Case 1: Backend allows caching
        header('X-Allow-Cache: yes');
        $status_msg = "Cache ALLOWED (yes)";
        break;

    case '/testcase2':
        // Case 2: Backend explicitly forbids caching
        header('X-Allow-Cache: no');
        $status_msg = "Cache FORBIDDEN (no)";
        break;

    case '/noheader':
        // Case 3: No header sent at all
        $status_msg = "No header sent (Default bypass)";
        break;

    default:
        // Default case
        $status_msg = "Default URI - no cache header";
        break;
}

// Read JSON POST body
$raw_post = file_get_contents('php://input');
$json_data = json_decode($raw_post, true);

echo json_encode([
    "timestamp" => microtime(true),
    "uri"       => $uri,
    "status"    => $status_msg,
    "payload"   => $json_data
], JSON_PRETTY_PRINT);

?>
