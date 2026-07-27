<?php
/** Explainable, store-local growth intelligence workspace. */
defined( 'ABSPATH' ) || exit;

$source_labels = array(
	'all'     => __( 'All', 'kidia-mobile-cms' ),
	'website' => __( 'Website', 'kidia-mobile-cms' ),
	'mobile'  => __( 'Mobile App', 'kidia-mobile-cms' ),
);
$kind_labels = array(
	'all'           => __( 'All recommendations', 'kidia-mobile-cms' ),
	'campaign'      => __( 'Offers & campaigns', 'kidia-mobile-cms' ),
	'merchandising' => __( 'Products & bundles', 'kidia-mobile-cms' ),
	'inventory'     => __( 'Inventory', 'kidia-mobile-cms' ),
	'funnel'        => __( 'Sales funnel', 'kidia-mobile-cms' ),
	'timing'        => __( 'Timing', 'kidia-mobile-cms' ),
);
$kind_icons = array(
	'campaign'      => 'dashicons-megaphone',
	'merchandising' => 'dashicons-products',
	'inventory'     => 'dashicons-archive',
	'funnel'        => 'dashicons-filter',
	'timing'        => 'dashicons-clock',
);
$date_labels = array(
	'all_time'       => __( 'All time', 'kidia-mobile-cms' ),
	'today'          => __( 'Today', 'kidia-mobile-cms' ),
	'yesterday'      => __( 'Yesterday', 'kidia-mobile-cms' ),
	'last_7_days'    => __( 'Last 7 days', 'kidia-mobile-cms' ),
	'last_30_days'   => __( 'Last 30 days', 'kidia-mobile-cms' ),
	'this_month'     => __( 'This month', 'kidia-mobile-cms' ),
	'previous_month' => __( 'Last month', 'kidia-mobile-cms' ),
	'last_year'      => __( 'Last year', 'kidia-mobile-cms' ),
	'custom'         => __( 'Custom', 'kidia-mobile-cms' ),
);
$event = static fn( string $name ): array => $ai_summary['events'][ $name ] ?? array( 'count' => 0, 'unique' => 0, 'value' => 0.0 );
$rate  = static fn( float $part, float $whole ): float => $whole > 0 ? round( 100 * $part / $whole, 1 ) : 0.0;
$tracked_funnel = is_array( $ai_summary['funnel'] ?? null ) ? $ai_summary['funnel'] : array();
$coverage = is_array( $ai_summary['coverage'] ?? null ) ? $ai_summary['coverage'] : array();
$visitors = absint( $tracked_funnel['visitors'] ?? 0 );
$views = absint( $tracked_funnel['viewed_product'] ?? 0 );
$carts = absint( $tracked_funnel['added_to_cart'] ?? 0 );
$checks = absint( $tracked_funnel['started_checkout'] ?? 0 );
$buys = absint( $tracked_funnel['purchased'] ?? 0 );
$funnel = array(
	array( __( 'Visitors', 'kidia-mobile-cms' ), $visitors, $visitors > 0 ? 100 : 0 ),
	array( __( 'Viewed product', 'kidia-mobile-cms' ), $views, $rate( $views, $visitors ) ),
	array( __( 'Added to cart', 'kidia-mobile-cms' ), $carts, $rate( $carts, $visitors ) ),
	array( __( 'Started checkout', 'kidia-mobile-cms' ), $checks, $rate( $checks, $visitors ) ),
	array( __( 'Purchased', 'kidia-mobile-cms' ), $buys, $rate( $buys, $visitors ) ),
);
$playbook_groups = Kidia_Mobile_AI_Offer_Engine::playbook_groups();
$playbook_count = array_sum( array_map( static fn( $group ) => count( $group['items'] ?? array() ), $playbook_groups ) );
$playbook_group_kinds = array(
	'personalization' => 'merchandising',
	'relationships'   => 'merchandising',
	'merchandising'   => 'merchandising',
	'offers'          => 'campaign',
	'inventory'       => 'inventory,timing',
	'funnel'          => 'funnel',
);
$bundle_recipes = Kidia_Mobile_Bundle_Recipes::all();
$commerce = is_array( $ai_summary['commerce'] ?? null ) ? $ai_summary['commerce'] : array();
$orders_scanned = absint( $commerce['orders_scanned'] ?? $commerce['orders'] ?? 0 );
$orders_available = absint( $commerce['orders_available'] ?? $orders_scanned );
$rotation_group_meta = array(
	'fast' => array(
		'label'       => __( 'Fast-moving products', 'kidia-mobile-cms' ),
		'description' => __( 'Protect availability, increase visibility and grow basket size without unnecessary discounting.', 'kidia-mobile-cms' ),
	),
	'medium' => array(
		'label'       => __( 'Medium-moving products', 'kidia-mobile-cms' ),
		'description' => __( 'Use controlled incentives and product relationships to move these products into the fast group.', 'kidia-mobile-cms' ),
	),
	'slow' => array(
		'label'       => __( 'Slow-moving products', 'kidia-mobile-cms' ),
		'description' => __( 'Run measured product offers and bundles that improve sell-through while protecting margin.', 'kidia-mobile-cms' ),
	),
	'poor' => array(
		'label'       => __( 'Poor-performing products', 'kidia-mobile-cms' ),
		'description' => __( 'Use short clearance tests, then stop or revise decisions that do not recover cash and stock.', 'kidia-mobile-cms' ),
	),
	'storewide' => array(
		'label'       => __( 'Store-wide decisions', 'kidia-mobile-cms' ),
		'description' => __( 'Funnel, timing, merchandising and basket decisions supported by store-level evidence.', 'kidia-mobile-cms' ),
	),
);
$rotation_product_counts = array();
foreach ( array( 'fast', 'medium', 'slow', 'poor' ) as $rotation_key ) {
	$rotation_product_counts[ $rotation_key ] = count( $ai_rotation_segments[ $rotation_key ] ?? array() );
}
$action_result = static function ( array $row ): array {
	$uses       = 0;
	$type       = sanitize_key( (string) ( $row['type'] ?? '' ) );
	$reference  = absint( $row['created_reference'] ?? 0 );
	$created_at = absint( $row['created_at'] ?? 0 );
	$duration   = max( 1, absint( $row['duration_hours'] ?? 48 ) );
	$elapsed    = $created_at > 0 ? ( time() - $created_at ) / HOUR_IN_SECONDS : 0;
	if ( 'coupon' === $type && $reference > 0 && class_exists( 'WC_Coupon' ) ) {
		$coupon = new WC_Coupon( $reference );
		$uses   = $coupon->get_id() > 0 ? absint( $coupon->get_usage_count() ) : 0;
	} elseif ( 'bundle' === $type && '' !== (string) ( $row['created_reference'] ?? '' ) && class_exists( 'WC_Coupon' ) ) {
		$recipes   = Kidia_Mobile_Bundle_Recipes::all();
		$recipe    = is_array( $recipes[ (string) $row['created_reference'] ] ?? null ) ? $recipes[ (string) $row['created_reference'] ] : array();
		$coupon_id = absint( $recipe['coupon_id'] ?? 0 );
		if ( $coupon_id > 0 ) {
			$coupon = new WC_Coupon( $coupon_id );
			$uses   = $coupon->get_id() > 0 ? absint( $coupon->get_usage_count() ) : 0;
		}
	}
	if ( $uses > 0 ) {
		return array( 'state' => 'positive', 'uses' => $uses, 'label' => __( 'Continue while gross profit stays positive', 'kidia-mobile-cms' ) );
	}
	if ( $elapsed >= $duration ) {
		return array( 'state' => 'review', 'uses' => 0, 'label' => __( 'No measured conversion: review or stop this action', 'kidia-mobile-cms' ) );
	}
	return array( 'state' => 'collecting', 'uses' => $uses, 'label' => __( 'Collecting results until the decision window closes', 'kidia-mobile-cms' ) );
};
?>
<div class="wrap kidia-ai-page">
	<header class="kidia-ai-page__hero">
		<div><span class="dashicons dashicons-lightbulb"></span><div><h1><?php esc_html_e( 'AI Offer Studio', 'kidia-mobile-cms' ); ?></h1><p><?php esc_html_e( 'Store-local growth intelligence for offers, merchandising, inventory and funnel decisions. Nothing is activated without your review.', 'kidia-mobile-cms' ); ?></p></div></div>
		<div class="kidia-ai-page__trust"><strong><?php echo esc_html( (string) $ai_signal_count ); ?>+</strong><span><?php esc_html_e( 'documented signals', 'kidia-mobile-cms' ); ?></span></div>
	</header>

		<?php if ( isset( $_GET['ai_action_saved'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'The reviewed AI action was saved. Nothing else was activated automatically.', 'kidia-mobile-cms' ); ?></p></div><?php endif; ?>
	<?php if ( isset( $_GET['ai_action_error'] ) && 'stock_changed' === sanitize_key( wp_unslash( $_GET['ai_action_error'] ) ) ) : ?><div class="notice notice-error is-dismissible"><p><?php esc_html_e( 'This decision was not executed because its products are no longer in stock. Generate fresh offers before publishing.', 'kidia-mobile-cms' ); ?></p></div><?php endif; ?>
	<?php if ( isset( $_GET['bundle_saved'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Bundle recipe saved and is ready for Home Page or app placement.', 'kidia-mobile-cms' ); ?></p></div><?php endif; ?>

	<form class="kidia-date-filter kidia-ai-filter-bar" method="get" data-ai-generate-form
		data-ai-analysis-nonce="<?php echo esc_attr( wp_create_nonce( 'kidia_mobile_ai_analysis' ) ); ?>"
		data-ai-from="<?php echo esc_attr( (string) $date_from ); ?>"
		data-ai-to="<?php echo esc_attr( (string) $date_to ); ?>">
		<input type="hidden" name="page" value="kidia-mobile-ai-insights">
		<input type="hidden" name="ai_generate" value="1">
		<label><span><?php esc_html_e( 'Channel', 'kidia-mobile-cms' ); ?></span><select name="ai_source"><?php foreach ( $source_labels as $key => $label ) : ?><option value="<?php echo esc_attr( $key ); ?>" <?php selected( $ai_source, $key ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
		<label><span><?php esc_html_e( 'Recommendation type', 'kidia-mobile-cms' ); ?></span><select name="ai_kind"><?php foreach ( $kind_labels as $key => $label ) : ?><option value="<?php echo esc_attr( $key ); ?>" <?php selected( $ai_kind, $key ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
			<label><span><?php esc_html_e( 'Period', 'kidia-mobile-cms' ); ?></span><select name="date_preset"><?php foreach ( $date_labels as $key => $label ) : ?><option value="<?php echo esc_attr( $key ); ?>" <?php selected( $date_preset, $key ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
		<label><span><?php esc_html_e( 'From', 'kidia-mobile-cms' ); ?></span><input type="date" name="date_from" value="<?php echo esc_attr( wp_date( 'Y-m-d', $date_from ) ); ?>" <?php disabled( 'custom' !== $date_preset ); ?>></label>
		<label><span><?php esc_html_e( 'To', 'kidia-mobile-cms' ); ?></span><input type="date" name="date_to" value="<?php echo esc_attr( wp_date( 'Y-m-d', $date_to ) ); ?>" <?php disabled( 'custom' !== $date_preset ); ?>></label>
		<button class="button button-primary kidia-ai-generate-button" type="submit" data-ai-generate-button>
			<span class="dashicons dashicons-update"></span>
			<span data-ai-generate-label><?php echo esc_html( $ai_generated ? __( 'Refresh Offers from Store Data', 'kidia-mobile-cms' ) : __( 'Generate Offers from Store Data', 'kidia-mobile-cms' ) ); ?></span>
			<span class="spinner" data-ai-generate-spinner></span>
		</button>
	</form>
	<div class="kidia-ai-progress-overlay" data-ai-progress-overlay hidden aria-live="polite" aria-busy="true">
		<div class="kidia-ai-progress-card">
			<div class="kidia-ai-progress-ring" data-ai-progress-ring style="--kidia-ai-progress:0">
				<strong data-ai-progress-value>0%</strong>
			</div>
			<h2><?php esc_html_e( 'Analyzing store data & generating offers', 'kidia-mobile-cms' ); ?></h2>
			<p data-ai-progress-stage><?php esc_html_e( 'Preparing the selected store data…', 'kidia-mobile-cms' ); ?></p>
			<strong class="kidia-ai-progress-count" data-ai-progress-count><?php esc_html_e( 'Waiting for the first measured batch', 'kidia-mobile-cms' ); ?></strong>
			<div class="kidia-ai-progress-track"><i data-ai-progress-bar></i></div>
			<small data-ai-progress-note><?php esc_html_e( 'The percentage is calculated from completed WooCommerce orders and in-stock products—not from a timer.', 'kidia-mobile-cms' ); ?></small>
			<div class="kidia-ai-progress-actions">
				<button class="button button-primary" type="button" data-ai-background-button><span class="dashicons dashicons-migrate"></span><?php esc_html_e( 'Continue in background', 'kidia-mobile-cms' ); ?></button>
				<button class="button" type="button" data-ai-view-results hidden><span class="dashicons dashicons-chart-area"></span><?php esc_html_e( 'View results', 'kidia-mobile-cms' ); ?></button>
				<button class="button kidia-ai-cancel-button" type="button" data-ai-cancel-button><span class="dashicons dashicons-no-alt"></span><?php esc_html_e( 'Cancel analysis', 'kidia-mobile-cms' ); ?></button>
			</div>
		</div>
	</div>

	<?php if ( $ai_generated ) : ?>
	<section class="kidia-ai-overview">
		<article><span class="dashicons dashicons-cart"></span><div><small><?php esc_html_e( 'Paid WooCommerce orders analysed', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) $orders_scanned ); ?></strong><?php if ( $orders_available > $orders_scanned ) : ?><em><?php echo esc_html( sprintf( __( '%d paid orders found', 'kidia-mobile-cms' ), $orders_available ) ); ?></em><?php endif; ?></div></article>
		<article><span class="dashicons dashicons-products"></span><div><small><?php esc_html_e( 'Units analysed', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) absint( $commerce['units'] ?? 0 ) ); ?></strong></div></article>
		<article><span class="dashicons dashicons-store"></span><div><small><?php esc_html_e( 'In-stock products analysed', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) absint( $commerce['catalog_in_stock'] ?? 0 ) ); ?></strong></div></article>
		<article><span class="dashicons dashicons-visibility"></span><div><small><?php esc_html_e( 'Live behaviour signals', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) $ai_signal_volume ); ?></strong></div></article>
		<article><span class="dashicons dashicons-lightbulb"></span><div><small><?php esc_html_e( 'Recommendations found', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) count( $all_recommendations ) ); ?></strong></div></article>
	</section>

	<section class="kidia-ai-data-coverage<?php echo empty( $tracked_funnel['is_reliable'] ) ? ' is-limited' : ''; ?>">
		<span class="dashicons <?php echo empty( $tracked_funnel['is_reliable'] ) ? 'dashicons-info-outline' : 'dashicons-yes-alt'; ?>"></span>
		<div>
			<strong><?php esc_html_e( 'Sales history and live journey tracking are analysed separately', 'kidia-mobile-cms' ); ?></strong>
			<p>
				<?php
				echo esc_html(
					sprintf(
						/* translators: 1: scanned orders, 2: available orders, 3: in-stock products, 4: tracked days, 5: requested days. */
						__( '%1$d of %2$d paid WooCommerce orders and all %3$d currently in-stock products were analysed. Live funnel tracking covers %4$d of %5$d selected days; historical orders are never inserted into Add to cart or Checkout counts.', 'kidia-mobile-cms' ),
						absint( $commerce['orders_scanned'] ?? 0 ),
						absint( $commerce['orders_available'] ?? 0 ),
						absint( $commerce['catalog_in_stock'] ?? 0 ),
						absint( $coverage['tracked_days'] ?? 0 ),
						absint( $coverage['requested_days'] ?? 0 )
					)
				);
				?>
			</p>
			<?php if ( $orders_available > $orders_scanned ) : ?>
				<small class="kidia-ai-coverage-warning"><?php esc_html_e( 'The previous stored result was incomplete. Generate again to process every paid order with the corrected batched analyser.', 'kidia-mobile-cms' ); ?></small>
			<?php endif; ?>
			<?php if ( ! empty( $tracked_funnel['unmatched_purchases'] ) ) : ?>
				<small><?php echo esc_html( sprintf( __( '%d purchase events were excluded from the funnel because their earlier journey steps were not tracked.', 'kidia-mobile-cms' ), absint( $tracked_funnel['unmatched_purchases'] ) ) ); ?></small>
			<?php endif; ?>
		</div>
	</section>

	<nav class="kidia-ai-rotation-summary" aria-label="<?php esc_attr_e( 'Product rotation groups', 'kidia-mobile-cms' ); ?>">
		<?php foreach ( array( 'fast', 'medium', 'slow', 'poor' ) as $rotation_key ) : ?>
			<a class="is-<?php echo esc_attr( $rotation_key ); ?>" href="#kidia-ai-rotation-<?php echo esc_attr( $rotation_key ); ?>">
				<span><?php echo esc_html( (string) $rotation_group_meta[ $rotation_key ]['label'] ); ?></span>
				<strong><?php echo esc_html( (string) $rotation_product_counts[ $rotation_key ] ); ?></strong>
				<small><?php esc_html_e( 'in-stock products', 'kidia-mobile-cms' ); ?></small>
			</a>
		<?php endforeach; ?>
	</nav>

	<div class="kidia-ai-analysis-grid">
		<section class="kidia-ai-funnel-panel">
			<header><div><span class="dashicons dashicons-filter"></span><div><h2><?php esc_html_e( 'Tracked sales funnel', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Closed funnel: each customer must complete the previous tracked step first.', 'kidia-mobile-cms' ); ?></p></div></div></header>
			<div><?php foreach ( $funnel as $step ) : ?><article><span><strong><?php echo esc_html( $step[0] ); ?></strong><small><?php echo esc_html( (string) $step[1] ); ?></small></span><i><b style="width:<?php echo esc_attr( (string) min( 100, $step[2] ) ); ?>%"></b></i><em><?php echo esc_html( $step[2] . '%' ); ?></em></article><?php endforeach; ?></div>
		</section>
		<section class="kidia-ai-demand-panel">
			<header><div><span class="dashicons dashicons-chart-line"></span><div><h2><?php esc_html_e( 'Demand signals', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'What customers view, search for and buy in this period.', 'kidia-mobile-cms' ); ?></p></div></div></header>
			<div>
				<article><small><?php esc_html_e( 'Best-selling product', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) ( $ai_summary['top_purchases'][0]['event_label'] ?? '—' ) ); ?></strong><span><?php echo esc_html( (string) absint( $ai_summary['top_purchases'][0]['event_count'] ?? 0 ) ); ?> <?php esc_html_e( 'units', 'kidia-mobile-cms' ); ?></span></article>
				<article><small><?php esc_html_e( 'Top viewed product', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) ( $ai_summary['top_products'][0]['event_label'] ?? '—' ) ); ?></strong><span><?php echo esc_html( (string) absint( $ai_summary['top_products'][0]['event_count'] ?? 0 ) ); ?> <?php esc_html_e( 'views', 'kidia-mobile-cms' ); ?></span></article>
				<article><small><?php esc_html_e( 'Top search', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) ( $ai_summary['top_searches'][0]['event_label'] ?? '—' ) ); ?></strong><span><?php echo esc_html( (string) absint( $ai_summary['top_searches'][0]['event_count'] ?? 0 ) ); ?> <?php esc_html_e( 'searches', 'kidia-mobile-cms' ); ?></span></article>
			</div>
		</section>
	</div>

	<nav class="kidia-ai-workspace-tabs" aria-label="<?php esc_attr_e( 'AI Studio workspace', 'kidia-mobile-cms' ); ?>">
		<button type="button" class="is-active" data-ai-workspace-tab="decisions"><?php esc_html_e( 'Generated Decisions', 'kidia-mobile-cms' ); ?><b><?php echo esc_html( (string) count( $ai_recommendations ) ); ?></b></button>
		<button type="button" data-ai-workspace-tab="results"><?php esc_html_e( 'Actions & Results', 'kidia-mobile-cms' ); ?><b><?php echo esc_html( (string) count( $ai_action_history ) ); ?></b></button>
	</nav>
	<div data-ai-workspace-panel="decisions">
	<section class="kidia-ai-recommendation-section">
		<header>
			<div>
				<h2><?php esc_html_e( 'Decision-ready recommendations', 'kidia-mobile-cms' ); ?></h2>
				<p><?php esc_html_e( 'Every recommendation names the products, exact action, calculated value, evidence, success measure and safety guardrail.', 'kidia-mobile-cms' ); ?></p>
			</div>
			<details class="kidia-ai-playbooks">
				<summary>
					<span><?php echo esc_html( sprintf( __( '%d supported playbooks', 'kidia-mobile-cms' ), $playbook_count ) ); ?></span>
					<span class="dashicons dashicons-arrow-down-alt2"></span>
				</summary>
				<div class="kidia-ai-playbook-groups">
					<?php foreach ( $playbook_groups as $group_key => $group ) : ?>
						<section>
							<h3><?php echo esc_html( (string) $group['label'] ); ?></h3>
							<div><?php foreach ( (array) $group['items'] as $playbook ) : ?><button type="button" data-ai-playbook-kind="<?php echo esc_attr( $playbook_group_kinds[ $group_key ] ?? 'all' ); ?>"><?php echo esc_html( $playbook ); ?></button><?php endforeach; ?></div>
						</section>
					<?php endforeach; ?>
				</div>
			</details>
		</header>
		<?php if ( $ai_recommendations ) : ?>
			<div class="kidia-ai-rotation-groups">
			<?php foreach ( $rotation_group_meta as $rotation_key => $rotation_meta ) :
				$rotation_recommendations = array_values(
					array_filter(
						$ai_recommendations,
						static fn( $item ) => $rotation_key === ( $item['rotation_segment'] ?? 'storewide' )
					)
				);
				$is_product_rotation = array_key_exists( $rotation_key, $rotation_product_counts );
				if ( empty( $rotation_recommendations ) && ! $is_product_rotation ) {
					continue;
				}
				$catalog_count = ! $is_product_rotation
					? count( $rotation_recommendations )
					: $rotation_product_counts[ $rotation_key ];
				?>
				<section id="kidia-ai-rotation-<?php echo esc_attr( $rotation_key ); ?>" class="kidia-ai-rotation-group is-<?php echo esc_attr( $rotation_key ); ?>">
					<header>
						<div><h3><?php echo esc_html( (string) $rotation_meta['label'] ); ?></h3><p><?php echo esc_html( (string) $rotation_meta['description'] ); ?></p></div>
						<b><?php echo esc_html( sprintf( _n( '%d product', '%d products', $catalog_count, 'kidia-mobile-cms' ), $catalog_count ) ); ?></b>
					</header>
					<?php if ( empty( $rotation_recommendations ) ) : ?>
						<div class="kidia-ai-segment-empty">
							<strong><?php esc_html_e( 'No action is needed for this group under the current filters.', 'kidia-mobile-cms' ); ?></strong>
							<p><?php esc_html_e( 'The products are still classified here; widen the recommendation type to show any matching decisions.', 'kidia-mobile-cms' ); ?></p>
						</div>
					<?php else : ?>
					<div class="kidia-ai-recommendations kidia-ai-recommendations--workspace">
				<?php foreach ( $rotation_recommendations as $recommendation ) :
					$kind = sanitize_key( (string) ( $recommendation['kind'] ?? 'campaign' ) );
					$product_ids = array_values( array_filter( array_map( 'absint', (array) ( $recommendation['product_ids'] ?? array() ) ) ) );
					$recommended_action = sanitize_key( (string) ( $recommendation['implementation'] ?? 'store_action' ) );
					?>
					<article class="kidia-ai-decision-card is-<?php echo esc_attr( $kind ); ?>" data-ai-decision-kind="<?php echo esc_attr( $kind ); ?>">
						<header><span class="dashicons <?php echo esc_attr( $kind_icons[ $kind ] ?? 'dashicons-lightbulb' ); ?>"></span><div><small><?php echo esc_html( $kind_labels[ $kind ] ?? ucfirst( $kind ) ); ?></small><h3><?php echo esc_html( (string) $recommendation['title'] ); ?></h3></div><b class="is-<?php echo esc_attr( (string) $recommendation['risk'] ); ?>"><?php echo esc_html( sprintf( __( '%d%% confidence', 'kidia-mobile-cms' ), absint( $recommendation['confidence'] ) ) ); ?></b></header>
						<section class="kidia-ai-decision">
							<small><?php esc_html_e( 'Recommended decision', 'kidia-mobile-cms' ); ?></small>
							<strong><?php echo esc_html( (string) ( $recommendation['decision'] ?? $recommendation['title'] ) ); ?></strong>
						</section>
						<?php if ( ! empty( $recommendation['products'] ) ) : ?>
							<div class="kidia-ai-decision-products">
								<?php foreach ( (array) $recommendation['products'] as $product ) : ?>
									<article>
										<?php if ( ! empty( $product['image_url'] ) ) : ?><img src="<?php echo esc_url( (string) $product['image_url'] ); ?>" alt=""><?php else : ?><span class="dashicons dashicons-products"></span><?php endif; ?>
										<div><strong><?php echo esc_html( (string) ( $product['name'] ?? '' ) ); ?></strong><small><?php echo esc_html( wp_strip_all_tags( wc_price( (float) ( $product['price'] ?? 0 ) ) ) ); ?><?php if ( null !== ( $product['stock'] ?? null ) ) : ?> · <?php echo esc_html( sprintf( __( '%d in stock', 'kidia-mobile-cms' ), absint( $product['stock'] ) ) ); ?><?php endif; ?></small></div>
									</article>
								<?php endforeach; ?>
							</div>
						<?php endif; ?>
						<div class="kidia-ai-decision-metrics">
							<?php foreach ( (array) ( $recommendation['metrics'] ?? array() ) as $metric ) : ?><span><small><?php echo esc_html( (string) ( $metric['label'] ?? '' ) ); ?></small><b><?php echo esc_html( (string) ( $metric['value'] ?? '' ) ); ?></b></span><?php endforeach; ?>
						</div>
						<p><?php echo esc_html( (string) $recommendation['summary'] ); ?></p>
						<div><strong><?php esc_html_e( 'Why this recommendation', 'kidia-mobile-cms' ); ?></strong><ul><?php foreach ( (array) $recommendation['evidence'] as $evidence ) : ?><li><?php echo esc_html( (string) $evidence ); ?></li><?php endforeach; ?></ul><p class="kidia-ai-expected"><b><?php esc_html_e( 'Decision target:', 'kidia-mobile-cms' ); ?></b> <?php echo esc_html( (string) ( $recommendation['expected_outcome'] ?? '' ) ); ?></p></div>
						<p class="kidia-ai-success"><b><?php esc_html_e( 'Measure:', 'kidia-mobile-cms' ); ?></b> <?php echo esc_html( (string) ( $recommendation['success_metric'] ?? '' ) ); ?><br><b><?php esc_html_e( 'Guardrail:', 'kidia-mobile-cms' ); ?></b> <?php echo esc_html( (string) ( $recommendation['guardrail'] ?? '' ) ); ?></p>
						<details class="kidia-ai-action-builder">
							<summary class="button button-primary"><?php esc_html_e( 'Review & build', 'kidia-mobile-cms' ); ?></summary>
							<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
								<input type="hidden" name="action" value="kidia_mobile_build_ai_action">
								<input type="hidden" name="ai_offer_id" value="<?php echo esc_attr( (string) $recommendation['id'] ); ?>">
								<input type="hidden" name="ai_source" value="<?php echo esc_attr( $ai_source ); ?>">
								<input type="hidden" name="ai_from" value="<?php echo esc_attr( (string) $date_from ); ?>">
								<input type="hidden" name="ai_to" value="<?php echo esc_attr( (string) $date_to ); ?>">
								<?php wp_nonce_field( 'kidia_mobile_build_ai_action', 'kidia_mobile_ai_action_nonce' ); ?>
								<div class="kidia-ai-action-grid">
									<label><span><?php esc_html_e( 'Action name', 'kidia-mobile-cms' ); ?></span><input type="text" name="ai_action_name" value="<?php echo esc_attr( (string) $recommendation['title'] ); ?>"></label>
									<label><span><?php esc_html_e( 'Build as', 'kidia-mobile-cms' ); ?></span><select name="ai_action_type"><?php foreach ( array( 'coupon' => 'Coupon or discount', 'bundle' => 'Bundle', 'placement' => 'Recommendation placement', 'merchandising' => 'Merchandising action', 'shipping_rule' => 'Free-shipping rule', 'store_action' => 'Store improvement', 'schedule' => 'Campaign timing' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $recommended_action ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
									<label><span><?php esc_html_e( 'Channel', 'kidia-mobile-cms' ); ?></span><select name="ai_action_channel"><option value="all" <?php selected( 'all', $ai_source ); ?>>Website + Mobile App</option><option value="website" <?php selected( 'website', $ai_source ); ?>>Website only</option><option value="mobile" <?php selected( 'mobile', $ai_source ); ?>>Mobile App only</option></select></label>
									<label><span><?php esc_html_e( 'Placement', 'kidia-mobile-cms' ); ?></span><select name="ai_placement"><?php foreach ( array( 'home' => 'Home Page', 'product' => 'Product Page', 'category' => 'Category Page', 'search' => 'Search results', 'cart' => 'Cart', 'checkout' => 'Checkout', 'confirmation' => 'Order confirmation' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $recommendation['recommended_placement'] ?? 'home' ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
									<label><span><?php esc_html_e( 'Discount type', 'kidia-mobile-cms' ); ?></span><select name="ai_discount_type"><option value="percent" <?php selected( 'percent', $recommendation['discount_type'] ?? '' ); ?>>Percentage</option><option value="fixed_cart" <?php selected( 'fixed_cart', $recommendation['discount_type'] ?? '' ); ?>>Fixed cart</option><option value="fixed_product" <?php selected( 'fixed_product', $recommendation['discount_type'] ?? '' ); ?>>Fixed product</option></select></label>
									<label><span><?php esc_html_e( 'Discount value', 'kidia-mobile-cms' ); ?></span><input type="number" min="0" step=".01" name="ai_discount_value" value="<?php echo esc_attr( (string) ( $recommendation['discount_value'] ?? 0 ) ); ?>"></label>
									<label><span><?php esc_html_e( 'Duration (hours)', 'kidia-mobile-cms' ); ?></span><input type="number" min="1" max="720" name="ai_duration_hours" value="<?php echo esc_attr( (string) ( $recommendation['duration_hours'] ?? 48 ) ); ?>"></label>
									<label><span><?php esc_html_e( 'Bundle concept', 'kidia-mobile-cms' ); ?></span><select name="ai_bundle_type"><?php foreach ( array( 'fixed' => 'Fixed bundle', 'multipack' => 'Multipack', 'mix_match' => 'Mix & Match', 'build_box' => 'Build your box', 'buy_x_get_y' => 'Buy X from A + Y from B', 'bogo' => 'BOGO', 'frequently_bought' => 'Frequently bought together', 'complete_look' => 'Complete the look', 'composite' => 'Composite builder', 'quantity' => 'Quantity bundle', 'category' => 'Category bundle', 'gift' => 'Gift bundle', 'chained' => 'Chained products', 'addons' => 'Optional add-ons', 'mystery' => 'Mystery box', 'subscription' => 'Subscription bundle' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( 'frequently_bought', $value ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
									<label><span><?php esc_html_e( 'Minimum items', 'kidia-mobile-cms' ); ?></span><input type="number" min="1" name="ai_bundle_minimum" value="2"></label>
									<label><span><?php esc_html_e( 'Maximum items', 'kidia-mobile-cms' ); ?></span><input type="number" min="1" name="ai_bundle_maximum" value="<?php echo esc_attr( (string) max( 2, count( $product_ids ) ) ); ?>"></label>
									<label><span><?php esc_html_e( 'Bundle pricing', 'kidia-mobile-cms' ); ?></span><select name="ai_bundle_pricing"><option value="percentage">Percentage off</option><option value="fixed_discount">Fixed discount</option><option value="fixed">Fixed bundle price</option><option value="cheapest_free">Cheapest item free</option><option value="tiered">Tiered pricing</option><option value="none">No discount</option></select></label>
									<label><span><?php esc_html_e( 'Stock policy', 'kidia-mobile-cms' ); ?></span><select name="ai_bundle_stock_policy"><option value="all_components">Require every component</option><option value="hide_unavailable">Hide unavailable choices</option><option value="allow_backorder">Allow backorders</option></select></label>
									<label class="kidia-ai-check"><input type="checkbox" name="ai_bundle_variants" value="1" checked><span><?php esc_html_e( 'Allow variant selection', 'kidia-mobile-cms' ); ?></span></label>
									<label class="kidia-ai-check"><input type="checkbox" name="ai_coupon_stacking" value="1"><span><?php esc_html_e( 'Allow coupon stacking', 'kidia-mobile-cms' ); ?></span></label>
									<label><span><?php esc_html_e( 'Save status', 'kidia-mobile-cms' ); ?></span><select name="ai_action_status"><option value="draft">Save draft for review</option><option value="publish">Publish after this review</option></select></label>
									<label class="kidia-ai-check"><input type="checkbox" name="ai_promote_push" value="1"><span><?php esc_html_e( 'After saving, optionally promote this action with Push Notification', 'kidia-mobile-cms' ); ?></span></label>
								</div>
								<footer><p><?php esc_html_e( 'AI never publishes an action or sends a notification unless you choose it here.', 'kidia-mobile-cms' ); ?></p><button class="button button-primary" type="submit"><?php esc_html_e( 'Save reviewed action', 'kidia-mobile-cms' ); ?></button></footer>
							</form>
						</details>
						<footer><span><?php echo esc_html( sprintf( __( 'Profit risk: %s', 'kidia-mobile-cms' ), ucfirst( (string) $recommendation['risk'] ) ) ); ?></span><?php if ( $product_ids && get_edit_post_link( $product_ids[0] ) ) : ?><a class="button" href="<?php echo esc_url( get_edit_post_link( $product_ids[0] ) ); ?>"><?php esc_html_e( 'Review product', 'kidia-mobile-cms' ); ?></a><?php endif; ?></footer>
					</article>
				<?php endforeach; ?>
					</div>
					<?php endif; ?>
				</section>
			<?php endforeach; ?>
			</div>
		<?php else : ?>
			<div class="kidia-ai-empty"><span class="dashicons dashicons-database"></span><div><strong><?php esc_html_e( 'No recommendation matches these filters yet', 'kidia-mobile-cms' ); ?></strong><p><?php esc_html_e( 'Widen the period or wait for more real store activity. The studio does not invent evidence.', 'kidia-mobile-cms' ); ?></p></div></div>
		<?php endif; ?>
	</section>
	</div>
	<section class="kidia-ai-results-panel" data-ai-workspace-panel="results" hidden>
		<header><div><span class="dashicons dashicons-chart-line"></span><div><h2><?php esc_html_e( 'Actions & Results', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Every approved decision stays here with its execution status, measured outcome and next recommended step.', 'kidia-mobile-cms' ); ?></p></div></div></header>
		<?php if ( $ai_action_history ) : ?>
			<div class="kidia-ai-result-list">
				<?php foreach ( $ai_action_history as $history_id => $history_row ) :
					$result = $action_result( (array) $history_row );
					$history_recommendation = is_array( $history_row['recommendation'] ?? null ) ? $history_row['recommendation'] : array();
					?>
					<article class="is-<?php echo esc_attr( (string) $result['state'] ); ?>">
						<header><div><small><?php echo esc_html( strtoupper( (string) ( $history_row['type'] ?? 'action' ) ) ); ?> · <?php echo esc_html( strtoupper( (string) ( $history_row['channel'] ?? 'all' ) ) ); ?></small><h3><?php echo esc_html( (string) ( $history_row['name'] ?? 'AI action' ) ); ?></h3></div><b><?php echo esc_html( ucfirst( (string) ( $history_row['status'] ?? 'draft' ) ) ); ?></b></header>
						<div class="kidia-ai-result-metrics">
							<span><small><?php esc_html_e( 'Measured conversions', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) absint( $result['uses'] ?? 0 ) ); ?></strong></span>
							<span><small><?php esc_html_e( 'Placement', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( ucfirst( (string) ( $history_row['placement'] ?? 'home' ) ) ); ?></strong></span>
							<span><small><?php esc_html_e( 'Started', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( absint( $history_row['created_at'] ?? 0 ) ? wp_date( get_option( 'date_format' ), absint( $history_row['created_at'] ) ) : '—' ); ?></strong></span>
						</div>
						<?php if ( ! empty( $history_recommendation['products'] ) ) : ?>
							<div class="kidia-ai-result-products">
								<strong><?php esc_html_e( 'Products included in this action', 'kidia-mobile-cms' ); ?></strong>
								<div>
									<?php foreach ( (array) $history_recommendation['products'] as $product ) : ?>
										<span>
											<?php if ( ! empty( $product['image_url'] ) ) : ?><img src="<?php echo esc_url( (string) $product['image_url'] ); ?>" alt=""><?php endif; ?>
											<?php echo esc_html( (string) ( $product['name'] ?? '' ) ); ?>
										</span>
									<?php endforeach; ?>
								</div>
							</div>
						<?php endif; ?>
						<?php if ( ! empty( $history_row['publication']['target'] ) ) : ?><p><b><?php esc_html_e( 'Published to:', 'kidia-mobile-cms' ); ?></b> <?php echo esc_html( ucfirst( (string) $history_row['publication']['target'] ) ); ?></p><?php endif; ?>
						<p><b><?php esc_html_e( 'Next decision:', 'kidia-mobile-cms' ); ?></b> <?php echo esc_html( (string) $result['label'] ); ?></p>
						<?php if ( ! empty( $history_recommendation['success_metric'] ) ) : ?><small><?php echo esc_html( (string) $history_recommendation['success_metric'] ); ?></small><?php endif; ?>
						<footer>
							<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
								<input type="hidden" name="action" value="kidia_mobile_review_ai_result">
								<input type="hidden" name="history_id" value="<?php echo esc_attr( (string) $history_id ); ?>">
								<?php wp_nonce_field( 'kidia_mobile_review_ai_result', 'kidia_mobile_ai_result_nonce' ); ?>
								<button class="button" type="submit" name="result_decision" value="continue"><?php esc_html_e( 'Approve continue', 'kidia-mobile-cms' ); ?></button>
								<button class="button button-secondary" type="submit" name="result_decision" value="stop"><?php esc_html_e( 'Approve stop', 'kidia-mobile-cms' ); ?></button>
							</form>
						</footer>
					</article>
				<?php endforeach; ?>
			</div>
		<?php else : ?>
			<div class="kidia-ai-empty"><span class="dashicons dashicons-chart-line"></span><div><strong><?php esc_html_e( 'No approved actions yet', 'kidia-mobile-cms' ); ?></strong><p><?php esc_html_e( 'Build and approve a generated decision; its execution and results will appear here.', 'kidia-mobile-cms' ); ?></p></div></div>
		<?php endif; ?>
	</section>
	<?php else : ?>
		<section class="kidia-ai-ready-state">
			<span class="dashicons dashicons-chart-area"></span>
			<div>
				<h2><?php esc_html_e( 'Ready to build data-backed offers', 'kidia-mobile-cms' ); ?></h2>
				<p><?php esc_html_e( 'Choose the channel and period, then analyze the store and generate executable offers. AI Studio stays light until you start this process.', 'kidia-mobile-cms' ); ?></p>
			</div>
		</section>
	<?php endif; ?>

	<details class="kidia-ai-bundle-studio">
		<summary><div><span class="dashicons dashicons-products"></span><div><h2><?php esc_html_e( 'Optional manual bundle builder', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'AI recommendations are generated above. Open this only when you want to create a bundle without an analytical recommendation.', 'kidia-mobile-cms' ); ?></p></div></div><b><?php echo esc_html( sprintf( _n( '%d saved bundle', '%d saved bundles', count( $bundle_recipes ), 'kidia-mobile-cms' ), count( $bundle_recipes ) ) ); ?></b></summary>
		<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
			<input type="hidden" name="action" value="kidia_mobile_save_bundle_recipe"><?php wp_nonce_field( 'kidia_mobile_save_bundle_recipe', 'kidia_mobile_bundle_nonce' ); ?>
			<div class="kidia-ai-bundle-grid">
				<label><span><?php esc_html_e( 'Bundle name', 'kidia-mobile-cms' ); ?></span><input type="text" name="bundle[name]" required></label>
				<label><span><?php esc_html_e( 'Concept', 'kidia-mobile-cms' ); ?></span><select name="bundle[type]"><?php foreach ( array( 'fixed' => 'Fixed bundle', 'multipack' => 'Multipack', 'mix_match' => 'Mix & Match', 'build_box' => 'Build your box', 'buy_x_get_y' => 'Buy X from A + Y from B', 'bogo' => 'BOGO', 'frequently_bought' => 'Frequently bought together', 'complete_look' => 'Complete the look', 'composite' => 'Composite step builder', 'quantity' => 'Quantity bundle', 'category' => 'Category bundle', 'gift' => 'Gift bundle', 'chained' => 'Chained products', 'addons' => 'Optional add-ons', 'mystery' => 'Mystery box', 'subscription' => 'Subscription bundle', 'ai' => 'AI-selected bundle' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>"><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
				<label><span><?php esc_html_e( 'Product IDs', 'kidia-mobile-cms' ); ?></span><input type="text" name="bundle[product_ids]" placeholder="12, 45, 98"></label>
				<label><span><?php esc_html_e( 'Category IDs', 'kidia-mobile-cms' ); ?></span><input type="text" name="bundle[category_ids]" placeholder="3, 7"></label>
				<label><span><?php esc_html_e( 'Minimum items', 'kidia-mobile-cms' ); ?></span><input type="number" min="1" name="bundle[minimum_items]" value="2"></label>
				<label><span><?php esc_html_e( 'Maximum items', 'kidia-mobile-cms' ); ?></span><input type="number" min="1" name="bundle[maximum_items]" value="2"></label>
				<label><span><?php esc_html_e( 'Pricing rule', 'kidia-mobile-cms' ); ?></span><select name="bundle[pricing]"><option value="percentage">Percentage off</option><option value="fixed_discount">Fixed discount</option><option value="fixed">Fixed bundle price</option><option value="cheapest_free">Cheapest free</option><option value="tiered">Tiered</option><option value="none">No discount</option></select></label>
				<label><span><?php esc_html_e( 'Value', 'kidia-mobile-cms' ); ?></span><input type="number" min="0" step=".01" name="bundle[discount_value]" value="10"></label>
				<label><span><?php esc_html_e( 'Channel', 'kidia-mobile-cms' ); ?></span><select name="bundle[channel]"><option value="all">Website + Mobile App</option><option value="website">Website only</option><option value="mobile">Mobile App only</option></select></label>
				<label><span><?php esc_html_e( 'Stock policy', 'kidia-mobile-cms' ); ?></span><select name="bundle[stock_policy]"><option value="all_components">Require all components</option><option value="hide_unavailable">Hide unavailable choices</option><option value="allow_backorder">Allow backorders</option></select></label>
				<label><span><?php esc_html_e( 'Starts at', 'kidia-mobile-cms' ); ?></span><input type="datetime-local" name="bundle[starts_at]"></label>
				<label><span><?php esc_html_e( 'Ends at', 'kidia-mobile-cms' ); ?></span><input type="datetime-local" name="bundle[ends_at]"></label>
				<label class="kidia-ai-check"><input type="checkbox" name="bundle[allow_variants]" value="1" checked><span><?php esc_html_e( 'Customers may choose variants', 'kidia-mobile-cms' ); ?></span></label>
				<label class="kidia-ai-check"><input type="checkbox" name="bundle[allow_repeats]" value="1"><span><?php esc_html_e( 'Allow repeated products', 'kidia-mobile-cms' ); ?></span></label>
				<label class="kidia-ai-check"><input type="checkbox" name="bundle[coupon_stacking]" value="1"><span><?php esc_html_e( 'Allow coupon stacking', 'kidia-mobile-cms' ); ?></span></label>
				<label class="kidia-ai-check"><input type="checkbox" name="bundle[create_product]" value="1"><span><?php esc_html_e( 'Create a WooCommerce product for fixed bundles', 'kidia-mobile-cms' ); ?></span></label>
				<label><span><?php esc_html_e( 'Status', 'kidia-mobile-cms' ); ?></span><select name="bundle[status]"><option value="draft">Draft</option><option value="published">Published</option></select></label>
			</div>
			<label class="kidia-ai-bundle-description"><span><?php esc_html_e( 'Customer-facing description', 'kidia-mobile-cms' ); ?></span><textarea name="bundle[description]" rows="3"></textarea></label>
			<footer><button class="button button-primary" type="submit"><?php esc_html_e( 'Save bundle recipe', 'kidia-mobile-cms' ); ?></button></footer>
		</form>
	</details>
</div>
