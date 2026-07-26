<?php
/**
 * Editable checkout-field snapshot backed by WooCommerce's filtered schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_Checkout_Fields_Store {
	public const OPTION = 'kidia_mobile_checkout_fields_builder';

	/** @return array{enabled:bool,fields:array<int,array<string,mixed>>} */
	public function get(): array {
		$saved = get_option( self::OPTION, null );
		if ( ! is_array( $saved ) || ! isset( $saved['fields'] ) || ! is_array( $saved['fields'] ) ) {
			return array( 'enabled' => true, 'fields' => $this->site_fields() );
		}
		return array(
			'enabled' => ! isset( $saved['enabled'] ) || ! empty( $saved['enabled'] ),
			'fields'  => $this->sanitize_fields( $saved['fields'] ),
		);
	}

	/** @return array<int,array<string,mixed>> */
	public function site_fields(): array {
		if ( ! function_exists( 'WC' ) || ! WC() || ! method_exists( WC(), 'checkout' ) ) {
			return array();
		}
		$checkout = WC()->checkout();
		if ( ! $checkout instanceof WC_Checkout ) {
			return array();
		}
		$rows = array();
		foreach ( array( 'billing', 'shipping', 'order' ) as $group ) {
			$fields = $checkout->get_checkout_fields( $group );
			if ( ! is_array( $fields ) ) {
				continue;
			}
			foreach ( $fields as $key => $field ) {
				if ( ! is_array( $field ) ) {
					continue;
				}
				$field['key']     = (string) $key;
				$field['group']   = $group;
				$field['enabled'] = true;
				$rows[]           = $field;
			}
		}
		return $this->sanitize_fields( $rows );
	}

	/** @param array<string,mixed> $submitted */
	public function save( array $submitted ): void {
		$fields = isset( $submitted['fields'] ) && is_array( $submitted['fields'] )
			? $submitted['fields']
			: array();
		update_option(
			self::OPTION,
			array(
				'enabled' => ! empty( $submitted['enabled'] ),
				'fields'  => $this->sanitize_fields( $fields ),
			),
			false
		);
	}

	public function reset_from_site(): void {
		update_option(
			self::OPTION,
			array( 'enabled' => true, 'fields' => $this->site_fields() ),
			false
		);
	}

	/** @return array<string,array<string,array<string,mixed>>> */
	public function checkout_groups(): array {
		$config = $this->get();
		if ( empty( $config['enabled'] ) ) {
			return array( 'billing' => array(), 'shipping' => array(), 'order' => array() );
		}
		$groups = array( 'billing' => array(), 'shipping' => array(), 'order' => array() );
		foreach ( $config['fields'] as $field ) {
			if ( empty( $field['enabled'] ) ) {
				continue;
			}
			$group = (string) $field['group'];
			$key   = (string) $field['key'];
			$groups[ $group ][ $key ] = array(
				'type'         => $field['type'],
				'label'        => $field['label'],
				'placeholder'  => $field['placeholder'],
				'required'     => $field['required'],
				'priority'     => $field['priority'],
				'options'      => $field['options'],
				'default'      => $field['default'],
				'autocomplete' => $field['autocomplete'],
			);
		}
		return $groups;
	}

	/** @param array<int|string,mixed> $fields
	 *  @return array<int,array<string,mixed>>
	 */
	private function sanitize_fields( array $fields ): array {
		$clean = array();
		$used  = array();
		foreach ( $fields as $position => $field ) {
			if ( ! is_array( $field ) ) {
				continue;
			}
			$group = sanitize_key( (string) ( $field['group'] ?? 'billing' ) );
			$group = in_array( $group, array( 'billing', 'shipping', 'order' ), true ) ? $group : 'billing';
			$label = sanitize_text_field( (string) ( $field['label'] ?? '' ) );
			$key   = sanitize_key( (string) ( $field['key'] ?? '' ) );
			if ( '' === $key ) {
				$key = sanitize_key( $group . '_' . ( '' !== $label ? $label : 'custom_' . ( (int) $position + 1 ) ) );
			}
			if ( isset( $used[ $key ] ) ) {
				$key .= '_' . ( (int) $position + 1 );
			}
			$used[ $key ] = true;
			$type = sanitize_key( (string) ( $field['type'] ?? 'text' ) );
			$type = in_array( $type, array( 'text', 'email', 'tel', 'select', 'textarea', 'checkbox', 'hidden', 'country', 'state' ), true ) ? $type : 'text';
			$options = array();
			if ( isset( $field['options'] ) && is_array( $field['options'] ) ) {
				foreach ( $field['options'] as $option_key => $option_label ) {
					$options[ sanitize_text_field( (string) $option_key ) ] = sanitize_text_field( (string) $option_label );
				}
			} elseif ( isset( $field['options_text'] ) ) {
				foreach ( preg_split( '/\R/', (string) $field['options_text'] ) ?: array() as $line ) {
					$parts = array_map( 'trim', explode( '|', $line, 2 ) );
					if ( '' !== ( $parts[0] ?? '' ) ) {
						$options[ sanitize_text_field( $parts[0] ) ] = sanitize_text_field( $parts[1] ?? $parts[0] );
					}
				}
			}
			$clean[] = array(
				'key'          => $key,
				'group'        => $group,
				'type'         => $type,
				'label'        => '' !== $label ? $label : $key,
				'placeholder'  => sanitize_text_field( (string) ( $field['placeholder'] ?? '' ) ),
				'required'     => ! empty( $field['required'] ),
				'enabled'      => ! isset( $field['enabled'] ) || ! empty( $field['enabled'] ),
				'priority'     => isset( $field['priority'] ) ? (int) $field['priority'] : ( ( count( $clean ) + 1 ) * 10 ),
				'options'      => $options,
				'default'      => is_scalar( $field['default'] ?? '' ) ? sanitize_text_field( (string) $field['default'] ) : '',
				'autocomplete' => sanitize_text_field( (string) ( $field['autocomplete'] ?? '' ) ),
			);
		}
		foreach ( $clean as $index => &$field ) {
			$field['priority'] = ( $index + 1 ) * 10;
		}
		unset( $field );
		return $clean;
	}
}
