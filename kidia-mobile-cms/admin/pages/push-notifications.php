<?php
/** Push notification composer, automations and delivery configuration. */
defined( 'ABSPATH' ) || exit;

$push_types = array(
	'broadcast'      => array( __( 'Broadcast', 'kidia-mobile-cms' ), 'dashicons-megaphone', __( 'One message for everyone', 'kidia-mobile-cms' ) ),
	'offer'          => array( __( 'Offer', 'kidia-mobile-cms' ), 'dashicons-tickets-alt', __( 'Sale, coupon or product', 'kidia-mobile-cms' ) ),
	'order'          => array( __( 'Order update', 'kidia-mobile-cms' ), 'dashicons-cart', __( 'Status and delivery alerts', 'kidia-mobile-cms' ) ),
	'restock'        => array( __( 'Back in stock', 'kidia-mobile-cms' ), 'dashicons-products', __( 'Notify product followers', 'kidia-mobile-cms' ) ),
	'abandoned_cart' => array( __( 'Abandoned cart', 'kidia-mobile-cms' ), 'dashicons-cart', __( 'Recover unfinished carts', 'kidia-mobile-cms' ) ),
	'welcome'        => array( __( 'Welcome', 'kidia-mobile-cms' ), 'dashicons-heart', __( 'Greet new app customers', 'kidia-mobile-cms' ) ),
	'custom'         => array( __( 'Custom', 'kidia-mobile-cms' ), 'dashicons-admin-generic', __( 'Build your own journey', 'kidia-mobile-cms' ) ),
);
$prefill_title   = is_array( $prefill_offer ) ? (string) $prefill_offer['title'] : '';
$prefill_message = is_array( $prefill_offer ) ? (string) $prefill_offer['summary'] : '';
$destination_labels = array(
	'home'        => __( 'Home — recommended default', 'kidia-mobile-cms' ),
	'product'     => __( 'Product', 'kidia-mobile-cms' ),
	'category'    => __( 'Category', 'kidia-mobile-cms' ),
	'subcategory' => __( 'Subcategory', 'kidia-mobile-cms' ),
	'collection'  => __( 'Collection', 'kidia-mobile-cms' ),
	'cart'        => __( 'Cart', 'kidia-mobile-cms' ),
	'checkout'    => __( 'Checkout', 'kidia-mobile-cms' ),
	'wishlist'    => __( 'Wishlist', 'kidia-mobile-cms' ),
	'order'       => __( 'Order details', 'kidia-mobile-cms' ),
	'account'     => __( 'Account', 'kidia-mobile-cms' ),
	'offers'      => __( 'Offers', 'kidia-mobile-cms' ),
	'search'      => __( 'Search', 'kidia-mobile-cms' ),
	'custom'      => __( 'Custom app page', 'kidia-mobile-cms' ),
	'external'    => __( 'External URL', 'kidia-mobile-cms' ),
);
?>
<div class="wrap kidia-push-page">
	<header class="kidia-push-hero">
		<div><span class="dashicons dashicons-megaphone"></span><div><h1><?php esc_html_e( 'Push Notifications', 'kidia-mobile-cms' ); ?></h1><p><?php esc_html_e( 'Compose messages, build automatic journeys and measure delivery, opens and sales.', 'kidia-mobile-cms' ); ?></p></div></div>
		<span class="kidia-provider-status <?php echo $provider_connected ? 'is-connected' : ''; ?>"><?php echo esc_html( (string) $provider_status['label'] ); ?></span>
	</header>

	<?php if ( isset( $_GET['provider_saved'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Push provider settings saved. Use a test audience before enabling an automation.', 'kidia-mobile-cms' ); ?></p></div><?php endif; ?>
	<?php if ( isset( $_GET['push_sent'] ) ) : ?><div class="kidia-toast is-visible"><span class="dashicons dashicons-yes-alt"></span><?php esc_html_e( 'Notification saved successfully.', 'kidia-mobile-cms' ); ?></div><?php elseif ( isset( $_GET['push_error'] ) ) : ?><div class="notice notice-error"><p><?php esc_html_e( 'Check the required fields and scheduled time.', 'kidia-mobile-cms' ); ?></p></div><?php endif; ?>

	<details class="kidia-push-provider" <?php echo $provider_connected ? '' : 'open'; ?>>
		<summary><span class="dashicons dashicons-cloud"></span><div><strong><?php esc_html_e( 'Delivery connection', 'kidia-mobile-cms' ); ?></strong><small><?php echo esc_html( (string) $provider_status['reason'] ); ?></small></div><b><?php echo $provider_connected ? esc_html__( 'Connected', 'kidia-mobile-cms' ) : esc_html__( 'Setup required', 'kidia-mobile-cms' ); ?></b></summary>
		<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
			<input type="hidden" name="action" value="kidia_mobile_save_push_provider"><?php wp_nonce_field( 'kidia_mobile_save_push_provider', 'kidia_mobile_push_provider_nonce' ); ?>
			<div class="kidia-push-provider-grid">
				<label><span><?php esc_html_e( 'Provider', 'kidia-mobile-cms' ); ?></span><select name="push_provider[provider]" data-push-provider><option value="none" <?php selected( 'none', $provider_settings['provider'] ); ?>>Choose provider</option><option value="fcm" <?php selected( 'fcm', $provider_settings['provider'] ); ?>>Firebase Cloud Messaging</option><option value="onesignal" <?php selected( 'onesignal', $provider_settings['provider'] ); ?>>OneSignal</option><option value="webhook" <?php selected( 'webhook', $provider_settings['provider'] ); ?>>Signed webhook</option></select></label>
				<label data-provider-fields="onesignal"><span>OneSignal App ID</span><input type="text" name="push_provider[onesignal_app_id]" value="<?php echo esc_attr( (string) $provider_settings['onesignal_app_id'] ); ?>"></label>
				<label data-provider-fields="onesignal"><span>OneSignal REST API key</span><input type="password" name="push_provider[onesignal_api_key]" placeholder="<?php echo empty( $provider_settings['onesignal_api_key'] ) ? '' : esc_attr__( 'Saved — leave blank to keep', 'kidia-mobile-cms' ); ?>"></label>
				<label data-provider-fields="fcm"><span>Firebase project ID</span><input type="text" name="push_provider[fcm_project_id]" value="<?php echo esc_attr( (string) $provider_settings['fcm_project_id'] ); ?>"></label>
				<label data-provider-fields="fcm"><span>Service-account client email</span><input type="email" name="push_provider[fcm_client_email]" value="<?php echo esc_attr( (string) $provider_settings['fcm_client_email'] ); ?>"></label>
				<label class="is-wide" data-provider-fields="fcm"><span>Service-account private key</span><textarea name="push_provider[fcm_private_key]" rows="4" placeholder="<?php echo empty( $provider_settings['fcm_private_key'] ) ? '-----BEGIN PRIVATE KEY-----' : esc_attr__( 'Saved — leave blank to keep', 'kidia-mobile-cms' ); ?>"></textarea></label>
				<label data-provider-fields="webhook"><span><?php esc_html_e( 'Webhook URL', 'kidia-mobile-cms' ); ?></span><input type="url" name="push_provider[webhook_url]" value="<?php echo esc_attr( (string) $provider_settings['webhook_url'] ); ?>"></label>
				<label data-provider-fields="webhook"><span><?php esc_html_e( 'Signing secret', 'kidia-mobile-cms' ); ?></span><input type="password" name="push_provider[webhook_secret]" placeholder="<?php echo empty( $provider_settings['webhook_secret'] ) ? '' : esc_attr__( 'Saved — leave blank to keep', 'kidia-mobile-cms' ); ?>"></label>
			</div>
			<footer><p><?php esc_html_e( 'The mobile app registers its FCM/OneSignal token through /woo-mobile/v1/push/devices. Credentials stay in WordPress.', 'kidia-mobile-cms' ); ?></p><button class="button button-primary" type="submit"><?php esc_html_e( 'Save delivery connection', 'kidia-mobile-cms' ); ?></button></footer>
		</form>
	</details>

	<div class="kidia-push-stats is-four">
		<div><span class="dashicons dashicons-smartphone"></span><b><?php echo esc_html( (string) $provider_status['devices'] ); ?></b><small><?php esc_html_e( 'Registered devices', 'kidia-mobile-cms' ); ?></small></div>
		<div><span class="dashicons dashicons-yes-alt"></span><b><?php echo esc_html( (string) ( $push_metrics['delivered'] ?? 0 ) ); ?></b><small><?php esc_html_e( 'Delivered', 'kidia-mobile-cms' ); ?></small></div>
		<div><span class="dashicons dashicons-visibility"></span><b><?php echo esc_html( (string) ( $push_metrics['opened'] ?? 0 ) ); ?></b><small><?php esc_html_e( 'Opened', 'kidia-mobile-cms' ); ?></small></div>
		<div><span class="dashicons dashicons-chart-line"></span><b><?php echo esc_html( (string) ( $push_metrics['converted'] ?? 0 ) ); ?></b><small><?php esc_html_e( 'Converted', 'kidia-mobile-cms' ); ?></small></div>
	</div>

	<form class="kidia-push-builder" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
		<input type="hidden" name="action" value="kidia_mobile_send_push_notification"><?php wp_nonce_field( 'kidia_mobile_send_push_notification', 'kidia_mobile_push_nonce' ); ?>
		<section class="kidia-push-type-step">
			<div class="kidia-push-step-title"><b>1</b><div><h2><?php esc_html_e( 'Choose a journey', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Start from a ready event, then control the message, destination and delivery rules.', 'kidia-mobile-cms' ); ?></p></div></div>
			<div class="kidia-push-types"><?php foreach ( $push_types as $key => $type ) : ?><label><input type="radio" name="push_type" value="<?php echo esc_attr( $key ); ?>" <?php checked( $selected_push_type, $key ); ?> data-push-type><span class="dashicons <?php echo esc_attr( $type[1] ); ?>"></span><strong><?php echo esc_html( $type[0] ); ?></strong><small><?php echo esc_html( $type[2] ); ?></small></label><?php endforeach; ?></div>
		</section>

		<div class="kidia-push-workspace">
			<section class="kidia-push-compose">
				<div class="kidia-push-step-title"><b>2</b><div><h2><?php esc_html_e( 'Message & action', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'The recommended destination is selected automatically, but you can change it.', 'kidia-mobile-cms' ); ?></p></div></div>
				<div class="kidia-push-form-stack">
					<section class="kidia-push-form-section"><header><span class="dashicons dashicons-format-chat"></span><div><h3><?php esc_html_e( 'Message', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'Keep it short, clear and actionable.', 'kidia-mobile-cms' ); ?></p></div></header><div class="kidia-push-fields">
						<label><span><?php esc_html_e( 'Title', 'kidia-mobile-cms' ); ?></span><input type="text" name="push_title" maxlength="100" required data-push-title value="<?php echo esc_attr( $prefill_title ); ?>" placeholder="<?php esc_attr_e( 'A new update for you', 'kidia-mobile-cms' ); ?>"></label>
						<label data-push-field="offer"><span><?php esc_html_e( 'Coupon code', 'kidia-mobile-cms' ); ?></span><input type="text" name="push_coupon"></label>
						<label class="is-wide"><span><?php esc_html_e( 'Message', 'kidia-mobile-cms' ); ?></span><textarea name="push_message" maxlength="500" rows="4" required data-push-message placeholder="<?php esc_attr_e( 'Tell customers why they should open the app.', 'kidia-mobile-cms' ); ?>"><?php echo esc_textarea( $prefill_message ); ?></textarea></label>
					</div></section>

					<section class="kidia-push-form-section"><header><span class="dashicons dashicons-admin-links"></span><div><h3><?php esc_html_e( 'Open destination', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'Choose where the customer lands after tapping the notification.', 'kidia-mobile-cms' ); ?></p></div></header><div class="kidia-push-fields">
						<label><span><?php esc_html_e( 'Destination', 'kidia-mobile-cms' ); ?></span><select name="push_destination" data-push-destination><?php foreach ( $destination_labels as $key => $label ) : ?><option value="<?php echo esc_attr( $key ); ?>"><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
						<label><span><?php esc_html_e( 'Destination product/category/order ID', 'kidia-mobile-cms' ); ?></span><input type="text" name="push_destination_id" placeholder="<?php esc_attr_e( 'Shown when the destination needs an item', 'kidia-mobile-cms' ); ?>"></label>
						<label><span><?php esc_html_e( 'Action display', 'kidia-mobile-cms' ); ?></span><select name="push_action_style" data-push-action-style><option value="link"><?php esc_html_e( 'Open link', 'kidia-mobile-cms' ); ?></option><option value="button"><?php esc_html_e( 'Button', 'kidia-mobile-cms' ); ?></option></select></label>
						<label data-push-button-label hidden><span><?php esc_html_e( 'Button label', 'kidia-mobile-cms' ); ?></span><input type="text" name="push_cta_label" maxlength="30" value="<?php esc_attr_e( 'Open', 'kidia-mobile-cms' ); ?>"></label>
						<label class="is-wide"><span><?php esc_html_e( 'Custom URL or app deep link', 'kidia-mobile-cms' ); ?></span><input type="url" name="push_action_url" placeholder="https://"></label>
					</div></section>

					<section class="kidia-push-form-section"><header><span class="dashicons dashicons-controls-repeat"></span><div><h3><?php esc_html_e( 'Audience & delivery', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'Send once, schedule, or save a guarded automation.', 'kidia-mobile-cms' ); ?></p></div></header><div class="kidia-push-fields">
						<label><span><?php esc_html_e( 'Audience', 'kidia-mobile-cms' ); ?></span><select name="push_audience" data-push-audience><option value="all">All devices</option><option value="customers">Signed-in customers</option><option value="guests">Guest shoppers</option><option value="segment">Smart segment</option><option value="test">Test devices</option></select></label>
						<label><span><?php esc_html_e( 'Delivery', 'kidia-mobile-cms' ); ?></span><select name="push_delivery" data-push-delivery><option value="now">Send now</option><option value="scheduled">Schedule once</option><option value="automation">Save as automation</option></select></label>
						<label data-push-schedule hidden><span><?php esc_html_e( 'Send date and time', 'kidia-mobile-cms' ); ?></span><input type="datetime-local" name="push_schedule_at"></label>
						<div class="kidia-push-segment is-wide" data-push-segment hidden><label><span>Minimum orders</span><input type="number" min="0" name="push_min_orders"></label><label><span>Minimum spent</span><input type="number" min="0" step=".01" name="push_min_spent"></label><label><span>Inactive for days</span><input type="number" min="0" name="push_inactive_days"></label></div>
						<div class="kidia-push-automation is-wide" data-push-automation hidden>
							<label><span><?php esc_html_e( 'Trigger', 'kidia-mobile-cms' ); ?></span><select name="push_trigger"><option value="abandoned_cart">Cart becomes abandoned</option><option value="browse_abandonment">Viewed without cart</option><option value="checkout_abandonment">Checkout not completed</option><option value="welcome">Customer registers</option><option value="restock">Product is back in stock</option><option value="price_drop">Price drops</option><option value="winback">Customer becomes inactive</option><option value="new_product">New product is published</option><option value="coupon_expiry">Coupon is about to expire</option></select></label>
							<label><span><?php esc_html_e( 'First delay (minutes)', 'kidia-mobile-cms' ); ?></span><input type="number" min="0" max="43200" name="push_delay_minutes" value="30"></label>
							<label><span><?php esc_html_e( 'Maximum sends', 'kidia-mobile-cms' ); ?></span><input type="number" min="1" max="20" name="push_max_sends" value="3"></label>
							<label><span><?php esc_html_e( 'Cooldown (hours)', 'kidia-mobile-cms' ); ?></span><input type="number" min="1" max="8760" name="push_cooldown_hours" value="24"></label>
							<label><span><?php esc_html_e( 'Allowed from', 'kidia-mobile-cms' ); ?></span><input type="time" name="push_allowed_from" value="09:00"></label>
							<label><span><?php esc_html_e( 'Allowed until', 'kidia-mobile-cms' ); ?></span><input type="time" name="push_allowed_to" value="21:00"></label>
							<label class="kidia-push-check"><input type="checkbox" name="push_stop_on_purchase" value="1" checked><span><?php esc_html_e( 'Stop immediately after purchase', 'kidia-mobile-cms' ); ?></span></label>
						</div>
					</div></section>
				</div>

				<details class="kidia-push-advanced"><summary><?php esc_html_e( 'Advanced options', 'kidia-mobile-cms' ); ?></summary><div class="kidia-push-fields"><label class="is-wide"><span><?php esc_html_e( 'Image URL', 'kidia-mobile-cms' ); ?></span><input type="url" name="push_image_url" placeholder="https://"></label><label><span><?php esc_html_e( 'Priority', 'kidia-mobile-cms' ); ?></span><select name="push_priority"><option value="normal">Normal</option><option value="high">High</option></select></label><label><span><?php esc_html_e( 'Expires after (hours)', 'kidia-mobile-cms' ); ?></span><input type="number" name="push_expiry_hours" min="1" max="168" value="24"></label><label><span><?php esc_html_e( 'App badge number', 'kidia-mobile-cms' ); ?></span><input type="number" name="push_badge" min="0"></label><label class="kidia-push-check"><input type="checkbox" name="push_sound" value="1" checked><span><?php esc_html_e( 'Play notification sound', 'kidia-mobile-cms' ); ?></span></label></div></details>
				<div class="kidia-push-submit"><button class="button button-primary" type="submit"><span class="dashicons dashicons-paper-plane"></span><?php esc_html_e( 'Save & continue', 'kidia-mobile-cms' ); ?></button></div>
			</section>

			<aside class="kidia-push-preview"><small><?php esc_html_e( 'Live preview', 'kidia-mobile-cms' ); ?></small><div class="kidia-push-phone"><div class="kidia-push-clock">9:41</div><div class="kidia-push-bubble"><span>W</span><div><b data-push-preview-title><?php esc_html_e( 'Your notification title', 'kidia-mobile-cms' ); ?></b><p data-push-preview-message><?php esc_html_e( 'Your message will appear here.', 'kidia-mobile-cms' ); ?></p></div><small><?php esc_html_e( 'now', 'kidia-mobile-cms' ); ?></small></div></div></aside>
		</div>
	</form>

	<section class="kidia-push-history"><h2><?php esc_html_e( 'History & automations', 'kidia-mobile-cms' ); ?></h2><?php if ( $history ) : ?><div><?php foreach ( $history as $item ) : ?><article><span class="dashicons dashicons-megaphone"></span><div><strong><?php echo esc_html( (string) ( $item['title'] ?? '' ) ); ?></strong><p><?php echo esc_html( (string) ( $item['message'] ?? '' ) ); ?></p></div><small><?php echo esc_html( ucfirst( str_replace( '_', ' ', (string) ( $item['type'] ?? 'broadcast' ) ) ) ); ?> · <?php echo esc_html( wp_date( get_option( 'date_format' ) . ' ' . get_option( 'time_format' ), absint( $item['created_at'] ?? time() ) ) ); ?></small><em><?php echo esc_html( (string) ( $item['status'] ?? 'saved' ) ); ?></em></article><?php endforeach; ?></div><?php else : ?><div class="kidia-data-empty"><span class="dashicons dashicons-megaphone"></span><strong><?php esc_html_e( 'No notifications yet', 'kidia-mobile-cms' ); ?></strong></div><?php endif; ?></section>
</div>
