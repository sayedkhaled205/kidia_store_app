<?php
/**
 * Authenticated WooCommerce customer profile, addresses and support details.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_CMS_Customer_Account_Endpoint {

	private const ADDRESS_FIELDS = array(
		'first_name',
		'last_name',
		'company',
		'address_1',
		'address_2',
		'city',
		'state',
		'postcode',
		'country',
		'email',
		'phone',
	);

	/** Register customer account routes. */
	public function register(): void {
		add_action(
			'rest_api_init',
			array( $this, 'register_routes' )
		);
	}

	/** Register read and update endpoints behind the mobile session. */
	public function register_routes(): void {
		$permission = array( $this, 'authenticate_customer' );
		register_rest_route(
			'woo-mobile/v1',
			'/customer/account',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array( $this, 'get_account' ),
				'permission_callback' => $permission,
			)
		);
		register_rest_route(
			'woo-mobile/v1',
			'/customer/account/profile',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'update_profile' ),
				'permission_callback' => $permission,
			)
		);
		register_rest_route(
			'woo-mobile/v1',
			'/customer/account/address/(?P<type>billing|shipping)',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'update_address' ),
				'permission_callback' => $permission,
				'args'                => array(
					'type' => array(
						'required'          => true,
						'type'              => 'string',
						'sanitize_callback' => 'sanitize_key',
						'validate_callback' => static fn( $value ): bool => in_array( $value, array( 'billing', 'shipping' ), true ),
					),
				),
			)
		);
	}

	/** Require a customer resolved by the existing mobile-session filter. */
	public function authenticate_customer( WP_REST_Request $request ) {
		unset( $request );
		return get_current_user_id() > 0
			? true
			: new WP_Error(
				'woo_mobile_auth_unauthorized',
				__( 'The customer session is missing or expired.', 'kidia-mobile-cms' ),
				array( 'status' => 401 )
			);
	}

	/** Return the current WooCommerce account and its saved addresses. */
	public function get_account() {
		$customer = $this->current_customer();
		if ( is_wp_error( $customer ) ) {
			return $customer;
		}
		return $this->response( $this->account_payload( $customer ) );
	}

	/** Update the same fields exposed by WooCommerce's edit-account screen. */
	public function update_profile( WP_REST_Request $request ) {
		$customer = $this->current_customer();
		if ( is_wp_error( $customer ) ) {
			return $customer;
		}
		$values = $this->json_values( $request );
		$user   = array( 'ID' => (int) $customer->get_id() );

		foreach ( array( 'first_name', 'last_name', 'display_name' ) as $field ) {
			if ( array_key_exists( $field, $values ) ) {
				$user[ $field ] = sanitize_text_field( (string) $values[ $field ] );
			}
		}
		if ( array_key_exists( 'email', $values ) ) {
			$email = sanitize_email( (string) $values['email'] );
			if ( ! is_email( $email ) ) {
				return new WP_Error(
					'woo_mobile_account_invalid_email',
					__( 'Enter a valid email address.', 'kidia-mobile-cms' ),
					array( 'status' => 400 )
				);
			}
			$existing = email_exists( $email );
			if ( $existing && (int) $existing !== (int) $customer->get_id() ) {
				return new WP_Error(
					'woo_mobile_account_email_exists',
					__( 'This email address is already used by another account.', 'kidia-mobile-cms' ),
					array( 'status' => 409 )
				);
			}
			$user['user_email'] = $email;
		}

		$updated = wp_update_user( $user );
		if ( is_wp_error( $updated ) ) {
			return new WP_Error(
				'woo_mobile_account_update_failed',
				__( 'The customer profile could not be updated.', 'kidia-mobile-cms' ),
				array( 'status' => 500 )
			);
		}
		$customer = new WC_Customer( (int) $updated );
		return $this->response(
			array( 'profile' => $this->profile_payload( $customer ) )
		);
	}

	/** Update one saved WooCommerce address without inventing local-only data. */
	public function update_address( WP_REST_Request $request ) {
		$customer = $this->current_customer();
		if ( is_wp_error( $customer ) ) {
			return $customer;
		}
		$type = sanitize_key( (string) $request->get_param( 'type' ) );
		if ( ! in_array( $type, array( 'billing', 'shipping' ), true ) ) {
			return new WP_Error(
				'woo_mobile_account_invalid_address',
				__( 'The saved address type is invalid.', 'kidia-mobile-cms' ),
				array( 'status' => 400 )
			);
		}

		$values = $this->json_values( $request );
		foreach ( self::ADDRESS_FIELDS as $field ) {
			$key = $type . '_' . $field;
			if ( ! array_key_exists( $key, $values ) ) {
				continue;
			}
			$setter = 'set_' . $key;
			if ( ! is_callable( array( $customer, $setter ) ) ) {
				continue;
			}
			$value = $this->sanitize_address_value( $field, $values[ $key ] );
			if ( is_wp_error( $value ) ) {
				return $value;
			}
			$customer->$setter( $value );
		}
		$customer->save();
		return $this->response(
			array(
				'type'    => $type,
				'address' => $this->address_payload( $customer, $type ),
			)
		);
	}

	/** Load the authenticated customer through WooCommerce's HPOS-safe model. */
	private function current_customer() {
		$customer_id = get_current_user_id();
		if ( $customer_id <= 0 ) {
			return new WP_Error(
				'woo_mobile_auth_unauthorized',
				__( 'The customer session is missing or expired.', 'kidia-mobile-cms' ),
				array( 'status' => 401 )
			);
		}
		if ( ! class_exists( 'WC_Customer' ) ) {
			return new WP_Error(
				'woo_mobile_account_woocommerce_unavailable',
				__( 'WooCommerce customer accounts are unavailable.', 'kidia-mobile-cms' ),
				array( 'status' => 503 )
			);
		}
		return new WC_Customer( $customer_id );
	}

	private function account_payload( $customer ): array {
		return array(
			'profile'  => $this->profile_payload( $customer ),
			'billing'  => $this->address_payload( $customer, 'billing' ),
			'shipping' => $this->address_payload( $customer, 'shipping' ),
			'support'  => $this->support_payload(),
		);
	}

	private function profile_payload( $customer ): array {
		return array(
			'id'           => (int) $customer->get_id(),
			'email'        => sanitize_email( (string) $customer->get_email() ),
			'first_name'   => sanitize_text_field( (string) $customer->get_first_name() ),
			'last_name'    => sanitize_text_field( (string) $customer->get_last_name() ),
			'display_name' => sanitize_text_field( (string) $customer->get_display_name() ),
		);
	}

	private function address_payload( $customer, string $type ): array {
		$address = array();
		foreach ( self::ADDRESS_FIELDS as $field ) {
			$getter = 'get_' . $type . '_' . $field;
			$key    = $type . '_' . $field;
			$address[ $key ] = is_callable( array( $customer, $getter ) )
				? sanitize_text_field( (string) $customer->$getter() )
				: '';
		}
		return $address;
	}

	/** Store-controlled contact details with filters for live deployments. */
	private function support_payload(): array {
		$email = apply_filters(
			'woo_mobile_cms_support_email',
			(string) get_option( 'admin_email', '' )
		);
		$phone = apply_filters(
			'woo_mobile_cms_support_phone',
			(string) get_option( 'woocommerce_store_phone', '' )
		);
		$whatsapp = apply_filters(
			'woo_mobile_cms_support_whatsapp',
			$phone
		);
		$contact_url = apply_filters(
			'woo_mobile_cms_support_url',
			home_url( '/contact-us/' )
		);
		return array(
			'email'       => sanitize_email( (string) $email ),
			'phone'       => sanitize_text_field( (string) $phone ),
			'whatsapp'    => sanitize_text_field( (string) $whatsapp ),
			'contact_url' => esc_url_raw( (string) $contact_url ),
		);
	}

	private function json_values( WP_REST_Request $request ): array {
		$values = $request->get_json_params();
		return is_array( $values ) ? $values : array();
	}

	private function sanitize_address_value( string $field, $value ) {
		if ( 'email' === $field ) {
			$email = sanitize_email( (string) $value );
			if ( '' !== $email && ! is_email( $email ) ) {
				return new WP_Error(
					'woo_mobile_account_invalid_email',
					__( 'Enter a valid email address.', 'kidia-mobile-cms' ),
					array( 'status' => 400 )
				);
			}
			return $email;
		}
		if ( 'country' === $field ) {
			$country = strtoupper( sanitize_text_field( (string) $value ) );
			return preg_match( '/^[A-Z]{2}$/', $country ) ? $country : '';
		}
		if ( 'phone' === $field && function_exists( 'wc_sanitize_phone_number' ) ) {
			return wc_sanitize_phone_number( (string) $value );
		}
		return sanitize_text_field( (string) $value );
	}

	private function response( array $payload ): WP_REST_Response {
		$response = new WP_REST_Response( $payload, 200 );
		$response->header( 'Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0' );
		$response->header( 'Pragma', 'no-cache' );
		return $response;
	}
}
