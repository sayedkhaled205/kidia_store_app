<?php
define('ABSPATH', __DIR__);
final class MobiShop_Store_Notifications {
    public static array $value = ['store_id' => '6990b322-e396-46bb-a188-a1e472b6bf64', 'token' => ''];
    public static function connection(): array { return self::$value; }
}
function wp_json_encode($value) { return json_encode($value); }
function is_wp_error($value) { return $value instanceof Throwable; }
function wp_remote_request($url, $args) { $GLOBALS['calls'][] = [$url, $args]; return array_shift($GLOBALS['responses']); }
function wp_remote_retrieve_response_code($response) { return $response['status']; }
function wp_remote_retrieve_body($response) { return $response['body']; }
require __DIR__.'/../connector/class-customer-identity-client.php';
$checks = 0;
function verify($condition, $name) { global $checks; if (!$condition) throw new RuntimeException($name); $checks++; }
function rejected($call) { try { $call(); } catch (RuntimeException) { return true; } return false; }
$GLOBALS['calls'] = [];
verify(rejected(fn() => MobiShop_Customer_Identity_Client::capabilities()), 'Missing connection must stay closed');
verify($GLOBALS['calls'] === [], 'No unauthenticated HTTP');
MobiShop_Store_Notifications::$value['token'] = str_repeat('a', 80);
$GLOBALS['responses'] = [['status' => 200, 'body' => '{"ok":true,"available":true,"project_id":"synthetic-auth-project"}']];
verify(MobiShop_Customer_Identity_Client::capabilities()['available'], 'Configured capability');
verify($GLOBALS['calls'][0][1]['redirection'] === 0, 'No credential redirects');
verify($GLOBALS['calls'][0][1]['limit_response_size'] === 8192, 'Bounded HTTP body');
$GLOBALS['responses'] = [['status' => 200, 'body' => '{"ok":true,"status":"present","created_at":"12345"}']];
verify(MobiShop_Customer_Identity_Client::lookup('synthetic-auth-project', 'uid/path?x') === ['status' => 'present', 'created_at' => '12345'], 'Minimal validated lookup');
[$url, $args] = end($GLOBALS['calls']);
verify(!str_contains($url, 'uid/path'), 'UID never in URL');
verify(json_decode($args['body'], true) === ['project_id' => 'synthetic-auth-project', 'uid' => 'uid/path?x'], 'Exact JSON identity');
foreach ([['status' => 503, 'body' => '{}'], ['status' => 200, 'body' => '{"ok":true}'], ['status' => 200, 'body' => '{"ok":false,"status":"absent"}'], ['status' => 200, 'body' => '{"ok":true,"status":"pending"}'], ['status' => 200, 'body' => '{"ok":true,"status":"present","created_at":"12345"}']] as $response) {
    $GLOBALS['responses'] = [$response];
    verify(rejected(fn() => MobiShop_Customer_Identity_Client::erase('synthetic-auth-project', 'uid', '12345')), 'Ambiguous erasure must not complete');
}
$GLOBALS['responses'] = [['status' => 200, 'body' => '{"ok":true,"status":"absent"}']];
verify(MobiShop_Customer_Identity_Client::erase('synthetic-auth-project', 'uid', '12345') === ['status' => 'absent'], 'Confirmed absence accepted');
echo $checks.' connector identity transport checks passed.'.PHP_EOL;
