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
$views = absint( $event( 'view_item' )['unique'] );
$carts = absint( $event( 'add_to_cart' )['unique'] );
$checks = absint( $event( 'begin_checkout' )['unique'] );
$buys = absint( $event( 'purchase' )['unique'] );
$funnel = array(
	array( __( 'Visitors', 'kidia-mobile-cms' ), absint( $ai_summary['visitors'] ), 100 ),
	array( __( 'Viewed product', 'kidia-mobile-cms' ), $views, $rate( $views, absint( $ai_summary['visitors'] ) ) ),
	array( __( 'Added to cart', 'kidia-mobile-cms' ), $carts, $rate( $carts, absint( $ai_summary['visitors'] ) ) ),
	array( __( 'Started checkout', 'kidia-mobile-cms' ), $checks, $rate( $checks, absint( $ai_summary['visitors'] ) ) ),
	array( __( 'Purchased', 'kidia-mobile-cms' ), $buys, $rate( $buys, absint( $ai_summary['visitors'] ) ) ),
);
$playbooks = array(
	'Frequently bought together', 'Complementary bundle', 'Category cross-sell', 'Search-demand merchandising',
	'Slow-stock rescue', 'Low-stock urgency', 'Restock priority', 'Seasonal clearance',
	'High view / low purchase', 'Cart recovery', 'Checkout rescue', 'Registration friction',
	'Free shipping threshold', 'AOV lift', 'BOGO', 'Quantity break',
	'First purchase', 'VIP', 'Win-back', 'New launch', 'Peak-time scheduling',
);
?>
<div class="wrap kidia-ai-page">
	<header class="kidia-ai-page__hero">
		<div><span class="dashicons dashicons-lightbulb"></span><div><h1><?php esc_html_e( 'AI Offer Studio', 'kidia-mobile-cms' ); ?></h1><p><?php esc_html_e( 'Store-local growth intelligence for offers, merchandising, inventory and funnel decisions. Nothing is activated without your review.', 'kidia-mobile-cms' ); ?></p></div></div>
		<div class="kidia-ai-page__trust"><strong><?php echo esc_html( (string) $ai_signal_count ); ?>+</strong><span><?php esc_html_e( 'documented signals', 'kidia-mobile-cms' ); ?></span></div>
	</header>

	<?php if ( isset( $_GET['updated'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'AI analysis settings saved.', 'kidia-mobile-cms' ); ?></p></div><?php endif; ?>

	<form class="kidia-date-filter kidia-ai-filter-bar" method="get">
		<input type="hidden" name="page" value="kidia-mobile-ai-insights">
		<label><span><?php esc_html_e( 'Channel', 'kidia-mobile-cms' ); ?></span><select name="ai_source"><?php foreach ( $source_labels as $key => $label ) : ?><option value="<?php echo esc_attr( $key ); ?>" <?php selected( $ai_source, $key ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
		<label><span><?php esc_html_e( 'Recommendation type', 'kidia-mobile-cms' ); ?></span><select name="ai_kind"><?php foreach ( $kind_labels as $key => $label ) : ?><option value="<?php echo esc_attr( $key ); ?>" <?php selected( $ai_kind, $key ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
		<label><span><?php esc_html_e( 'Minimum confidence', 'kidia-mobile-cms' ); ?></span><select name="minimum_confidence"><?php foreach ( array( 30, 40, 50, 60, 70, 80, 90 ) as $confidence ) : ?><option value="<?php echo esc_attr( (string) $confidence ); ?>" <?php selected( $minimum_confidence, $confidence ); ?>><?php echo esc_html( $confidence . '%+' ); ?></option><?php endforeach; ?></select></label>
		<label><span><?php esc_html_e( 'Period', 'kidia-mobile-cms' ); ?></span><select name="date_preset"><?php foreach ( $date_labels as $key => $label ) : ?><option value="<?php echo esc_attr( $key ); ?>" <?php selected( $date_preset, $key ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
		<label><span><?php esc_html_e( 'From', 'kidia-mobile-cms' ); ?></span><input type="date" name="date_from" value="<?php echo esc_attr( wp_date( 'Y-m-d', $date_from ) ); ?>" <?php disabled( 'custom' !== $date_preset ); ?>></label>
		<label><span><?php esc_html_e( 'To', 'kidia-mobile-cms' ); ?></span><input type="date" name="date_to" value="<?php echo esc_attr( wp_date( 'Y-m-d', $date_to ) ); ?>" <?php disabled( 'custom' !== $date_preset ); ?>></label>
		<button class="button button-primary" type="submit"><?php esc_html_e( 'Apply', 'kidia-mobile-cms' ); ?></button>
	</form>

	<section class="kidia-ai-overview">
		<article><span class="dashicons dashicons-database"></span><div><small><?php esc_html_e( 'Signals in period', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) $ai_signal_volume ); ?></strong></div></article>
		<article><span class="dashicons dashicons-lightbulb"></span><div><small><?php esc_html_e( 'Recommendations found', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) count( $all_recommendations ) ); ?></strong></div></article>
		<article><span class="dashicons dashicons-groups"></span><div><small><?php esc_html_e( 'Visitors', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) absint( $ai_summary['visitors'] ) ); ?></strong></div></article>
		<article><span class="dashicons dashicons-cart"></span><div><small><?php esc_html_e( 'Tracked purchases', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) absint( $event( 'purchase' )['count'] ) ); ?></strong></div></article>
	</section>

	<div class="kidia-ai-analysis-grid">
		<section class="kidia-ai-funnel-panel">
			<header><div><span class="dashicons dashicons-filter"></span><div><h2><?php esc_html_e( 'Sales funnel', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'See where measured customers stop before buying.', 'kidia-mobile-cms' ); ?></p></div></div></header>
			<div><?php foreach ( $funnel as $step ) : ?><article><span><strong><?php echo esc_html( $step[0] ); ?></strong><small><?php echo esc_html( (string) $step[1] ); ?></small></span><i><b style="width:<?php echo esc_attr( (string) min( 100, $step[2] ) ); ?>%"></b></i><em><?php echo esc_html( $step[2] . '%' ); ?></em></article><?php endforeach; ?></div>
		</section>
		<section class="kidia-ai-demand-panel">
			<header><div><span class="dashicons dashicons-chart-line"></span><div><h2><?php esc_html_e( 'Demand signals', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'What customers view, search for and buy in this period.', 'kidia-mobile-cms' ); ?></p></div></div></header>
			<div>
				<article><small><?php esc_html_e( 'Top viewed product', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) ( $ai_summary['top_products'][0]['event_label'] ?? '—' ) ); ?></strong><span><?php echo esc_html( (string) absint( $ai_summary['top_products'][0]['event_count'] ?? 0 ) ); ?> <?php esc_html_e( 'views', 'kidia-mobile-cms' ); ?></span></article>
				<article><small><?php esc_html_e( 'Top search', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) ( $ai_summary['top_searches'][0]['event_label'] ?? '—' ) ); ?></strong><span><?php echo esc_html( (string) absint( $ai_summary['top_searches'][0]['event_count'] ?? 0 ) ); ?> <?php esc_html_e( 'searches', 'kidia-mobile-cms' ); ?></span></article>
				<article><small><?php esc_html_e( 'Top category', 'kidia-mobile-cms' ); ?></small><strong><?php echo esc_html( (string) ( $ai_summary['top_categories'][0]['event_label'] ?? '—' ) ); ?></strong><span><?php echo esc_html( (string) absint( $ai_summary['top_categories'][0]['event_count'] ?? 0 ) ); ?> <?php esc_html_e( 'views', 'kidia-mobile-cms' ); ?></span></article>
			</div>
		</section>
	</div>

	<section class="kidia-ai-recommendation-section">
		<header><div><h2><?php esc_html_e( 'Decision-ready recommendations', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Each card explains the evidence, confidence and risk. Recommendations without enough real data are not shown.', 'kidia-mobile-cms' ); ?></p></div><details class="kidia-ai-playbooks"><summary><?php echo esc_html( sprintf( __( '%d supported playbooks', 'kidia-mobile-cms' ), count( $playbooks ) ) ); ?></summary><div><?php foreach ( $playbooks as $playbook ) : ?><span><?php echo esc_html( $playbook ); ?></span><?php endforeach; ?></div></details></header>
		<?php if ( $ai_recommendations ) : ?>
			<div class="kidia-ai-recommendations kidia-ai-recommendations--workspace">
				<?php foreach ( $ai_recommendations as $recommendation ) :
					$kind = sanitize_key( (string) ( $recommendation['kind'] ?? 'campaign' ) );
					$product_ids = array_values( array_filter( array_map( 'absint', (array) ( $recommendation['product_ids'] ?? array() ) ) ) );
					$is_offer = ! empty( $recommendation['is_offer'] );
					if ( $is_offer ) {
						$action_url = add_query_arg(
							array(
								'page'        => 'kidia-mobile-push-notifications',
								'ai_offer_id' => (string) $recommendation['id'],
								'ai_source'   => $ai_source,
								'ai_from'     => $date_from,
								'ai_to'       => $date_to,
							),
							admin_url( 'admin.php' )
						);
						$action_label = __( 'Prepare campaign', 'kidia-mobile-cms' );
					} elseif ( $product_ids && get_edit_post_link( $product_ids[0] ) ) {
						$action_url = get_edit_post_link( $product_ids[0] );
						$action_label = __( 'Review product', 'kidia-mobile-cms' );
					} else {
						$action_url = add_query_arg( array( 'page' => 'kidia-mobile-store-data', 'store_tab' => 'analytics', 'store_source' => $ai_source, 'date_preset' => $date_preset ), admin_url( 'admin.php' ) );
						$action_label = __( 'Open supporting analytics', 'kidia-mobile-cms' );
					}
					?>
					<article class="kidia-ai-decision-card is-<?php echo esc_attr( $kind ); ?>">
						<header><span class="dashicons <?php echo esc_attr( $kind_icons[ $kind ] ?? 'dashicons-lightbulb' ); ?>"></span><div><small><?php echo esc_html( $kind_labels[ $kind ] ?? ucfirst( $kind ) ); ?></small><h3><?php echo esc_html( (string) $recommendation['title'] ); ?></h3></div><b class="is-<?php echo esc_attr( (string) $recommendation['risk'] ); ?>"><?php echo esc_html( sprintf( __( '%d%% confidence', 'kidia-mobile-cms' ), absint( $recommendation['confidence'] ) ) ); ?></b></header>
						<p><?php echo esc_html( (string) $recommendation['summary'] ); ?></p>
						<div><strong><?php esc_html_e( 'Why this recommendation', 'kidia-mobile-cms' ); ?></strong><ul><?php foreach ( (array) $recommendation['evidence'] as $evidence ) : ?><li><?php echo esc_html( (string) $evidence ); ?></li><?php endforeach; ?></ul><p class="kidia-ai-expected"><b><?php esc_html_e( 'Decision target:', 'kidia-mobile-cms' ); ?></b> <?php echo esc_html( (string) ( $recommendation['expected_outcome'] ?? '' ) ); ?></p></div>
						<footer><span><?php echo esc_html( sprintf( __( 'Profit risk: %s', 'kidia-mobile-cms' ), ucfirst( (string) $recommendation['risk'] ) ) ); ?></span><a class="button button-primary" href="<?php echo esc_url( $action_url ); ?>"><?php echo esc_html( $action_label ); ?></a></footer>
					</article>
				<?php endforeach; ?>
			</div>
		<?php else : ?>
			<div class="kidia-ai-empty"><span class="dashicons dashicons-database"></span><div><strong><?php esc_html_e( 'No recommendation matches these filters yet', 'kidia-mobile-cms' ); ?></strong><p><?php esc_html_e( 'Lower the confidence filter, widen the period or wait for more real store activity. The studio does not invent evidence.', 'kidia-mobile-cms' ); ?></p></div></div>
		<?php endif; ?>
	</section>

	<details class="kidia-ai-settings">
		<summary><span class="dashicons dashicons-admin-generic"></span><div><strong><?php esc_html_e( 'Analysis settings', 'kidia-mobile-cms' ); ?></strong><small><?php esc_html_e( 'Control when the engine is allowed to recommend an action.', 'kidia-mobile-cms' ); ?></small></div></summary>
		<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
			<input type="hidden" name="action" value="kidia_mobile_save_ai_insights"><?php wp_nonce_field( 'kidia_mobile_save_ai_insights', 'kidia_mobile_ai_nonce' ); ?>
			<div>
				<label><span><?php esc_html_e( 'Minimum confidence', 'kidia-mobile-cms' ); ?></span><input type="number" min="30" max="95" name="ai_settings[minimum_confidence]" value="<?php echo esc_attr( (string) $ai_settings['minimum_confidence'] ); ?>"></label>
				<label><span><?php esc_html_e( 'Maximum recommendations', 'kidia-mobile-cms' ); ?></span><input type="number" min="4" max="24" name="ai_settings[maximum_recommendations]" value="<?php echo esc_attr( (string) $ai_settings['maximum_recommendations'] ); ?>"></label>
				<label><span><?php esc_html_e( 'High-interest minimum views', 'kidia-mobile-cms' ); ?></span><input type="number" min="3" max="1000" name="ai_settings[high_interest_min_views]" value="<?php echo esc_attr( (string) $ai_settings['high_interest_min_views'] ); ?>"></label>
				<label><span><?php esc_html_e( 'Low-conversion threshold (%)', 'kidia-mobile-cms' ); ?></span><input type="number" min="1" max="50" name="ai_settings[low_conversion_percent]" value="<?php echo esc_attr( (string) $ai_settings['low_conversion_percent'] ); ?>"></label>
				<label><span><?php esc_html_e( 'Slow-stock minimum age (days)', 'kidia-mobile-cms' ); ?></span><input type="number" min="14" max="730" name="ai_settings[slow_stock_min_age_days]" value="<?php echo esc_attr( (string) $ai_settings['slow_stock_min_age_days'] ); ?>"></label>
				<label><span><?php esc_html_e( 'Slow-stock minimum units', 'kidia-mobile-cms' ); ?></span><input type="number" min="1" max="1000" name="ai_settings[slow_stock_min_units]" value="<?php echo esc_attr( (string) $ai_settings['slow_stock_min_units'] ); ?>"></label>
				<label class="kidia-ai-margin-check"><input type="checkbox" name="ai_settings[protect_margin]" value="1" <?php checked( ! empty( $ai_settings['protect_margin'] ) ); ?>><span><?php esc_html_e( 'Prefer non-discount actions and protect margin', 'kidia-mobile-cms' ); ?></span></label>
			</div>
			<button class="button button-primary" type="submit"><?php esc_html_e( 'Save analysis settings', 'kidia-mobile-cms' ); ?></button>
		</form>
	</details>
</div>
