<?php
/**
 * Plugin Name: MobiShop — Kidia address book adapter
 * Description: Exposes the website's saved shipping addresses through the
 * shared native checkout address contract. No customer records are modified.
 */
defined( 'ABSPATH' ) || exit;

add_filter( 'mobishop_native_checkout_addresses92', 'mobishop_kidia_address_book', 10, 2 );

function mobishop_kidia_address_book( array $rows, int $customer_id ): array {
	if ( $customer_id <= 0 || $customer_id !== get_current_user_id() ||
		! class_exists( 'Kidia_Shipping_Addresses' ) ) {
		return $rows;
	}
	// Kidia_Shipping_Addresses v1 is also the source used by the web checkout.
	$addresses = get_user_meta( $customer_id, 'kidia_shipping_addresses_v1', true );
	if ( ! is_array( $addresses ) ) return $rows;
	$book = array();
	$core = array( 'first_name', 'last_name', 'company', 'country', 'state',
		'city', 'address_1', 'address_2', 'postcode', 'email', 'phone' );
	foreach ( array_slice( $addresses, 0, 30, true ) as $key => $address ) {
		if ( ! is_array( $address ) || empty( $address['address_1'] ) ) continue;
		$values = array();
		foreach ( $core as $field ) {
			if ( isset( $address[ $field ] ) && is_scalar( $address[ $field ] ) ) {
				$values[ $field ] = (string) $address[ $field ];
			}
		}
		// Preserve merchant fields such as an alternate phone, using the same
		// unprefixed field names as the common checkout contract.
		foreach ( (array) ( $address['checkout_fields'] ?? array() ) as $field => $value ) {
			if ( is_string( $field ) && str_starts_with( $field, 'billing_' ) && is_scalar( $value ) ) {
				$name = substr( $field, 8 );
				if ( ! array_key_exists( $name, $values ) ) $values[ $name ] = (string) $value;
			}
		}
		$book[] = array( 'id' => 'address-book-' . (string) ( $address['id'] ?? $key ),
			'label' => (string) ( $address['label'] ?? '' ), 'values' => $values );
	}
	return array_merge( $book, $rows );
}
