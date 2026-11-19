<?php
// Standalone response contract; no network, customer records or orders.
define( 'ABSPATH', __DIR__ );
$filters = array();
function add_filter( ...$args ) { global $filters; $filters[] = $args; }
class WP_REST_Response {
    public function __construct( private $data, private int $status = 200 ) {}
    public function get_data() { return $this->data; }
    public function set_data( $data ) { $this->data = $data; }
    public function get_status() { return $this->status; }
}
class Shipping_Request {
    public function __construct( private string $route = '/wc/store/v1/cart', private string $channel = 'mobile' ) {}
    public function get_route() { return $this->route; }
    public function get_header( $key ) { return $this->channel; }
}
$root = getenv( 'MOBISHOP_CONNECTOR_TEST_ROOT' ) ?: __DIR__ . '/../source';
$file = $root . '/api/class-store-api-shipping-compatibility.php';
if ( file_exists( $file ) ) { require $file; }
$count = 0;
function scenario( string $name, $cart, bool $changed, int $status = 200, string $route = '/wc/store/v1/cart', string $channel = 'mobile' ) {
    global $count;
    $expected = unserialize( serialize( $cart ) );
    if ( $changed ) {
        if ( is_object( $expected ) ) { $expected->has_calculated_shipping = false; }
        else { $expected['has_calculated_shipping'] = false; }
    }
    $response = new WP_REST_Response( $cart, $status );
    $result = class_exists( 'MobiShop_Store_Api_Shipping_Compatibility' )
        ? MobiShop_Store_Api_Shipping_Compatibility::cart_response( $response, null, new Shipping_Request( $route, $channel ) ) : $response;
    if ( $result !== $response || serialize( $result->get_data() ) !== serialize( $expected ) || $result->get_status() !== $status ) {
        throw new RuntimeException( 'FAIL ' . $name );
    }
    ++$count;
    echo 'PASS ' . $name . PHP_EOL;
}
$initial = array(
    'needs_shipping' => true, 'has_calculated_shipping' => true,
    'shipping_address' => array( 'country' => '', 'state' => '' ),
    'shipping_rates' => array( array( 'package_id' => 0, 'shipping_rates' => array() ) ),
    'totals' => array( 'total_shipping' => '0', 'total_price' => '25000' ),
);
scenario( 'actual guest add-item201 waits for destination', $initial, true, 201, '/wc/store/v1/cart/add-item' );
scenario( 'guest cart refresh200 waits for destination', $initial, true );
scenario( 'customer update response waits for destination', $initial, true, 200, '/wc/store/v1/cart/update-customer' );
$no_packages = $initial; $no_packages['shipping_rates'] = array();
scenario( 'empty package list is pending', $no_packages, true );
$free = $initial;
$free['shipping_rates'][0]['shipping_rates'][] = array( 'rate_id' => 'free_shipping:1', 'price' => '0', 'selected' => true );
scenario( 'genuine selected free rate remains calculated', $free, false );
$paid = $free;
$paid['shipping_address']['country'] = 'EG'; $paid['shipping_address']['state'] = 'EGC';
$paid['shipping_rates'][0]['shipping_rates'][0] = array( 'rate_id' => 'flat_rate:1', 'price' => '5500', 'selected' => true );
$paid['totals']['total_shipping'] = '5500';
scenario( 'valid paid quote remains unchanged', $paid, false );
$unsupported = $initial; $unsupported['shipping_address'] = array( 'country' => 'EG', 'state' => 'unknown' );
scenario( 'destination without methods preserves no-rates message', $unsupported, false );
$virtual = $initial; $virtual['needs_shipping'] = false;
scenario( 'virtual cart is unchanged', $virtual, false );
$pending = $initial; $pending['has_calculated_shipping'] = false;
scenario( 'existing pending state is unchanged', $pending, false );
$two = $free; $two['shipping_rates'][] = $free['shipping_rates'][0];
scenario( 'two fully selected packages remain calculated', $two, false );
$two['shipping_rates'][1]['shipping_rates'] = array();
scenario( 'incomplete destination with missing package quote is pending', $two, true );
$ambiguous = $free; $ambiguous['shipping_rates'][0]['shipping_rates'][] = $free['shipping_rates'][0]['shipping_rates'][0];
scenario( 'ambiguous package selection is pending', $ambiguous, true );
$unselected = $free; $unselected['shipping_rates'][0]['shipping_rates'][0]['selected'] = false;
scenario( 'unselected rates do not prove a quote', $unselected, true );
$invalid = $free; $invalid['shipping_rates'][0]['shipping_rates'][0]['rate_id'] = '';
scenario( 'empty selected rate id is pending', $invalid, true );
scenario( 'stdClass response retains its shape', json_decode( json_encode( $initial ) ), true );
scenario( 'stdClass free shipping remains calculated', json_decode( json_encode( $free ) ), false );
scenario( 'website response is unchanged', $initial, false, 200, '/wc/store/v1/cart', '' );
scenario( 'website channel is unchanged', $initial, false, 200, '/wc/store/v1/cart', 'website' );
scenario( 'checkout response is unchanged', $initial, false, 200, '/wc/store/v1/checkout' );
scenario( 'error response is unchanged', $initial, false, 400 );
scenario( 'cartesian route is unchanged', $initial, false, 200, '/wc/store/v1/cartesian' );
scenario( 'unrelated successful payload is unchanged', array( 'success' => true ), false );
echo "PASS $count shipping response scenarios\n";
