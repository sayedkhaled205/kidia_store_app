<?php
/**
 * Mirrors filtered WooCommerce checkout fields into the native mobile app.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

final class MobiShop_Checkout_Config_Endpoint {

	/** Register the public config route and Store API extension. */
	public function register(): void {
		add_action(
			'rest_api_init',
			array( $this, 'register_routes' )
		);
		add_action(
			'woocommerce_store_api_checkout_update_order_from_request',
			array( $this, 'save_mobile_checkout_fields' ),
			10,
			2
		);

		if ( did_action( 'woocommerce_blocks_loaded' ) > 0 ) {
			$this->register_store_api_data();
			return;
		}
		add_action(
			'woocommerce_blocks_loaded',
			array( $this, 'register_store_api_data' )
		);
	}

	/** Register the native checkout configuration endpoint. */
	public function register_routes(): void {
		register_rest_route( 'mobishop/v1', '/customer/checkout/config', array(
			'methods' => WP_REST_Server::READABLE,
			'callback' => array( $this, 'get_checkout_config' ),
			'permission_callback' => array( new MobiShop_Native_Payment92(), 'authenticate' ),
		) );
		register_rest_route(
			'mobishop/v1',
			'/checkout-config',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array( $this, 'get_checkout_config' ),
				'permission_callback' => '__return_true',
			)
		);
	}

	/** Return the checkout field contract after all installed plugins filter it. */
	public function get_checkout_config() {
		if ( ! function_exists( 'WC' ) || ! WC() || ! method_exists( WC(), 'checkout' ) ) {
			return new WP_Error(
				'mobishop_checkout_unavailable',
				__( 'WooCommerce checkout is unavailable.', 'mobi2app-connector' ),
				array( 'status' => 503 )
			);
		}

		$checkout = WC()->checkout();
		if ( ! $checkout instanceof WC_Checkout ) {
			return new WP_Error(
				'mobishop_checkout_unavailable',
				__( 'WooCommerce checkout is unavailable.', 'mobi2app-connector' ),
				array( 'status' => 503 )
			);
		}
		$default_country = $this->get_default_country();
		$states          = $this->get_country_states( $default_country );
		$checkout_store  = new MobiShop_Checkout_Fields_Store();

		$response = rest_ensure_response(
			array(
				'version'  => 8,
				'renderer' => 'native',
				'saved_addresses' => $this->saved_addresses(),
				'payment_methods' => $this->payment_method_labels(),
				'design'   => $checkout_store->design(),
				'defaults' => array(
					'country' => $default_country,
					'states'  => $states,
				),
				'fields'   => $this->normalize_fields(
					$this->merchant_groups(),
					$default_country
				),
			)
		);
		$response->header( 'Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0' );
		$response->header( 'Pragma', 'no-cache' );
		return $response;
	}

	/** Read current merchant fields on every checkout; never a stale builder copy. */
	private function merchant_groups(): array {
		return array( 'billing' => WC()->checkout()->get_checkout_fields( 'billing' ),
			'shipping' => WC()->checkout()->get_checkout_fields( 'shipping' ),
			'order' => WC()->checkout()->get_checkout_fields( 'order' ) );
	}

	private function saved_addresses(): array {
		$id = get_current_user_id();
		if ( $id <= 0 ) return array();
		$customer = new WC_Customer( $id );
		$rows = array();
		foreach ( array( 'billing', 'shipping' ) as $group ) {
			$values = $customer->{ 'get_' . $group }();
			if ( empty( $values['address_1'] ) ) continue;
			$rows[] = array( 'id' => $group, 'label' => trim( ( $values['first_name'] ?? '' ) . ' ' . ( $values['last_name'] ?? '' ) ), 'values' => $values );
		}
		// Address-book integrations supply only the current authenticated buyer.
		$rows = apply_filters( 'mobishop_native_checkout_addresses92', $rows, $id );
		$output = array();
		$seen = array();
		foreach ( is_array( $rows ) ? array_slice( $rows, 0, 30 ) : array() as $row ) {
			if ( ! is_array( $row ) || ! is_array( $row['values'] ?? null ) ) continue;
			$values = array();
			foreach ( $row['values'] as $key => $value ) {
				if ( is_string( $key ) && preg_match( '/^[a-zA-Z0-9_]{1,100}$/D', $key ) && is_scalar( $value ) ) $values[ $key ] = substr( sanitize_text_field( (string) $value ), 0, 500 );
			}
			$fingerprint = hash( 'sha256', wp_json_encode( $values ) );
			if ( isset( $seen[ $fingerprint ] ) || empty( $values['address_1'] ) ) continue;
			$seen[ $fingerprint ] = true;
			$output[] = array( 'id' => substr( sanitize_key( (string) ( $row['id'] ?? $fingerprint ) ), 0, 100 ),
				'label' => sanitize_text_field( (string) ( $row['label'] ?? '' ) ), 'values' => $values );
		}
		return $output;
	}

	/** Allow the app to submit custom plugin fields inside Store API extensions. */
	public function payment_method_labels(): array {
		$methods = array();
		// Display metadata only. Store API cart.payment_methods remains the
		// authority for availability after shipping, customer and total rules.
		foreach ( WC()->payment_gateways()->payment_gateways() as $id => $gateway ) {
			if ( 'yes' !== $gateway->enabled ) continue;
			$methods[] = array(
				'id' => (string) $id,
				'title' => html_entity_decode( wp_strip_all_tags( $gateway->get_title() ), ENT_QUOTES, 'UTF-8' ),
				'native_adapter' => MobiShop_Native_Payment92::adapter( $gateway ),
			);
		}
		return $methods;
	}

	public function register_store_api_data(): void {
		if ( ! function_exists( 'woocommerce_store_api_register_endpoint_data' ) ||
			! class_exists( '\\Automattic\\WooCommerce\\StoreApi\\Schemas\\V1\\CheckoutSchema' ) ) {
			return;
		}

		woocommerce_store_api_register_endpoint_data(
			array(
				'endpoint'        => \Automattic\WooCommerce\StoreApi\Schemas\V1\CheckoutSchema::IDENTIFIER,
				'namespace'       => 'mobishop_cms',
				'data_callback'   => static fn(): array => array(
					'checkout_fields' => array(),
				),
				'schema_callback' => array( $this, 'get_checkout_extension_schema' ),
				'schema_type'     => ARRAY_A,
			)
		);
	}

	/** Schema for the namespaced request payload. */
	public function get_checkout_extension_schema(): array {
		return array(
			'checkout_fields' => array(
				'description'          => __( 'Filtered WooCommerce checkout plugin fields.', 'mobi2app-connector' ),
				'type'                 => 'object',
				'context'              => array( 'view', 'edit' ),
				'additionalProperties' => true,
			),
		);
	}

	/** Save only known custom fields from the current filtered checkout schema. */
	public function save_mobile_checkout_fields( $order, $request ): void {
		if ( ! $order instanceof WC_Order || ! $request instanceof WP_REST_Request ) {
			return;
		}

		$extensions = $request->get_param( 'extensions' );
		if ( is_array( $extensions ) && isset( $extensions['mobishop_cms'] ) ) {
			$order->update_meta_data( '_mobishop_order_source', 'mobile' );
		}
		$values     = is_array( $extensions ) &&
			isset( $extensions['mobishop_cms']['checkout_fields'] ) &&
			is_array( $extensions['mobishop_cms']['checkout_fields'] )
			? $extensions['mobishop_cms']['checkout_fields']
			: array();
		if ( empty( $values ) || ! function_exists( 'WC' ) || ! WC() || ! method_exists( WC(), 'checkout' ) ) {
			return;
		}

		$checkout = WC()->checkout();
		if ( ! $checkout instanceof WC_Checkout ) {
			return;
		}

		$definitions = array();
		foreach ( $this->normalize_fields( $this->merchant_groups(), $this->get_default_country() ) as $definition ) {
			$definitions[ $definition['key'] ] = $definition;
		}

		foreach ( $values as $key => $value ) {
			$key = sanitize_key( (string) $key );
			if ( ! isset( $definitions[ $key ] ) || $this->is_core_field( $key ) ) {
				continue;
			}
			$clean = $this->sanitize_field_value( $definitions[ $key ], $value );
			$order->update_meta_data( $key, $clean );
		}
	}

	/** Flatten billing, shipping and order groups while preserving priorities. */
	private function normalize_fields( array $groups, string $default_country ): array {
		$normalized = array();
		$states     = $this->get_country_states( $default_country );
		foreach ( array( 'billing', 'shipping', 'order' ) as $group ) {
			$fields = isset( $groups[ $group ] ) && is_array( $groups[ $group ] )
				? $groups[ $group ]
				: array();
			foreach ( $fields as $key => $field ) {
				if ( ! is_array( $field ) ) {
					continue;
				}
				$key     = sanitize_key( (string) $key );
				$type    = sanitize_key( (string) ( $field['type'] ?? 'text' ) );
				$options = array();
				if ( isset( $field['options'] ) && is_array( $field['options'] ) && ! empty( $field['options'] ) ) {
					foreach ( $field['options'] as $option_key => $option_label ) {
						$options[ (string) $option_key ] = wp_strip_all_tags( (string) $option_label );
					}
				}

				$default  = is_scalar( $field['default'] ?? '' ) ? (string) ( $field['default'] ?? '' ) : '';
				$required = ! empty( $field['required'] );
				$is_country = 'country' === $type || str_ends_with( $key, '_country' );
				$is_state   = 'state' === $type || str_ends_with( $key, '_state' );
				$options_by_country = array();
				$allowed_countries = 'shipping' === $group
					? WC()->countries->get_shipping_countries()
					: WC()->countries->get_allowed_countries();
				if ( $is_country ) {
					// Single-country stores need no extra input. International
					// stores must retain their allowed destinations and choice.
					$options = ! empty( $options ) ? $options : $allowed_countries;
					if ( 1 === count( $options ) ) {
						$type = 'hidden';
						$default = (string) array_key_first( $options );
					} else {
						$type = 'select';
						$default = isset( $options[ $default ] ) ? $default : ( isset( $options[ $default_country ] ) ? $default_country : '' );
					}
				} elseif ( $is_state ) {
					foreach ( array_keys( $allowed_countries ) as $country_code ) {
						$options_by_country[ $country_code ] = $this->get_country_states( (string) $country_code );
					}
					$options = ! empty( $options ) ? $options : $states;
					$options_by_country[ $default_country ] = $options;
					$type = ! empty( $options ) ? 'select' : 'text';
				}


				$normalized[] = array(
					'key'          => $key,
					'group'        => $group,
					'type'         => $type,
					'label'        => wp_strip_all_tags( (string) ( $field['label'] ?? $key ) ),
					'placeholder'  => wp_strip_all_tags( (string) ( $field['placeholder'] ?? '' ) ),
					'required'     => $required,
					'priority'     => isset( $field['priority'] ) ? (int) $field['priority'] : 100,
					'options'      => $options,
					'options_by_country' => $options_by_country,
					'default'      => $default,
					'autocomplete' => sanitize_text_field( (string) ( $field['autocomplete'] ?? '' ) ),
				);
			}
		}

		usort(
			$normalized,
			static fn( array $first, array $second ): int => $first['priority'] <=> $second['priority']
		);
		// Distinct merchant fields may legitimately share a label. Identity is
		// their key, never translated display text.
		return $normalized;
	}

	/** Keep one visible field per label and group, preferring Woo core fields. */
	private function remove_duplicate_visible_fields( array $fields ): array {
		$deduplicated = array();
		$positions    = array();
		foreach ( $fields as $field ) {
			if ( 'hidden' === $field['type'] ) {
				$deduplicated[] = $field;
				continue;
			}
			$label     = strtolower( preg_replace( '/\s+/u', ' ', trim( (string) $field['label'] ) ) ?? '' );
			$signature = $field['group'] . '|' . $label;
			if ( '' === $label || ! isset( $positions[ $signature ] ) ) {
				$positions[ $signature ] = count( $deduplicated );
				$deduplicated[]          = $field;
				continue;
			}

			$position = $positions[ $signature ];
			if ( $this->is_core_field( $field['key'] ) && ! $this->is_core_field( $deduplicated[ $position ]['key'] ) ) {
				$deduplicated[ $position ] = $field;
			}
		}

		return array_values( $deduplicated );
	}

	/** Store base country used by native checkout when the field is hidden. */
	private function get_default_country(): string {
		$location = function_exists( 'wc_get_base_location' ) ? wc_get_base_location() : array();
		$country  = isset( $location['country'] ) ? strtoupper( sanitize_key( (string) $location['country'] ) ) : '';
		return preg_match( '/^[A-Z]{2}$/', $country ) ? $country : '';
	}

	/** WooCommerce state codes and localized labels for the store country. */
	private function get_country_states( string $country ): array {
		$countries = null;
		if ( function_exists( 'WC' ) && WC() ) {
			$candidate = WC()->countries;
			if ( $candidate instanceof WC_Countries ) {
				$countries = $candidate;
			}
		}
		if ( ! $countries instanceof WC_Countries && class_exists( 'WC_Countries' ) ) {
			$countries = new WC_Countries();
		}
		if ( ! $countries instanceof WC_Countries ) {
			return array();
		}

		$raw_states = $countries->get_states( $country );
		if ( ! is_array( $raw_states ) ) {
			return array();
		}
		$states = array();
		foreach ( $raw_states as $code => $label ) {
			$code = sanitize_text_field( (string) $code );
			if ( '' !== $code ) {
				$states[ $code ] = wp_strip_all_tags( (string) $label );
			}
		}
		return $states;
	}

	/** Sanitize a custom value according to the filtered Woo field type. */
	private function sanitize_field_value( array $definition, $value ): string {
		if ( 'checkbox' === $definition['type'] ) {
			return rest_sanitize_boolean( $value ) ? '1' : '0';
		}
		if ( 'textarea' === $definition['type'] ) {
			return sanitize_textarea_field( (string) $value );
		}
		if ( ! empty( $definition['options'] ) ) {
			$value = (string) $value;
			return array_key_exists( $value, $definition['options'] ) ? sanitize_text_field( $value ) : '';
		}
		return sanitize_text_field( (string) $value );
	}

	/** Core address and note fields are already handled by Store API itself. */
	private function is_core_field( string $key ): bool {
		return in_array(
			$key,
			array(
				'billing_first_name', 'billing_last_name', 'billing_company',
				'billing_address_1', 'billing_address_2', 'billing_city',
				'billing_state', 'billing_postcode', 'billing_country',
				'billing_email', 'billing_phone', 'shipping_first_name',
				'shipping_last_name', 'shipping_company', 'shipping_address_1',
				'shipping_address_2', 'shipping_city', 'shipping_state',
				'shipping_postcode', 'shipping_country', 'shipping_email',
				'shipping_phone', 'order_comments',
			),
			true
		);
	}
}
