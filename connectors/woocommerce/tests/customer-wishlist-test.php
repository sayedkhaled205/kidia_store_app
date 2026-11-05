<?php
define('ABSPATH', __DIR__);
class WP_REST_Request {
    public function __construct(public array $body = [], public int $owner = 7) {}
    public function get_json_params() { return $this->body; }
}
class WP_REST_Response {
    public array $headers = [];
    public function __construct(public array $data) {}
    public function header($key, $value) { $this->headers[$key] = $value; }
}
class WP_Error { public function __construct(public $code, public $message, public $data) {} }
class MobiShop_Customer_Auth_Endpoint { public function customer_id_from_request($request) { return $request->owner; } }
function absint($value) { return abs((int)$value); }
function get_current_blog_id() { return 1; }
function wp_cache_delete($id, $group) {}
$GLOBALS['meta'] = [];
function get_user_meta($id, $key, $single) { return $GLOBALS['meta'][$id][$key] ?? []; }
function update_user_meta($id, $key, $value) { $GLOBALS['meta'][$id][$key] = $value; return true; }
class Database {
    public $held = false;
    public $available = true;
    public function prepare($sql, ...$args) { return $sql; }
    public function get_var($sql) { $this->held = $this->available; return $this->available ? '1' : '0'; }
    public function query($sql) { $this->held = false; }
}
$wpdb = new Database();
require dirname(__DIR__) . '/source/api/class-customer-wishlist-endpoint.php';
function verify($value, $label) { if (!$value) throw new Exception($label); echo "PASS $label\n"; }
$endpoint = new MobiShop_Customer_Wishlist_Endpoint();
verify($endpoint->authenticate(new WP_REST_Request([], 0)) instanceof WP_Error, 'missing token rejected');
$endpoint->authenticate(new WP_REST_Request([], 7));
verify($endpoint->mutate(new WP_REST_Request(['add'=>[1,2]]))->data['product_ids'] === [1,2], 'first device saved');
verify($endpoint->mutate(new WP_REST_Request(['add'=>[3]]))->data['product_ids'] === [3,1,2], 'second device preserves saves');
verify($endpoint->mutate(new WP_REST_Request(['remove'=>[2]]))->data['product_ids'] === [3,1], 'delta removes only intended id');
verify(!$wpdb->held, 'lock released');
verify(str_contains($endpoint->read()->headers['Cache-Control'], 'no-store'), 'private response uncached');
$endpoint->authenticate(new WP_REST_Request([], 8));
verify($endpoint->read()->data['product_ids'] === [], 'other account isolated');
verify($endpoint->mutate(new WP_REST_Request(['add'=>['2']])) instanceof WP_Error, 'non integer ids rejected');
$wpdb->available = false;
verify($endpoint->mutate(new WP_REST_Request(['add'=>[9]])) instanceof WP_Error, 'lock failure does not write');
verify($endpoint->read()->data['product_ids'] === [], 'failed write leaves data intact');
