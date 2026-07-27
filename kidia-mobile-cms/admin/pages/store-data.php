<?php
/** Central WooCommerce store data workspace. */
defined( 'ABSPATH' ) || exit;
$store_tabs = array(
	'products' => array( __( 'Products', 'kidia-mobile-cms' ), 'dashicons-products' ),
	'categories' => array( __( 'Categories', 'kidia-mobile-cms' ), 'dashicons-category' ),
	'discounts' => array( __( 'Discounts', 'kidia-mobile-cms' ), 'dashicons-tickets-alt' ),
	'customers' => array( __( 'Customers', 'kidia-mobile-cms' ), 'dashicons-groups' ),
	'orders' => array( __( 'Orders', 'kidia-mobile-cms' ), 'dashicons-cart' ),
	'reports' => array( __( 'Reports', 'kidia-mobile-cms' ), 'dashicons-chart-bar' ),
	'analytics' => array( __( 'Analytics', 'kidia-mobile-cms' ), 'dashicons-chart-line' ),
	'settings' => array( __( 'Settings', 'kidia-mobile-cms' ), 'dashicons-admin-generic' ),
);
$manage_urls = array(
	'products' => admin_url( 'edit.php?post_type=product' ),
	'categories' => admin_url( 'edit-tags.php?taxonomy=product_cat&post_type=product' ),
	'discounts' => admin_url( 'edit.php?post_type=shop_coupon' ),
	'customers' => admin_url( 'users.php?role=customer' ),
	'orders' => admin_url( 'edit.php?post_type=shop_order' ),
	'reports' => admin_url( 'admin.php?page=wc-reports' ),
	'analytics' => admin_url( 'admin.php?page=wc-admin&path=/analytics/overview' ),
	'settings' => admin_url( 'admin.php?page=wc-settings' ),
);
?>
<div class="wrap kidia-data-page">
	<header class="kidia-data-hero">
		<div><span class="dashicons dashicons-database"></span><div><h1><?php esc_html_e( 'Store Data', 'kidia-mobile-cms' ); ?></h1><p><?php esc_html_e( 'Manage the live WooCommerce data used by your website and mobile application.', 'kidia-mobile-cms' ); ?></p></div></div>
		<a class="button button-primary" href="<?php echo esc_url( $manage_urls[ $store_tab ] ); ?>"><?php esc_html_e( 'Open full manager', 'kidia-mobile-cms' ); ?></a>
	</header>
	<nav class="kidia-data-tabs">
		<?php foreach ( $store_tabs as $key => $item ) : ?><a class="<?php echo $key === $store_tab ? 'is-active' : ''; ?>" href="<?php echo esc_url( add_query_arg( array( 'page' => 'kidia-mobile-store-data', 'store_tab' => $key ), admin_url( 'admin.php' ) ) ); ?>"><span class="dashicons <?php echo esc_attr( $item[1] ); ?>"></span><?php echo esc_html( $item[0] ); ?><?php if ( isset( $counts[ $key ] ) ) : ?><b><?php echo esc_html( (string) $counts[ $key ] ); ?></b><?php endif; ?></a><?php endforeach; ?>
	</nav>
	<section class="kidia-data-panel">
		<div class="kidia-data-panel__head"><h2><?php echo esc_html( $store_tabs[ $store_tab ][0] ); ?></h2><a class="button button-primary" href="<?php echo esc_url( $manage_urls[ $store_tab ] ); ?>"><span class="dashicons dashicons-edit"></span><?php esc_html_e( 'Manage', 'kidia-mobile-cms' ); ?></a></div>
		<div class="kidia-data-grid">
			<?php if ( 'products' === $store_tab ) : foreach ( $products as $product ) : ?>
				<a class="kidia-data-tile" href="<?php echo esc_url( get_edit_post_link( $product->get_id() ) ); ?>"><span class="dashicons dashicons-products"></span><strong><?php echo esc_html( $product->get_name() ); ?></strong><em><?php echo wp_kses_post( $product->get_price_html() ); ?></em><small><?php echo esc_html( ucfirst( $product->get_status() ) ); ?></small></a>
			<?php endforeach; elseif ( 'categories' === $store_tab && ! is_wp_error( $categories ) ) : foreach ( $categories as $category ) : ?>
				<a class="kidia-data-tile" href="<?php echo esc_url( get_edit_term_link( $category->term_id, 'product_cat' ) ); ?>"><span class="dashicons dashicons-category"></span><strong><?php echo esc_html( $category->name ); ?></strong><em><?php echo esc_html( sprintf( _n( '%d product', '%d products', $category->count, 'kidia-mobile-cms' ), $category->count ) ); ?></em></a>
			<?php endforeach; elseif ( 'discounts' === $store_tab ) : foreach ( $coupons as $coupon ) : ?>
				<a class="kidia-data-tile" href="<?php echo esc_url( get_edit_post_link( $coupon->ID ) ); ?>"><span class="dashicons dashicons-tickets-alt"></span><strong><?php echo esc_html( $coupon->post_title ); ?></strong><em><?php echo esc_html( ucfirst( $coupon->post_status ) ); ?></em></a>
			<?php endforeach; elseif ( 'customers' === $store_tab ) : foreach ( $customers as $customer ) : ?>
				<a class="kidia-data-tile" href="<?php echo esc_url( get_edit_user_link( $customer->ID ) ); ?>"><span class="dashicons dashicons-admin-users"></span><strong><?php echo esc_html( $customer->display_name ); ?></strong><em><?php echo esc_html( $customer->user_email ); ?></em></a>
			<?php endforeach; elseif ( 'orders' === $store_tab ) : foreach ( $orders as $order ) : ?>
				<a class="kidia-data-tile" href="<?php echo esc_url( method_exists( $order, 'get_edit_order_url' ) ? $order->get_edit_order_url() : '#' ); ?>"><span class="dashicons dashicons-cart"></span><strong>#<?php echo esc_html( (string) $order->get_id() ); ?> · <?php echo esc_html( $order->get_formatted_billing_full_name() ); ?></strong><em><?php echo wp_kses_post( $order->get_formatted_order_total() ); ?></em><small><?php echo esc_html( wc_get_order_status_name( $order->get_status() ) ); ?></small></a>
			<?php endforeach; else : ?>
				<?php foreach ( array( 'reports' => array( 'Sales reports', 'Taxes and stock', 'Customer reports' ), 'analytics' => array( 'Revenue', 'Orders', 'Products performance' ), 'settings' => array( 'General store settings', 'Payments and shipping', 'Emails and advanced settings' ) )[ $store_tab ] ?? array() as $label ) : ?><a class="kidia-data-tile" href="<?php echo esc_url( $manage_urls[ $store_tab ] ); ?>"><span class="dashicons <?php echo esc_attr( $store_tabs[ $store_tab ][1] ); ?>"></span><strong><?php echo esc_html( $label ); ?></strong><em><?php esc_html_e( 'Open WooCommerce', 'kidia-mobile-cms' ); ?></em></a><?php endforeach; ?>
			<?php endif; ?>
		</div>
		<?php if ( ! in_array( $store_tab, array( 'reports', 'analytics', 'settings' ), true ) && ! count( $store_tab === 'products' ? $products : ( $store_tab === 'orders' ? $orders : ( $store_tab === 'customers' ? $customers : ( $store_tab === 'discounts' ? $coupons : ( is_wp_error( $categories ) ? array() : $categories ) ) ) ) ) ) : ?><div class="kidia-data-empty"><span class="dashicons dashicons-plus-alt2"></span><strong><?php esc_html_e( 'No items yet', 'kidia-mobile-cms' ); ?></strong><a class="button button-primary" href="<?php echo esc_url( $manage_urls[ $store_tab ] ); ?>"><?php esc_html_e( 'Create the first item', 'kidia-mobile-cms' ); ?></a></div><?php endif; ?>
	</section>
</div>
