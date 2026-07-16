<?php
/**
 * Mirrors filtered WooCommerce checkout fields into the native mobile app.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_CMS_Checkout_Config_Endpoint {

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
		register_rest_route(
			'woo-mobile/v1',
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
				'woo_mobile_checkout_unavailable',
				__( 'WooCommerce checkout is unavailable.', 'kidia-mobile-cms' ),
				array( 'status' => 503 )
			);
		}

		$checkout = WC()->checkout();
		if ( ! $checkout instanceof WC_Checkout ) {
			return new WP_Error(
				'woo_mobile_checkout_unavailable',
				__( 'WooCommerce checkout is unavailable.', 'kidia-mobile-cms' ),
				array( 'status' => 503 )
			);
		}
		$default_country = $this->get_default_country();
		$states          = $this->get_country_states( $default_country );

		$response = rest_ensure_response(
			array(
				'version'  => 3,
				'defaults' => array(
					'country' => $default_country,
					'states'  => $states,
				),
				'fields'   => $this->normalize_fields(
					$checkout->get_checkout_fields(),
					$default_country
				),
			)
		);
		$response->header( 'Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0' );
		$response->header( 'Pragma', 'no-cache' );
		return $response;
	}

	/** Allow the app to submit custom plugin fields inside Store API extensions. */
	public function register_store_api_data(): void {
		if ( ! function_exists( 'woocommerce_store_api_register_endpoint_data' ) ||
			! class_exists( '\\Automattic\\WooCommerce\\StoreApi\\Schemas\\V1\\CheckoutSchema' ) ) {
			return;
		}

		woocommerce_store_api_register_endpoint_data(
			array(
				'endpoint'        => \Automattic\WooCommerce\StoreApi\Schemas\V1\CheckoutSchema::IDENTIFIER,
				'namespace'       => 'woo_mobile_cms',
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
				'description'          => __( 'Filtered WooCommerce checkout plugin fields.', 'kidia-mobile-cms' ),
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
		$values     = is_array( $extensions ) &&
			isset( $extensions['woo_mobile_cms']['checkout_fields'] ) &&
			is_array( $extensions['woo_mobile_cms']['checkout_fields'] )
			? $extensions['woo_mobile_cms']['checkout_fields']
			: array();
		if ( empty( $values ) || ! function_exists( 'WC' ) || ! WC() || ! method_exists( WC(), 'checkout' ) ) {
			return;
		}

		$checkout = WC()->checkout();
		if ( ! $checkout instanceof WC_Checkout ) {
			return;
		}

		$definitions = array();
		foreach ( $this->normalize_fields( $checkout->get_checkout_fields(), $this->get_default_country() ) as $definition ) {
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

				$default  = is_scalar( $field['default'] ?? '' ) ? (string) $field['default'] : '';
				$required = ! empty( $field['required'] );
				$is_country = 'country' === $type || str_ends_with( $key, '_country' );
				$is_state   = 'state' === $type || str_ends_with( $key, '_state' );
				if ( $is_country ) {
					$type     = 'hidden';
					$options  = array();
					$default  = $default_country;
					$required = false;
				} elseif ( $is_state ) {
					$options  = ! empty( $states ) ? $states : $options;
					$type     = ! empty( $options ) ? 'select' : 'text';
					$required = ! empty( $options ) ? true : $required;
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
					'default'      => $default,
					'autocomplete' => sanitize_text_field( (string) ( $field['autocomplete'] ?? '' ) ),
				);
			}
		}

		usort(
			$normalized,
			static fn( array $first, array $second ): int => $first['priority'] <=> $second['priority']
		);
		return $this->remove_duplicate_visible_fields( $normalized );
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
		return preg_match( '/^[A-Z]{2}$/', $country ) ? $country : 'EG';
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
