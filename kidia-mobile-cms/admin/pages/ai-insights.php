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
$playbook_groups = Kidia_Mobile_AI_Offer_Engine::playbook_groups();
$playbook_count = array_sum( array_map( static fn( $group ) => count( $group['items'] ?? array() ), $playbook_groups ) );
$bundle_recipes = Kidia_Mobile_Bundle_Recipes::all();
?>
<div class="wrap kidia-ai-page">
	<header class="kidia-ai-page__hero">
		<div><span class="dashicons dashicons-lightbulb"></span><div><h1><?php esc_html_e( 'AI Offer Studio', 'kidia-mobile-cms' ); ?></h1><p><?php esc_html_e( 'Store-local growth intelligence for offers, merchandising, inventory and funnel decisions. Nothing is activated without your review.', 'kidia-mobile-cms' ); ?></p></div></div>
		<div class="kidia-ai-page__trust"><strong><?php echo esc_html( (string) $ai_signal_count ); ?>+</strong><span><?php esc_html_e( 'documented signals', 'kidia-mobile-cms' ); ?></span></div>
	</header>

	<?php if ( isset( $_GET['updated'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'AI analysis settings saved.', 'kidia-mobile-cms' ); ?></p></div><?php endif; ?>
	<?php if ( isset( $_GET['ai_action_saved'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'The reviewed AI action was saved. Nothing else was activated automatically.', 'kidia-mobile-cms' ); ?></p></div><?php endif; ?>
	<?php if ( isset( $_GET['bundle_saved'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Bundle recipe saved and is ready for Home Page or app placement.', 'kidia-mobile-cms' ); ?></p></div><?php endif; ?>

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
		<header><div><h2><?php esc_html_e( 'Decision-ready recommendations', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Each card explains the evidence, confidence and risk. Recommendations without enough real data are not shown.', 'kidia-mobile-cms' ); ?></p></div><details class="kidia-ai-playbooks"><summary><?php echo esc_html( sprintf( __( '%d supported playbooks', 'kidia-mobile-cms' ), $playbook_count ) ); ?></summary><div class="kidia-ai-playbook-groups"><?php foreach ( $playbook_groups as $group ) : ?><section><h3><?php echo esc_html( (string) $group['label'] ); ?></h3><div><?php foreach ( (array) $group['items'] as $playbook ) : ?><span><?php echo esc_html( $playbook ); ?></span><?php endforeach; ?></div></section><?php endforeach; ?></div></details></header>
		<?php if ( $ai_recommendations ) : ?>
			<div class="kidia-ai-recommendations kidia-ai-recommendations--workspace">
				<?php foreach ( $ai_recommendations as $recommendation ) :
					$kind = sanitize_key( (string) ( $recommendation['kind'] ?? 'campaign' ) );
					$product_ids = array_values( array_filter( array_map( 'absint', (array) ( $recommendation['product_ids'] ?? array() ) ) ) );
					$recommended_action = sanitize_key( (string) ( $recommendation['implementation'] ?? 'store_action' ) );
					?>
					<article class="kidia-ai-decision-card is-<?php echo esc_attr( $kind ); ?>">
						<header><span class="dashicons <?php echo esc_attr( $kind_icons[ $kind ] ?? 'dashicons-lightbulb' ); ?>"></span><div><small><?php echo esc_html( $kind_labels[ $kind ] ?? ucfirst( $kind ) ); ?></small><h3><?php echo esc_html( (string) $recommendation['title'] ); ?></h3></div><b class="is-<?php echo esc_attr( (string) $recommendation['risk'] ); ?>"><?php echo esc_html( sprintf( __( '%d%% confidence', 'kidia-mobile-cms' ), absint( $recommendation['confidence'] ) ) ); ?></b></header>
						<p><?php echo esc_html( (string) $recommendation['summary'] ); ?></p>
						<div><strong><?php esc_html_e( 'Why this recommendation', 'kidia-mobile-cms' ); ?></strong><ul><?php foreach ( (array) $recommendation['evidence'] as $evidence ) : ?><li><?php echo esc_html( (string) $evidence ); ?></li><?php endforeach; ?></ul><p class="kidia-ai-expected"><b><?php esc_html_e( 'Decision target:', 'kidia-mobile-cms' ); ?></b> <?php echo esc_html( (string) ( $recommendation['expected_outcome'] ?? '' ) ); ?></p></div>
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
									<label><span><?php esc_html_e( 'Discount type', 'kidia-mobile-cms' ); ?></span><select name="ai_discount_type"><option value="percent">Percentage</option><option value="fixed_cart">Fixed cart</option><option value="fixed_product">Fixed product</option></select></label>
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
		<?php else : ?>
			<div class="kidia-ai-empty"><span class="dashicons dashicons-database"></span><div><strong><?php esc_html_e( 'No recommendation matches these filters yet', 'kidia-mobile-cms' ); ?></strong><p><?php esc_html_e( 'Lower the confidence filter, widen the period or wait for more real store activity. The studio does not invent evidence.', 'kidia-mobile-cms' ); ?></p></div></div>
		<?php endif; ?>
	</section>

	<section class="kidia-ai-bundle-studio">
		<header><div><span class="dashicons dashicons-products"></span><div><h2><?php esc_html_e( 'Universal Bundle Builder', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Create any bundle concept manually or start from an AI recommendation. Fixed bundles can behave like a product; choice bundles open a customer selection page.', 'kidia-mobile-cms' ); ?></p></div></div><b><?php echo esc_html( sprintf( _n( '%d saved bundle', '%d saved bundles', count( $bundle_recipes ), 'kidia-mobile-cms' ), count( $bundle_recipes ) ) ); ?></b></header>
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
