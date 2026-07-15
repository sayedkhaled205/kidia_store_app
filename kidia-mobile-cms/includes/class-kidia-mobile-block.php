<?php
/**
 * Base Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Block', false ) ) {
	return;
}

/**
 * Base class for every Home Builder block.
 */
abstract class Kidia_Mobile_Block {

	/**
	 * Unique block type.
	 *
	 * Example: image_banner, product_carousel.
	 *
	 * @return string
	 */
	abstract public function get_type(): string;

	/**
	 * Block display name inside the Builder.
	 *
	 * @return string
	 */
	abstract public function get_label(): string;

	/**
	 * WordPress Dashicon class.
	 *
	 * @return string
	 */
	public function get_icon(): string {
		return 'dashicons-screenoptions';
	}

	/**
	 * Short block description.
	 *
	 * @return string
	 */
	public function get_description(): string {
		return '';
	}

	/**
	 * Returns default block settings.
	 *
	 * @return array<string, mixed>
	 */
	public function get_default_settings(): array {
		return array();
	}

	/**
	 * Sanitizes submitted settings.
	 *
	 * Child blocks may override this method.
	 *
	 * @param array<string, mixed> $settings Submitted settings.
	 *
	 * @return array<string, mixed>
	 */
	public function sanitize_settings(
		array $settings
	): array {
		return $this->sanitize_value_array(
			$settings
		);
	}

	/**
	 * Builds the block data returned by the REST API.
	 *
	 * @param array<string, mixed> $settings Saved settings.
	 *
	 * @return array<string, mixed>|null
	 */
	abstract public function build_api_data(
		array $settings
	): ?array;

	/**
	 * Renders the block settings inside Home Builder.
	 *
	 * @param int                  $index    Block index.
	 * @param array<string, mixed> $settings Saved settings.
	 *
	 * @return void
	 */
	abstract public function render_settings(
		int $index,
		array $settings
	): void;

	/**
	 * Creates a new block instance.
	 *
	 * @param int $order Block order.
	 *
	 * @return array<string, mixed>
	 */
	public function create_instance(
		int $order = 1
	): array {
		return array(
			'id'       => $this->generate_instance_id(),
			'type'     => $this->get_type(),
			'enabled'  => true,
			'order'    => max( 1, $order ),
			'settings' => $this->get_default_settings(),
		);
	}

	/**
	 * Normalizes a saved block instance.
	 *
	 * @param array<string, mixed> $block Raw saved block.
	 * @param int                  $order Block order.
	 *
	 * @return array<string, mixed>
	 */
	public function normalize_instance(
		array $block,
		int $order
	): array {
		$id = isset( $block['id'] )
			? sanitize_key(
				(string) $block['id']
			)
			: '';

		if ( empty( $id ) ) {
			$id = $this->generate_instance_id();
		}

		$settings = isset( $block['settings'] )
			&& is_array( $block['settings'] )
				? $block['settings']
				: array();

		$settings = wp_parse_args(
			$this->sanitize_settings( $settings ),
			$this->get_default_settings()
		);

		return array(
			'id'       => $id,
			'type'     => $this->get_type(),
			'enabled'  => ! empty( $block['enabled'] ),
			'order'    => max( 1, $order ),
			'settings' => $settings,
		);
	}

	/**
	 * Builds the complete REST API block structure.
	 *
	 * @param array<string, mixed> $instance Saved block instance.
	 *
	 * @return array<string, mixed>|null
	 */
	public function build_api_block(
		array $instance
	): ?array {
		if ( empty( $instance['enabled'] ) ) {
			return null;
		}

		$settings = isset( $instance['settings'] )
			&& is_array( $instance['settings'] )
				? $instance['settings']
				: array();

		$data = $this->build_api_data(
			wp_parse_args(
				$settings,
				$this->get_default_settings()
			)
		);

		if ( null === $data ) {
			return null;
		}

		$id = isset( $instance['id'] )
			? sanitize_key(
				(string) $instance['id']
			)
			: $this->generate_instance_id();

		return array(
			'id'      => $id,
			'type'    => $this->get_type(),
			'enabled' => true,
			'data'    => $data,
		);
	}

	/**
	 * Returns block metadata for the Add Element popup.
	 *
	 * @return array<string, mixed>
	 */
	public function get_definition(): array {
		return array(
			'type'        => $this->get_type(),
			'label'       => $this->get_label(),
			'description' => $this->get_description(),
			'icon'        => $this->get_icon(),
			'duplicable'  => true,
		);
	}

	/**
	 * Generates a unique instance ID.
	 *
	 * @return string
	 */
	protected function generate_instance_id(): string {
		$uuid = function_exists( 'wp_generate_uuid4' )
			? wp_generate_uuid4()
			: uniqid( '', true );

		return sanitize_key(
			$this->get_type()
			. '_'
			. str_replace( '-', '', $uuid )
		);
	}

	/**
	 * Sanitizes nested settings arrays.
	 *
	 * @param array<string|int, mixed> $values Raw values.
	 *
	 * @return array<string|int, mixed>
	 */
	protected function sanitize_value_array(
		array $values
	): array {
		$sanitized = array();

		foreach ( $values as $key => $value ) {
			$clean_key = is_string( $key )
				? sanitize_key( $key )
				: absint( $key );

			if ( is_array( $value ) ) {
				$sanitized[ $clean_key ] =
					$this->sanitize_value_array( $value );

				continue;
			}

			if ( is_bool( $value ) ) {
				$sanitized[ $clean_key ] = $value;
				continue;
			}

			if ( is_int( $value ) || is_float( $value ) ) {
				$sanitized[ $clean_key ] = $value;
				continue;
			}

			if ( null === $value ) {
				$sanitized[ $clean_key ] = null;
				continue;
			}

			$string_value = (string) $value;

			if (
				is_string( $clean_key )
				&& (
					str_ends_with( $clean_key, '_url' )
					|| 'url' === $clean_key
				)
			) {
				$sanitized[ $clean_key ] = esc_url_raw(
					$string_value
				);

				continue;
			}

			if (
				is_string( $clean_key )
				&& in_array(
					$clean_key,
					array(
						'content',
						'description',
						'subtitle',
					),
					true
				)
			) {
				$sanitized[ $clean_key ] =
					sanitize_textarea_field(
						$string_value
					);

				continue;
			}

			$sanitized[ $clean_key ] =
				sanitize_text_field(
					$string_value
				);
		}

		return $sanitized;
	}

	/**
	 * Builds a Flutter navigation action.
	 *
	 * @param mixed $type  Action type.
	 * @param mixed $value Action value.
	 *
	 * @return array<string, string>|null
	 */
	protected function build_action(
		$type,
		$value
	): ?array {
		$type = sanitize_key(
			(string) $type
		);

		$value = trim(
			(string) $value
		);

		$allowed_types = array(
			'product',
			'category',
			'collection',
			'search',
			'external',
		);

		if (
			empty( $type )
			|| empty( $value )
			|| ! in_array(
				$type,
				$allowed_types,
				true
			)
		) {
			return null;
		}

		if ( 'external' === $type ) {
			$value = esc_url_raw( $value );

			if ( empty( $value ) ) {
				return null;
			}
		} else {
			$value = sanitize_text_field(
				$value
			);
		}

		return array(
			'type'  => $type,
			'value' => $value,
		);
	}
}