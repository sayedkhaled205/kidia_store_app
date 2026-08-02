<?php
/** Website-to-app promotion campaign builder. */
defined( 'ABSPATH' ) || exit;

$value = static function ( string $key ) use ( $promotion_settings ): string {
	return (string) ( $promotion_settings[ $key ] ?? '' );
};
$campaign = static function ( string $key ) use ( $promotion_settings ): array {
	return isset( $promotion_settings[ $key ] ) && is_array( $promotion_settings[ $key ] )
		? $promotion_settings[ $key ]
		: array();
};
$campaigns = array(
	'smart_banner' => array(
		__( 'Smart Banner', 'kidia-mobile-cms' ),
		'dashicons-align-full-width',
		__( 'A compact bar at the top or bottom. Recommended default.', 'kidia-mobile-cms' ),
		__( 'Mobile + desktop', 'kidia-mobile-cms' ),
	),
	'bottom_sheet' => array(
		__( 'Mobile Bottom Sheet', 'kidia-mobile-cms' ),
		'dashicons-align-wide',
		__( 'A touch-friendly app card that slides up on mobile.', 'kidia-mobile-cms' ),
		__( 'Mobile', 'kidia-mobile-cms' ),
	),
	'popup' => array(
		__( 'Timed Popup', 'kidia-mobile-cms' ),
		'dashicons-welcome-widgets-menus',
		__( 'A larger campaign with delay, scroll or exit trigger.', 'kidia-mobile-cms' ),
		__( 'Mobile + desktop', 'kidia-mobile-cms' ),
	),
	'desktop_qr' => array(
		__( 'Desktop QR Card', 'kidia-mobile-cms' ),
		'dashicons-screenoptions',
		__( 'A small QR download card for desktop visitors.', 'kidia-mobile-cms' ),
		__( 'Desktop', 'kidia-mobile-cms' ),
	),
	'floating_button' => array(
		__( 'Floating App Button', 'kidia-mobile-cms' ),
		'dashicons-smartphone',
		__( 'A persistent compact shortcut that opens the app campaign.', 'kidia-mobile-cms' ),
		__( 'Mobile + desktop', 'kidia-mobile-cms' ),
	),
	'inline_banner' => array(
		__( 'Inline Download Banner', 'kidia-mobile-cms' ),
		'dashicons-editor-insertmore',
		__( 'A full-width section inside the website content.', 'kidia-mobile-cms' ),
		__( 'Mobile + desktop', 'kidia-mobile-cms' ),
	),
);
$status_labels = array(
	'live'            => __( 'Live', 'kidia-mobile-cms' ),
	'announcement'    => __( 'Announcement live', 'kidia-mobile-cms' ),
	'needs-link'      => __( 'Needs app link', 'kidia-mobile-cms' ),
	'needs-placement' => __( 'Needs placement', 'kidia-mobile-cms' ),
	'paused'          => __( 'Paused', 'kidia-mobile-cms' ),
);
$campaign_statuses = array();
$live_count        = 0;
foreach ( array_keys( $campaigns ) as $campaign_key ) {
	$campaign_statuses[ $campaign_key ] = Kidia_Mobile_Website_App_Promotion::campaign_status( $campaign_key, $promotion_settings );
	if ( in_array( $campaign_statuses[ $campaign_key ], array( 'live', 'announcement' ), true ) ) {
		++$live_count;
	}
}
$has_destination = false;
foreach ( array( 'smart_url', 'android_url', 'ios_url', 'huawei_url', 'deep_link', 'qr_url' ) as $destination_key ) {
	if ( '' !== trim( $value( $destination_key ) ) ) {
		$has_destination = true;
		break;
	}
}
$click_rate = $promotion_metrics['views'] > 0
	? round( ( $promotion_metrics['clicks'] / $promotion_metrics['views'] ) * 100, 1 )
	: 0;
