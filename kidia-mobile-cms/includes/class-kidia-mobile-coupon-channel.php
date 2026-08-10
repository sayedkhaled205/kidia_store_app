<?php
/**
 * Enforces coupon availability by sales channel.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_Coupon_Channel {

	public const META_KEY = '_kidia_coupon_channel';

	public function register(): void {
		add_action( 'woocommerce_coupon_options', array( $this, 'render_field' ) );
		add_action( 'woocommerce_coupon_options_save', array( $this, 'save_field' ) );
		add_filter( 'woocommerce_coupon_is_valid', array( $this, 'validate_coupon' ), 20, 2 );
		add_filter( 'woocommerce_coupon_error', array( $this, 'coupon_error' ), 20, 3 );
	}

	public function render_field( int $coupon_id ): void {
		if ( ! function_exists( 'woocommerce_wp_select' ) ) {
			return;
		}
		woocommerce_wp_select(
			array(
				'id'          => self::META_KEY,
				'label'       => __( 'Sales channels', 'mobishop' ),
				'description' => __( 'Choose where this coupon can be redeemed. All channels is the default.', 'mobishop' ),
				'desc_tip'    => true,
				'value'       => self::get( $coupon_id ),
				'options'     => self::labels(),
			)
		);
	}

	public function save_field( int $coupon_id ): void {
		$value = sanitize_key( (string) wp_unslash( $_POST[ self::META_KEY ] ?? 'all' ) );
		self::set( $coupon_id, $value );
	}

	public function validate_coupon( bool $valid, WC_Coupon $coupon ): bool {
		if ( ! $valid ) {
			return false;
		}
		$scope = self::get( $coupon->get_id() );
		return 'all' === $scope || self::current_channel() === $scope;
	}

	public function coupon_error( string $message, int $code, WC_Coupon $coupon ): string {
		unset( $code );
		$scope = self::get( $coupon->get_id() );
		if ( 'all' !== $scope && self::current_channel() !== $scope ) {
			return 'mobile' === $scope
				? __( 'This coupon is available in the mobile app only.', 'mobishop' )
				: __( 'This coupon is available on the website only.', 'mobishop' );
		}
		return $message;
	}

	public static function get( int $coupon_id ): string {
		$value = sanitize_key( (string) get_post_meta( $coupon_id, self::META_KEY, true ) );
		return in_array( $value, array( 'all', 'website', 'mobile' ), true ) ? $value : 'all';
	}

	public static function set( int $coupon_id, string $channel ): void {
		$channel = in_array( $channel, array( 'all', 'website', 'mobile' ), true ) ? $channel : 'all';
		update_post_meta( $coupon_id, self::META_KEY, $channel );
	}

	/** @return array<string,string> */
	public static function labels(): array {
		return array(
			'all'     => __( 'Website + Mobile App', 'mobishop' ),
			'website' => __( 'Website only', 'mobishop' ),
			'mobile'  => __( 'Mobile App only', 'mobishop' ),
		);
	}

	public static function current_channel(): string {
		$header = sanitize_key( (string) ( $_SERVER['HTTP_X_KIDIA_CHANNEL'] ?? '' ) );
		$requested = isset( $_REQUEST['kidia_channel'] ) ? sanitize_key( wp_unslash( $_REQUEST['kidia_channel'] ) ) : '';
		return 'mobile' === $header || 'mobile' === $requested ? 'mobile' : 'website';
	}
}
