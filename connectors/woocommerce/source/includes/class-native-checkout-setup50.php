<?php
/**
 * Prepare the existing checkout ledger through the authorized central connection.
 * No orders, gateway calls, customer permissions or external credentials are created.
 */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Native_Checkout_Setup50 {
	public const OPTION = 'mobishop_native_checkout50_installation';

	/** Read-only bootstrap. A server-owned disable always wins. */
	public static function runtime_enabled(): bool {
		if ( defined( 'MOBISHOP_NATIVE_CHECKOUT50_ENABLED' ) && true !== MOBISHOP_NATIVE_CHECKOUT50_ENABLED ) {
			return false;
		}
		$record = get_option( self::OPTION, null );
		if ( null !== $record && ! self::valid_record( $record ) ) {
			return false;
		}
		if ( ! self::load_key( $record ) ) {
			return false;
		}
		return defined( 'MOBISHOP_NATIVE_CHECKOUT50_ENABLED' )
			? true === MOBISHOP_NATIVE_CHECKOUT50_ENABLED
			: is_array( $record ) && 'ready' === $record['state'];
	}

	/** Called only from authenticated, licensed central/bootstrap POST. */
	public static function prepare() {
		if ( ! current_user_can( 'manage_options' ) || ! current_user_can( 'manage_woocommerce' ) ) {
			return self::error( 'forbidden', 403 );
		}
		if ( ! class_exists( 'MobiShop_License_Manager' ) || ! ( new MobiShop_License_Manager() )->is_active() ) {
			return self::error( 'license_required', 403 );
		}
		if ( defined( 'MOBISHOP_NATIVE_CHECKOUT50_ENABLED' ) && true !== MOBISHOP_NATIVE_CHECKOUT50_ENABLED ) {
			return self::error( 'disabled', 409 );
		}
		if ( ! defined( 'WC_VERSION' ) || version_compare( WC_VERSION, '9.9.0', '<' ) || ! function_exists( 'array_is_list' ) ) {
			return self::error( 'woocommerce_update_required', 409 );
		}
		require_once MOBISHOP_PATH . 'api/class-native-checkout-safety50.php';
		$db = $GLOBALS['wpdb'];
		$prefix = (string) ( $db->prefix ?? '' );
		if ( ! preg_match( '/^[A-Za-z0-9_]+$/D', $prefix ) || '0' !== (string) $db->get_var( 'SELECT @@in_transaction' ) ) {
			return self::error( 'storage_unavailable', 503 );
		}
		// MySQL advisory lock is connection-scoped; it cannot commit a transaction.
		$lock = 'mobishop-checkout50:' . substr( hash( 'sha256', ( defined( 'DB_NAME' ) ? DB_NAME : '' ) . '|' . $prefix ), 0, 40 );
		if ( '1' !== (string) $db->get_var( $db->prepare( 'SELECT GET_LOCK(%s, 0)', $lock ) ) ) {
			return self::error( 'preparing', 503 );
		}
		try {
			$record = get_option( self::OPTION, null );
			if ( null !== $record && ! self::valid_record( $record ) ) {
				return self::error( 'installation_review_required', 409 );
			}
			$tables = array();
			foreach ( array( 'buyers', 'attempts', 'carts', 'config' ) as $name ) {
				$table = $prefix . 'mobishop_native_checkout50_' . $name;
				$status = $db->get_row( $db->prepare( 'SHOW TABLE STATUS WHERE Name = %s', $table ), ARRAY_A );
				if ( ! empty( $db->last_error ) ) {
					return self::error( 'storage_unavailable', 503 );
				}
				$tables[ $name ] = array( 'name' => $table, 'exists' => is_array( $status ) );
				if ( is_array( $status ) && ( ( $status['Name'] ?? '' ) !== $table || ( $status['Engine'] ?? '' ) !== 'InnoDB' ) ) {
					return self::error( 'installation_review_required', 409 );
				}
			}
			$existing = count( array_filter( $tables, static fn( array $table ): bool => $table['exists'] ) );
			$external = defined( 'MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY' );
			if ( null === $record ) {
				// An unowned/partial old ledger is never reset or given a new key.
				if ( $existing && ( 4 !== $existing || ! $external || ! MobiShop_Native_Checkout_Wpdb50::key_configured() ) ) {
					return self::error( 'installation_review_required', 409 );
				}
				if ( $external && ! MobiShop_Native_Checkout_Wpdb50::key_configured() ) {
					return self::error( 'installation_review_required', 409 );
				}
				if ( $existing && ! ( new MobiShop_Native_Checkout_Wpdb50() )->ready() ) {
					return self::error( 'installation_review_required', 409 );
				}
				$key = $external ? MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY : bin2hex( random_bytes( 32 ) );
				$record = array( 'schema' => 1, 'source' => $external ? 'constant' : 'option', 'state' => $existing ? 'ready' : 'preparing', 'fingerprint' => hash( 'sha256', $key ) );
				if ( ! $external ) {
					$record['key'] = $key;
				}
				// Persist before DDL so a failed connection can safely resume its own setup.
				if ( ! add_option( self::OPTION, $record, '', false ) || get_option( self::OPTION, null ) !== $record ) {
					return self::error( 'storage_unavailable', 503 );
				}
			}
			if ( ! self::load_key( $record ) ) {
				return self::error( 'installation_review_required', 409 );
			}
			$storage = new MobiShop_Native_Checkout_Wpdb50();
			if ( 'ready' === $record['state'] ) {
				return $storage->ready() ? array( 'protocol' => 50, 'prepared' => true ) : self::error( 'installation_review_required', 409 );
			}
			// Resume only our own unused preparation. Never modify a live ledger.
			foreach ( $tables as $name => $table ) {
				if ( ! $table['exists'] ) {
					continue;
				}
				$count = $db->get_var( "SELECT COUNT(*) FROM `{$table['name']}`" );
				if ( ! empty( $db->last_error ) || null === $count || ( 'config' !== $name && '0' !== (string) $count ) || ( 'config' === $name && ! in_array( (string) $count, array( '0', '1' ), true ) ) ) {
					return self::error( 'installation_review_required', 409 );
				}
				if ( 'config' === $name && '1' === (string) $count ) {
					$fingerprint = $db->get_var( "SELECT key_fingerprint FROM `{$table['name']}` WHERE id = 1" );
					if ( ! is_string( $fingerprint ) || ! hash_equals( $record['fingerprint'], $fingerprint ) ) {
						return self::error( 'installation_review_required', 409 );
					}
				}
			}
			$sql = $storage->installation_sql();
			foreach ( array_values( $tables ) as $index => $table ) {
				if ( ! $table['exists'] && false === $db->query( $sql[ $index ] ) ) {
					return self::error( 'storage_unavailable', 503 );
				}
			}
			$config = $tables['config']['name'];
			$count = $db->get_var( "SELECT COUNT(*) FROM `{$config}`" );
			if ( '0' === (string) $count && false === $db->query( $sql[4] ) ) {
				return self::error( 'storage_unavailable', 503 );
			}
			if ( ! $storage->ready() ) {
				return self::error( 'installation_review_required', 409 );
			}
			$record['state'] = 'ready';
			update_option( self::OPTION, $record, false );
			if ( get_option( self::OPTION, null ) !== $record ) {
				return self::error( 'storage_unavailable', 503 );
			}
			return array( 'protocol' => 50, 'prepared' => true );
		} catch ( Throwable $error ) {
			return self::error( 'storage_unavailable', 503 );
		} finally {
			$db->get_var( $db->prepare( 'SELECT RELEASE_LOCK(%s)', $lock ) );
		}
	}

	private static function valid_record( $record ): bool {
		return is_array( $record ) && 1 === ( $record['schema'] ?? null )
			&& in_array( $record['source'] ?? null, array( 'constant', 'option' ), true )
			&& in_array( $record['state'] ?? null, array( 'preparing', 'ready' ), true )
			&& is_string( $record['fingerprint'] ?? null ) && preg_match( '/^[a-f0-9]{64}$/D', $record['fingerprint'] )
			&& ( 'constant' === $record['source'] || ( is_string( $record['key'] ?? null ) && preg_match( '/^[a-f0-9]{64}$/D', $record['key'] ) && hash_equals( $record['fingerprint'], hash( 'sha256', $record['key'] ) ) ) );
	}

	private static function load_key( $record ): bool {
		if ( null !== $record && ! self::valid_record( $record ) ) {
			return false;
		}
		if ( ! defined( 'MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY' ) && is_array( $record ) && 'option' === $record['source'] ) {
			define( 'MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY', $record['key'] );
		}
		if ( ! defined( 'MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY' ) || ! is_string( MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY ) || ! preg_match( '/^[a-f0-9]{64}$/D', MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY ) ) {
			return false;
		}
		return null === $record || hash_equals( $record['fingerprint'], hash( 'sha256', MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY ) );
	}

	private static function error( string $reason, int $status ): WP_Error {
		return new WP_Error( 'native_checkout_' . $reason, 'Native checkout preparation needs attention; existing checkout attempts have been preserved.', array( 'status' => $status ) );
	}
}
