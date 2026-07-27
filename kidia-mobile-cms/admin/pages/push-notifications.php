<?php
/** Push notification management screen. */
defined( 'ABSPATH' ) || exit;
$push_types = array(
	'broadcast' => array( __( 'Broadcast', 'kidia-mobile-cms' ), 'dashicons-megaphone', __( 'One message for everyone', 'kidia-mobile-cms' ) ),
	'offer' => array( __( 'Offer', 'kidia-mobile-cms' ), 'dashicons-tickets-alt', __( 'Sale, coupon or product', 'kidia-mobile-cms' ) ),
	'ai_offer' => array( __( 'AI Offer', 'kidia-mobile-cms' ), 'dashicons-lightbulb', __( 'Evidence-based offer idea', 'kidia-mobile-cms' ) ),
	'order' => array( __( 'Order update', 'kidia-mobile-cms' ), 'dashicons-cart', __( 'Status and delivery alerts', 'kidia-mobile-cms' ) ),
	'restock' => array( __( 'Back in stock', 'kidia-mobile-cms' ), 'dashicons-products', __( 'Notify product followers', 'kidia-mobile-cms' ) ),
	'abandoned_cart' => array( __( 'Abandoned cart', 'kidia-mobile-cms' ), 'dashicons-cart', __( 'Recover unfinished carts', 'kidia-mobile-cms' ) ),
	'welcome' => array( __( 'Welcome', 'kidia-mobile-cms' ), 'dashicons-heart', __( 'Greet new app customers', 'kidia-mobile-cms' ) ),
	'custom' => array( __( 'Custom', 'kidia-mobile-cms' ), 'dashicons-admin-generic', __( 'Build your own message', 'kidia-mobile-cms' ) ),
);
$supported_playbooks = array(
	'Frequently bought together',
	'Slow-stock rescue',
	'High view / low purchase',
	'Cart recovery',
	'Checkout rescue',
	'BOGO',
	'Quantity break',
	'Free shipping threshold',
	'AOV lift',
	'Complementary bundle',
	'New launch',
	'VIP',
	'First purchase',
	'Win-back',
	'Category cross-sell',
	'Low-stock urgency',
	'Seasonal clearance',
);
$available_offer_schemes = array();
foreach ( $ai_offers as $offer ) {
	$available_offer_schemes[ $offer['scheme'] ] = ucwords( str_replace( '_', ' ', $offer['scheme'] ) );
}
?>
<div class="wrap kidia-push-page">
	<header class="kidia-push-hero"><div><span class="dashicons dashicons-megaphone"></span><div><h1><?php esc_html_e( 'Push Notifications', 'kidia-mobile-cms' ); ?></h1><p><?php esc_html_e( 'Choose a notification type, write the message and decide when it should run.', 'kidia-mobile-cms' ); ?></p></div></div></header>
	<?php if ( ! $provider_connected ) : ?><div class="kidia-push-connection-note"><span class="dashicons dashicons-info-outline"></span><div><strong><?php esc_html_e( 'Push delivery is not connected yet', 'kidia-mobile-cms' ); ?></strong><p><?php esc_html_e( 'You can prepare and save messages here, but WordPress needs a push-delivery integration before it can send them to registered devices.', 'kidia-mobile-cms' ); ?></p></div></div><?php endif; ?>
	<?php if ( isset( $_GET['push_sent'] ) ) : ?><div class="kidia-toast is-visible"><span class="dashicons dashicons-yes-alt"></span><?php esc_html_e( 'Notification saved successfully.', 'kidia-mobile-cms' ); ?></div><?php elseif ( isset( $_GET['push_error'] ) ) : ?><div class="notice notice-error"><p><?php esc_html_e( 'Check the required fields and scheduled time.', 'kidia-mobile-cms' ); ?></p></div><?php endif; ?>
	<div class="kidia-push-stats"><div><span class="dashicons dashicons-groups"></span><b><?php echo esc_html( (string) $subscribed_customers ); ?></b><small><?php esc_html_e( 'Subscribed customers', 'kidia-mobile-cms' ); ?></small></div><div><span class="dashicons dashicons-smartphone"></span><b><?php echo esc_html( (string) $registered_devices ); ?></b><small><?php esc_html_e( 'Registered devices', 'kidia-mobile-cms' ); ?></small></div><div><span class="dashicons dashicons-controls-repeat"></span><b><?php echo esc_html( (string) count( $automations ) ); ?></b><small><?php esc_html_e( 'Active automations', 'kidia-mobile-cms' ); ?></small></div></div>
	<section class="kidia-ai-offer-studio">
		<header><div><span class="dashicons dashicons-lightbulb"></span><div><h2><?php esc_html_e( 'AI Offer Studio', 'kidia-mobile-cms' ); ?></h2><p><?php echo esc_html( sprintf( __( 'Explainable recommendations from %d sales, stock, funnel, timing and customer signals. Store data stays on this website.', 'kidia-mobile-cms' ), $ai_signal_count ) ); ?></p></div></div><nav class="kidia-source-filter" aria-label="<?php esc_attr_e( 'Recommendation source', 'kidia-mobile-cms' ); ?>"><?php foreach ( array( 'all' => __( 'All', 'kidia-mobile-cms' ), 'website' => __( 'Website', 'kidia-mobile-cms' ), 'mobile' => __( 'Mobile App', 'kidia-mobile-cms' ) ) as $key => $label ) : ?><a class="<?php echo $key === $ai_source ? 'is-active' : ''; ?>" href="<?php echo esc_url( add_query_arg( array( 'page' => 'kidia-mobile-push-notifications', 'ai_source' => $key ), admin_url( 'admin.php' ) ) ); ?>"><?php echo esc_html( $label ); ?></a><?php endforeach; ?></nav></header>
		<div class="kidia-ai-toolbar">
			<label><span><?php esc_html_e( 'Offer type', 'kidia-mobile-cms' ); ?></span><select data-ai-scheme-filter><option value="all"><?php esc_html_e( 'All recommendations', 'kidia-mobile-cms' ); ?></option><?php foreach ( $available_offer_schemes as $scheme => $label ) : ?><option value="<?php echo esc_attr( $scheme ); ?>"><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
			<details class="kidia-ai-schemes"><summary><?php echo esc_html( sprintf( __( 'View %d supported offer strategies', 'kidia-mobile-cms' ), count( $supported_playbooks ) ) ); ?></summary><div><?php foreach ( $supported_playbooks as $scheme ) : ?><span><?php echo esc_html( $scheme ); ?></span><?php endforeach; ?></div></details>
		</div>
		<?php if ( $ai_offers ) : ?><div class="kidia-ai-recommendations"><?php foreach ( $ai_offers as $offer ) : ?>
			<article data-ai-scheme-card="<?php echo esc_attr( $offer['scheme'] ); ?>">
				<header><span class="dashicons dashicons-chart-line"></span><div><small><?php echo esc_html( ucwords( str_replace( '_', ' ', $offer['scheme'] ) ) ); ?></small><h3><?php echo esc_html( $offer['title'] ); ?></h3></div><b class="is-<?php echo esc_attr( $offer['risk'] ); ?>"><?php echo esc_html( sprintf( __( '%d%% confidence', 'kidia-mobile-cms' ), $offer['confidence'] ) ); ?></b></header>
				<p class="kidia-ai-summary"><?php echo esc_html( $offer['summary'] ); ?></p>
				<div class="kidia-ai-evidence"><strong><?php esc_html_e( 'Why this offer', 'kidia-mobile-cms' ); ?></strong><ul><?php foreach ( $offer['evidence'] as $evidence ) : ?><li><?php echo esc_html( $evidence ); ?></li><?php endforeach; ?></ul></div>
				<footer><span><?php echo esc_html( sprintf( __( 'Profit risk: %s', 'kidia-mobile-cms' ), ucfirst( $offer['risk'] ) ) ); ?></span><button type="button" class="button button-primary" data-ai-offer data-title="<?php echo esc_attr( $offer['title'] ); ?>" data-message="<?php echo esc_attr( $offer['summary'] ); ?>" data-scheme="<?php echo esc_attr( $offer['scheme'] ); ?>" data-confidence="<?php echo esc_attr( (string) $offer['confidence'] ); ?>" data-source="<?php echo esc_attr( $offer['source'] ); ?>" data-products="<?php echo esc_attr( implode( ',', $offer['product_ids'] ) ); ?>" data-discount-type="<?php echo esc_attr( $offer['discount_type'] ); ?>" data-discount-value="<?php echo esc_attr( (string) $offer['discount_value'] ); ?>" data-duration="<?php echo esc_attr( (string) $offer['duration_hours'] ); ?>"><?php esc_html_e( 'Review this offer', 'kidia-mobile-cms' ); ?></button></footer>
			</article>
		<?php endforeach; ?></div><?php else : ?><div class="kidia-ai-empty"><span class="dashicons dashicons-database"></span><div><strong><?php esc_html_e( 'Collecting enough evidence', 'kidia-mobile-cms' ); ?></strong><p><?php esc_html_e( 'No recommendation is shown until real sales, stock or funnel data supports it. The studio never invents numbers.', 'kidia-mobile-cms' ); ?></p></div></div><?php endif; ?>
	</section>
	<form class="kidia-push-builder" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
		<input type="hidden" name="action" value="kidia_mobile_send_push_notification"><?php wp_nonce_field( 'kidia_mobile_send_push_notification', 'kidia_mobile_push_nonce' ); ?>
		<section class="kidia-push-type-step"><div class="kidia-push-step-title"><b>1</b><div><h2><?php esc_html_e( 'What do you want to send?', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Choose a ready type. You can still edit every detail.', 'kidia-mobile-cms' ); ?></p></div></div><div class="kidia-push-types"><?php foreach ( $push_types as $key => $type ) : ?><label><input type="radio" name="push_type" value="<?php echo esc_attr( $key ); ?>" <?php checked( 'broadcast', $key ); ?> data-push-type><span class="dashicons <?php echo esc_attr( $type[1] ); ?>"></span><strong><?php echo esc_html( $type[0] ); ?></strong><small><?php echo esc_html( $type[2] ); ?></small></label><?php endforeach; ?></div></section>
		<div class="kidia-push-workspace">
			<section class="kidia-push-compose"><div class="kidia-push-step-title"><b>2</b><div><h2><?php esc_html_e( 'Message', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Keep it short, clear and actionable.', 'kidia-mobile-cms' ); ?></p></div></div>
				<section class="kidia-push-form-section">
					<header><span class="dashicons dashicons-format-chat"></span><div><h3><?php esc_html_e( 'Content', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'The title and message customers will see.', 'kidia-mobile-cms' ); ?></p></div></header>
					<div class="kidia-push-fields">
						<label><span><?php esc_html_e( 'Title', 'kidia-mobile-cms' ); ?></span><input type="text" name="push_title" maxlength="100" required data-push-title placeholder="<?php esc_attr_e( 'A new update for you', 'kidia-mobile-cms' ); ?>"></label>
						<label class="is-wide"><span><?php esc_html_e( 'Message', 'kidia-mobile-cms' ); ?></span><textarea name="push_message" maxlength="500" rows="4" required data-push-message placeholder="<?php esc_attr_e( 'Tell customers why they should open the app.', 'kidia-mobile-cms' ); ?>"></textarea></label>
						<label data-push-field="offer"><span><?php esc_html_e( 'Coupon code', 'kidia-mobile-cms' ); ?></span><input type="text" name="push_coupon"></label>
						<label data-push-field="offer restock"><span><?php esc_html_e( 'Product ID', 'kidia-mobile-cms' ); ?></span><input type="number" min="0" name="push_product_id"></label>
					</div>
				</section>
				<section class="kidia-push-form-section" data-push-field="ai_offer" hidden>
					<header><span class="dashicons dashicons-tickets-alt"></span><div><h3><?php esc_html_e( 'Offer settings', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'Review the suggested discount before creating anything.', 'kidia-mobile-cms' ); ?></p></div></header>
					<div class="kidia-ai-offer-review">
						<input type="hidden" name="ai_offer_scheme" data-ai-scheme><input type="hidden" name="ai_offer_confidence" data-ai-confidence><input type="hidden" name="ai_offer_source" data-ai-source><input type="hidden" name="ai_offer_product_ids" data-ai-products>
						<label><span><?php esc_html_e( 'Discount type', 'kidia-mobile-cms' ); ?></span><select name="ai_discount_type" data-ai-discount-type><option value="percent"><?php esc_html_e( 'Percentage', 'kidia-mobile-cms' ); ?></option><option value="fixed_cart"><?php esc_html_e( 'Fixed cart', 'kidia-mobile-cms' ); ?></option><option value="fixed_product"><?php esc_html_e( 'Fixed product', 'kidia-mobile-cms' ); ?></option></select></label>
						<label><span><?php esc_html_e( 'Discount value', 'kidia-mobile-cms' ); ?></span><input type="number" min="0" step=".01" name="ai_discount_value" data-ai-discount-value></label>
						<label><span><?php esc_html_e( 'Duration (hours)', 'kidia-mobile-cms' ); ?></span><input type="number" min="1" max="720" name="ai_duration_hours" data-ai-duration value="48"></label>
						<label class="kidia-push-check"><input type="checkbox" name="ai_create_coupon" value="1" checked><span><?php esc_html_e( 'Create the scoped coupon after I approve and save', 'kidia-mobile-cms' ); ?></span></label>
						<p><?php esc_html_e( 'The recommendation is never activated automatically. Review the message, value, duration and audience before saving.', 'kidia-mobile-cms' ); ?></p>
					</div>
				</section>
				<section class="kidia-push-form-section">
					<header><span class="dashicons dashicons-groups"></span><div><h3><?php esc_html_e( 'Audience and delivery', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'Choose who receives the message and when it runs.', 'kidia-mobile-cms' ); ?></p></div></header>
					<div class="kidia-push-fields">
						<label data-push-field="order"><span><?php esc_html_e( 'Order status trigger', 'kidia-mobile-cms' ); ?></span><select name="push_order_status"><option value="processing"><?php esc_html_e( 'Processing', 'kidia-mobile-cms' ); ?></option><option value="completed"><?php esc_html_e( 'Completed', 'kidia-mobile-cms' ); ?></option><option value="shipped"><?php esc_html_e( 'Shipped', 'kidia-mobile-cms' ); ?></option><option value="cancelled"><?php esc_html_e( 'Cancelled', 'kidia-mobile-cms' ); ?></option></select></label>
						<label><span><?php esc_html_e( 'Audience', 'kidia-mobile-cms' ); ?></span><select name="push_audience" data-push-audience><option value="all"><?php esc_html_e( 'All devices', 'kidia-mobile-cms' ); ?></option><option value="customers"><?php esc_html_e( 'Signed-in customers', 'kidia-mobile-cms' ); ?></option><option value="guests"><?php esc_html_e( 'Guest shoppers', 'kidia-mobile-cms' ); ?></option><option value="segment"><?php esc_html_e( 'Smart segment', 'kidia-mobile-cms' ); ?></option><option value="test"><?php esc_html_e( 'Test devices', 'kidia-mobile-cms' ); ?></option></select></label>
						<div class="kidia-push-segment is-wide" data-push-segment hidden><label><span><?php esc_html_e( 'Minimum orders', 'kidia-mobile-cms' ); ?></span><input type="number" min="0" name="push_min_orders"></label><label><span><?php esc_html_e( 'Minimum spent', 'kidia-mobile-cms' ); ?></span><input type="number" min="0" step=".01" name="push_min_spent"></label><label><span><?php esc_html_e( 'Inactive for days', 'kidia-mobile-cms' ); ?></span><input type="number" min="0" name="push_inactive_days"></label></div>
						<label><span><?php esc_html_e( 'Delivery', 'kidia-mobile-cms' ); ?></span><select name="push_delivery" data-push-delivery><option value="now"><?php esc_html_e( 'Send now', 'kidia-mobile-cms' ); ?></option><option value="scheduled"><?php esc_html_e( 'Schedule once', 'kidia-mobile-cms' ); ?></option><option value="automation"><?php esc_html_e( 'Save as automation', 'kidia-mobile-cms' ); ?></option></select></label>
						<label data-push-schedule hidden><span><?php esc_html_e( 'Send date and time', 'kidia-mobile-cms' ); ?></span><input type="datetime-local" name="push_schedule_at"></label>
					</div>
				</section>
				<details class="kidia-push-advanced"><summary><?php esc_html_e( 'Advanced options', 'kidia-mobile-cms' ); ?></summary><div class="kidia-push-fields"><label><span><?php esc_html_e( 'Open URL or deep link', 'kidia-mobile-cms' ); ?></span><input type="url" name="push_action_url" placeholder="https://"></label><label><span><?php esc_html_e( 'Button label', 'kidia-mobile-cms' ); ?></span><input type="text" name="push_cta_label" maxlength="30"></label><label class="is-wide"><span><?php esc_html_e( 'Image URL', 'kidia-mobile-cms' ); ?></span><input type="url" name="push_image_url" placeholder="https://"></label><label><span><?php esc_html_e( 'Priority', 'kidia-mobile-cms' ); ?></span><select name="push_priority"><option value="normal"><?php esc_html_e( 'Normal', 'kidia-mobile-cms' ); ?></option><option value="high"><?php esc_html_e( 'High', 'kidia-mobile-cms' ); ?></option></select></label><label><span><?php esc_html_e( 'Expires after (hours)', 'kidia-mobile-cms' ); ?></span><input type="number" name="push_expiry_hours" min="1" max="168" value="24"></label><label><span><?php esc_html_e( 'App badge number', 'kidia-mobile-cms' ); ?></span><input type="number" name="push_badge" min="0"></label><label class="kidia-push-check"><input type="checkbox" name="push_sound" value="1" checked><span><?php esc_html_e( 'Play notification sound', 'kidia-mobile-cms' ); ?></span></label></div></details>
				<div class="kidia-push-submit"><button class="button button-primary button-hero" type="submit"><span class="dashicons dashicons-paper-plane"></span><?php esc_html_e( 'Save & continue', 'kidia-mobile-cms' ); ?></button></div>
			</section>
			<aside class="kidia-push-preview"><small><?php esc_html_e( 'Live preview', 'kidia-mobile-cms' ); ?></small><div class="kidia-push-phone"><div class="kidia-push-clock">9:41</div><div class="kidia-push-bubble"><span>W</span><div><b data-push-preview-title><?php esc_html_e( 'Your notification title', 'kidia-mobile-cms' ); ?></b><p data-push-preview-message><?php esc_html_e( 'Your message will appear here.', 'kidia-mobile-cms' ); ?></p></div><small><?php esc_html_e( 'now', 'kidia-mobile-cms' ); ?></small></div></div></aside>
		</div>
	</form>
	<section class="kidia-push-history"><h2><?php esc_html_e( 'History', 'kidia-mobile-cms' ); ?></h2><?php if ( $history ) : ?><div><?php foreach ( $history as $item ) : ?><article><span class="dashicons dashicons-megaphone"></span><div><strong><?php echo esc_html( (string) ( $item['title'] ?? '' ) ); ?></strong><p><?php echo esc_html( (string) ( $item['message'] ?? '' ) ); ?></p></div><small><?php echo esc_html( ucfirst( str_replace( '_', ' ', (string) ( $item['type'] ?? 'broadcast' ) ) ) ); ?> · <?php echo esc_html( wp_date( get_option( 'date_format' ) . ' ' . get_option( 'time_format' ), absint( $item['created_at'] ?? time() ) ) ); ?></small><em><?php echo esc_html( (string) ( $item['status'] ?? 'saved' ) ); ?></em></article><?php endforeach; ?></div><?php else : ?><div class="kidia-data-empty"><span class="dashicons dashicons-megaphone"></span><strong><?php esc_html_e( 'No notifications yet', 'kidia-mobile-cms' ); ?></strong></div><?php endif; ?></section>
</div>
