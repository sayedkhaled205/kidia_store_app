<?php
/** Central WooCommerce store data workspace. */
defined( 'ABSPATH' ) || exit;

$store_tabs = array(
	'products'        => array( __( 'Products', 'kidia-mobile-cms' ), 'dashicons-products' ),
	'categories'      => array( __( 'Categories', 'kidia-mobile-cms' ), 'dashicons-category' ),
	'discounts'       => array( __( 'Discounts', 'kidia-mobile-cms' ), 'dashicons-tickets-alt' ),
	'customers'       => array( __( 'Customers', 'kidia-mobile-cms' ), 'dashicons-groups' ),
	'orders'          => array( __( 'Orders', 'kidia-mobile-cms' ), 'dashicons-cart' ),
	'reports'         => array( __( 'Reports', 'kidia-mobile-cms' ), 'dashicons-chart-bar' ),
	'analytics'       => array( __( 'Analytics', 'kidia-mobile-cms' ), 'dashicons-chart-line' ),
	'abandoned-carts' => array( __( 'Abandoned Carts', 'kidia-mobile-cms' ), 'dashicons-cart' ),
);
$manage_urls = array(
	'products'        => admin_url( 'edit.php?post_type=product' ),
	'categories'      => admin_url( 'edit-tags.php?taxonomy=product_cat&post_type=product' ),
	'discounts'       => admin_url( 'edit.php?post_type=shop_coupon' ),
	'customers'       => admin_url( 'users.php?role=customer' ),
	'orders'          => admin_url( 'edit.php?post_type=shop_order' ),
	'reports'         => admin_url( 'admin.php?page=wc-reports' ),
	'analytics'       => admin_url( 'admin.php?page=wc-admin&path=/analytics/overview' ),
	'abandoned-carts' => add_query_arg( array( 'page' => 'kidia-mobile-store-data', 'store_tab' => 'abandoned-carts' ), admin_url( 'admin.php' ) ),
);
$tab_url = static function ( string $tab, ?string $source = null ) use ( $store_tab, $store_source, $date_preset, $date_from, $date_to ): string {
	$target_preset = $tab === $store_tab ? $date_preset : ( 'customers' === $tab ? 'all_time' : 'last_30_days' );
	return add_query_arg(
		array(
			'page'         => 'kidia-mobile-store-data',
			'store_tab'    => $tab,
			'store_source' => null === $source ? $store_source : $source,
			'date_preset'  => $target_preset,
			'date_from'    => 'custom' === $target_preset ? wp_date( 'Y-m-d', $date_from ) : false,
			'date_to'      => 'custom' === $target_preset ? wp_date( 'Y-m-d', $date_to ) : false,
		),
		admin_url( 'admin.php' )
	);
};
$source_tabs = array( 'customers', 'orders', 'reports', 'analytics', 'abandoned-carts' );
$dated_tabs  = array( 'customers', 'orders', 'reports', 'analytics', 'abandoned-carts' );
$source_labels = array(
	'all'     => __( 'All', 'kidia-mobile-cms' ),
	'website' => __( 'Website', 'kidia-mobile-cms' ),
	'mobile'  => __( 'Mobile App', 'kidia-mobile-cms' ),
);
$date_labels = array(
	'all_time'       => __( 'All time', 'kidia-mobile-cms' ),
	'today'          => __( 'Today', 'kidia-mobile-cms' ),
	'yesterday'      => __( 'Yesterday', 'kidia-mobile-cms' ),
	'last_7_days'    => __( 'Last 7 days', 'kidia-mobile-cms' ),
	'last_30_days'   => __( 'Last 30 days', 'kidia-mobile-cms' ),
	'this_month'     => __( 'This month', 'kidia-mobile-cms' ),
	'previous_month' => __( 'Previous month', 'kidia-mobile-cms' ),
	'custom'         => __( 'Custom', 'kidia-mobile-cms' ),
);
$money = static fn( float $amount ): string => function_exists( 'wc_price' ) ? wc_price( $amount ) : number_format_i18n( $amount, 2 );
$event = static fn( string $name ): array => $analytics['events'][ $name ] ?? array( 'count' => 0, 'unique' => 0, 'value' => 0.0 );
$rate = static fn( float $part, float $whole ): float => $whole > 0 ? round( 100 * $part / $whole, 1 ) : 0.0;
$change = static function ( float $current, float $previous ): array {
	if ( 0.0 === $previous ) {
		return array( $current > 0 ? 100.0 : 0.0, $current > 0 ? 'up' : 'flat' );
	}
	$value = round( 100 * ( $current - $previous ) / $previous, 1 );
	return array( $value, $value > 0 ? 'up' : ( $value < 0 ? 'down' : 'flat' ) );
};
$analytics_signups = $event( 'sign_up' );
$analytics_registration_starts = $event( 'registration_started' );
$analytics_views = $event( 'view_item' );
$analytics_cart = $event( 'add_to_cart' );
$analytics_checkout = $event( 'begin_checkout' );
$analytics_purchase = $event( 'purchase' );
$previous_event = static fn( string $name ): array => $analytics_previous['events'][ $name ] ?? array( 'count' => 0, 'unique' => 0, 'value' => 0.0 );
$purchases_by_product = array();
foreach ( $analytics['top_purchases'] as $purchase_row ) {
	$purchases_by_product[ absint( $purchase_row['object_id'] ) ] = absint( $purchase_row['event_count'] );
}
$high_interest_products = array_values(
	array_filter(
		$analytics['top_products'],
		static fn( $product_row ) => absint( $product_row['event_count'] ) >= 3
			&& absint( $purchases_by_product[ absint( $product_row['object_id'] ) ] ?? 0 ) < max( 1, round( absint( $product_row['event_count'] ) * 0.05 ) )
	)
);
$is_abandoned_page = 'abandoned-carts' === $store_tab;
$category_image = static function ( WP_Term $category ): string {
	$image_id = absint( get_term_meta( $category->term_id, 'thumbnail_id', true ) );
	$image    = $image_id > 0 ? wp_get_attachment_image( $image_id, 'thumbnail', false, array( 'loading' => 'lazy' ) ) : '';
	if ( '' !== $image ) {
		return $image;
	}
	$placeholder = function_exists( 'wc_placeholder_img_src' ) ? wc_placeholder_img_src( 'thumbnail' ) : '';
	return '' !== $placeholder
		? '<img src="' . esc_url( $placeholder ) . '" alt="" loading="lazy">'
		: '<span class="dashicons dashicons-category"></span>';
};
?>
<div class="wrap kidia-data-page">
	<header class="kidia-data-hero">
		<div><span class="dashicons <?php echo $is_abandoned_page ? 'dashicons-cart' : 'dashicons-database'; ?>"></span><div><h1><?php echo esc_html( $is_abandoned_page ? __( 'Abandoned Carts', 'kidia-mobile-cms' ) : __( 'Store Data', 'kidia-mobile-cms' ) ); ?></h1><p><?php echo esc_html( $is_abandoned_page ? __( 'Recover purchase intent from website and mobile carts before it is lost.', 'kidia-mobile-cms' ) : __( 'Live commerce data from your website and mobile app, organised for clear sales decisions.', 'kidia-mobile-cms' ) ); ?></p></div></div>
		<?php if ( ! $is_abandoned_page ) : ?><a class="button button-primary" href="<?php echo esc_url( $manage_urls[ $store_tab ] ); ?>"><?php esc_html_e( 'Open full manager', 'kidia-mobile-cms' ); ?></a><?php endif; ?>
	</header>

	<?php if ( ! $is_abandoned_page ) : ?><nav class="kidia-data-tabs">
		<?php foreach ( $store_tabs as $key => $item ) : if ( 'abandoned-carts' === $key ) { continue; } ?>
			<a class="<?php echo $key === $store_tab ? 'is-active' : ''; ?>" href="<?php echo esc_url( $tab_url( $key ) ); ?>">
				<span class="dashicons <?php echo esc_attr( $item[1] ); ?>"></span><span><?php echo esc_html( $item[0] ); ?></span>
				<?php if ( isset( $counts[ $key ] ) ) : ?><b><?php echo esc_html( (string) $counts[ $key ] ); ?></b><?php endif; ?>
			</a>
		<?php endforeach; ?>
	</nav><?php endif; ?>

	<section class="kidia-data-panel kidia-data-panel--<?php echo esc_attr( $store_tab ); ?>">
		<div class="kidia-data-panel__head">
			<div>
				<h2><?php echo esc_html( $store_tabs[ $store_tab ][0] ); ?></h2>
				<?php if ( in_array( $store_tab, $source_tabs, true ) ) : ?>
					<nav class="kidia-source-filter" aria-label="<?php esc_attr_e( 'Data source', 'kidia-mobile-cms' ); ?>">
						<?php foreach ( $source_labels as $key => $label ) : ?><a class="<?php echo $key === $store_source ? 'is-active' : ''; ?>" href="<?php echo esc_url( $tab_url( $store_tab, $key ) ); ?>"><?php echo esc_html( $label ); ?></a><?php endforeach; ?>
					</nav>
				<?php endif; ?>
			</div>
			<?php if ( ! $is_abandoned_page ) : ?><a class="button button-primary" href="<?php echo esc_url( $manage_urls[ $store_tab ] ); ?>"><span class="dashicons dashicons-edit"></span><?php esc_html_e( 'Manage', 'kidia-mobile-cms' ); ?></a><?php endif; ?>
		</div>

		<?php if ( in_array( $store_tab, $dated_tabs, true ) ) : ?>
			<form class="kidia-date-filter" method="get">
				<input type="hidden" name="page" value="kidia-mobile-store-data">
				<input type="hidden" name="store_tab" value="<?php echo esc_attr( $store_tab ); ?>">
				<input type="hidden" name="store_source" value="<?php echo esc_attr( $store_source ); ?>">
				<label><span><?php esc_html_e( 'Period', 'kidia-mobile-cms' ); ?></span><select name="date_preset"><?php foreach ( $date_labels as $key => $label ) : ?><option value="<?php echo esc_attr( $key ); ?>" <?php selected( $date_preset, $key ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
				<label><span><?php esc_html_e( 'From', 'kidia-mobile-cms' ); ?></span><input type="date" name="date_from" value="<?php echo esc_attr( wp_date( 'Y-m-d', $date_from ) ); ?>"></label>
				<label><span><?php esc_html_e( 'To', 'kidia-mobile-cms' ); ?></span><input type="date" name="date_to" value="<?php echo esc_attr( wp_date( 'Y-m-d', $date_to ) ); ?>"></label>
				<button class="button button-primary" type="submit"><?php esc_html_e( 'Apply', 'kidia-mobile-cms' ); ?></button>
				<p><?php echo esc_html( wp_date( get_option( 'date_format' ), $date_from ) . ' – ' . wp_date( get_option( 'date_format' ), $date_to ) ); ?></p>
			</form>
		<?php endif; ?>

		<?php if ( 'products' === $store_tab ) : ?>
			<form class="kidia-product-search" method="get">
				<input type="hidden" name="page" value="kidia-mobile-store-data">
				<input type="hidden" name="store_tab" value="products">
				<label for="kidia-product-search"><?php esc_html_e( 'Search products', 'kidia-mobile-cms' ); ?></label>
				<input id="kidia-product-search" type="search" name="product_search" value="<?php echo esc_attr( $product_search ); ?>" placeholder="<?php esc_attr_e( 'Search by product name or exact SKU', 'kidia-mobile-cms' ); ?>">
				<button class="button button-primary" type="submit"><?php esc_html_e( 'Search', 'kidia-mobile-cms' ); ?></button>
				<?php if ( '' !== $product_search ) : ?><a class="button" href="<?php echo esc_url( $tab_url( 'products' ) ); ?>"><?php esc_html_e( 'Clear', 'kidia-mobile-cms' ); ?></a><?php endif; ?>
				<span><?php echo esc_html( sprintf( _n( '%d product', '%d products', $product_total, 'kidia-mobile-cms' ), $product_total ) ); ?></span>
			</form>
			<div class="kidia-data-table-wrap"><table class="kidia-data-table"><thead><tr><th><?php esc_html_e( 'Product', 'kidia-mobile-cms' ); ?></th><th><?php esc_html_e( 'SKU', 'kidia-mobile-cms' ); ?></th><th><?php esc_html_e( 'Stock', 'kidia-mobile-cms' ); ?></th><th><?php esc_html_e( 'Price', 'kidia-mobile-cms' ); ?></th><th><?php esc_html_e( 'Status', 'kidia-mobile-cms' ); ?></th><th><?php esc_html_e( 'Actions', 'kidia-mobile-cms' ); ?></th></tr></thead><tbody>
				<?php foreach ( $products as $product ) : $link = get_permalink( $product->get_id() ); $hide_mobile = Kidia_Mobile_Product_Channel_Visibility::is_hidden( $product->get_id(), 'mobile' ); $hide_website = Kidia_Mobile_Product_Channel_Visibility::is_hidden( $product->get_id(), 'website' ); ?><tr><td><div class="kidia-data-identity"><?php echo wp_kses_post( $product->get_image( 'thumbnail', array( 'loading' => 'lazy' ) ) ); ?><span><strong><?php echo esc_html( $product->get_name() ); ?></strong><small class="kidia-product-channel-state"><?php if ( $hide_mobile ) : ?><b><span class="dashicons dashicons-hidden"></span><?php esc_html_e( 'Hidden from mobile', 'kidia-mobile-cms' ); ?></b><?php endif; ?><?php if ( $hide_website ) : ?><b><span class="dashicons dashicons-hidden"></span><?php esc_html_e( 'Hidden from website', 'kidia-mobile-cms' ); ?></b><?php endif; ?></small></span></div></td><td><code><?php echo esc_html( $product->get_sku() ?: '—' ); ?></code></td><td><?php echo esc_html( wc_get_stock_html( $product ) ? wp_strip_all_tags( wc_get_stock_html( $product ) ) : __( 'Not managed', 'kidia-mobile-cms' ) ); ?></td><td><?php echo wp_kses_post( $product->get_price_html() ); ?></td><td><span class="kidia-status"><?php echo esc_html( ucfirst( $product->get_status() ) ); ?></span></td><td><div class="kidia-row-actions kidia-product-actions"><a href="<?php echo esc_url( get_edit_post_link( $product->get_id() ) ); ?>"><?php esc_html_e( 'Edit', 'kidia-mobile-cms' ); ?></a><a href="<?php echo esc_url( $link ); ?>" target="_blank" rel="noopener"><?php esc_html_e( 'View', 'kidia-mobile-cms' ); ?></a><button type="button" data-copy-link="<?php echo esc_attr( $link ); ?>"><?php esc_html_e( 'Copy link', 'kidia-mobile-cms' ); ?></button><form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>"><?php wp_nonce_field( 'kidia_mobile_toggle_product_channel' ); ?><input type="hidden" name="action" value="kidia_mobile_toggle_product_channel"><input type="hidden" name="product_id" value="<?php echo esc_attr( (string) $product->get_id() ); ?>"><input type="hidden" name="channel" value="mobile"><input type="hidden" name="hidden" value="<?php echo $hide_mobile ? '0' : '1'; ?>"><button type="submit"><?php echo esc_html( $hide_mobile ? __( 'Show on mobile', 'kidia-mobile-cms' ) : __( 'Hide from mobile', 'kidia-mobile-cms' ) ); ?></button></form><form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>"><?php wp_nonce_field( 'kidia_mobile_toggle_product_channel' ); ?><input type="hidden" name="action" value="kidia_mobile_toggle_product_channel"><input type="hidden" name="product_id" value="<?php echo esc_attr( (string) $product->get_id() ); ?>"><input type="hidden" name="channel" value="website"><input type="hidden" name="hidden" value="<?php echo $hide_website ? '0' : '1'; ?>"><button type="submit"><?php echo esc_html( $hide_website ? __( 'Show on website', 'kidia-mobile-cms' ) : __( 'Hide from website', 'kidia-mobile-cms' ) ); ?></button></form></div></td></tr><?php endforeach; ?>
			</tbody></table></div>
			<?php if ( $product_pages > 1 ) : ?><nav class="kidia-data-pagination"><?php echo wp_kses_post( paginate_links( array( 'base' => add_query_arg( 'product_page', '%#%' ), 'format' => '', 'current' => $product_page, 'total' => $product_pages ) ) ); ?></nav><?php endif; ?>

		<?php elseif ( 'categories' === $store_tab ) : ?>
			<div class="kidia-category-section"><h3><?php esc_html_e( 'Main categories', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'Top-level categories are kept separate from their subcategories.', 'kidia-mobile-cms' ); ?></p><div class="kidia-category-list">
				<?php foreach ( $parent_categories as $category ) : $category_link = get_term_link( $category ); ?><article><div class="kidia-category-thumb"><?php echo wp_kses_post( $category_image( $category ) ); ?></div><div><strong><?php echo esc_html( $category->name ); ?></strong><small><?php echo esc_html( sprintf( _n( '%d product', '%d products', $category->count, 'kidia-mobile-cms' ), $category->count ) ); ?></small><div class="kidia-row-actions"><a href="<?php echo esc_url( get_edit_term_link( $category->term_id, 'product_cat' ) ); ?>"><?php esc_html_e( 'Edit', 'kidia-mobile-cms' ); ?></a><?php if ( ! is_wp_error( $category_link ) ) : ?><button type="button" data-copy-link="<?php echo esc_attr( $category_link ); ?>"><?php esc_html_e( 'Copy link', 'kidia-mobile-cms' ); ?></button><?php endif; ?></div></div></article><?php endforeach; ?>
			</div></div>
			<div class="kidia-category-section is-subcategories"><h3><?php esc_html_e( 'Subcategories', 'kidia-mobile-cms' ); ?></h3>
				<?php foreach ( $parent_categories as $parent ) : $children = $subcategory_groups[ $parent->term_id ] ?? array(); if ( empty( $children ) ) { continue; } ?><section><h4><?php echo esc_html( $parent->name ); ?><b><?php echo esc_html( (string) count( $children ) ); ?></b></h4><div class="kidia-category-list"><?php foreach ( $children as $category ) : $category_link = get_term_link( $category ); ?><article><div class="kidia-category-thumb"><?php echo wp_kses_post( $category_image( $category ) ); ?></div><div><strong><?php echo esc_html( $category->name ); ?></strong><small><?php echo esc_html( sprintf( _n( '%d product', '%d products', $category->count, 'kidia-mobile-cms' ), $category->count ) ); ?></small><div class="kidia-row-actions"><a href="<?php echo esc_url( get_edit_term_link( $category->term_id, 'product_cat' ) ); ?>"><?php esc_html_e( 'Edit', 'kidia-mobile-cms' ); ?></a><?php if ( ! is_wp_error( $category_link ) ) : ?><button type="button" data-copy-link="<?php echo esc_attr( $category_link ); ?>"><?php esc_html_e( 'Copy link', 'kidia-mobile-cms' ); ?></button><?php endif; ?></div></div></article><?php endforeach; ?></div></section><?php endforeach; ?>
			</div>

		<?php elseif ( 'discounts' === $store_tab ) : ?>
			<div class="kidia-coupon-list"><?php foreach ( $coupons as $coupon_post ) : $coupon = class_exists( 'WC_Coupon' ) ? new WC_Coupon( $coupon_post->ID ) : null; ?><article><span class="dashicons dashicons-tickets-alt"></span><code><?php echo esc_html( $coupon_post->post_title ); ?></code><strong><?php echo esc_html( $coupon ? $coupon->get_amount() . ( 'percent' === $coupon->get_discount_type() ? '%' : ' ' . get_woocommerce_currency() ) : '' ); ?></strong><small><?php echo esc_html( $coupon && $coupon->get_date_expires() ? $coupon->get_date_expires()->date_i18n( get_option( 'date_format' ) ) : __( 'No expiry', 'kidia-mobile-cms' ) ); ?></small><div class="kidia-row-actions"><a href="<?php echo esc_url( get_edit_post_link( $coupon_post->ID ) ); ?>"><?php esc_html_e( 'Edit', 'kidia-mobile-cms' ); ?></a><button type="button" data-copy-text="<?php echo esc_attr( $coupon_post->post_title ); ?>"><?php esc_html_e( 'Copy code', 'kidia-mobile-cms' ); ?></button></div></article><?php endforeach; ?></div>

		<?php elseif ( 'customers' === $store_tab ) : ?>
			<div class="kidia-data-summary"><div><small><?php esc_html_e( 'Customers in period', 'kidia-mobile-cms' ); ?></small><b><?php echo esc_html( (string) $customer_total ); ?></b></div><div><small><?php esc_html_e( 'Page', 'kidia-mobile-cms' ); ?></small><b><?php echo esc_html( $customer_page . ' / ' . $customer_pages ); ?></b></div></div>
			<div class="kidia-customer-list"><?php foreach ( $customers as $customer ) : $sources = Kidia_Mobile_Analytics::customer_sources( $customer->ID ); $customer_orders = absint( get_user_meta( $customer->ID, '_order_count', true ) ); $customer_spent = (float) get_user_meta( $customer->ID, '_money_spent', true ); ?><article><?php echo get_avatar( $customer->ID, 48 ); ?><div><strong><?php echo esc_html( $customer->display_name ); ?></strong><small><?php echo esc_html( $customer->user_email ); ?></small><span class="kidia-source-badges"><?php if ( $sources['website'] ) : ?><b class="is-website"><span class="dashicons dashicons-desktop"></span><?php esc_html_e( 'Website', 'kidia-mobile-cms' ); ?></b><?php endif; ?><?php if ( $sources['mobile'] ) : ?><b class="is-mobile"><span class="dashicons dashicons-smartphone"></span><?php esc_html_e( 'Mobile', 'kidia-mobile-cms' ); ?></b><?php endif; ?></span></div><div><b><?php echo esc_html( (string) $customer_orders ); ?></b><small><?php esc_html_e( 'Orders', 'kidia-mobile-cms' ); ?></small></div><div><b><?php echo wp_kses_post( $money( $customer_spent ) ); ?></b><small><?php esc_html_e( 'Total spent', 'kidia-mobile-cms' ); ?></small></div><a class="button" href="<?php echo esc_url( get_edit_user_link( $customer->ID ) ); ?>"><?php esc_html_e( 'Profile', 'kidia-mobile-cms' ); ?></a></article><?php endforeach; ?></div>
			<?php if ( $customer_pages > 1 ) : ?><nav class="kidia-data-pagination"><?php echo wp_kses_post( paginate_links( array( 'base' => add_query_arg( 'customer_page', '%#%' ), 'format' => '', 'current' => $customer_page, 'total' => $customer_pages ) ) ); ?></nav><?php endif; ?>

		<?php elseif ( 'orders' === $store_tab ) : ?>
			<div class="kidia-data-summary"><div><small><?php esc_html_e( 'Orders in period', 'kidia-mobile-cms' ); ?></small><b><?php echo esc_html( (string) count( $orders ) ); ?></b></div><div><small><?php esc_html_e( 'Revenue in period', 'kidia-mobile-cms' ); ?></small><b><?php echo wp_kses_post( $money( $order_revenue ) ); ?></b></div></div>
			<div class="kidia-order-list"><?php foreach ( $orders as $order ) : $source = 'mobile' === $order->get_meta( '_kidia_order_source' ) ? 'mobile' : 'website'; ?><article><div class="kidia-order-number"><span>#<?php echo esc_html( (string) $order->get_id() ); ?></span><small class="kidia-source-badge is-<?php echo esc_attr( $source ); ?>"><?php echo esc_html( $source_labels[ $source ] ); ?></small></div><div><strong><?php echo esc_html( $order->get_formatted_billing_full_name() ?: __( 'Guest', 'kidia-mobile-cms' ) ); ?></strong><small><?php echo esc_html( $order->get_billing_email() ); ?></small></div><div><strong><?php echo wp_kses_post( $order->get_formatted_order_total() ); ?></strong><small><?php echo esc_html( $order->get_date_created() ? $order->get_date_created()->date_i18n( get_option( 'date_format' ) ) : '' ); ?></small></div><span class="kidia-status is-<?php echo esc_attr( $order->get_status() ); ?>"><?php echo esc_html( wc_get_order_status_name( $order->get_status() ) ); ?></span><a class="button" href="<?php echo esc_url( method_exists( $order, 'get_edit_order_url' ) ? $order->get_edit_order_url() : '#' ); ?>"><?php esc_html_e( 'Open', 'kidia-mobile-cms' ); ?></a></article><?php endforeach; ?></div>

		<?php elseif ( 'reports' === $store_tab ) : ?>
			<div class="kidia-data-summary is-four"><div><small><?php esc_html_e( 'Orders', 'kidia-mobile-cms' ); ?></small><b><?php echo esc_html( (string) count( $orders ) ); ?></b></div><div><small><?php esc_html_e( 'Paid revenue', 'kidia-mobile-cms' ); ?></small><b><?php echo wp_kses_post( $money( $order_revenue ) ); ?></b></div><div><small><?php esc_html_e( 'Average paid order', 'kidia-mobile-cms' ); ?></small><b><?php echo wp_kses_post( $money( $paid_order_count ? $order_revenue / $paid_order_count : 0 ) ); ?></b></div><div><small><?php esc_html_e( 'Units sold', 'kidia-mobile-cms' ); ?></small><b><?php echo esc_html( (string) $order_units ); ?></b></div></div>
			<div class="kidia-report-grid">
				<section><header><h3><?php esc_html_e( 'Order status', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'See where fulfilment or cancellations affect sales.', 'kidia-mobile-cms' ); ?></p></header><div class="kidia-metric-list"><?php foreach ( $order_statuses as $status => $status_count ) : ?><div><span><?php echo esc_html( wc_get_order_status_name( $status ) ); ?></span><b><?php echo esc_html( (string) $status_count ); ?></b><i style="--kidia-progress:<?php echo esc_attr( count( $orders ) ? (string) round( 100 * $status_count / count( $orders ) ) : '0' ); ?>%"></i></div><?php endforeach; ?></div></section>
				<section><header><h3><?php esc_html_e( 'Best-selling products', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'Prioritise products producing revenue in the selected source and period.', 'kidia-mobile-cms' ); ?></p></header><div class="kidia-ranked-list"><?php $rank = 0; foreach ( $product_performance as $product_id => $product_row ) : ++$rank; ?><div><b><?php echo esc_html( (string) $rank ); ?></b><span><strong><?php echo esc_html( $product_row['name'] ); ?></strong><small><?php echo esc_html( sprintf( __( '%d units', 'kidia-mobile-cms' ), $product_row['units'] ) ); ?></small></span><em><?php echo wp_kses_post( $money( $product_row['revenue'] ) ); ?></em></div><?php endforeach; ?></div></section>
			</div>

		<?php elseif ( 'analytics' === $store_tab ) : ?>
			<?php
			$visitor_change = $change( (float) $analytics['visitors'], (float) $analytics_previous['visitors'] );
			$signup_change = $change( (float) $analytics_signups['count'], (float) $previous_event( 'sign_up' )['count'] );
			$purchase_change = $change( (float) $analytics_purchase['count'], (float) $previous_event( 'purchase' )['count'] );
			$revenue_change = $change( (float) $analytics_purchase['value'], (float) $previous_event( 'purchase' )['value'] );
			?>
			<div class="kidia-data-summary is-four kidia-analytics-kpis">
				<div><small><?php esc_html_e( 'Visitors', 'kidia-mobile-cms' ); ?></small><b><?php echo esc_html( (string) $analytics['visitors'] ); ?></b><span class="is-<?php echo esc_attr( $visitor_change[1] ); ?>"><?php echo esc_html( $visitor_change[0] . '%' ); ?> <?php esc_html_e( 'vs previous period', 'kidia-mobile-cms' ); ?></span></div>
				<div><small><?php esc_html_e( 'Completed registrations', 'kidia-mobile-cms' ); ?></small><b><?php echo esc_html( (string) $analytics_signups['count'] ); ?></b><span class="is-<?php echo esc_attr( $signup_change[1] ); ?>"><?php echo esc_html( $signup_change[0] . '%' ); ?> <?php esc_html_e( 'vs previous period', 'kidia-mobile-cms' ); ?></span></div>
				<div><small><?php esc_html_e( 'Purchases', 'kidia-mobile-cms' ); ?></small><b><?php echo esc_html( (string) $analytics_purchase['count'] ); ?></b><span class="is-<?php echo esc_attr( $purchase_change[1] ); ?>"><?php echo esc_html( $purchase_change[0] . '%' ); ?> <?php esc_html_e( 'vs previous period', 'kidia-mobile-cms' ); ?></span></div>
				<div><small><?php esc_html_e( 'Tracked revenue', 'kidia-mobile-cms' ); ?></small><b><?php echo wp_kses_post( $money( (float) $analytics_purchase['value'] ) ); ?></b><span class="is-<?php echo esc_attr( $revenue_change[1] ); ?>"><?php echo esc_html( $revenue_change[0] . '%' ); ?> <?php esc_html_e( 'vs previous period', 'kidia-mobile-cms' ); ?></span></div>
			</div>
			<div class="kidia-audience-strip"><div><small><?php esc_html_e( 'New users', 'kidia-mobile-cms' ); ?></small><b><?php echo esc_html( (string) $analytics['new_users'] ); ?></b></div><div><small><?php esc_html_e( 'Returning users', 'kidia-mobile-cms' ); ?></small><b><?php echo esc_html( (string) $analytics['returning_users'] ); ?></b></div><div><small><?php esc_html_e( 'Logins', 'kidia-mobile-cms' ); ?></small><b><?php echo esc_html( (string) $event( 'login' )['count'] ); ?></b></div><div><small><?php esc_html_e( 'Searches', 'kidia-mobile-cms' ); ?></small><b><?php echo esc_html( (string) $event( 'search' )['count'] ); ?></b></div><div><small><?php esc_html_e( 'Average order', 'kidia-mobile-cms' ); ?></small><b><?php echo wp_kses_post( $money( $analytics_purchase['count'] ? (float) $analytics_purchase['value'] / $analytics_purchase['count'] : 0 ) ); ?></b></div></div>
			<div class="kidia-analytics-grid">
				<section class="kidia-funnel"><header><h3><?php esc_html_e( 'Sales funnel', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'Find the step where customers leave before buying.', 'kidia-mobile-cms' ); ?></p></header><?php
				$funnel = array(
					array( 'mobile' === $store_source ? __( 'Opened app', 'kidia-mobile-cms' ) : __( 'Visited store', 'kidia-mobile-cms' ), $analytics['visitors'], 100 ),
					array( __( 'Viewed product', 'kidia-mobile-cms' ), $analytics_views['unique'], $rate( $analytics_views['unique'], $analytics['visitors'] ) ),
					array( __( 'Added to cart', 'kidia-mobile-cms' ), $analytics_cart['unique'], $rate( $analytics_cart['unique'], $analytics['visitors'] ) ),
					array( __( 'Started checkout', 'kidia-mobile-cms' ), $analytics_checkout['unique'], $rate( $analytics_checkout['unique'], $analytics['visitors'] ) ),
					array( __( 'Purchased', 'kidia-mobile-cms' ), $analytics_purchase['unique'], $rate( $analytics_purchase['unique'], $analytics['visitors'] ) ),
				);
				foreach ( $funnel as $stage ) : ?><div><span><strong><?php echo esc_html( $stage[0] ); ?></strong><small><?php echo esc_html( (string) $stage[1] ); ?></small></span><i><b style="width:<?php echo esc_attr( (string) min( 100, $stage[2] ) ); ?>%"></b></i><em><?php echo esc_html( $stage[2] . '%' ); ?></em></div><?php endforeach; ?></section>
				<section><header><h3><?php esc_html_e( 'Registration funnel', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'Measure how many people finish creating an account.', 'kidia-mobile-cms' ); ?></p></header><div class="kidia-decision-card"><strong><?php echo esc_html( $rate( $analytics_signups['count'], $analytics_registration_starts['count'] ) . '%' ); ?></strong><span><?php esc_html_e( 'registration completion', 'kidia-mobile-cms' ); ?></span><small><?php echo esc_html( sprintf( __( '%1$d completed from %2$d starts', 'kidia-mobile-cms' ), $analytics_signups['count'], $analytics_registration_starts['count'] ) ); ?></small></div><div class="kidia-decision-card"><strong><?php echo esc_html( $rate( $analytics_purchase['unique'], $analytics['visitors'] ) . '%' ); ?></strong><span><?php esc_html_e( 'visitor-to-purchase conversion', 'kidia-mobile-cms' ); ?></span></div></section>
				<section><header><h3><?php esc_html_e( 'Top viewed products', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'Products getting attention in the selected channel.', 'kidia-mobile-cms' ); ?></p></header><div class="kidia-ranked-list"><?php $rank = 0; foreach ( $analytics['top_products'] as $row ) : ++$rank; ?><div><b><?php echo esc_html( (string) $rank ); ?></b><span><strong><?php echo esc_html( $row['event_label'] ); ?></strong><small><?php echo esc_html( sprintf( __( '%d unique viewers', 'kidia-mobile-cms' ), $row['unique_clients'] ) ); ?></small></span><em><?php echo esc_html( (string) $row['event_count'] ); ?></em></div><?php endforeach; ?></div></section>
				<section><header><h3><?php esc_html_e( 'Top searches', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'Use demand that customers explicitly typed.', 'kidia-mobile-cms' ); ?></p></header><div class="kidia-ranked-list"><?php $rank = 0; foreach ( $analytics['top_searches'] as $row ) : ++$rank; ?><div><b><?php echo esc_html( (string) $rank ); ?></b><span><strong><?php echo esc_html( $row['event_label'] ); ?></strong><small><?php echo esc_html( sprintf( __( '%d people', 'kidia-mobile-cms' ), $row['unique_clients'] ) ); ?></small></span><em><?php echo esc_html( (string) $row['event_count'] ); ?></em></div><?php endforeach; ?></div></section>
				<section><header><h3><?php esc_html_e( 'Category demand', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'Categories attracting the most attention in the selected channel.', 'kidia-mobile-cms' ); ?></p></header><div class="kidia-ranked-list"><?php $rank = 0; foreach ( $analytics['top_categories'] as $row ) : ++$rank; ?><div><b><?php echo esc_html( (string) $rank ); ?></b><span><strong><?php echo esc_html( $row['event_label'] ); ?></strong><small><?php echo esc_html( sprintf( __( '%d unique viewers', 'kidia-mobile-cms' ), $row['unique_clients'] ) ); ?></small></span><em><?php echo esc_html( (string) $row['event_count'] ); ?></em></div><?php endforeach; ?></div></section>
				<section><header><h3><?php esc_html_e( 'Activity & actions', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'Understand intent and the best times to launch offers.', 'kidia-mobile-cms' ); ?></p></header><div class="kidia-metric-list"><div><span><?php esc_html_e( 'Product views', 'kidia-mobile-cms' ); ?></span><b><?php echo esc_html( (string) $analytics_views['count'] ); ?></b></div><div><span><?php esc_html_e( 'Category views', 'kidia-mobile-cms' ); ?></span><b><?php echo esc_html( (string) $event( 'view_category' )['count'] ); ?></b></div><div><span><?php esc_html_e( 'Added to cart', 'kidia-mobile-cms' ); ?></span><b><?php echo esc_html( (string) $analytics_cart['count'] ); ?></b></div><div><span><?php esc_html_e( 'Removed from cart', 'kidia-mobile-cms' ); ?></span><b><?php echo esc_html( (string) $event( 'remove_from_cart' )['count'] ); ?></b></div></div><?php if ( ! empty( $analytics['activity_hours'] ) ) : ?><div class="kidia-activity-hours"><strong><?php esc_html_e( 'Busiest hours', 'kidia-mobile-cms' ); ?></strong><?php foreach ( $analytics['activity_hours'] as $hour ) : ?><span><?php echo esc_html( wp_date( get_option( 'time_format' ), mktime( (int) $hour['hour'], 0 ) ) ); ?><b><?php echo esc_html( (string) $hour['event_count'] ); ?></b></span><?php endforeach; ?></div><?php endif; ?></section>
			</div>
			<div class="kidia-opportunities"><h3><?php esc_html_e( 'Sales opportunities', 'kidia-mobile-cms' ); ?></h3><div>
				<?php if ( $analytics_views['unique'] > 0 && $rate( $analytics_cart['unique'], $analytics_views['unique'] ) < 15 ) : ?><article><span class="dashicons dashicons-lightbulb"></span><div><strong><?php esc_html_e( 'Improve product-to-cart conversion', 'kidia-mobile-cms' ); ?></strong><p><?php echo esc_html( sprintf( __( 'Only %s of product viewers added an item. Review price, photos and the add-to-cart offer on highly viewed products.', 'kidia-mobile-cms' ), $rate( $analytics_cart['unique'], $analytics_views['unique'] ) . '%' ) ); ?></p></div></article><?php endif; ?>
				<?php if ( $analytics_checkout['unique'] > $analytics_purchase['unique'] ) : ?><article><span class="dashicons dashicons-cart"></span><div><strong><?php esc_html_e( 'Recover checkout drop-off', 'kidia-mobile-cms' ); ?></strong><p><?php echo esc_html( sprintf( __( '%d shoppers started checkout without a tracked purchase. Check delivery cost, payment methods and abandoned carts.', 'kidia-mobile-cms' ), $analytics_checkout['unique'] - $analytics_purchase['unique'] ) ); ?></p></div></article><?php endif; ?>
				<?php if ( ! empty( $high_interest_products ) ) : ?><article><span class="dashicons dashicons-visibility"></span><div><strong><?php esc_html_e( 'High interest, low purchase', 'kidia-mobile-cms' ); ?></strong><p><?php echo esc_html( sprintf( __( '%s receives views but few tracked purchases. Review stock, price and product-page clarity.', 'kidia-mobile-cms' ), $high_interest_products[0]['event_label'] ) ); ?></p></div></article><?php endif; ?>
				<?php if ( 0 === $analytics['visitors'] ) : ?><article><span class="dashicons dashicons-info-outline"></span><div><strong><?php esc_html_e( 'Tracking is ready', 'kidia-mobile-cms' ); ?></strong><p><?php esc_html_e( 'Metrics will appear after customers use the selected sales channel. No placeholder values are shown.', 'kidia-mobile-cms' ); ?></p></div></article><?php endif; ?>
			</div></div>

		<?php elseif ( 'abandoned-carts' === $store_tab ) : ?>
			<div class="kidia-data-summary is-four"><div><small><?php esc_html_e( 'Carts in view', 'kidia-mobile-cms' ); ?></small><b><?php echo esc_html( (string) count( $abandoned_carts ) ); ?></b></div><div><small><?php esc_html_e( 'Abandoned', 'kidia-mobile-cms' ); ?></small><b><?php echo esc_html( (string) count( array_filter( $abandoned_carts, static fn( $cart ) => 'abandoned' === $cart['status'] ) ) ); ?></b></div><div><small><?php esc_html_e( 'Recovered / converted', 'kidia-mobile-cms' ); ?></small><b><?php echo esc_html( (string) count( array_filter( $abandoned_carts, static fn( $cart ) => in_array( $cart['status'], array( 'recovered', 'converted' ), true ) ) ) ); ?></b></div><div><small><?php esc_html_e( 'Potential value', 'kidia-mobile-cms' ); ?></small><b><?php echo wp_kses_post( $money( array_sum( array_map( static fn( $cart ) => 'abandoned' === $cart['status'] ? (float) $cart['cart_total'] : 0.0, $abandoned_carts ) ) ) ); ?></b></div></div>
			<div class="kidia-data-table-wrap"><table class="kidia-data-table kidia-abandoned-table"><thead><tr><th><?php esc_html_e( 'Customer', 'kidia-mobile-cms' ); ?></th><th><?php esc_html_e( 'Items', 'kidia-mobile-cms' ); ?></th><th><?php esc_html_e( 'Value', 'kidia-mobile-cms' ); ?></th><th><?php esc_html_e( 'Source', 'kidia-mobile-cms' ); ?></th><th><?php esc_html_e( 'Last activity', 'kidia-mobile-cms' ); ?></th><th><?php esc_html_e( 'Status', 'kidia-mobile-cms' ); ?></th></tr></thead><tbody><?php foreach ( $abandoned_carts as $cart ) : ?><tr><td><strong><?php echo esc_html( $cart['customer_name'] ?: __( 'Guest', 'kidia-mobile-cms' ) ); ?></strong><small><?php echo esc_html( $cart['customer_email'] ); ?></small></td><td><strong><?php echo esc_html( (string) $cart['item_count'] ); ?></strong><small><?php echo esc_html( implode( ', ', array_slice( array_filter( array_column( $cart['items'], 'name' ) ), 0, 3 ) ) ); ?></small></td><td><?php echo wp_kses_post( $money( (float) $cart['cart_total'] ) ); ?></td><td><span class="kidia-source-badge is-<?php echo esc_attr( $cart['source'] ); ?>"><?php echo esc_html( $source_labels[ $cart['source'] ] ?? ucfirst( $cart['source'] ) ); ?></span></td><td><?php echo esc_html( get_date_from_gmt( $cart['last_activity_at'], get_option( 'date_format' ) . ' ' . get_option( 'time_format' ) ) ); ?><small><?php echo esc_html( human_time_diff( strtotime( $cart['last_activity_at'] . ' UTC' ), time() ) . ' ' . __( 'ago', 'kidia-mobile-cms' ) ); ?></small></td><td><span class="kidia-status is-<?php echo esc_attr( $cart['status'] ); ?>"><?php echo esc_html( ucfirst( $cart['status'] ) ); ?></span><?php if ( ! empty( $cart['order_id'] ) ) : ?><small>#<?php echo esc_html( (string) $cart['order_id'] ); ?></small><?php endif; ?></td></tr><?php endforeach; ?></tbody></table></div>

		<?php endif; ?>
	</section>
</div>
