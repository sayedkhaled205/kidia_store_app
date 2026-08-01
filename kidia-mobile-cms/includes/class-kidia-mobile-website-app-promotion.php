<?php
/**
 * Website-to-app promotion campaigns.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_Website_App_Promotion {

	public const OPTION = 'kidia_mobile_website_app_promotion_v1';
	private const METRICS_OPTION = 'kidia_mobile_website_app_promotion_metrics_v1';
	private const PREVIEW_ACTION = 'kidia_mobile_website_app_promotion_preview';
	private const PREVIEW_QUERY = 'kidia_app_promotion_preview';
	private const TEST_ACTION = 'kidia_mobile_website_app_promotion_test';
	private const TEST_QUERY = 'kidia_app_promotion_test';
	private const TEST_NONCE_QUERY = 'kidia_app_promotion_test_nonce';
	private const CAMPAIGNS = array(
		'smart_banner',
		'bottom_sheet',
		'popup',
		'desktop_qr',
		'floating_button',
		'inline_banner',
	);

	public function register(): void {
		add_action( 'wp_enqueue_scripts', array( $this, 'enqueue_assets' ), 40 );
		add_action( 'wp_head', array( $this, 'render_native_ios_banner' ), 2 );
		add_action( 'wp_body_open', array( $this, 'render_after_header_slot' ), 30 );
		add_action( 'wp_footer', array( $this, 'render_footer' ), 5 );
		add_shortcode( 'woo_mobile_app_promo', array( $this, 'shortcode' ) );
		add_action( 'admin_post_kidia_mobile_save_website_app_promotion', array( $this, 'save' ) );
		add_action( 'wp_ajax_kidia_mobile_app_promotion_event', array( $this, 'track_event' ) );
		add_action( 'wp_ajax_nopriv_kidia_mobile_app_promotion_event', array( $this, 'track_event' ) );
	}

	/** @return array<string,mixed> */
	public static function defaults(): array {
		$identity = class_exists( 'Kidia_Mobile_Setup_Wizard' )
			? ( new Kidia_Mobile_Setup_Wizard() )->identity()
			: array();

		return array(
			'enabled'             => false,
			'app_name'            => sanitize_text_field( (string) ( $identity['app_name'] ?? get_bloginfo( 'name' ) ) ),
			'tagline'             => __( 'Shop faster and get app-only offers.', 'kidia-mobile-cms' ),
			'description'         => __( 'Download our app for a smoother shopping experience.', 'kidia-mobile-cms' ),
			'logo_url'            => esc_url_raw( (string) ( $identity['logo_url'] ?? '' ) ),
			'primary_color'       => sanitize_hex_color( (string) ( $identity['primary_color'] ?? '' ) ) ?: '#2F806E',
			'text_color'          => '#15352D',
			'surface_color'       => '#FFFFFF',
			'button_label'        => __( 'Download app', 'kidia-mobile-cms' ),
			'open_label'          => __( 'Open app', 'kidia-mobile-cms' ),
			'dismiss_label'       => __( 'Not now', 'kidia-mobile-cms' ),
			'offer_text'          => '',
			'coupon_code'         => '',
			'android_url'         => '',
			'ios_url'             => '',
			'huawei_url'          => '',
			'smart_url'           => '',
			'deep_link'           => '',
			'qr_url'              => '',
			'audience_devices'    => 'all',
			'audience_users'      => 'all',
			'page_target'         => 'all',
			'custom_paths'        => '',
			'excluded_paths'      => '/checkout/order-received/',
			'frequency'           => 'daily',
			'native_ios_enabled'  => false,
			'ios_app_id'          => '',
			'ios_app_argument'    => '',
			'smart_banner'        => array(
				'enabled'  => true,
				'position' => 'top',
				'delay'    => 0,
			),
			'bottom_sheet'        => array(
				'enabled'  => false,
				'trigger'  => 'delay',
				'delay'    => 8,
				'scroll'   => 35,
				'style'    => 'compact',
			),
			'popup'              => array(
				'enabled' => false,
				'trigger' => 'exit',
				'delay'   => 12,
				'scroll'  => 50,
				'style'   => 'split',
			),
			'desktop_qr'         => array(
				'enabled'  => true,
				'position' => 'bottom-right',
				'delay'    => 3,
			),
			'floating_button'    => array(
				'enabled'  => false,
				'position' => 'bottom-left',
				'label'    => __( 'Get the app', 'kidia-mobile-cms' ),
			),
			'inline_banner'      => array(
				'enabled'   => false,
				'placement' => 'shortcode',
				'style'     => 'wide',
			),
		);
	}

	/** @return array<string,mixed> */
	public static function settings(): array {
		$saved = get_option( self::OPTION, array() );
		$settings = self::merge_settings( self::defaults(), is_array( $saved ) ? $saved : array() );
		if ( '' === trim( (string) $settings['logo_url'] ) ) {
			$settings['logo_url'] = self::site_logo_url();
		}
		return $settings;
	}

	/** @return array<string,int> */
	public static function metrics(): array {
		$saved = get_option( self::METRICS_OPTION, array() );
		return wp_parse_args(
			is_array( $saved ) ? array_map( 'absint', $saved ) : array(),
			array(
				'views'     => 0,
				'clicks'    => 0,
				'dismisses' => 0,
			)
		);
	}

	public static function preview_url(): string {
		return add_query_arg(
			self::PREVIEW_QUERY,
			wp_create_nonce( self::PREVIEW_ACTION ),
			home_url( '/' )
		);
	}

	public static function test_url( string $campaign ): string {
		if ( ! in_array( $campaign, self::CAMPAIGNS, true ) ) {
			return home_url( '/' );
		}
		return add_query_arg(
			array(
				self::TEST_QUERY       => $campaign,
				self::TEST_NONCE_QUERY => wp_create_nonce( self::TEST_ACTION . '|' . $campaign ),
			),
			home_url( '/' )
		);
	}

	/** @param array<string,mixed>|null $settings */
	public static function campaign_status( string $campaign, ?array $settings = null ): string {
		$settings = is_array( $settings ) ? $settings : self::settings();
		if (
			! in_array( $campaign, self::CAMPAIGNS, true )
			|| empty( $settings['enabled'] )
			|| empty( $settings[ $campaign ]['enabled'] )
		) {
			return 'paused';
		}
		if ( in_array( $campaign, array( 'desktop_qr', 'floating_button' ), true ) && ! self::has_destination( $settings, $campaign ) ) {
			return 'needs-link';
		}
		if (
			'inline_banner' === $campaign
			&& 'shortcode' === (string) ( $settings['inline_banner']['placement'] ?? '' )
		) {
			return 'needs-placement';
		}
		return self::has_destination( $settings, $campaign ) ? 'live' : 'announcement';
	}

	/** @param array<string,mixed> $settings */
	private static function has_destination( array $settings, string $campaign = '' ): bool {
		if ( 'desktop_qr' === $campaign && '' !== trim( (string) ( $settings['qr_url'] ?? '' ) ) ) {
			return true;
		}
		foreach ( array( 'smart_url', 'android_url', 'ios_url', 'huawei_url', 'deep_link', 'qr_url' ) as $key ) {
			if ( '' !== trim( (string) ( $settings[ $key ] ?? '' ) ) ) {
				return true;
			}
		}
		return false;
	}

	private static function site_logo_url(): string {
		$custom_logo_id = function_exists( 'get_theme_mod' )
			? absint( get_theme_mod( 'custom_logo', 0 ) )
			: 0;
		if ( $custom_logo_id > 0 && function_exists( 'wp_get_attachment_image_url' ) ) {
			$custom_logo = wp_get_attachment_image_url( $custom_logo_id, 'full' );
			if ( is_string( $custom_logo ) && '' !== $custom_logo ) {
				return esc_url_raw( $custom_logo );
			}
		}
		$site_icon = function_exists( 'get_site_icon_url' ) ? get_site_icon_url( 512 ) : '';
		return is_string( $site_icon ) ? esc_url_raw( $site_icon ) : '';
	}

	private static function is_preview_request(): bool {
		if ( is_admin() || ! is_user_logged_in() || ! current_user_can( 'manage_options' ) ) {
			return false;
		}
		$nonce = isset( $_GET[ self::PREVIEW_QUERY ] )
			? sanitize_text_field( wp_unslash( $_GET[ self::PREVIEW_QUERY ] ) )
			: '';
		return '' !== $nonce && (bool) wp_verify_nonce( $nonce, self::PREVIEW_ACTION );
	}

	private static function test_campaign(): string {
		if ( is_admin() || ! is_user_logged_in() || ! current_user_can( 'manage_options' ) ) {
			return '';
		}
		$campaign = isset( $_GET[ self::TEST_QUERY ] )
			? sanitize_key( wp_unslash( $_GET[ self::TEST_QUERY ] ) )
			: '';
		$nonce = isset( $_GET[ self::TEST_NONCE_QUERY ] )
			? sanitize_text_field( wp_unslash( $_GET[ self::TEST_NONCE_QUERY ] ) )
			: '';
		if (
			! in_array( $campaign, self::CAMPAIGNS, true )
			|| '' === $nonce
			|| ! wp_verify_nonce( $nonce, self::TEST_ACTION . '|' . $campaign )
		) {
			return '';
		}
		return $campaign;
	}

	/** @param array<string,mixed> $defaults @param array<string,mixed> $saved */
	private static function merge_settings( array $defaults, array $saved ): array {
		foreach ( $defaults as $key => $value ) {
			if ( is_array( $value ) ) {
				$saved_value    = isset( $saved[ $key ] ) && is_array( $saved[ $key ] ) ? $saved[ $key ] : array();
				$defaults[ $key ] = array_merge( $value, $saved_value );
			} elseif ( array_key_exists( $key, $saved ) ) {
				$defaults[ $key ] = $saved[ $key ];
			}
		}
		return $defaults;
	}

	public function enqueue_assets(): void {
		$settings      = self::settings();
		$test_campaign = self::test_campaign();
		if ( is_admin() || self::is_preview_request() || ( ! $settings['enabled'] && '' === $test_campaign ) ) {
			return;
		}
		wp_enqueue_style(
			'kidia-mobile-website-app-promotion',
			KIDIA_MOBILE_CMS_URL . 'public/assets/website-app-promotion.css',
			array(),
			KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'public/assets/website-app-promotion.css' )
		);
		wp_enqueue_script(
			'kidia-mobile-qrcode',
			KIDIA_MOBILE_CMS_URL . 'public/assets/vendor/qrcode.min.js',
			array(),
			'1.0.0',
			true
		);
		wp_enqueue_script(
			'kidia-mobile-website-app-promotion',
			KIDIA_MOBILE_CMS_URL . 'public/assets/website-app-promotion.js',
			array( 'kidia-mobile-qrcode' ),
			KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'public/assets/website-app-promotion.js' ),
			true
		);
		wp_localize_script(
			'kidia-mobile-website-app-promotion',
			'KidiaAppPromotion',
			$this->frontend_config()
		);
	}

	/** @return array<string,mixed> */
	private function frontend_config(): array {
		return array(
			'settings'     => self::settings(),
			'ajaxUrl'      => admin_url( 'admin-ajax.php' ),
			'nonce'        => wp_create_nonce( 'kidia_mobile_app_promotion_event' ),
			'page'         => $this->page_context(),
			'loggedIn'     => is_user_logged_in(),
			'shortcode'    => '[woo_mobile_app_promo]',
			'testCampaign' => self::test_campaign(),
			'labels'       => array(
				'comingSoon'  => __( 'Coming soon', 'kidia-mobile-cms' ),
				'needsLink'   => __( 'Add an app link to activate this action.', 'kidia-mobile-cms' ),
				'testPreview' => __( 'Private live test', 'kidia-mobile-cms' ),
			),
		);
	}

	public function render_native_ios_banner(): void {
		$settings = self::settings();
		if ( self::is_preview_request() || ! $settings['enabled'] || ! $settings['native_ios_enabled'] || '' === (string) $settings['ios_app_id'] ) {
			return;
		}
		$content = 'app-id=' . preg_replace( '/\D+/', '', (string) $settings['ios_app_id'] );
		if ( '' !== (string) $settings['ios_app_argument'] ) {
			$content .= ', app-argument=' . esc_url_raw( (string) $settings['ios_app_argument'] );
		}
		printf( "<meta name=\"apple-itunes-app\" content=\"%s\">\n", esc_attr( $content ) );
	}

	public function render_after_header_slot(): void {
		$settings = self::settings();
		$test_campaign = self::test_campaign();
		if (
			! self::is_preview_request()
			&& (
				'inline_banner' === $test_campaign
				|| (
					$settings['enabled']
					&& ! empty( $settings['inline_banner']['enabled'] )
					&& 'after_header' === (string) $settings['inline_banner']['placement']
				)
			)
		) {
			echo '<div class="kidia-app-promo-slot" data-kidia-app-promo-slot="inline" data-kidia-app-promo-placement="after_header"></div>';
		}
	}

	public function render_footer(): void {
		$settings = self::settings();
		$test_campaign = self::test_campaign();
		if ( self::is_preview_request() || ( ! $settings['enabled'] && '' === $test_campaign ) ) {
			return;
		}
		if (
			'inline_banner' !== $test_campaign
			&& ! empty( $settings['inline_banner']['enabled'] )
			&& 'before_footer' === (string) $settings['inline_banner']['placement']
		) {
			echo '<div class="kidia-app-promo-slot" data-kidia-app-promo-slot="inline" data-kidia-app-promo-placement="before_footer"></div>';
		}
		echo '<div class="kidia-app-promo-root" data-kidia-app-promo-root></div>';
		echo '<script type="application/json" data-kidia-app-promo-config>';
		echo wp_json_encode( $this->frontend_config(), JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT );
		echo '</script>';
	}

	public function shortcode(): string {
		if ( self::is_preview_request() || ! self::settings()['enabled'] ) {
			return '';
		}
		return '<div class="kidia-app-promo-slot" data-kidia-app-promo-slot="inline" data-kidia-app-promo-placement="shortcode"></div>';
	}

	public function save(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( esc_html__( 'You do not have permission to change these settings.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_save_website_app_promotion', 'kidia_mobile_promotion_nonce' );
		$submitted = isset( $_POST['promotion'] ) && is_array( $_POST['promotion'] )
			? wp_unslash( $_POST['promotion'] )
			: array();
		$settings = self::sanitize( $submitted );
		update_option( self::OPTION, $settings, false );
		$this->purge_frontend_cache();
		wp_safe_redirect(
			add_query_arg(
				array(
					'page'            => 'kidia-mobile-website-app-promotion',
					'promotion_saved' => '1',
				),
				admin_url( 'admin.php' )
			)
		);
		exit;
	}

	private function purge_frontend_cache(): void {
		$front_page_id = absint( get_option( 'page_on_front', 0 ) );
		if ( $front_page_id > 0 ) {
			clean_post_cache( $front_page_id );
		}
		wp_cache_flush();

		// Promotion settings change the generated frontend HTML, so page caches
		// must not keep serving a version without the campaign assets or config.
		do_action( 'breeze_clear_all_cache' );
		do_action( 'litespeed_purge_all' );
		if ( function_exists( 'rocket_clean_domain' ) ) {
			rocket_clean_domain();
		}
		if ( function_exists( 'w3tc_flush_all' ) ) {
			w3tc_flush_all();
		}
	}

	/** @param array<string,mixed> $submitted @return array<string,mixed> */
	public static function sanitize( array $submitted ): array {
		$defaults = self::defaults();
		$clean    = $defaults;

		foreach ( array( 'app_name', 'tagline', 'description', 'button_label', 'open_label', 'dismiss_label', 'offer_text', 'coupon_code' ) as $key ) {
			$clean[ $key ] = sanitize_text_field( (string) ( $submitted[ $key ] ?? '' ) );
		}
		foreach ( array( 'logo_url', 'android_url', 'ios_url', 'huawei_url', 'smart_url', 'qr_url', 'ios_app_argument' ) as $key ) {
			$clean[ $key ] = esc_url_raw( (string) ( $submitted[ $key ] ?? '' ), array( 'http', 'https' ) );
		}
		$clean['deep_link'] = self::sanitize_deep_link( (string) ( $submitted['deep_link'] ?? '' ) );
		foreach ( array( 'primary_color', 'text_color', 'surface_color' ) as $key ) {
			$clean[ $key ] = sanitize_hex_color( (string) ( $submitted[ $key ] ?? '' ) ) ?: $defaults[ $key ];
		}

		$clean['enabled']            = ! empty( $submitted['enabled'] );
		$clean['native_ios_enabled'] = ! empty( $submitted['native_ios_enabled'] );
		$clean['ios_app_id']         = preg_replace( '/\D+/', '', (string) ( $submitted['ios_app_id'] ?? '' ) );
		$clean['custom_paths']       = self::sanitize_paths( (string) ( $submitted['custom_paths'] ?? '' ) );
		$clean['excluded_paths']     = self::sanitize_paths( (string) ( $submitted['excluded_paths'] ?? '' ) );
		$clean['audience_devices']   = self::choice( $submitted, 'audience_devices', array( 'all', 'mobile', 'desktop', 'android', 'ios' ), 'all' );
		$clean['audience_users']     = self::choice( $submitted, 'audience_users', array( 'all', 'guests', 'customers' ), 'all' );
		$clean['page_target']        = self::choice( $submitted, 'page_target', array( 'all', 'home', 'shop', 'product', 'category', 'cart', 'checkout', 'custom' ), 'all' );
		$clean['frequency']          = self::choice( $submitted, 'frequency', array( 'session', 'daily', 'three_days', 'weekly', 'always' ), 'daily' );

		$clean['smart_banner'] = self::sanitize_campaign(
			$submitted['smart_banner'] ?? array(),
			$defaults['smart_banner'],
			array( 'position' => array( 'top', 'bottom' ) )
		);
		$clean['bottom_sheet'] = self::sanitize_campaign(
			$submitted['bottom_sheet'] ?? array(),
			$defaults['bottom_sheet'],
			array(
				'trigger' => array( 'immediate', 'delay', 'scroll' ),
				'style'   => array( 'compact', 'coupon', 'image' ),
			)
		);
		$clean['popup'] = self::sanitize_campaign(
			$submitted['popup'] ?? array(),
			$defaults['popup'],
			array(
				'trigger' => array( 'delay', 'scroll', 'exit' ),
				'style'   => array( 'split', 'centered', 'coupon' ),
			)
		);
		$clean['desktop_qr'] = self::sanitize_campaign(
			$submitted['desktop_qr'] ?? array(),
			$defaults['desktop_qr'],
			array( 'position' => array( 'bottom-right', 'bottom-left' ) )
		);
		$clean['floating_button'] = self::sanitize_campaign(
			$submitted['floating_button'] ?? array(),
			$defaults['floating_button'],
			array( 'position' => array( 'bottom-right', 'bottom-left' ) )
		);
		$clean['floating_button']['label'] = sanitize_text_field( (string) ( $submitted['floating_button']['label'] ?? $defaults['floating_button']['label'] ) );
		$clean['inline_banner'] = self::sanitize_campaign(
			$submitted['inline_banner'] ?? array(),
			$defaults['inline_banner'],
			array(
				'placement' => array( 'shortcode', 'after_header', 'before_footer' ),
				'style'     => array( 'wide', 'card', 'coupon' ),
			)
		);

		return $clean;
	}

	/** @param mixed $submitted @param array<string,mixed> $defaults @param array<string,list<string>> $choices */
	private static function sanitize_campaign( $submitted, array $defaults, array $choices ): array {
		$submitted = is_array( $submitted ) ? $submitted : array();
		$clean     = $defaults;
		$clean['enabled'] = ! empty( $submitted['enabled'] );
		foreach ( array( 'delay', 'scroll' ) as $number ) {
			if ( array_key_exists( $number, $defaults ) ) {
				$clean[ $number ] = min( 100, max( 0, absint( $submitted[ $number ] ?? $defaults[ $number ] ) ) );
			}
		}
		foreach ( $choices as $key => $allowed ) {
			$value         = sanitize_key( (string) ( $submitted[ $key ] ?? '' ) );
			$clean[ $key ] = in_array( $value, $allowed, true ) ? $value : $defaults[ $key ];
		}
		return $clean;
	}

	/** @param array<string,mixed> $submitted @param list<string> $allowed */
	private static function choice( array $submitted, string $key, array $allowed, string $fallback ): string {
		$value = sanitize_key( (string) ( $submitted[ $key ] ?? '' ) );
		return in_array( $value, $allowed, true ) ? $value : $fallback;
	}

	private static function sanitize_paths( string $paths ): string {
		$clean = array();
		foreach ( preg_split( '/[\r\n,]+/', $paths ) ?: array() as $path ) {
			$path = trim( wp_strip_all_tags( $path ) );
			if ( '' !== $path ) {
				$clean[] = '/' . ltrim( mb_substr( $path, 0, 180 ), '/' );
			}
		}
		return implode( "\n", array_unique( $clean ) );
	}

	private static function sanitize_deep_link( string $url ): string {
		$url = trim( sanitize_text_field( $url ) );
		if (
			'' === $url
			|| preg_match( '/^(?:javascript|data|vbscript):/i', $url )
			|| ! preg_match( '/^[a-z][a-z0-9+.-]*:\/\/[^\s]+$/i', $url )
		) {
			return '';
		}
		return mb_substr( $url, 0, 500 );
	}

	/** @return array<string,mixed> */
	private function page_context(): array {
		$type = 'other';
		if ( is_front_page() || is_home() ) {
			$type = 'home';
		} elseif ( function_exists( 'is_shop' ) && is_shop() ) {
			$type = 'shop';
		} elseif ( function_exists( 'is_product' ) && is_product() ) {
			$type = 'product';
		} elseif ( function_exists( 'is_product_category' ) && is_product_category() ) {
			$type = 'category';
		} elseif ( function_exists( 'is_cart' ) && is_cart() ) {
			$type = 'cart';
		} elseif ( function_exists( 'is_checkout' ) && is_checkout() ) {
			$type = 'checkout';
		}
		return array(
			'type' => $type,
			'path' => isset( $_SERVER['REQUEST_URI'] ) ? esc_url_raw( wp_unslash( $_SERVER['REQUEST_URI'] ) ) : '/',
		);
	}

	public function track_event(): void {
		check_ajax_referer( 'kidia_mobile_app_promotion_event', 'nonce' );
		$event = isset( $_POST['event'] ) ? sanitize_key( wp_unslash( $_POST['event'] ) ) : '';
		$key   = array(
			'view'    => 'views',
			'click'   => 'clicks',
			'dismiss' => 'dismisses',
		)[ $event ] ?? '';
		if ( '' === $key ) {
			wp_send_json_error( array( 'message' => 'invalid_event' ), 400 );
		}
		$address = isset( $_SERVER['REMOTE_ADDR'] ) ? sanitize_text_field( wp_unslash( $_SERVER['REMOTE_ADDR'] ) ) : 'unknown';
		$limit_key = 'kidia_promo_' . md5( $address . '|' . $event . '|' . gmdate( 'Y-m-d-H' ) );
		$count = absint( get_transient( $limit_key ) );
		if ( $count >= 120 ) {
			wp_send_json_error( array( 'message' => 'rate_limited' ), 429 );
		}
		set_transient( $limit_key, $count + 1, HOUR_IN_SECONDS );
		$metrics = self::metrics();
		++$metrics[ $key ];
		update_option( self::METRICS_OPTION, $metrics, false );
		wp_send_json_success( array( 'recorded' => true ) );
	}
}
