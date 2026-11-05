<?php
/** Map verified store administrators to a customer-only shopping profile. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Storefront_Admin {
	public static function accepts( $user ): bool {
		return $user instanceof WP_User && in_array( 'administrator', (array) $user->roles, true );
	}

	private static function login( int $owner ): string {
		return 'mobishop_shop_' . get_current_blog_id() . '_' . $owner;
	}

	private static function marker(): string {
		return '_mobishop_storefront_owner_' . get_current_blog_id();
	}

	private static function clean_customer( WP_User $user ): bool {
		// This principal must never acquire extra roles or staff capabilities.
		return array_values( (array) $user->roles ) === array( 'customer' )
			&& ! array_diff_key( array_filter( (array) $user->allcaps ),
				array_flip( array( 'customer', 'read', 'level_0' ) ) )
			&& ( ! is_multisite() || ! is_super_admin( $user->ID ) );
	}

	public static function valid_session_user( WP_User $user ): bool {
		if ( ! str_starts_with( (string) ( $user->user_login ?? '' ), 'mobishop_shop_' ) ) return true;
		$owner = (int) get_user_meta( $user->ID, self::marker(), true );
		return $owner === 0 || ( $user->user_login === self::login( $owner ) && self::clean_customer( $user ) );
	}

	public static function contact_email( WP_User $user ): string {
		if ( ! str_starts_with( (string) ( $user->user_login ?? '' ), 'mobishop_shop_' ) || ! self::valid_session_user( $user ) ) return '';
		$owner = get_user_by( 'id', (int) get_user_meta( $user->ID, self::marker(), true ) );
		return self::accepts( $owner ) ? sanitize_email( $owner->user_email ) : '';
	}

	/** Call only after authenticating the owner, never to resolve an unverified email or phone. */
	public static function resolve( WP_User $owner ) {
		global $wpdb;
		$error = new WP_Error( 'mobishop_shopping_identity_unavailable', 'Could not open the shopping profile.', array( 'status' => 409 ) );
		if ( ! self::accepts( $owner ) ) return $error;
		$login = self::login( $owner->ID );
		$lock = 'ms_shop_' . substr( hash( 'sha256', $wpdb->users . ':' . $login ), 0, 48 );
		if ( '1' !== (string) $wpdb->get_var( $wpdb->prepare( 'SELECT GET_LOCK(%s, 3)', $lock ) ) ) return $error;
		try {
			if ( function_exists( 'clean_user_cache' ) ) clean_user_cache( $owner );
			$fresh = get_user_by( 'id', $owner->ID );
			if ( ! self::accepts( $fresh ) || $fresh->user_email !== $owner->user_email || $fresh->user_pass !== $owner->user_pass ) return $error;
			$shopper = get_user_by( 'login', $login );
			if ( ! $shopper ) {
				$id = wp_insert_user( array(
					'user_login' => $login, 'user_pass' => wp_generate_password( 64, true, true ),
					'role' => 'customer', 'user_email' => '', 'display_name' => $fresh->display_name,
					'meta_input' => array( self::marker() => (string) $fresh->ID, 'billing_email' => $fresh->user_email ),
				) );
				if ( is_wp_error( $id ) ) return $error;
				$shopper = get_user_by( 'id', $id );
			}
			if ( $shopper instanceof WP_User && function_exists( 'clean_user_cache' ) ) {
				clean_user_cache( $shopper );
				$shopper = get_user_by( 'id', $shopper->ID );
			}
			if ( ! $shopper instanceof WP_User || $shopper->ID === $owner->ID || $shopper->user_login !== $login
				|| (int) get_user_meta( $shopper->ID, self::marker(), true ) !== (int) $owner->ID
				|| ! self::clean_customer( $shopper ) ) return $error;
			// Registration hooks can mark this generated shopper as a new sign-up.
			// Only discard that marker after verifying both the owner and the isolated customer.
			if ( 'account' === get_user_meta( $shopper->ID, 'kidia_phone_setup_required', true ) ) {
				delete_user_meta( $shopper->ID, 'kidia_phone_setup_required', 'account' );
			}
			return $shopper;
		} finally {
			$wpdb->get_var( $wpdb->prepare( 'SELECT RELEASE_LOCK(%s)', $lock ) );
		}
	}
}
