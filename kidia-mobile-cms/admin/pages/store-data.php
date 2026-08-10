
<?php
/** Central WooCommerce store data workspace. */
defined( 'ABSPATH' ) || exit;

$store_tabs = array(
	'products'        => array( __( 'Products', 'mobishop' ), 'dashicons-products' ),
	'categories'      => array( __( 'Categories', 'mobishop' ), 'dashicons-category' ),
	'discounts'       => array( __( 'Discounts', 'mobishop' ), 'dashicons-tickets-alt' ),
	'customers'       => array( __( 'Customers', 'mobishop' ), 'dashicons-groups' ),
	'orders'          => array( __( 'Orders', 'mobishop' ), 'dashicons-cart' ),
	'reports'         => array( __( 'Reports', 'mobishop' ), 'dashicons-chart-bar' ),
	'analytics'       => array( __( 'Analytics', 'mobishop' ), 'dashicons-chart-line' ),
	'abandoned-carts' => array( __( 'Abandoned Carts', 'mobishop' ), 'dashicons-cart' ),
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
	$target_preset = $tab === $store_tab
		? $date_preset
		: ( 'abandoned-carts' === $tab
			? 'all_time'
			: ( in_array( $tab, array( 'reports', 'analytics' ), true )
				? 'today'
				: ( 'customers' === $tab ? 'all_time' : 'last_30_days' ) ) );
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
	'all'     => __( 'All', 'mobishop' ),
	'website' => __( 'Website', 'mobishop' ),
	'mobile'  => __( 'Mobile App', 'mobishop' ),
);
$date_labels = array(
	'all_time'       => __( 'All time', 'mobishop' ),
	'today'          => __( 'Today', 'mobishop' ),
	'yesterday'      => __( 'Yesterday', 'mobishop' ),
	'last_7_days'    => __( 'Last 7 days', 'mobishop' ),
	'last_30_days'   => __( 'Last 30 days', 'mobishop' ),
	'this_month'     => __( 'This month', 'mobishop' ),
	'previous_month' => __( 'Last month', 'mobishop' ),
	'last_year'      => __( 'Last year', 'mobishop' ),
	'custom'         => __( 'Custom', 'mobishop' ),
);
$money = static fn( float $amount ): string => function_exists( 'wc_price' ) ? wc_price( $amount ) : number_format_i18n( $amount, 2 );
$coupon_type_labels = function_exists( 'wc_get_coupon_types' ) ? wc_get_coupon_types() : array();
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
$analytics_tracked_purchase = $event( 'purchase' );
$analytics_closed_funnel = array_merge(
	array( 'visitors' => 0, 'viewed_product' => 0, 'added_to_cart' => 0, 'started_checkout' => 0, 'purchased' => 0 ),
	is_array( $analytics['funnel'] ?? null ) ? $analytics['funnel'] : array()
);
$analytics_purchase = array(
	'count'         => absint( $analytics['commerce']['orders'] ?? 0 ),
	'unique'        => absint( $analytics['commerce']['customers'] ?? 0 ),
	'value'         => (float) ( $analytics['commerce']['revenue'] ?? 0 ),
	'average_value' => (float) ( $analytics['commerce']['average_order_value'] ?? 0 ),
);
$previous_event = static fn( string $name ): array => $analytics_previous['events'][ $name ] ?? array( 'count' => 0, 'unique' => 0, 'value' => 0.0 );
$analytics_previous_purchase = array(
	'count'  => absint( $analytics_previous['commerce']['orders'] ?? 0 ),
	'unique' => absint( $analytics_previous['commerce']['customers'] ?? 0 ),
	'value'  => (float) ( $analytics_previous['commerce']['revenue'] ?? 0 ),
);
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
$is_reporting_tab = in_array( $store_tab, array( 'reports', 'analytics' ), true );
$is_abandoned_page = 'abandoned-carts' === $store_tab;
$cart_import_return_url = add_query_arg(
	array(
		'page'          => 'kidia-mobile-cms',
		'view'          => 'store-data',
		'store_tab'     => 'abandoned-carts',
		'store_source'  => $store_source,
		'date_preset'   => $date_preset,
		'date_from'     => 'custom' === $date_preset ? wp_date( 'Y-m-d', $date_from ) : false,
		'date_to'       => 'custom' === $date_preset ? wp_date( 'Y-m-d', $date_to ) : false,
		'cart_view'     => $cart_view,
		'cart_per_page' => $cart_per_page,
		'cart_page'     => $cart_page,
	),
	admin_url( 'admin.php' )
);
$cart_view_url = static function ( string $view, int $page_number = 1 ) use ( $store_source, $date_preset, $date_from, $date_to, $cart_per_page ): string {
	return add_query_arg(
		array(
			'page'          => 'kidia-mobile-store-data',
			'store_tab'     => 'abandoned-carts',
			'store_source'  => $store_source,
			'date_preset'   => $date_preset,
			'date_from'     => 'custom' === $date_preset ? wp_date( 'Y-m-d', $date_from ) : false,
			'date_to'       => 'custom' === $date_preset ? wp_date( 'Y-m-d', $date_to ) : false,
			'cart_view'     => $view,
			'cart_per_page' => $cart_per_page,
			'cart_page'     => max( 1, $page_number ),
		),
		admin_url( 'admin.php' )
	);
};
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
		<div><span class="dashicons <?php echo $is_abandoned_page ? 'dashicons-cart' : 'dashicons-database'; ?>"></span><div><h1><?php echo esc_html( $is_abandoned_page ? __( 'Abandoned Carts', 'mobishop' ) : __( 'Store Data', 'mobishop' ) ); ?></h1><p><?php echo esc_html( $is_abandoned_page ? __( 'Recover purchase intent from website and mobile carts before it is lost.', 'mobishop' ) : __( 'Live commerce data from your website and mobile app, organised for clear sales decisions.', 'mobishop' ) ); ?></p></div></div>
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
					<nav class="kidia-source-filter" aria-label="<?php esc_attr_e( 'Data source', 'mobishop' ); ?>">
						<?php foreach ( $source_labels as $key => $label ) : ?><a class="<?php echo $key === $store_source ? 'is-active' : ''; ?>" href="<?php echo esc_url( $tab_url( $store_tab, $key ) ); ?>"><?php echo esc_html( $label ); ?></a><?php endforeach; ?>
					</nav>
				<?php endif; ?>
			</div>
			<?php if ( $is_abandoned_page ) : $cart_has_results = 'not_started' !== (string) ( $abandoned_import_state['phase'] ?? 'not_started' ); ?>
				<div class="kidia-cart-generate-actions">
					<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
						<input type="hidden" name="action" value="kidia_mobile_start_abandoned_cart_import">
						<input type="hidden" name="cart_import_mode" value="<?php echo esc_attr( $cart_has_results ? 'update' : 'generate' ); ?>">
						<input type="hidden" name="redirect_to" value="<?php echo esc_url( $cart_import_return_url ); ?>">
						<?php wp_nonce_field( 'kidia_mobile_start_abandoned_cart_import', 'kidia_mobile_cart_import_nonce' ); ?>
						<button class="button button-primary" type="submit"><?php echo esc_html( $cart_has_results ? __( 'Update', 'mobishop' ) : __( 'Generate', 'mobishop' ) ); ?></button>
					</form>
					<?php if ( $cart_has_results ) : ?>
						<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
							<input type="hidden" name="action" value="kidia_mobile_start_abandoned_cart_import">
							<input type="hidden" name="cart_import_mode" value="full">
							<input type="hidden" name="redirect_to" value="<?php echo esc_url( $cart_import_return_url ); ?>">
							<?php wp_nonce_field( 'kidia_mobile_start_abandoned_cart_import', 'kidia_mobile_cart_import_nonce' ); ?>
							<button class="button kidia-cart-full-regenerate" type="submit"><?php esc_html_e( 'Full Regenerate', 'mobishop' ); ?></button>
						</form>
					<?php endif; ?>
				</div>
			<?php else : ?>
				<a class="button button-primary" href="<?php echo esc_url( $manage_urls[ $store_tab ] ); ?>"><span class="dashicons dashicons-edit"></span><?php esc_html_e( 'Manage', 'mobishop' ); ?></a>
			<?php endif; ?>
		</div>

		<?php if ( in_array( $store_tab, $dated_tabs, true ) ) : ?>
			<form class="kidia-date-filter" method="get" data-kidia-instant-filter="date" <?php if ( $is_reporting_tab ) : ?>data-kidia-reporting-filter="1" data-kidia-reporting-ready="<?php echo $store_reporting_ready ? '1' : '0'; ?>"<?php endif; ?>>
				<input type="hidden" name="page" value="kidia-mobile-store-data">
				<input type="hidden" name="store_tab" value="<?php echo esc_attr( $store_tab ); ?>">
				<input type="hidden" name="store_source" value="<?php echo esc_attr( $store_source ); ?>">
				<label><span><?php esc_html_e( 'Period', 'mobishop' ); ?></span><select name="date_preset"><?php foreach ( $date_labels as $key => $label ) : ?><option value="<?php echo esc_attr( $key ); ?>" <?php selected( $date_preset, $key ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
				<label><span><?php esc_html_e( 'From', 'mobishop' ); ?></span><input type="date" name="date_from" value="<?php echo esc_attr( wp_date( 'Y-m-d', $date_from ) ); ?>" <?php disabled( 'custom' !== $date_preset ); ?>></label>
				<label><span><?php esc_html_e( 'To', 'mobishop' ); ?></span><input type="date" name="date_to" value="<?php echo esc_attr( wp_date( 'Y-m-d', $date_to ) ); ?>" <?php disabled( 'custom' !== $date_preset ); ?>></label>
				<?php if ( $is_reporting_tab ) : ?><button class="button button-primary kidia-store-generate" type="button" data-kidia-generate-store-reporting><span class="dashicons dashicons-database"></span><?php esc_html_e( 'Generate', 'mobishop' ); ?></button><?php else : ?><button class="button button-primary" type="submit" data-kidia-instant-submit-fallback><?php esc_html_e( 'Apply', 'mobishop' ); ?></button><?php endif; ?>
				<p><?php echo esc_html( wp_date( get_option( 'date_format' ), $date_from ) . ' – ' . wp_date( get_option( 'date_format' ), $date_to ) ); ?></p>
			</form>
		<?php endif; ?>

		<?php if ( 'products' === $store_tab ) : ?>
			<form class="kidia-product-search" method="get" data-kidia-instant-filter="products">
				<input type="hidden" name="page" value="kidia-mobile-store-data">
				<input type="hidden" name="store_tab" value="products">
				<label for="kidia-product-search"><?php esc_html_e( 'Search products', 'mobishop' ); ?></label>
				<input id="kidia-product-search" type="search" name="product_search" value="<?php echo esc_attr( $product_search ); ?>" placeholder="<?php esc_attr_e( 'Search by product name or exact SKU', 'mobishop' ); ?>">
				<label class="screen-reader-text" for="kidia-product-visibility"><?php esc_html_e( 'Channel visibility', 'mobishop' ); ?></label>
				<select id="kidia-product-visibility" name="product_visibility">
					<option value="all" <?php selected( $product_visibility, 'all' ); ?>><?php esc_html_e( 'All products', 'mobishop' ); ?></option>
					<option value="shown" <?php selected( $product_visibility, 'shown' ); ?>><?php esc_html_e( 'Shown everywhere', 'mobishop' ); ?></option>
					<option value="hidden_mobile" <?php selected( $product_visibility, 'hidden_mobile' ); ?>><?php esc_html_e( 'Hidden from mobile', 'mobishop' ); ?></option>
					<option value="hidden_website" <?php selected( $product_visibility, 'hidden_website' ); ?>><?php esc_html_e( 'Hidden from website', 'mobishop' ); ?></option>
					<option value="hidden_both" <?php selected( $product_visibility, 'hidden_both' ); ?>><?php esc_html_e( 'Hidden from both', 'mobishop' ); ?></option>
				</select>
				<button class="button button-primary" type="submit" data-kidia-instant-submit-fallback><?php esc_html_e( 'Search', 'mobishop' ); ?></button>
				<?php if ( '' !== $product_search || 'all' !== $product_visibility ) : ?><a class="button" href="<?php echo esc_url( $tab_url( 'products' ) ); ?>"><?php esc_html_e( 'Clear', 'mobishop' ); ?></a><?php endif; ?>
				<?php /* translators: Placeholder values are supplied at runtime. */ ?>
				<span><?php echo esc_html( sprintf( _n( '%d product', '%d products', $product_total, 'mobishop' ), $product_total ) ); ?></span>
			</form>
			<div class="kidia-data-table-wrap"><table class="kidia-data-table"><thead><tr><th><?php esc_html_e( 'Product', 'mobishop' ); ?></th><th><?php esc_html_e( 'SKU', 'mobishop' ); ?></th><th><?php esc_html_e( 'Stock', 'mobishop' ); ?></th><th><?php esc_html_e( 'Price', 'mobishop' ); ?></th><th><?php esc_html_e( 'Status', 'mobishop' ); ?></th><th><?php esc_html_e( 'Actions', 'mobishop' ); ?></th></tr></thead><tbody>
				<?php foreach ( $products as $product ) : $link = get_permalink( $product->get_id() ); $hide_mobile = Kidia_Mobile_Product_Channel_Visibility::is_hidden( $product->get_id(), 'mobile' ); $hide_website = Kidia_Mobile_Product_Channel_Visibility::is_hidden( $product->get_id(), 'website' ); ?><tr><td><div class="kidia-data-identity"><?php echo wp_kses_post( $product->get_image( 'thumbnail', array( 'loading' => 'lazy' ) ) ); ?><span><strong><?php echo esc_html( $product->get_name() ); ?></strong><small class="kidia-product-channel-state"><?php if ( $hide_mobile ) : ?><b><span class="dashicons dashicons-hidden"></span><?php esc_html_e( 'Hidden from mobile', 'mobishop' ); ?></b><?php endif; ?><?php if ( $hide_website ) : ?><b><span class="dashicons dashicons-hidden"></span><?php esc_html_e( 'Hidden from website', 'mobishop' ); ?></b><?php endif; ?></small></span></div></td><td><code><?php echo esc_html( $product->get_sku() ?: '—' ); ?></code></td><td><?php echo esc_html( wc_get_stock_html( $product ) ? wp_strip_all_tags( wc_get_stock_html( $product ) ) : __( 'Not managed', 'mobishop' ) ); ?></td><td><?php echo wp_kses_post( $product->get_price_html() ); ?></td><td><span class="kidia-status"><?php echo esc_html( ucfirst( $product->get_status() ) ); ?></span></td><td><div class="kidia-row-actions kidia-product-actions"><a href="<?php echo esc_url( get_edit_post_link( $product->get_id() ) ); ?>"><?php esc_html_e( 'Edit', 'mobishop' ); ?></a><a href="<?php echo esc_url( $link ); ?>" target="_blank" rel="noopener"><?php esc_html_e( 'View', 'mobishop' ); ?></a><button type="button" data-copy-link="<?php echo esc_attr( $link ); ?>"><?php esc_html_e( 'Copy link', 'mobishop' ); ?></button><form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" data-kidia-instant-action="product-channel"><?php wp_nonce_field( 'kidia_mobile_toggle_product_channel' ); ?><input type="hidden" name="action" value="kidia_mobile_toggle_product_channel"><input type="hidden" name="product_id" value="<?php echo esc_attr( (string) $product->get_id() ); ?>"><input type="hidden" name="channel" value="mobile"><input type="hidden" name="hidden" value="<?php echo $hide_mobile ? '0' : '1'; ?>"><button type="submit"><?php echo esc_html( $hide_mobile ? __( 'Show on mobile', 'mobishop' ) : __( 'Hide from mobile', 'mobishop' ) ); ?></button></form><form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" data-kidia-instant-action="product-channel"><?php wp_nonce_field( 'kidia_mobile_toggle_product_channel' ); ?><input type="hidden" name="action" value="kidia_mobile_toggle_product_channel"><input type="hidden" name="product_id" value="<?php echo esc_attr( (string) $product->get_id() ); ?>"><input type="hidden" name="channel" value="website"><input type="hidden" name="hidden" value="<?php echo $hide_website ? '0' : '1'; ?>"><button type="submit"><?php echo esc_html( $hide_website ? __( 'Show on website', 'mobishop' ) : __( 'Hide from website', 'mobishop' ) ); ?></button></form></div></td></tr><?php endforeach; ?>
			</tbody></table></div>
			<?php if ( $product_pages > 1 ) : ?><nav class="kidia-data-pagination"><?php echo wp_kses_post( paginate_links( array( 'base' => add_query_arg( 'product_page', '%#%' ), 'format' => '', 'current' => $product_page, 'total' => $product_pages ) ) ); ?></nav><?php endif; ?>

		<?php elseif ( 'categories' === $store_tab ) : ?>
			<div class="kidia-category-section"><h3><?php esc_html_e( 'Main categories', 'mobishop' ); ?></h3><p><?php esc_html_e( 'Top-level categories are kept separate from their subcategories.', 'mobishop' ); ?></p><div class="kidia-category-list">
				<?php /* translators: Placeholder values are supplied at runtime. */ ?>
				<?php foreach ( $parent_categories as $category ) : $category_link = get_term_link( $category ); ?><article><div class="kidia-category-thumb"><?php echo wp_kses_post( $category_image( $category ) ); ?></div><div><strong><?php echo …6253 tokens truncated…tegory demand', 'mobishop' ); ?></h3><p><?php esc_html_e( 'Categories attracting the most attention in the selected channel.', 'mobishop' ); ?></p></header><div class="kidia-ranked-list"><?php $rank = 0; foreach ( $analytics['top_categories'] as $row ) : ++$rank; ?><div><b><?php echo esc_html( (string) $rank ); ?></b><span><strong><?php echo esc_html( $row['event_label'] ); ?></strong><small><?php echo esc_html( sprintf( __( '%d unique viewers', 'mobishop' ), $row['unique_clients'] ) ); ?></small></span><em><?php echo esc_html( (string) $row['event_count'] ); ?></em></div><?php endforeach; ?></div></section>
				<section><header><h3><?php esc_html_e( 'Activity & actions', 'mobishop' ); ?></h3><p><?php esc_html_e( 'Understand intent and the best times to launch offers.', 'mobishop' ); ?></p></header><div class="kidia-metric-list"><div><span><?php esc_html_e( 'Product views', 'mobishop' ); ?></span><b><?php echo esc_html( (string) $analytics_views['count'] ); ?></b></div><div><span><?php esc_html_e( 'Category views', 'mobishop' ); ?></span><b><?php echo esc_html( (string) $event( 'view_category' )['count'] ); ?></b></div><div><span><?php esc_html_e( 'Added to cart', 'mobishop' ); ?></span><b><?php echo esc_html( (string) $analytics_cart['count'] ); ?></b></div><div><span><?php esc_html_e( 'Removed from cart', 'mobishop' ); ?></span><b><?php echo esc_html( (string) $event( 'remove_from_cart' )['count'] ); ?></b></div></div><?php if ( ! empty( $analytics['activity_hours'] ) ) : ?><div class="kidia-activity-hours"><strong><?php esc_html_e( 'Busiest hours', 'mobishop' ); ?></strong><?php foreach ( $analytics['activity_hours'] as $hour ) : ?><span><?php echo esc_html( wp_date( get_option( 'time_format' ), mktime( (int) $hour['hour'], 0 ) ) ); ?><b><?php echo esc_html( (string) $hour['event_count'] ); ?></b></span><?php endforeach; ?></div><?php endif; ?></section>
			</div>
			<div class="kidia-opportunities"><h3><?php esc_html_e( 'Sales opportunities', 'mobishop' ); ?></h3><div>
				<?php /* translators: Placeholder values are supplied at runtime. */ ?>
				<?php if ( $analytics_closed_funnel['viewed_product'] > 0 && $rate( $analytics_closed_funnel['added_to_cart'], $analytics_closed_funnel['viewed_product'] ) < 15 ) : ?><article><span class="dashicons dashicons-lightbulb"></span><div><strong><?php esc_html_e( 'Improve product-to-cart conversion', 'mobishop' ); ?></strong><p><?php echo esc_html( sprintf( __( 'Only %s of product viewers added an item. Review price, photos and the add-to-cart offer on highly viewed products.', 'mobishop' ), $rate( $analytics_closed_funnel['added_to_cart'], $analytics_closed_funnel['viewed_product'] ) . '%' ) ); ?></p></div></article><?php endif; ?>
				<?php /* translators: Placeholder values are supplied at runtime. */ ?>
				<?php if ( $analytics_closed_funnel['started_checkout'] > $analytics_closed_funnel['purchased'] ) : ?><article><span class="dashicons dashicons-cart"></span><div><strong><?php esc_html_e( 'Recover checkout drop-off', 'mobishop' ); ?></strong><p><?php echo esc_html( sprintf( __( '%d shoppers started checkout without a tracked purchase. Check delivery cost, payment methods and abandoned carts.', 'mobishop' ), $analytics_closed_funnel['started_checkout'] - $analytics_closed_funnel['purchased'] ) ); ?></p></div></article><?php endif; ?>
				<?php /* translators: Placeholder values are supplied at runtime. */ ?>
				<?php if ( ! empty( $high_interest_products ) ) : ?><article><span class="dashicons dashicons-visibility"></span><div><strong><?php esc_html_e( 'High interest, low purchase', 'mobishop' ); ?></strong><p><?php echo esc_html( sprintf( __( '%s receives views but few tracked purchases. Review stock, price and product-page clarity.', 'mobishop' ), $high_interest_products[0]['event_label'] ) ); ?></p></div></article><?php endif; ?>
				<?php if ( 0 === $analytics['visitors'] ) : ?><article><span class="dashicons dashicons-info-outline"></span><div><strong><?php esc_html_e( 'Tracking is ready', 'mobishop' ); ?></strong><p><?php esc_html_e( 'Metrics will appear after customers use the selected sales channel. No placeholder values are shown.', 'mobishop' ); ?></p></div></article><?php endif; ?>
			</div></div>
			</div>
			<?php endif; ?>

		<?php elseif ( 'abandoned-carts' === $store_tab ) : ?>
			<div data-kidia-live-store-data="abandoned-carts-overview" aria-live="polite">
			<div class="kidia-data-summary is-five"><div><small><?php esc_html_e( 'Carts found', 'mobishop' ); ?></small><b><?php echo esc_html( (string) absint( $abandoned_summary['carts'] ?? 0 ) ); ?></b></div><div><small><?php esc_html_e( 'Active', 'mobishop' ); ?></small><b><?php echo esc_html( (string) absint( $abandoned_summary['active'] ?? 0 ) ); ?></b></div><div><small><?php esc_html_e( 'Abandoned', 'mobishop' ); ?></small><b><?php echo esc_html( (string) absint( $abandoned_summary['abandoned'] ?? 0 ) ); ?></b></div><div><small><?php esc_html_e( 'Recovered / converted', 'mobishop' ); ?></small><b><?php echo esc_html( (string) absint( $abandoned_summary['recovered'] ?? 0 ) ); ?></b></div><div><small><?php esc_html_e( 'Potential value', 'mobishop' ); ?></small><b><?php echo wp_kses_post( $money( (float) ( $abandoned_summary['potential_value'] ?? 0 ) ) ); ?></b></div></div>
			</div>
			<nav class="kidia-cart-view-tabs" aria-label="<?php esc_attr_e( 'Cart status', 'mobishop' ); ?>">
				<a class="<?php echo 'active' === $cart_view ? 'is-active' : ''; ?>" href="<?php echo esc_url( $cart_view_url( 'active' ) ); ?>"><?php esc_html_e( 'Active', 'mobishop' ); ?><b><?php echo esc_html( (string) absint( $abandoned_summary['active'] ?? 0 ) ); ?></b></a>
				<a class="<?php echo 'abandoned' === $cart_view ? 'is-active' : ''; ?>" href="<?php echo esc_url( $cart_view_url( 'abandoned' ) ); ?>"><?php esc_html_e( 'Abandoned', 'mobishop' ); ?><b><?php echo esc_html( (string) absint( $abandoned_summary['abandoned'] ?? 0 ) ); ?></b></a>
				<a class="<?php echo 'recovered' === $cart_view ? 'is-active' : ''; ?>" href="<?php echo esc_url( $cart_view_url( 'recovered' ) ); ?>"><?php esc_html_e( 'Recovered', 'mobishop' ); ?><b><?php echo esc_html( (string) absint( $abandoned_summary['recovered'] ?? 0 ) ); ?></b></a>
			</nav>
			<?php /* translators: Placeholder values are supplied at runtime. */ ?>
			<?php if ( isset( $_GET['recovery_result'] ) ) : ?><div class="notice notice-info inline"><p><?php echo esc_html( 'created' === $_GET['recovery_result'] ? sprintf( __( '%d personal recovery offers were created.', 'mobishop' ), absint( $_GET['recovery_count'] ?? 0 ) ) : __( 'No recovery offer was created. Select carts with a customer email and check the schedule.', 'mobishop' ) ); ?></p></div><?php endif; ?>
			<form class="kidia-recovery-builder" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
				<input type="hidden" name="action" value="kidia_mobile_create_recovery_campaign"><?php wp_nonce_field( 'kidia_mobile_create_recovery_campaign', 'kidia_mobile_recovery_nonce' ); ?>
				<?php if ( 'abandoned' === $cart_view ) : ?>
				<details open>
					<summary><span class="dashicons dashicons-megaphone"></span><?php esc_html_e( 'Send recovery offer to selected carts', 'mobishop' ); ?></summary>
					<div class="kidia-recovery-controls">
						<section class="kidia-recovery-group">
							<header><span class="dashicons dashicons-tickets-alt"></span><div><h4><?php esc_html_e( 'Personal coupon', 'mobishop' ); ?></h4><p><?php esc_html_e( 'One private, single-use code is created for each selected customer.', 'mobishop' ); ?></p></div></header>
							<div class="kidia-recovery-fields is-four">
								<label><span><?php esc_html_e( 'Discount type', 'mobishop' ); ?></span><select name="recovery_discount_type"><option value="percent"><?php esc_html_e( 'Percentage', 'mobishop' ); ?></option><option value="fixed_cart"><?php esc_html_e( 'Fixed cart amount', 'mobishop' ); ?></option></select></label>
								<label><span><?php esc_html_e( 'Discount value', 'mobishop' ); ?></span><input type="number" min="0" step=".01" name="recovery_discount_value" value="10" required></label>
								<label><span><?php esc_html_e( 'Expires after (hours)', 'mobishop' ); ?></span><input type="number" min="1" max="720" name="recovery_expiry_hours" value="48"></label>
								<label><span><?php esc_html_e( 'Minimum spend', 'mobishop' ); ?></span><input type="number" min="0" step=".01" name="recovery_minimum_spend" value="0"></label>
							</div>
							<label class="kidia-recovery-check"><input type="checkbox" name="recovery_restrict_products" value="1" checked><span><?php esc_html_e( 'Restrict every coupon to the products in that customer’s cart', 'mobishop' ); ?></span></label>
						</section>
						<section class="kidia-recovery-group">
							<header><span class="dashicons dashicons-format-chat"></span><div><h4><?php esc_html_e( 'Notification message', 'mobishop' ); ?></h4><p><?php esc_html_e( 'Use {coupon} in the message to insert each personal code.', 'mobishop' ); ?></p></div></header>
							<div class="kidia-recovery-fields">
								<label><span><?php esc_html_e( 'Notification title', 'mobishop' ); ?></span><input type="text" name="recovery_title" maxlength="100" value="<?php esc_attr_e( 'Your cart is waiting', 'mobishop' ); ?>" required></label>
								<label><span><?php esc_html_e( 'Action display', 'mobishop' ); ?></span><select name="recovery_action_style" data-recovery-action-style><option value="link"><?php esc_html_e( 'Open link', 'mobishop' ); ?></option><option value="button"><?php esc_html_e( 'Button', 'mobishop' ); ?></option></select></label>
								<label class="is-wide"><span><?php esc_html_e( 'Message', 'mobishop' ); ?></span><textarea name="recovery_message" rows="3" maxlength="500" required><?php esc_html_e( 'Complete your order with code {coupon} before your personal offer expires.', 'mobishop' ); ?></textarea></label>
								<label data-recovery-button-label hidden><span><?php esc_html_e( 'Button text', 'mobishop' ); ?></span><input type="text" name="recovery_cta_label" maxlength="30" value="<?php esc_attr_e( 'Complete purchase', 'mobishop' ); ?>"></label>
								<label class="is-wide"><span><?php esc_html_e( 'Destination URL', 'mobishop' ); ?></span><input type="url" name="recovery_action_url" value="<?php echo esc_attr( function_exists( 'wc_get_cart_url' ) ? wc_get_cart_url() : home_url( '/' ) ); ?>"></label>
							</div>
						</section>
						<section class="kidia-recovery-group is-delivery">
							<header><span class="dashicons dashicons-clock"></span><div><h4><?php esc_html_e( 'Delivery', 'mobishop' ); ?></h4><p><?php esc_html_e( 'Send now or choose one future date and time.', 'mobishop' ); ?></p></div></header>
							<div class="kidia-recovery-fields">
								<label><span><?php esc_html_e( 'Delivery', 'mobishop' ); ?></span><select name="recovery_delivery" data-recovery-delivery><option value="now"><?php esc_html_e( 'Send now', 'mobishop' ); ?></option><option value="scheduled"><?php esc_html_e( 'Schedule', 'mobishop' ); ?></option></select></label>
								<label data-recovery-schedule hidden><span><?php esc_html_e( 'Send date and time', 'mobishop' ); ?></span><input type="datetime-local" name="recovery_schedule_at"></label>
							</div>
						</section>
						<footer class="kidia-recovery-submit"><p><?php esc_html_e( 'Coupons are created only for the carts you select in the table below.', 'mobishop' ); ?></p><button class="button button-primary" type="submit"><span class="dashicons dashicons-paper-plane"></span><?php esc_html_e( 'Create coupons & send', 'mobishop' ); ?></button></footer>
					</div>
				</details>
				<div class="kidia-cart-segment-legend">
					<span><i class="is-alternative"></i><?php esc_html_e( 'Bought an alternative order', 'mobishop' ); ?></span>
					<span><i class="is-returning"></i><?php esc_html_e( 'Returning customer', 'mobishop' ); ?></span>
					<span><i class="is-first_time"></i><?php esc_html_e( 'First-time customer', 'mobishop' ); ?></span>
				</div>
				<?php endif; ?>
				<div class="kidia-cart-table-toolbar">
					<strong><?php echo esc_html( 'active' === $cart_view ? __( 'Active carts', 'mobishop' ) : ( 'recovered' === $cart_view ? __( 'Recovered orders', 'mobishop' ) : __( 'Abandoned orders', 'mobishop' ) ) ); ?></strong>
					<label><span><?php esc_html_e( 'Orders per page', 'mobishop' ); ?></span><select data-cart-per-page>
						<?php foreach ( array( 20, 50, 100 ) as $size ) : ?><option value="<?php echo esc_attr( (string) $size ); ?>" <?php selected( $cart_per_page, $size ); ?>><?php echo esc_html( (string) $size ); ?></option><?php endforeach; ?>
					</select></label>
				</div>
				<div class="kidia-data-table-wrap"><table class="kidia-data-table kidia-abandoned-table">
					<thead><tr><?php if ( 'abandoned' === $cart_view ) : ?><th><input type="checkbox" data-select-all-carts aria-label="<?php esc_attr_e( 'Select all carts', 'mobishop' ); ?>"></th><?php endif; ?><th><?php esc_html_e( 'Customer', 'mobishop' ); ?></th><th><?php esc_html_e( 'Items', 'mobishop' ); ?></th><th><?php esc_html_e( 'Value', 'mobishop' ); ?></th><th><?php esc_html_e( 'Source', 'mobishop' ); ?></th><th><?php esc_html_e( 'Last activity', 'mobishop' ); ?></th><th><?php esc_html_e( 'Status', 'mobishop' ); ?></th><th><?php esc_html_e( 'Details', 'mobishop' ); ?></th></tr></thead>
					<tbody data-kidia-live-store-data="abandoned-carts-table">
					<?php foreach ( $abandoned_carts as $cart ) : ?>
						<tr data-abandoned-cart-row="<?php echo esc_attr( (string) $cart['id'] ); ?>">
							<?php if ( 'abandoned' === $cart_view ) : ?><td><input type="checkbox" name="cart_ids[]" value="<?php echo esc_attr( (string) $cart['id'] ); ?>" <?php disabled( empty( $cart['customer_email'] ) ); ?> aria-label="<?php esc_attr_e( 'Select cart', 'mobishop' ); ?>"></td><?php endif; ?>
							<td><strong class="kidia-cart-customer"><i class="kidia-cart-segment is-<?php echo esc_attr( $cart['customer_segment'] ?? 'first_time' ); ?>" aria-hidden="true"></i><?php echo esc_html( $cart['customer_name'] ?: __( 'Guest', 'mobishop' ) ); ?></strong><small><?php echo esc_html( $cart['customer_email'] ?: __( 'Email required for a personal coupon', 'mobishop' ) ); ?></small></td>
							<td><strong><?php echo esc_html( (string) $cart['item_count'] ); ?></strong><small><?php echo esc_html( implode( ', ', array_slice( array_filter( array_column( $cart['items'], 'name' ) ), 0, 3 ) ) ); ?></small></td>
							<td><?php echo wp_kses_post( $money( (float) $cart['cart_total'] ) ); ?></td>
							<td><span class="kidia-source-badge is-<?php echo esc_attr( $cart['source'] ); ?>"><?php echo esc_html( $source_labels[ $cart['source'] ] ?? ucfirst( $cart['source'] ) ); ?></span></td>
							<td><?php echo esc_html( get_date_from_gmt( $cart['last_activity_at'], get_option( 'date_format' ) . ' ' . get_option( 'time_format' ) ) ); ?><small><?php echo esc_html( human_time_diff( strtotime( $cart['last_activity_at'] . ' UTC' ), time() ) . ' ' . __( 'ago', 'mobishop' ) ); ?></small></td>
							<?php /* translators: Placeholder values are supplied at runtime. */ ?>
							<td><span class="kidia-status is-<?php echo esc_attr( $cart['status'] ); ?>"><?php echo esc_html( ucfirst( $cart['status'] ) ); ?></span><?php if ( ! empty( $cart['alternative_order_id'] ) ) : ?><small><?php echo esc_html( sprintf( __( 'Possible alternative #%d', 'mobishop' ), absint( $cart['alternative_order_id'] ) ) ); ?></small><?php endif; ?></td>
							<td><button type="button" class="button kidia-cart-details-button" data-abandoned-cart-details="<?php echo esc_attr( (string) $cart['id'] ); ?>" aria-expanded="false"><?php esc_html_e( 'View details', 'mobishop' ); ?></button></td>
						</tr>
						<tr class="kidia-cart-details-row" data-abandoned-cart-details-row="<?php echo esc_attr( (string) $cart['id'] ); ?>" hidden><td colspan="<?php echo 'abandoned' === $cart_view ? '8' : '7'; ?>"><div class="kidia-cart-details-content" aria-live="polite"></div></td></tr>
					<?php endforeach; ?>
					</tbody>
				</table></div>
				<?php if ( $cart_pages > 1 ) : ?><nav class="kidia-data-pagination" data-kidia-live-store-data="abandoned-carts-pagination" aria-label="<?php esc_attr_e( 'Cart pages', 'mobishop' ); ?>"><?php
					echo wp_kses_post(
						paginate_links(
							array(
								'base'      => str_replace( '999999', '%#%', esc_url( $cart_view_url( $cart_view, 999999 ) ) ),
								'format'    => '',
								'current'   => $cart_page,
								'total'     => $cart_pages,
								'prev_text' => '‹',
								'next_text' => '›',
							)
						)
					);
				?></nav><?php endif; ?>
			</form>
			<?php if ( 'recovered' === $cart_view ) : ?>
			<section class="kidia-recovery-attribution"><h3><?php esc_html_e( 'Recovery attribution', 'mobishop' ); ?></h3><p><?php esc_html_e( 'A conversion is counted only when the same customer uses the personal campaign coupon.', 'mobishop' ); ?></p><div class="kidia-data-summary is-four"><div><small><?php esc_html_e( 'Sent', 'mobishop' ); ?></small><b><?php echo esc_html( (string) ( $recovery_stats['sent'] ?? 0 ) ); ?></b></div><div><small><?php esc_html_e( 'Opened', 'mobishop' ); ?></small><b><?php echo esc_html( (string) ( $recovery_stats['opened'] ?? 0 ) ); ?></b></div><div><small><?php esc_html_e( 'Converted', 'mobishop' ); ?></small><b><?php echo esc_html( (string) ( $recovery_stats['converted'] ?? 0 ) ); ?></b></div><div><small><?php esc_html_e( 'Net recovered revenue', 'mobishop' ); ?></small><b><?php echo wp_kses_post( $money( (float) ( $recovery_stats['revenue'] ?? 0 ) - (float) ( $recovery_stats['discount'] ?? 0 ) ) ); ?></b></div></div>
				<div class="kidia-recovery-rates"><span><small><?php esc_html_e( 'Open rate', 'mobishop' ); ?></small><b><?php echo esc_html( $rate( (float) ( $recovery_stats['opened'] ?? 0 ), (float) ( $recovery_stats['sent'] ?? 0 ) ) . '%' ); ?></b></span><span><small><?php esc_html_e( 'Conversion rate', 'mobishop' ); ?></small><b><?php echo esc_html( $rate( (float) ( $recovery_stats['converted'] ?? 0 ), (float) ( $recovery_stats['sent'] ?? 0 ) ) . '%' ); ?></b></span><span><small><?php esc_html_e( 'Average time to convert', 'mobishop' ); ?></small><b><?php echo esc_html( ( $recovery_stats['time_to_convert'] ?? 0 ) > 0 ? human_time_diff( time() - absint( $recovery_stats['time_to_convert'] ), time() ) : '—' ); ?></b></span><span><small><?php esc_html_e( 'Discount cost', 'mobishop' ); ?></small><b><?php echo wp_kses_post( $money( (float) ( $recovery_stats['discount'] ?? 0 ) ) ); ?></b></span></div>
				<?php if ( $recovery_campaigns ) : ?><div class="kidia-data-table-wrap"><table class="kidia-data-table"><thead><tr><th><?php esc_html_e( 'Customer', 'mobishop' ); ?></th><th><?php esc_html_e( 'Coupon', 'mobishop' ); ?></th><th><?php esc_html_e( 'Source', 'mobishop' ); ?></th><th><?php esc_html_e( 'State', 'mobishop' ); ?></th><th><?php esc_html_e( 'Order', 'mobishop' ); ?></th><th><?php esc_html_e( 'Revenue / discount', 'mobishop' ); ?></th></tr></thead><tbody><?php foreach ( $recovery_campaigns as $campaign ) : ?><tr><td><?php echo esc_html( $campaign['customer_email'] ); ?></td><td><code><?php echo esc_html( $campaign['coupon_code'] ); ?></code></td><td><?php echo esc_html( ucfirst( $campaign['source'] ) ); ?></td><td><span class="kidia-status is-<?php echo esc_attr( $campaign['status'] ); ?>"><?php echo esc_html( ucfirst( $campaign['status'] ) ); ?></span></td><td><?php echo $campaign['order_id'] ? '#' . esc_html( (string) $campaign['order_id'] ) : '—'; ?></td><td><?php echo wp_kses_post( $money( (float) $campaign['order_total'] ) ); ?> / <?php echo wp_kses_post( $money( (float) $campaign['discount_total'] ) ); ?></td></tr><?php endforeach; ?></tbody></table></div><?php endif; ?>
			</section>
			<?php endif; ?>

		<?php endif; ?>
	</section>
</div>
