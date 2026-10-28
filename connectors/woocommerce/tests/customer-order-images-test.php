<?php
require __DIR__ . '/customer-orders-endpoint-contract-test.php';

function wc_get_product( $id ) { return $GLOBALS['image_parent'] ?? false; }
function wp_get_attachment_image_url( $id, $size ) {
    mobishop_orders_assert( $size === 'woocommerce_thumbnail', 'Use a bounded catalog thumbnail.' );
    return $id === 99 ? false : "https://store.example/images/$id.jpg";
}
function esc_url_raw( $url, $protocols = null ) { return $url; }
class ImageTestProduct {
    public function __construct( private int $id ) {}
    public function get_image_id() { return $this->id; }
}
class ImageTestItem {
    public function __construct( private $product ) {}
    public function get_product() { return $this->product; }
    public function get_product_id() { return 10; }
}
$method = new ReflectionMethod( MobiShop_Customer_Orders_Endpoint::class, 'item_image_url' );
$GLOBALS['image_parent'] = new ImageTestProduct( 20 );
mobishop_orders_assert( $method->invoke( $endpoint, new ImageTestItem( new ImageTestProduct( 30 ) ) ) === 'https://store.example/images/30.jpg', 'Variation image takes precedence.' );
mobishop_orders_assert( $method->invoke( $endpoint, new ImageTestItem( new ImageTestProduct( 0 ) ) ) === 'https://store.example/images/20.jpg', 'Variation without a photo uses its parent.' );
mobishop_orders_assert( $method->invoke( $endpoint, new ImageTestItem( false ) ) === 'https://store.example/images/20.jpg', 'Deleted variation can still show parent image.' );
$GLOBALS['image_parent'] = false;
mobishop_orders_assert( $method->invoke( $endpoint, new ImageTestItem( false ) ) === '', 'Deleted product keeps order readable.' );
mobishop_orders_assert( $method->invoke( $endpoint, new ImageTestItem( new ImageTestProduct( 99 ) ) ) === '', 'Missing attachment keeps order readable.' );
mobishop_orders_assert( $method->invoke( $endpoint, new stdClass() ) === '', 'Legacy item stays readable.' );
echo "CUSTOMER_ORDER_IMAGES_OK 6 cases\n";
