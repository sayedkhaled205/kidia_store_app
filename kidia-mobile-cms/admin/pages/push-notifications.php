<?php
/** Push notification composer, automations and delivery configuration. */
defined( 'ABSPATH' ) || exit;

$push_types = array(
	'broadcast'      => array( __( 'Broadcast', 'mobishop' ), 'dashicons-megaphone', __( 'One message for everyone', 'mobishop' ) ),
	'offer'          => array( __( 'Offer', 'mobishop' ), 'dashicons-tickets-alt', __( 'Sale, coupon or product', 'mobishop' ) ),
	'order'          => array( __( 'Order update', 'mobishop' ), 'dashicons-cart', __( 'Status and delivery alerts', 'mobishop' ) ),
	'restock'        => array( __( 'Back in stock', 'mobishop' ), 'dashicons-products', __( 'Notify product followers', 'mobishop' ) ),
	'abandoned_cart' => array( __( 'Abandoned cart', 'mobishop' ), 'dashicons-cart', __( 'Recover unfinished carts', 'mobishop' ) ),
	'welcome'        => array( __( 'Welcome', 'mobishop' ), 'dashicons-heart', __( 'Greet new app customers', 'mobishop' ) ),
	'custom'         => array( __( 'Custom', 'mobishop' ), 'dashicons-admin-generic', __( 'Build your own journey', 'mobishop' ) ),
);
$prefill_title   = is_array( $prefill_offer ) ? (string) $prefill_offer['title'] : '';
$prefill_message = is_array( $prefill_offer ) ? (string) $prefill_offer['summary'] : '';
$destination_labels = array(
	'home'        => __( 'Home — recommended default', 'mobishop' ),
	'product'     => __( 'Product', 'mobishop' ),
	'category'    => __( 'Category', 'mobishop' ),
	'subcategory' => __( 'Subcategory', 'mobishop' ),
	'collection'  => __( 'Collection', 'mobishop' ),
	'cart'        => __( 'Cart', 'mobishop' ),
	'checkout'    => __( 'Checkout', 'mobishop' ),
	'wishlist'    => __( 'Wishlist', 'mobishop' ),
	'order'       => __( 'Order details', 'mobishop' ),
	'account'     => __( 'Account', 'mobishop' ),
	'offers'      => __( 'Offers', 'mobishop' ),
	'search'      => __( 'Search', 'mobishop' ),
	'custom'      => __( 'Custom app page', 'mobishop' ),
	'external'    => __( 'External URL', 'mobishop' ),
);
?>
<div class="wrap kidia-push-page">
	<header class="kidia-push-hero">
		<div><span class="dashicons dashicons-megaphone"></span><div><h1><?php esc_html_e( 'Push Notifications', 'mobishop' ); ?></h1><p><?php esc_html_e( 'Compose messages, build automatic journeys and measure delivery, opens and sales.', 'mobishop' ); ?></p></div></div>
		<span class="kidia-push-status <?php echo $push_connected ? 'is-connected' : ''; ?>"><?php echo esc_html( (string) $push_status['label'] ); ?></span>
	</header>

	<?php if ( isset( $_GET['push_sent'] ) ) : ?><div class="kidia-toast is-visible"><span class="dashicons dashicons-yes-alt"></span><?php esc_html_e( 'Notification saved successfully.', 'mobishop' ); ?></div><?php elseif ( isset( $_GET['push_error'] ) ) : ?><div class="notice notice-error"><p><?php echo esc_html( 'delivery' === sanitize_key( wp_unslash( $_GET['push_error'] ) ) ? __( 'The notification could not be delivered. Prepare Firebase and register a test device, then try again.', 'mobishop' ) : __( 'Check the required fields and scheduled time.', 'mobishop' ) ); ?></p></div><?php endif; ?>
	<?php if ( 'ready' === sanitize_key( (string) ( $_GET['push_setup'] ?? '' ) ) ) : ?><div class="notice notice-success"><p><?php esc_html_e( 'Firebase setup completed. Android, iOS and Cloud Messaging are ready.', 'mobishop' ); ?></p></div><?php elseif ( 'error' === sanitize_key( (string) ( $_GET['push_setup'] ?? '' ) ) ) : ?><div class="notice notice-error"><p><?php echo esc_html( sanitize_text_field( wp_unslash( (string) ( $_GET['push_setup_message'] ?? __( 'Firebase setup could not be completed.', 'mobishop' ) ) ) ) ); ?></p></div><?php endif; ?>
	<?php if ( 'success' === sanitize_key( (string) ( $_GET['push_test'] ?? '' ) ) ) : ?><div class="notice notice-success"><p><?php esc_html_e( 'Firebase connection test passed without sending a notification.', 'mobishop' ); ?></p></div><?php elseif ( 'error' === sanitize_key( (string) ( $_GET['push_test'] ?? '' ) ) ) : ?><div class="notice notice-error"><p><?php echo esc_html( sanitize_text_field( wp_unslash( (string) ( $_GET['push_test_message'] ?? __( 'Firebase connection test failed.', 'mobishop' ) ) ) ) ); ?></p></div><?php endif; ?>

	<div class="kidia-push-managed">
		<span class="dashicons dashicons-cloud-saved"></span>
		<div>
			<strong><?php esc_html_e( 'Push connection managed automatically', 'mobishop' ); ?></strong>
			<p><?php echo esc_html( (string) $push_status['reason'] ); ?> <?php esc_html_e( 'Each application uses its own private connection; no provider selection or Firebase keys are required.', 'mobishop' ); ?></p>
			<?php if ( ! empty( $push_status['project_id'] ) ) : ?><small><?php esc_html_e( 'Project:', 'mobishop' ); ?> <code><?php echo esc_html( (string) $push_status['project_id'] ); ?></code></small><?php endif; ?>
		</div>
		<div class="kidia-push-managed__actions">
			<?php if ( $push_connected ) : ?>
				<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>"><input type="hidden" name="action" value="kidia_mobile_test_push_connection"><?php wp_nonce_field( 'kidia_mobile_test_push_connection', 'kidia_mobile_push_test_nonce' ); ?><button class="button" type="submit"><span class="dashicons dashicons-yes-alt"></span><?php esc_html_e( 'Test connection', 'mobishop' ); ?></button></form>
			<?php elseif ( ! empty( $push_status['license_active'] ) ) : ?>
				<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>"><input type="hidden" name="action" value="kidia_mobile_provision_push"><?php wp_nonce_field( 'kidia_mobile_provision_push', 'kidia_mobile_push_setup_nonce' ); ?><button class="button button-primary" type="submit"><span class="dashicons dashicons-cloud-saved"></span><?php esc_html_e( 'Prepare Firebase', 'mobishop' ); ?></button></form>
			<?php endif; ?>
		</div>
	</div>

	<div class="kidia-push-readiness" aria-label="<?php esc_attr_e( 'Firebase readiness', 'mobishop' ); ?>">
		<div class="<?php echo ! empty( $push_status['android_ready'] ) ? 'is-ready' : ''; ?>"><span class="dashicons dashicons-smartphone"></span><b>Android</b><small><?php echo ! empty( $push_status['android_ready'] ) ? esc_html__( 'Ready', 'mobishop' ) : esc_html__( 'Waiting', 'mobishop' ); ?></small></div>
		<div class="<?php echo ! empty( $push_status['ios_ready'] ) ? 'is-ready' : ''; ?>"><span class="dashicons dashicons-smartphone"></span><b>iOS</b><small><?php echo ! empty( $push_status['ios_ready'] ) ? esc_html__( 'Ready', 'mobishop' ) : esc_html__( 'Waiting', 'mobishop' ); ?></small></div>
		<div class="<?php echo ! empty( $push_status['messaging_ready'] ) ? 'is-ready' : ''; ?>"><span class="dashicons dashicons-megaphone"></span><b>Messaging</b><small><?php echo ! empty( $push_status['messaging_ready'] ) ? esc_html__( 'Ready', 'mobishop' ) : esc_html__( 'Waiting', 'mobishop' ); ?></small></div>
	</div>

	<div class="kidia-push-stats is-four">
		<div><span class="dashicons dashicons-smartphone"></span><b><?php echo esc_html( (string) $push_status['devices'] ); ?></b><small><?php esc_html_e( 'Registered devices', 'mobishop' ); ?></small></div>
		<div><span class="dashicons dashicons-yes-alt"></span><b><?php echo esc_html( (string) ( $push_metrics['delivered'] ?? 0 ) ); ?></b><small><?php esc_html_e( 'Delivered', 'mobishop' ); ?></small></div>
		<div><span class="dashicons dashicons-visibility"></span><b><?php echo esc_html( (string) ( $push_metrics['opened'] ?? 0 ) ); ?></b><small><?php esc_html_e( 'Opened', 'mobishop' ); ?></small></div>
		<div><span class="dashicons dashicons-chart-line"></span><b><?php echo esc_html( (string) ( $push_metrics['converted'] ?? 0 ) ); ?></b><small><?php esc_html_e( 'Converted', 'mobishop' ); ?></small></div>
	</div>

	<form class="kidia-push-builder" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
		<input type="hidden" name="action" value="kidia_mobile_send_push_notification"><?php wp_nonce_field( 'kidia_mobile_send_push_notification', 'kidia_mobile_push_nonce' ); ?>
		<section class="kidia-push-type-step">
			<div class="kidia-push-step-title"><b>1</b><div><h2><?php esc_html_e( 'Choose a journey', 'mobishop' ); ?></h2><p><?php esc_html_e( 'Start from a ready event, then control the message, destination and delivery rules.', 'mobishop' ); ?></p></div></div>
			<div class="kidia-push-types"><?php foreach ( $push_types as $key => $type ) : ?><label><input type="radio" name="push_type" value="<?php echo esc_attr( $key ); ?>" <?php checked( $selected_push_type, $key ); ?> data-push-type><span class="dashicons <?php echo esc_attr( $type[1] ); ?>"></span><strong><?php echo esc_html( $type[0] ); ?></strong><small><?php echo esc_html( $type[2] ); ?></small></label><?php endforeach; ?></div>
		</section>

		<div class="kidia-push-workspace">
			<section class="kidia-push-compose">
				<div class="kidia-push-step-title"><b>2</b><div><h2><?php esc_html_e( 'Message & action', 'mobishop' ); ?></h2><p><?php esc_html_e( 'The recommended destination is selected automatically, but you can change it.', 'mobishop' ); ?></p></div></div>
				<div class="kidia-push-form-stack">
					<section class="kidia-push-form-section"><header><span class="dashicons dashicons-format-chat"></span><div><h3><?php esc_html_e( 'Message', 'mobishop' ); ?></h3><p><?php esc_html_e( 'Keep it short, clear and actionable.', 'mobishop' ); ?></p></div></header><div class="kidia-push-fields">
						<label><span><?php esc_html_e( 'Title', 'mobishop' ); ?></span><input type="text" name="push_title" maxlength="100" required data-push-title value="<?php echo esc_attr( $prefill_title ); ?>" placeholder="<?php esc_attr_e( 'A new update for you', 'mobishop' ); ?>"></label>
						<label data-push-field="offer"><span><?php esc_html_e( 'Coupon code', 'mobishop' ); ?></span><input type="text" name="push_coupon"></label>
						<label class="is-wide"><span><?php esc_html_e( 'Message', 'mobishop' ); ?></span><textarea name="push_message" maxlength="500" rows="4" required data-push-message placeholder="<?php esc_attr_e( 'Tell customers why they should open the app.', 'mobishop' ); ?>"><?php echo esc_textarea( $prefill_message ); ?></textarea></label>
					</div></section>

					<section class="kidia-push-form-section"><header><span class="dashicons dashicons-admin-links"></span><div><h3><?php esc_html_e( 'Open destination', 'mobishop' ); ?></h3><p><?php esc_html_e( 'Choose where the customer lands after tapping the notification.', 'mobishop' ); ?></p></div></header><div class="kidia-push-fields">
						<label><span><?php esc_html_e( 'Destination', 'mobishop' ); ?></span><select name="push_destination" data-push-destination><?php foreach ( $destination_labels as $key => $label ) : ?><option value="<?php echo esc_attr( $key ); ?>"><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
						<label><span><?php esc_html_e( 'Destination product/category/order ID', 'mobishop' ); ?></span><input type="text" name="push_destination_id" placeholder="<?php esc_attr_e( 'Shown when the destination needs an item', 'mobishop' ); ?>"></label>
						<label><span><?php esc_html_e( 'Action display', 'mobishop' ); ?></span><select name="push_action_style" data-push-action-style><option value="link"><?php esc_html_e( 'Open link', 'mobishop' ); ?></option><option value="button"><?php esc_html_e( 'Button', 'mobishop' ); ?></option></select></label>
						<label data-push-button-label hidden><span><?php esc_html_e( 'Button label', 'mobishop' ); ?></span><input type="text" name="push_cta_label" maxlength="30" value="<?php esc_attr_e( 'Open', 'mobishop' ); ?>"></label>
						<label class="is-wide"><span><?php esc_html_e( 'Custom URL or app deep link', 'mobishop' ); ?></span><input type="url" name="push_action_url" placeholder="https://"></label>
					</div></section>

					<section class="kidia-push-form-section"><header><span class="dashicons dashicons-controls-repeat"></span><div><h3><?php esc_html_e( 'Audience & delivery', 'mobishop' ); ?></h3><p><?php esc_html_e( 'Send once, schedule, or save a guarded automation.', 'mobishop' ); ?></p></div></header><div class="kidia-push-fields">
						<label><span><?php esc_html_e( 'Audience', 'mobishop' ); ?></span><select name="push_audience" data-push-audience><option value="all">All devices</option><option value="customers">Signed-in customers</option><option value="guests">Guest shoppers</option><option value="segment">Smart segment</option><option value="test">Test devices</option></select></label>
						<label><span><?php esc_html_e( 'Delivery', 'mobishop' ); ?></span><select name="push_delivery" data-push-delivery><option value="now">Send now</option><option value="scheduled">Schedule once</option><option value="automation">Save as automation</option></select></label>
						<label data-push-schedule hidden><span><?php esc_html_e( 'Send date and time', 'mobishop' ); ?></span><input type="datetime-local" name="push_schedule_at"></label>
						<div class="kidia-push-segment is-wide" data-push-segment hidden><label><span>Minimum orders</span><input type="number" min="0" name="push_min_orders"></label><label><span>Minimum spent</span><input type="number" min="0" step=".01" name="push_min_spent"></label><label><span>Inactive for days</span><input type="number" min="0" name="push_inactive_days"></label></div>
						<div class="kidia-push-automation is-wide" data-push-automation hidden>
							<label><span><?php esc_html_e( 'Trigger', 'mobishop' ); ?></span><select name="push_trigger"><option value="abandoned_cart">Cart becomes abandoned</option><option value="browse_abandonment">Viewed without cart</option><option value="checkout_abandonment">Checkout not completed</option><option value="welcome">Customer registers</option><option value="restock">Product is back in stock</option><option value="price_drop">Price drops</option><option value="winback">Customer becomes inactive</option><option value="new_product">New product is published</option><option value="coupon_expiry">Coupon is about to expire</option></select></label>
							<label><span><?php esc_html_e( 'First delay (minutes)', 'mobishop' ); ?></span><input type="number" min="0" max="43200" name="push_delay_minutes" value="30"></label>
							<label><span><?php esc_html_e( 'Maximum sends', 'mobishop' ); ?></span><input type="number" min="1" max="20" name="push_max_sends" value="3"></label>
							<label><span><?php esc_html_e( 'Cooldown (hours)', 'mobishop' ); ?></span><input type="number" min="1" max="8760" name="push_cooldown_hours" value="24"></label>
							<label><span><?php esc_html_e( 'Allowed from', 'mobishop' ); ?></span><input type="time" name="push_allowed_from" value="09:00"></label>
							<label><span><?php esc_html_e( 'Allowed until', 'mobishop' ); ?></span><input type="time" name="push_allowed_to" value="21:00"></label>
							<label class="kidia-push-check"><input type="checkbox" name="push_stop_on_purchase" value="1" checked><span><?php esc_html_e( 'Stop immediately after purchase', 'mobishop' ); ?></span></label>
						</div>
					</div></section>
				</div>

				<details class="kidia-push-advanced"><summary><?php esc_html_e( 'Advanced options', 'mobishop' ); ?></summary><div class="kidia-push-fields"><label class="is-wide"><span><?php esc_html_e( 'Image URL', 'mobishop' ); ?></span><input type="url" name="push_image_url" placeholder="https://"></label><label><span><?php esc_html_e( 'Priority', 'mobishop' ); ?></span><select name="push_priority"><option value="normal">Normal</option><option value="high">High</option></select></label><label><span><?php esc_html_e( 'Expires after (hours)', 'mobishop' ); ?></span><input type="number" name="push_expiry_hours" min="1" max="168" value="24"></label><label><span><?php esc_html_e( 'App badge number', 'mobishop' ); ?></span><input type="number" name="push_badge" min="0"></label><label class="kidia-push-check"><input type="checkbox" name="push_sound" value="1" checked><span><?php esc_html_e( 'Play notification sound', 'mobishop' ); ?></span></label></div></details>
				<div class="kidia-push-submit"><button class="button button-primary" type="submit" data-push-submit><span class="dashicons dashicons-paper-plane"></span><span data-push-submit-label><?php esc_html_e( 'Send notification', 'mobishop' ); ?></span></button></div>
			</section>

			<aside class="kidia-push-preview"><small><?php esc_html_e( 'Live preview', 'mobishop' ); ?></small><div class="kidia-push-phone"><div class="kidia-push-clock">9:41</div><div class="kidia-push-bubble"><span>W</span><div><b data-push-preview-title><?php esc_html_e( 'Your notification title', 'mobishop' ); ?></b><p data-push-preview-message><?php esc_html_e( 'Your message will appear here.', 'mobishop' ); ?></p></div><small><?php esc_html_e( 'now', 'mobishop' ); ?></small></div></div></aside>
		</div>
	</form>

	<section class="kidia-push-history"><h2><?php esc_html_e( 'History & automations', 'mobishop' ); ?></h2><?php if ( $history ) : ?><div><?php foreach ( $history as $item ) : ?><article><span class="dashicons dashicons-megaphone"></span><div><strong><?php echo esc_html( (string) ( $item['title'] ?? '' ) ); ?></strong><p><?php echo esc_html( (string) ( $item['message'] ?? '' ) ); ?></p></div><small><?php echo esc_html( ucfirst( str_replace( '_', ' ', (string) ( $item['type'] ?? 'broadcast' ) ) ) ); ?> · <?php echo esc_html( wp_date( get_option( 'date_format' ) . ' ' . get_option( 'time_format' ), absint( $item['created_at'] ?? time() ) ) ); ?></small><em><?php echo esc_html( (string) ( $item['status'] ?? 'saved' ) ); ?></em></article><?php endforeach; ?></div><?php else : ?><div class="kidia-data-empty"><span class="dashicons dashicons-megaphone"></span><strong><?php esc_html_e( 'No notifications yet', 'mobishop' ); ?></strong></div><?php endif; ?></section>
</div>
