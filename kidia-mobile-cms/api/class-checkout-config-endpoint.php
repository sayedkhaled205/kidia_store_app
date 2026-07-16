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

		return rest_ensure_response(
			array(
				'version' => 1,
				'fields'  => $this->normalize_fields( $checkout->get_checkout_fields() ),
			)
		);
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
		if ( empty( $values ) || ! function_exists( 'WC' ) || ! WC() ) {
			return;
		}

		$definitions = array();
		foreach ( $this->normalize_fields( WC()->checkout()->get_checkout_fields() ) as $definition ) {
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
	private function normalize_fields( array $groups ): array {
		$normalized = array();
		foreach ( array( 'billing', 'shipping', 'order' ) as $group ) {
			$fields = isset( $groups[ $group ] ) && is_array( $groups[ $group ] )
				? $groups[ $group ]
				: array();
			foreach ( $fields as $key => $field ) {
				if ( ! is_array( $field ) ) {
					continue;
				}
				$type    = sanitize_key( (string) ( $field['type'] ?? 'text' ) );
				$options = array();
				if ( isset( $field['options'] ) && is_array( $field['options'] ) ) {
					foreach ( $field['options'] as $option_key => $option_label ) {
						$options[ (string) $option_key ] = wp_strip_all_tags( (string) $option_label );
					}
				} elseif ( 'country' === $type && isset( WC()->countries ) ) {
					$options = WC()->countries->get_countries();
				}

				$normalized[] = array(
					'key'          => sanitize_key( (string) $key ),
					'group'        => $group,
					'type'         => $type,
					'label'        => wp_strip_all_tags( (string) ( $field['label'] ?? $key ) ),
					'placeholder'  => wp_strip_all_tags( (string) ( $field['placeholder'] ?? '' ) ),
					'required'     => ! empty( $field['required'] ),
					'priority'     => isset( $field['priority'] ) ? (int) $field['priority'] : 100,
					'options'      => $options,
					'default'      => is_scalar( $field['default'] ?? '' ) ? (string) $field['default'] : '',
					'autocomplete' => sanitize_text_field( (string) ( $field['autocomplete'] ?? '' ) ),
				);
			}
		}

		usort(
			$normalized,
			static fn( array $first, array $second ): int => $first['priority'] <=> $second['priority']
		);
		return array_values( $normalized );
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