$preview_url  = Kidia_Mobile_Website_App_Promotion::preview_url();
$preview_host = (string) wp_parse_url( home_url( '/' ), PHP_URL_HOST );
?>
<div class="wrap kidia-app-promotion-admin" data-promotion-admin>
	<header class="kidia-app-promotion-hero">
		<div class="kidia-app-promotion-hero__copy">
			<span class="dashicons dashicons-welcome-view-site"></span>
			<div>
				<h1><?php esc_html_e( 'Promote Your App on the Website', 'kidia-mobile-cms' ); ?></h1>
				<p><?php esc_html_e( 'Turn website visitors into app users with smart banners, popups, QR codes and download links.', 'kidia-mobile-cms' ); ?></p>
			</div>
		</div>
		<span class="kidia-app-promotion-state <?php echo ! empty( $promotion_settings['enabled'] ) ? 'is-live' : ''; ?>">
			<i></i><span data-promotion-state-label><?php echo ! empty( $promotion_settings['enabled'] ) ? esc_html( sprintf( _n( '%d campaign live', '%d campaigns live', $live_count, 'kidia-mobile-cms' ), $live_count ) ) : esc_html__( 'Campaigns paused', 'kidia-mobile-cms' ); ?></span>
		</span>
	</header>

	<?php if ( isset( $_GET['promotion_saved'] ) ) : ?>
		<div class="kidia-app-promotion-notice"><span class="dashicons dashicons-yes-alt"></span><?php esc_html_e( 'Website app promotion settings saved.', 'kidia-mobile-cms' ); ?></div>
	<?php endif; ?>

	<section class="kidia-app-promotion-stats">
		<article><span class="dashicons dashicons-visibility"></span><div><b><?php echo esc_html( number_format_i18n( $promotion_metrics['views'] ) ); ?></b><small><?php esc_html_e( 'Campaign views', 'kidia-mobile-cms' ); ?></small></div></article>
		<article><span class="dashicons dashicons-download"></span><div><b><?php echo esc_html( number_format_i18n( $promotion_metrics['clicks'] ) ); ?></b><small><?php esc_html_e( 'Download clicks', 'kidia-mobile-cms' ); ?></small></div></article>
		<article><span class="dashicons dashicons-chart-line"></span><div><b><?php echo esc_html( (string) $click_rate ); ?>%</b><small><?php esc_html_e( 'Click rate', 'kidia-mobile-cms' ); ?></small></div></article>
		<article><span class="dashicons dashicons-dismiss"></span><div><b><?php echo esc_html( number_format_i18n( $promotion_metrics['dismisses'] ) ); ?></b><small><?php esc_html_e( 'Dismissed', 'kidia-mobile-cms' ); ?></small></div></article>
	</section>

	<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" data-promotion-form>
		<input type="hidden" name="action" value="kidia_mobile_save_website_app_promotion">
		<?php wp_nonce_field( 'kidia_mobile_save_website_app_promotion', 'kidia_mobile_promotion_nonce' ); ?>

		<section class="kidia-app-promotion-master">
			<div>
				<span class="dashicons dashicons-controls-play"></span>
				<div><strong><?php esc_html_e( 'Website app promotion', 'kidia-mobile-cms' ); ?></strong><small><?php esc_html_e( 'One master switch for every campaign below.', 'kidia-mobile-cms' ); ?></small></div>
			</div>
			<label class="kidia-promotion-switch"><input type="checkbox" name="promotion[enabled]" value="1" <?php checked( ! empty( $promotion_settings['enabled'] ) ); ?> data-promotion-master><span></span><b data-promotion-master-label><?php echo ! empty( $promotion_settings['enabled'] ) ? esc_html__( 'On', 'kidia-mobile-cms' ) : esc_html__( 'Off', 'kidia-mobile-cms' ); ?></b></label>
		</section>

		<section class="kidia-app-promotion-choose">
			<div class="kidia-app-promotion-heading">
				<b>1</b><div><h2><?php esc_html_e( 'Choose campaign types', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Enable one or combine several formats. Click any card to edit and preview it.', 'kidia-mobile-cms' ); ?></p></div>
			</div>
			<div class="kidia-app-promotion-types">
				<?php $first = true; foreach ( $campaigns as $key => $meta ) : $saved_campaign = $campaign( $key ); $campaign_status = $campaign_statuses[ $key ]; ?>
					<article class="<?php echo esc_attr( trim( ( $first ? 'is-selected ' : '' ) . ( in_array( $campaign_status, array( 'live', 'announcement' ), true ) ? 'is-enabled' : '' ) ) ); ?>" data-promotion-type="<?php echo esc_attr( $key ); ?>" data-promotion-status="<?php echo esc_attr( $campaign_status ); ?>" tabindex="0">
						<div class="kidia-app-promotion-type__top">
							<span class="dashicons <?php echo esc_attr( $meta[1] ); ?>"></span>
							<label class="kidia-promotion-switch"><input type="checkbox" name="promotion[<?php echo esc_attr( $key ); ?>][enabled]" value="1" <?php checked( ! empty( $saved_campaign['enabled'] ) ); ?>><span></span></label>
						</div>
						<strong><?php echo esc_html( $meta[0] ); ?></strong>
						<p><?php echo esc_html( $meta[2] ); ?></p>
						<div class="kidia-app-promotion-type__meta"><small><?php echo esc_html( $meta[3] ); ?></small><span class="kidia-app-promotion-type__status is-<?php echo esc_attr( $campaign_status ); ?>" data-promotion-status><?php echo esc_html( $status_labels[ $campaign_status ] ); ?></span></div>
						<div class="kidia-app-promotion-type__actions"><button type="button" data-edit-campaign="<?php echo esc_attr( $key ); ?>"><?php esc_html_e( 'Edit & preview', 'kidia-mobile-cms' ); ?></button><a href="<?php echo esc_url( Kidia_Mobile_Website_App_Promotion::test_url( $key ) ); ?>" target="_blank" rel="noopener" data-test-campaign="<?php echo esc_attr( $key ); ?>"><?php esc_html_e( 'Test on live site', 'kidia-mobile-cms' ); ?></a></div>
					</article>
				<?php $first = false; endforeach; ?>
			</div>
		</section>

		<div class="kidia-app-promotion-workspace">
			<main>
				<section class="kidia-app-promotion-panel">
					<div class="kidia-app-promotion-heading">
						<b>2</b><div><h2><?php esc_html_e( 'App & download links', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'The correct store opens automatically for each visitor.', 'kidia-mobile-cms' ); ?></p></div>
					</div>
					<div class="kidia-promotion-fields is-three">
						<label><span><?php esc_html_e( 'App name', 'kidia-mobile-cms' ); ?></span><input type="text" name="promotion[app_name]" value="<?php echo esc_attr( $value( 'app_name' ) ); ?>" data-preview-field="app_name"></label>
						<label><span><?php esc_html_e( 'Short headline', 'kidia-mobile-cms' ); ?></span><input type="text" name="promotion[tagline]" value="<?php echo esc_attr( $value( 'tagline' ) ); ?>" data-preview-field="tagline"></label>
						<label class="kidia-promotion-media"><span><?php esc_html_e( 'App icon URL', 'kidia-mobile-cms' ); ?></span><div><input type="url" name="promotion[logo_url]" value="<?php echo esc_attr( $value( 'logo_url' ) ); ?>" data-preview-field="logo_url"><button type="button" class="button" data-promotion-media><?php esc_html_e( 'Choose', 'kidia-mobile-cms' ); ?></button></div></label>
						<label class="is-wide"><span><?php esc_html_e( 'Description', 'kidia-mobile-cms' ); ?></span><input type="text" name="promotion[description]" value="<?php echo esc_attr( $value( 'description' ) ); ?>" data-preview-field="description"></label>
						<label><span><?php esc_html_e( 'Google Play URL', 'kidia-mobile-cms' ); ?></span><input type="url" name="promotion[android_url]" value="<?php echo esc_attr( $value( 'android_url' ) ); ?>" placeholder="https://play.google.com/store/apps/details?id=…"></label>
						<label><span><?php esc_html_e( 'Apple App Store URL', 'kidia-mobile-cms' ); ?></span><input type="url" name="promotion[ios_url]" value="<?php echo esc_attr( $value( 'ios_url' ) ); ?>" placeholder="https://apps.apple.com/app/id…"></label>
						<label><span><?php esc_html_e( 'Huawei AppGallery URL', 'kidia-mobile-cms' ); ?></span><input type="url" name="promotion[huawei_url]" value="<?php echo esc_attr( $value( 'huawei_url' ) ); ?>" placeholder="https://appgallery.huawei.com/…"></label>
						<label><span><?php esc_html_e( 'One smart link (optional)', 'kidia-mobile-cms' ); ?></span><input type="url" name="promotion[smart_url]" value="<?php echo esc_attr( $value( 'smart_url' ) ); ?>" placeholder="https://your-smart-link.example"></label>
						<label><span><?php esc_html_e( 'App deep link (optional)', 'kidia-mobile-cms' ); ?></span><input type="text" name="promotion[deep_link]" value="<?php echo esc_attr( $value( 'deep_link' ) ); ?>" placeholder="woomobile://home"></label>
						<label><span><?php esc_html_e( 'Custom QR destination (optional)', 'kidia-mobile-cms' ); ?></span><input type="url" name="promotion[qr_url]" value="<?php echo esc_attr( $value( 'qr_url' ) ); ?>" placeholder="Defaults to the smart link"></label>
					</div>
					<div class="kidia-promotion-tip"><span class="dashicons dashicons-lightbulb"></span><p><strong><?php esc_html_e( 'Best setup:', 'kidia-mobile-cms' ); ?></strong> <?php esc_html_e( 'Use one smart link if available. Otherwise Android, iOS and Huawei visitors are routed to their matching store automatically.', 'kidia-mobile-cms' ); ?></p></div>
					<?php if ( ! $has_destination ) : ?>
						<div class="kidia-promotion-warning is-link-status"><span class="dashicons dashicons-info-outline"></span><p><strong><?php esc_html_e( 'Safe announcement mode is active.', 'kidia-mobile-cms' ); ?></strong> <?php esc_html_e( 'Every enabled campaign stays customer-facing without a dead action. Until an app link is added, QR uses an honest placeholder and the floating shortcut remains visibly disabled.', 'kidia-mobile-cms' ); ?></p></div>
					<?php else : ?>
						<div class="kidia-promotion-ready"><span class="dashicons dashicons-yes-alt"></span><p><?php esc_html_e( 'App destination connected. Every enabled format can open or download the app.', 'kidia-mobile-cms' ); ?></p></div>
					<?php endif; ?>
				</section>

				<section class="kidia-app-promotion-panel">
					<div class="kidia-app-promotion-heading">
						<b>3</b><div><h2><?php esc_html_e( 'Message & design', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Use an app-only benefit to give customers a reason to install.', 'kidia-mobile-cms' ); ?></p></div>
					</div>
					<div class="kidia-promotion-fields is-three">
						<label><span><?php esc_html_e( 'Download button', 'kidia-mobile-cms' ); ?></span><input type="text" name="promotion[button_label]" value="<?php echo esc_attr( $value( 'button_label' ) ); ?>" data-preview-field="button_label"></label>
						<label><span><?php esc_html_e( 'Open app button', 'kidia-mobile-cms' ); ?></span><input type="text" name="promotion[open_label]" value="<?php echo esc_attr( $value( 'open_label' ) ); ?>"></label>
						<label><span><?php esc_html_e( 'Dismiss text', 'kidia-mobile-cms' ); ?></span><input type="text" name="promotion[dismiss_label]" value="<?php echo esc_attr( $value( 'dismiss_label' ) ); ?>"></label>
						<label><span><?php esc_html_e( 'App-only offer', 'kidia-mobile-cms' ); ?></span><input type="text" name="promotion[offer_text]" value="<?php echo esc_attr( $value( 'offer_text' ) ); ?>" placeholder="<?php esc_attr_e( '10% off your first app order', 'kidia-mobile-cms' ); ?>" data-preview-field="offer_text"></label>
						<label><span><?php esc_html_e( 'Coupon code', 'kidia-mobile-cms' ); ?></span><input type="text" name="promotion[coupon_code]" value="<?php echo esc_attr( $value( 'coupon_code' ) ); ?>" placeholder="APP10" data-preview-field="coupon_code"></label>
						<div class="kidia-promotion-colors">
							<label><span><?php esc_html_e( 'Brand', 'kidia-mobile-cms' ); ?></span><input type="color" name="promotion[primary_color]" value="<?php echo esc_attr( $value( 'primary_color' ) ); ?>" data-preview-field="primary_color"></label>
							<label><span><?php esc_html_e( 'Text', 'kidia-mobile-cms' ); ?></span><input type="color" name="promotion[text_color]" value="<?php echo esc_attr( $value( 'text_color' ) ); ?>" data-preview-field="text_color"></label>
							<label><span><?php esc_html_e( 'Surface', 'kidia-mobile-cms' ); ?></span><input type="color" name="promotion[surface_color]" value="<?php echo esc_attr( $value( 'surface_color' ) ); ?>" data-preview-field="surface_color"></label>
						</div>
					</div>
				</section>

				<section class="kidia-app-promotion-panel">
					<div class="kidia-app-promotion-heading">
						<b>4</b><div><h2><?php esc_html_e( 'Selected campaign settings', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Only the settings for the selected card are shown.', 'kidia-mobile-cms' ); ?></p></div>
					</div>

					<?php $smart = $campaign( 'smart_banner' ); ?>
					<div class="kidia-promotion-campaign-settings is-active" data-promotion-campaign-panel="smart_banner">
						<h3><span class="dashicons dashicons-align-full-width"></span><?php esc_html_e( 'Smart Banner', 'kidia-mobile-cms' ); ?></h3>
						<div class="kidia-promotion-fields is-three">
							<label><span><?php esc_html_e( 'Position', 'kidia-mobile-cms' ); ?></span><select name="promotion[smart_banner][position]"><option value="top" <?php selected( $smart['position'] ?? '', 'top' ); ?>><?php esc_html_e( 'Top of screen', 'kidia-mobile-cms' ); ?></option><option value="bottom" <?php selected( $smart['position'] ?? '', 'bottom' ); ?>><?php esc_html_e( 'Bottom of screen', 'kidia-mobile-cms' ); ?></option></select></label>
							<label><span><?php esc_html_e( 'Show after (seconds)', 'kidia-mobile-cms' ); ?></span><input type="number" min="0" max="100" name="promotion[smart_banner][delay]" value="<?php echo esc_attr( (string) ( $smart['delay'] ?? 0 ) ); ?>"></label>
						</div>
					</div>

					<?php $sheet = $campaign( 'bottom_sheet' ); ?>
					<div class="kidia-promotion-campaign-settings" data-promotion-campaign-panel="bottom_sheet" hidden>
						<h3><span class="dashicons dashicons-align-wide"></span><?php esc_html_e( 'Mobile Bottom Sheet', 'kidia-mobile-cms' ); ?></h3>
						<div class="kidia-promotion-fields is-three">
							<label><span><?php esc_html_e( 'Trigger', 'kidia-mobile-cms' ); ?></span><select name="promotion[bottom_sheet][trigger]"><option value="immediate" <?php selected( $sheet['trigger'] ?? '', 'immediate' ); ?>><?php esc_html_e( 'Immediately', 'kidia-mobile-cms' ); ?></option><option value="delay" <?php selected( $sheet['trigger'] ?? '', 'delay' ); ?>><?php esc_html_e( 'After delay', 'kidia-mobile-cms' ); ?></option><option value="scroll" <?php selected( $sheet['trigger'] ?? '', 'scroll' ); ?>><?php esc_html_e( 'After scrolling', 'kidia-mobile-cms' ); ?></option></select></label>
							<label><span><?php esc_html_e( 'Delay (seconds)', 'kidia-mobile-cms' ); ?></span><input type="number" min="0" max="100" name="promotion[bottom_sheet][delay]" value="<?php echo esc_attr( (string) ( $sheet['delay'] ?? 8 ) ); ?>"></label>
							<label><span><?php esc_html_e( 'Scroll depth (%)', 'kidia-mobile-cms' ); ?></span><input type="number" min="0" max="100" name="promotion[bottom_sheet][scroll]" value="<?php echo esc_attr( (string) ( $sheet['scroll'] ?? 35 ) ); ?>"></label>
							<label><span><?php esc_html_e( 'Layout', 'kidia-mobile-cms' ); ?></span><select name="promotion[bottom_sheet][style]"><option value="compact" <?php selected( $sheet['style'] ?? '', 'compact' ); ?>><?php esc_html_e( 'Compact app card', 'kidia-mobile-cms' ); ?></option><option value="coupon" <?php selected( $sheet['style'] ?? '', 'coupon' ); ?>><?php esc_html_e( 'Coupon focused', 'kidia-mobile-cms' ); ?></option><option value="image" <?php selected( $sheet['style'] ?? '', 'image' ); ?>><?php esc_html_e( 'Large app icon', 'kidia-mobile-cms' ); ?></option></select></label>
						</div>
					</div>

					<?php $popup = $campaign( 'popup' ); ?>
					<div class="kidia-promotion-campaign-settings" data-promotion-campaign-panel="popup" hidden>
						<h3><span class="dashicons dashicons-welcome-widgets-menus"></span><?php esc_html_e( 'Timed Popup', 'kidia-mobile-cms' ); ?></h3>
						<div class="kidia-promotion-fields is-three">
							<label><span><?php esc_html_e( 'Trigger', 'kidia-mobile-cms' ); ?></span><select name="promotion[popup][trigger]"><option value="exit" <?php selected( $popup['trigger'] ?? '', 'exit' ); ?>><?php esc_html_e( 'Exit intent (desktop)', 'kidia-mobile-cms' ); ?></option><option value="delay" <?php selected( $popup['trigger'] ?? '', 'delay' ); ?>><?php esc_html_e( 'After delay', 'kidia-mobile-cms' ); ?></option><option value="scroll" <?php selected( $popup['trigger'] ?? '', 'scroll' ); ?>><?php esc_html_e( 'After scrolling', 'kidia-mobile-cms' ); ?></option></select></label>
							<label><span><?php esc_html_e( 'Delay / touch fallback (seconds)', 'kidia-mobile-cms' ); ?></span><input type="number" min="0" max="100" name="promotion[popup][delay]" value="<?php echo esc_attr( (string) ( $popup['delay'] ?? 12 ) ); ?>"></label>
							<label><span><?php esc_html_e( 'Scroll depth (%)', 'kidia-mobile-cms' ); ?></span><input type="number" min="0" max="100" name="promotion[popup][scroll]" value="<?php echo esc_attr( (string) ( $popup['scroll'] ?? 50 ) ); ?>"></label>
							<label><span><?php esc_html_e( 'Layout', 'kidia-mobile-cms' ); ?></span><select name="promotion[popup][style]"><option value="split" <?php selected( $popup['style'] ?? '', 'split' ); ?>><?php esc_html_e( 'Split app + copy', 'kidia-mobile-cms' ); ?></option><option value="centered" <?php selected( $popup['style'] ?? '', 'centered' ); ?>><?php esc_html_e( 'Centered', 'kidia-mobile-cms' ); ?></option><option value="coupon" <?php selected( $popup['style'] ?? '', 'coupon' ); ?>><?php esc_html_e( 'Coupon focused', 'kidia-mobile-cms' ); ?></option></select></label>
						</div>
						<div class="kidia-promotion-warning"><span class="dashicons dashicons-shield"></span><p><?php esc_html_e( 'To protect mobile UX and search visibility, exit intent automatically falls back to a delayed bottom-style card on touch devices.', 'kidia-mobile-cms' ); ?></p></div>
					</div>

					<?php $qr = $campaign( 'desktop_qr' ); ?>
					<div class="kidia-promotion-campaign-settings" data-promotion-campaign-panel="desktop_qr" hidden>
						<h3><span class="dashicons dashicons-screenoptions"></span><?php esc_html_e( 'Desktop QR Card', 'kidia-mobile-cms' ); ?></h3>
						<div class="kidia-promotion-fields is-three">
							<label><span><?php esc_html_e( 'Position', 'kidia-mobile-cms' ); ?></span><select name="promotion[desktop_qr][position]"><option value="bottom-right" <?php selected( $qr['position'] ?? '', 'bottom-right' ); ?>><?php esc_html_e( 'Bottom right', 'kidia-mobile-cms' ); ?></option><option value="bottom-left" <?php selected( $qr['position'] ?? '', 'bottom-left' ); ?>><?php esc_html_e( 'Bottom left', 'kidia-mobile-cms' ); ?></option></select></label>
							<label><span><?php esc_html_e( 'Show after (seconds)', 'kidia-mobile-cms' ); ?></span><input type="number" min="0" max="100" name="promotion[desktop_qr][delay]" value="<?php echo esc_attr( (string) ( $qr['delay'] ?? 3 ) ); ?>"></label>
						</div>
					</div>

					<?php $floating = $campaign( 'floating_button' ); ?>
					<div class="kidia-promotion-campaign-settings" data-promotion-campaign-panel="floating_button" hidden>
						<h3><span class="dashicons dashicons-smartphone"></span><?php esc_html_e( 'Floating App Button', 'kidia-mobile-cms' ); ?></h3>
						<div class="kidia-promotion-fields is-three">
							<label><span><?php esc_html_e( 'Position', 'kidia-mobile-cms' ); ?></span><select name="promotion[floating_button][position]"><option value="bottom-left" <?php selected( $floating['position'] ?? '', 'bottom-left' ); ?>><?php esc_html_e( 'Bottom left', 'kidia-mobile-cms' ); ?></option><option value="bottom-right" <?php selected( $floating['position'] ?? '', 'bottom-right' ); ?>><?php esc_html_e( 'Bottom right', 'kidia-mobile-cms' ); ?></option></select></label>
							<label><span><?php esc_html_e( 'Button label', 'kidia-mobile-cms' ); ?></span><input type="text" name="promotion[floating_button][label]" value="<?php echo esc_attr( (string) ( $floating['label'] ?? '' ) ); ?>"></label>
						</div>
					</div>

					<?php $inline = $campaign( 'inline_banner' ); ?>
					<div class="kidia-promotion-campaign-settings" data-promotion-campaign-panel="inline_banner" hidden>
						<h3><span class="dashicons dashicons-editor-insertmore"></span><?php esc_html_e( 'Inline Download Banner', 'kidia-mobile-cms' ); ?></h3>
						<div class="kidia-promotion-fields is-three">
							<label><span><?php esc_html_e( 'Placement', 'kidia-mobile-cms' ); ?></span><select name="promotion[inline_banner][placement]" data-inline-placement><option value="shortcode" <?php selected( $inline['placement'] ?? '', 'shortcode' ); ?>><?php esc_html_e( 'Shortcode — place manually', 'kidia-mobile-cms' ); ?></option><option value="after_header" <?php selected( $inline['placement'] ?? '', 'after_header' ); ?>><?php esc_html_e( 'Automatically after header', 'kidia-mobile-cms' ); ?></option><option value="before_footer" <?php selected( $inline['placement'] ?? '', 'before_footer' ); ?>><?php esc_html_e( 'Automatically before footer', 'kidia-mobile-cms' ); ?></option></select></label>
							<label><span><?php esc_html_e( 'Layout', 'kidia-mobile-cms' ); ?></span><select name="promotion[inline_banner][style]"><option value="wide" <?php selected( $inline['style'] ?? '', 'wide' ); ?>><?php esc_html_e( 'Wide banner', 'kidia-mobile-cms' ); ?></option><option value="card" <?php selected( $inline['style'] ?? '', 'card' ); ?>><?php esc_html_e( 'Centered card', 'kidia-mobile-cms' ); ?></option><option value="coupon" <?php selected( $inline['style'] ?? '', 'coupon' ); ?>><?php esc_html_e( 'Offer + coupon', 'kidia-mobile-cms' ); ?></option></select></label>
							<div class="kidia-promotion-shortcode"><span><?php esc_html_e( 'Shortcode', 'kidia-mobile-cms' ); ?></span><code>[woo_mobile_app_promo]</code><button type="button" class="button" data-copy-shortcode><?php esc_html_e( 'Copy', 'kidia-mobile-cms' ); ?></button></div>
						</div>
					</div>
				</section>

				<section class="kidia-app-promotion-panel">
					<div class="kidia-app-promotion-heading">
						<b>5</b><div><h2><?php esc_html_e( 'Audience & frequency', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Show the campaign at the right moment without annoying repeat visitors.', 'kidia-mobile-cms' ); ?></p></div>
					</div>
					<div class="kidia-promotion-fields is-three">
						<label><span><?php esc_html_e( 'Devices', 'kidia-mobile-cms' ); ?></span><select name="promotion[audience_devices]"><option value="all" <?php selected( $value( 'audience_devices' ), 'all' ); ?>><?php esc_html_e( 'All devices', 'kidia-mobile-cms' ); ?></option><option value="mobile" <?php selected( $value( 'audience_devices' ), 'mobile' ); ?>><?php esc_html_e( 'Mobile only', 'kidia-mobile-cms' ); ?></option><option value="desktop" <?php selected( $value( 'audience_devices' ), 'desktop' ); ?>><?php esc_html_e( 'Desktop only', 'kidia-mobile-cms' ); ?></option><option value="android" <?php selected( $value( 'audience_devices' ), 'android' ); ?>><?php esc_html_e( 'Android only', 'kidia-mobile-cms' ); ?></option><option value="ios" <?php selected( $value( 'audience_devices' ), 'ios' ); ?>><?php esc_html_e( 'iPhone / iPad only', 'kidia-mobile-cms' ); ?></option></select></label>
						<label><span><?php esc_html_e( 'Visitors', 'kidia-mobile-cms' ); ?></span><select name="promotion[audience_users]"><option value="all" <?php selected( $value( 'audience_users' ), 'all' ); ?>><?php esc_html_e( 'Everyone', 'kidia-mobile-cms' ); ?></option><option value="guests" <?php selected( $value( 'audience_users' ), 'guests' ); ?>><?php esc_html_e( 'Guests only', 'kidia-mobile-cms' ); ?></option><option value="customers" <?php selected( $value( 'audience_users' ), 'customers' ); ?>><?php esc_html_e( 'Signed-in customers', 'kidia-mobile-cms' ); ?></option></select></label>
						<label><span><?php esc_html_e( 'Pages', 'kidia-mobile-cms' ); ?></span><select name="promotion[page_target]" data-page-target><option value="all" <?php selected( $value( 'page_target' ), 'all' ); ?>><?php esc_html_e( 'All website pages', 'kidia-mobile-cms' ); ?></option><option value="home" <?php selected( $value( 'page_target' ), 'home' ); ?>><?php esc_html_e( 'Home only', 'kidia-mobile-cms' ); ?></option><option value="shop" <?php selected( $value( 'page_target' ), 'shop' ); ?>><?php esc_html_e( 'Shop only', 'kidia-mobile-cms' ); ?></option><option value="product" <?php selected( $value( 'page_target' ), 'product' ); ?>><?php esc_html_e( 'Product pages', 'kidia-mobile-cms' ); ?></option><option value="category" <?php selected( $value( 'page_target' ), 'category' ); ?>><?php esc_html_e( 'Category pages', 'kidia-mobile-cms' ); ?></option><option value="cart" <?php selected( $value( 'page_target' ), 'cart' ); ?>><?php esc_html_e( 'Cart only', 'kidia-mobile-cms' ); ?></option><option value="checkout" <?php selected( $value( 'page_target' ), 'checkout' ); ?>><?php esc_html_e( 'Checkout only', 'kidia-mobile-cms' ); ?></option><option value="custom" <?php selected( $value( 'page_target' ), 'custom' ); ?>><?php esc_html_e( 'Custom URL paths', 'kidia-mobile-cms' ); ?></option></select></label>
						<label class="is-wide" data-custom-paths <?php echo 'custom' === $value( 'page_target' ) ? '' : 'hidden'; ?>><span><?php esc_html_e( 'Included URL paths — one per line', 'kidia-mobile-cms' ); ?></span><textarea name="promotion[custom_paths]" rows="3" placeholder="/shop/&#10;/summer-sale/"><?php echo esc_textarea( $value( 'custom_paths' ) ); ?></textarea></label>
						<label class="is-wide"><span><?php esc_html_e( 'Excluded URL paths — one per line', 'kidia-mobile-cms' ); ?></span><textarea name="promotion[excluded_paths]" rows="3" placeholder="/checkout/order-received/"><?php echo esc_textarea( $value( 'excluded_paths' ) ); ?></textarea></label>
						<label><span><?php esc_html_e( 'Show after dismissal', 'kidia-mobile-cms' ); ?></span><select name="promotion[frequency]"><option value="session" <?php selected( $value( 'frequency' ), 'session' ); ?>><?php esc_html_e( 'Next browser session', 'kidia-mobile-cms' ); ?></option><option value="daily" <?php selected( $value( 'frequency' ), 'daily' ); ?>><?php esc_html_e( 'After 1 day', 'kidia-mobile-cms' ); ?></option><option value="three_days" <?php selected( $value( 'frequency' ), 'three_days' ); ?>><?php esc_html_e( 'After 3 days', 'kidia-mobile-cms' ); ?></option><option value="weekly" <?php selected( $value( 'frequency' ), 'weekly' ); ?>><?php esc_html_e( 'After 7 days', 'kidia-mobile-cms' ); ?></option><option value="always" <?php selected( $value( 'frequency' ), 'always' ); ?>><?php esc_html_e( 'Every visit', 'kidia-mobile-cms' ); ?></option></select></label>
					</div>
				</section>

				<details class="kidia-app-promotion-native">
					<summary><span class="dashicons dashicons-apple"></span><div><strong><?php esc_html_e( 'Native Apple Smart App Banner', 'kidia-mobile-cms' ); ?></strong><small><?php esc_html_e( 'Optional standard Safari banner. Apple controls its design.', 'kidia-mobile-cms' ); ?></small></div><span class="dashicons dashicons-arrow-down-alt2"></span></summary>
					<div class="kidia-promotion-fields is-three">
						<label class="kidia-promotion-check"><input type="checkbox" name="promotion[native_ios_enabled]" value="1" <?php checked( ! empty( $promotion_settings['native_ios_enabled'] ) ); ?>><span><?php esc_html_e( 'Enable the native iOS banner', 'kidia-mobile-cms' ); ?></span></label>
						<label><span><?php esc_html_e( 'Apple App ID', 'kidia-mobile-cms' ); ?></span><input type="text" inputmode="numeric" name="promotion[ios_app_id]" value="<?php echo esc_attr( $value( 'ios_app_id' ) ); ?>" placeholder="123456789"></label>
						<label><span><?php esc_html_e( 'App argument / deep link', 'kidia-mobile-cms' ); ?></span><input type="url" name="promotion[ios_app_argument]" value="<?php echo esc_attr( $value( 'ios_app_argument' ) ); ?>" placeholder="https://store.example/product"></label>
					</div>
				</details>

				<div class="kidia-app-promotion-save">
					<button type="submit" class="button button-primary"><span class="dashicons dashicons-saved"></span><?php esc_html_e( 'Save & Publish Campaigns', 'kidia-mobile-cms' ); ?></button>
					<small><?php esc_html_e( 'Changes appear on the website immediately after saving.', 'kidia-mobile-cms' ); ?></small>
				</div>
			</main>

			<aside class="kidia-app-promotion-preview">
				<header><div><strong><?php esc_html_e( 'Live preview', 'kidia-mobile-cms' ); ?></strong><small data-preview-campaign-label><?php esc_html_e( 'Smart Banner', 'kidia-mobile-cms' ); ?></small></div><div class="kidia-promotion-device-switch" role="group" aria-label="<?php esc_attr_e( 'Preview device', 'kidia-mobile-cms' ); ?>"><button type="button" data-preview-device="mobile" aria-label="<?php esc_attr_e( 'Mobile preview', 'kidia-mobile-cms' ); ?>" aria-pressed="false"><span class="dashicons dashicons-smartphone" aria-hidden="true"></span></button><button type="button" class="is-active" data-preview-device="desktop" aria-label="<?php esc_attr_e( 'Laptop preview', 'kidia-mobile-cms' ); ?>" aria-pressed="true"><span class="dashicons dashicons-desktop" aria-hidden="true"></span></button></div></header>
				<div class="kidia-promotion-device is-desktop" data-promotion-preview>
					<div class="kidia-promotion-screen" data-promotion-screen>
						<div class="kidia-promotion-browser" data-promotion-browser>
							<div class="kidia-promotion-browser__bar"><i></i><i></i><i></i><span><?php echo esc_html( $preview_host ); ?></span></div>
							<div class="kidia-promotion-live-site">
								<iframe
									src="<?php echo esc_url( $preview_url ); ?>"
									title="<?php esc_attr_e( 'Live website campaign preview', 'kidia-mobile-cms' ); ?>"
									loading="eager"
									data-promotion-site-frame
								></iframe>
							</div>
							<div class="kidia-promotion-preview-output" data-preview-output></div>
						</div>
					</div>
				</div>
				<p class="kidia-app-promotion-preview__hint"><span class="dashicons dashicons-info-outline"></span><?php esc_html_e( 'Preview updates while you type. The live website also applies device, page and frequency rules.', 'kidia-mobile-cms' ); ?></p>
			</aside>
		</div>
	</form>
</div>
