<?php
/**
 * Mobile Home Builder layout storage.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Layout_Store', false ) ) {
	return;
}

final class Kidia_Mobile_Layout_Store {

	private const OPTION_NAME = 'kidia_mobile_home_layout_v3';

	/**
	 * Maps block types to their Library option names.
	 *
	 * @var array<string, string>
	 */
	private const LIBRARY_OPTIONS = array(
		'hero_slider'     => 'kidia_mobile_hero_sliders',
		'image_banner'    => 'kidia_mobile_image_banners',
		'product_carousel'=> 'kidia_mobile_product_carousels',
		'brand_carousel'  => 'kidia_mobile_brand_carousels',
		'category_grid'   => 'kidia_mobile_category_grids',
		'product_grid'    => 'kidia_mobile_product_grids',
		'section_header'  => 'kidia_mobile_section_headers',
		'promo_strip'     => 'kidia_mobile_promo_strips',
		'coupon_banner'   => 'kidia_mobile_coupon_banners',
		'countdown'       => 'kidia_mobile_countdowns',
		'video_banner'    => 'kidia_mobile_video_banners',
		'text_block'      => 'kidia_mobile_text_blocks',
		'divider'         => 'kidia_mobile_dividers',
		'spacer'          => 'kidia_mobile_spacers',
	);

	/**
	 * Returns the synchronized Home Layout.
	 *
	 * @return array<int, array<string, mixed>>
	 */
	public function get_layout(): array {
		$saved_layout = get_option(
			self::OPTION_NAME,
			array()
		);

		if ( ! is_array( $saved_layout ) ) {
			$saved_layout = array();
		}

		$layout = $this->hydrate_layout(
			$this->normalize_layout(
				$saved_layout
			)
		);

		$layout = $this->append_missing_library_items(
			$layout
		);

		if ( empty( $layout ) ) {
			$layout = $this->get_default_layout();
		}

		$layout = $this->reorder_layout(
			$layout
		);

		$this->save_layout_references(
			$layout
		);

		return $layout;
	}

	/**
	 * Saves and synchronizes the submitted Home Layout.
	 *
	 * @param array<int|string, mixed> $submitted_layout Submitted blocks.
	 *
	 * @return bool
	 */
	public function save_layout(
		array $submitted_layout
	): bool {
		$old_layout = $this->get_saved_layout();

		$new_layout = $this->normalize_layout(
			$submitted_layout
		);

		$new_layout = $this->reorder_layout(
			$new_layout
		);

		$this->sync_layout_with_libraries(
			$new_layout
		);

		$this->delete_removed_library_items(
			$old_layout,
			$new_layout
		);

		return $this->save_layout_references(
			$new_layout
		);
	}

	/**
	 * Returns default Home Page blocks.
	 *
	 * @return array<int, array<string, mixed>>
	 */
	public function get_default_layout(): array {
		$types = array(
			'hero_slider',
			'image_banner',
			'product_carousel',
		);

		$layout = array();

		foreach ( $types as $index => $type ) {
			$block = Kidia_Mobile_Block_Registry::create(
				$type,
				$index + 1
			);

			if ( null === $block ) {
				continue;
			}

			$block['name'] = $this->get_unique_default_name(
				$type,
				$layout
			);

			$block['library_id'] = $block['id'];

			$layout[] = $block;
		}

		$this->sync_layout_with_libraries(
			$layout
		);

		return $layout;
	}

	/**
	 * Returns the raw saved layout.
	 *
	 * @return array<int, array<string, mixed>>
	 */
	private function get_saved_layout(): array {
		$layout = get_option(
			self::OPTION_NAME,
			array()
		);

		if ( ! is_array( $layout ) ) {
			return array();
		}

		return $this->normalize_layout(
			$layout
		);
	}

	/**
	 * Normalizes all layout blocks.
	 *
	 * @param array<int|string, mixed> $layout Raw layout.
	 *
	 * @return array<int, array<string, mixed>>
	 */
	private function normalize_layout(
		array $layout
	): array {
		$normalized = array();

		foreach ( array_values( $layout ) as $index => $raw_block ) {
			if ( ! is_array( $raw_block ) ) {
				continue;
			}

			$type = isset( $raw_block['type'] )
				? sanitize_key(
					(string) $raw_block['type']
				)
				: '';

			if (
				empty( $type )
				|| ! Kidia_Mobile_Block_Registry::exists( $type )
			) {
				continue;
			}

			$id = isset( $raw_block['id'] )
				? sanitize_key(
					(string) $raw_block['id']
				)
				: '';

			if ( empty( $id ) ) {
				$id = Kidia_Mobile_Block_Registry::generate_id(
					$type
				);
			}

			$library_id = isset( $raw_block['library_id'] )
				? sanitize_key(
					(string) $raw_block['library_id']
				)
				: $id;

			if ( empty( $library_id ) ) {
				$library_id = $id;
			}

			$name = isset( $raw_block['name'] )
				? sanitize_text_field(
					(string) $raw_block['name']
				)
				: '';

			if ( empty( $name ) ) {
				$name = $this->get_default_name(
					$type
				);
			}

			$settings = isset( $raw_block['settings'] )
				&& is_array( $raw_block['settings'] )
					? $this->sanitize_settings(
						$raw_block['settings']
					)
					: array();

			$settings = wp_parse_args(
				$settings,
				Kidia_Mobile_Block_Registry::defaults(
					$type
				)
			);

			$normalized[] = array(
				'id'         => $id,
				'library_id' => $library_id,
				'type'       => $type,
				'name'       => $name,
				'enabled'    => ! empty( $raw_block['enabled'] ),
				'order'      => $index + 1,
				'settings'   => $settings,
			);
		}

		return $normalized;
	}

	/**
	 * Hydrates layout blocks from their Library records.
	 *
	 * @param array<int, array<string, mixed>> $layout Layout.
	 *
	 * @return array<int, array<string, mixed>>
	 */
	private function hydrate_layout(
		array $layout
	): array {
		$hydrated = array();

		foreach ( $layout as $block ) {
			$type = (string) $block['type'];

			$library_id = isset( $block['library_id'] )
				? (string) $block['library_id']
				: (string) $block['id'];

			$library_item = $this->find_library_item(
				$type,
				$library_id
			);

			if ( null === $library_item ) {
				continue;
			}

			$block['name'] = isset( $library_item['name'] )
				? sanitize_text_field(
					(string) $library_item['name']
				)
				: $block['name'];

			$block['enabled'] =
				! empty( $library_item['enabled'] )
				&& 'published' === (
					$library_item['status'] ?? 'draft'
				);

			$library_settings =
				isset( $library_item['settings'] )
				&& is_array( $library_item['settings'] )
					? $library_item['settings']
					: array();

			$block['settings'] = wp_parse_args(
				$this->sanitize_settings(
					$library_settings
				),
				Kidia_Mobile_Block_Registry::defaults(
					$type
				)
			);

			$hydrated[] = $block;
		}

		return $hydrated;
	}

	/**
	 * Appends Library items not yet present in Home Builder.
	 *
	 * @param array<int, array<string, mixed>> $layout Layout.
	 *
	 * @return array<int, array<string, mixed>>
	 */
	private function append_missing_library_items(
		array $layout
	): array {
		$existing = array();

		foreach ( $layout as $block ) {
			$key = (string) $block['type']
				. ':'
				. (string) (
					$block['library_id']
					?? $block['id']
				);

			$existing[ $key ] = true;
		}

		foreach ( self::LIBRARY_OPTIONS as $type => $option_name ) {
			$items = get_option(
				$option_name,
				array()
			);

			if ( ! is_array( $items ) ) {
				continue;
			}

			foreach ( $items as $item ) {
				if (
					! is_array( $item )
					|| empty( $item['id'] )
				) {
					continue;
				}

				$library_id = sanitize_key(
					(string) $item['id']
				);

				$key = $type . ':' . $library_id;

				if ( isset( $existing[ $key ] ) ) {
					continue;
				}

				$settings = isset( $item['settings'] )
					&& is_array( $item['settings'] )
						? $this->sanitize_settings(
							$item['settings']
						)
						: array();

				$layout[] = array(
					'id'         => $library_id,
					'library_id' => $library_id,
					'type'       => $type,
					'name'       => ! empty( $item['name'] )
						? sanitize_text_field(
							(string) $item['name']
						)
						: $this->get_default_name( $type ),
					'enabled'    => ! empty( $item['enabled'] )
						&& 'published' === (
							$item['status'] ?? 'draft'
						),
					'order'      => count( $layout ) + 1,
					'settings'   => wp_parse_args(
						$settings,
						Kidia_Mobile_Block_Registry::defaults(
							$type
						)
					),
				);

				$existing[ $key ] = true;
			}
		}

		return $layout;
	}

	/**
	 * Synchronizes Home Builder blocks with Library options.
	 *
	 * @param array<int, array<string, mixed>> $layout Layout.
	 *
	 * @return void
	 */
	private function sync_layout_with_libraries(
		array $layout
	): void {
		$grouped = array();

		foreach ( $layout as $block ) {
			$type = (string) $block['type'];

			if ( ! isset( self::LIBRARY_OPTIONS[ $type ] ) ) {
				continue;
			}

			if ( ! isset( $grouped[ $type ] ) ) {
				$grouped[ $type ] = $this->get_library_items(
					$type
				);
			}

			$library_id = isset( $block['library_id'] )
				? sanitize_key(
					(string) $block['library_id']
				)
				: sanitize_key(
					(string) $block['id']
				);

			$found = false;

			foreach ( $grouped[ $type ] as &$item ) {
				if (
					empty( $item['id'] )
					|| sanitize_key(
						(string) $item['id']
					) !== $library_id
				) {
					continue;
				}

				$item['name'] = sanitize_text_field(
					(string) $block['name']
				);

				$item['enabled'] =
					! empty( $block['enabled'] );

				$item['settings'] =
					$this->sanitize_settings(
						(array) $block['settings']
					);

				$item['updated_at'] = current_time(
					'mysql',
					true
				);

				$found = true;

				break;
			}

			unset( $item );

			if ( $found ) {
				continue;
			}

			$grouped[ $type ][] = array(
				'id'         => $library_id,
				'name'       => sanitize_text_field(
					(string) $block['name']
				),
				'status'     => 'published',
				'enabled'    => ! empty( $block['enabled'] ),
				'created_at' => current_time(
					'mysql',
					true
				),
				'updated_at' => current_time(
					'mysql',
					true
				),
				'settings'   => $this->sanitize_settings(
					(array) $block['settings']
				),
			);
		}

		foreach ( $grouped as $type => $items ) {
			update_option(
				self::LIBRARY_OPTIONS[ $type ],
				array_values( $items ),
				false
			);
		}
	}

	/**
	 * Deletes Library records removed from Home Builder.
	 *
	 * @param array<int, array<string, mixed>> $old_layout Old layout.
	 * @param array<int, array<string, mixed>> $new_layout New layout.
	 *
	 * @return void
	 */
	private function delete_removed_library_items(
		array $old_layout,
		array $new_layout
	): void {
		$new_keys = array();

		foreach ( $new_layout as $block ) {
			$new_keys[] = (string) $block['type']
				. ':'
				. (string) (
					$block['library_id']
					?? $block['id']
				);
		}

		foreach ( $old_layout as $block ) {
			$type = (string) $block['type'];

			if ( ! isset( self::LIBRARY_OPTIONS[ $type ] ) ) {
				continue;
			}

			$library_id = (string) (
				$block['library_id']
					?? $block['id']
			);

			$key = $type . ':' . $library_id;

			if ( in_array( $key, $new_keys, true ) ) {
				continue;
			}

			$items = $this->get_library_items(
				$type
			);

			$items = array_filter(
				$items,
				static function ( array $item ) use ( $library_id ): bool {
					return empty( $item['id'] )
						|| sanitize_key(
							(string) $item['id']
						) !== sanitize_key(
							$library_id
						);
				}
			);

			update_option(
				self::LIBRARY_OPTIONS[ $type ],
				array_values( $items ),
				false
			);
		}
	}

	/**
	 * Saves compact layout references.
	 *
	 * @param array<int, array<string, mixed>> $layout Layout.
	 *
	 * @return bool
	 */
	private function save_layout_references(
		array $layout
	): bool {
		$references = array();

		foreach ( $layout as $index => $block ) {
			$references[] = array(
				'id'         => sanitize_key(
					(string) $block['id']
				),
				'library_id' => sanitize_key(
					(string) (
						$block['library_id']
							?? $block['id']
					)
				),
				'type'       => sanitize_key(
					(string) $block['type']
				),
				'name'       => sanitize_text_field(
					(string) $block['name']
				),
				'enabled'    => ! empty( $block['enabled'] ),
				'order'      => $index + 1,
				'settings'   => $this->sanitize_settings(
					(array) $block['settings']
				),
			);
		}

		return update_option(
			self::OPTION_NAME,
			$references,
			false
		);
	}

	/**
	 * Returns all records for a Library type.
	 *
	 * @param string $type Block type.
	 *
	 * @return array<int, array<string, mixed>>
	 */
	private function get_library_items(
		string $type
	): array {
		if ( ! isset( self::LIBRARY_OPTIONS[ $type ] ) ) {
			return array();
		}

		$items = get_option(
			self::LIBRARY_OPTIONS[ $type ],
			array()
		);

		return is_array( $items )
			? array_values( $items )
			: array();
	}

	/**
	 * Finds one Library record.
	 *
	 * @param string $type       Block type.
	 * @param string $library_id Library item ID.
	 *
	 * @return array<string, mixed>|null
	 */
	private function find_library_item(
		string $type,
		string $library_id
	): ?array {
		foreach ( $this->get_library_items( $type ) as $item ) {
			if (
				! empty( $item['id'] )
				&& sanitize_key(
					(string) $item['id']
				) === sanitize_key( $library_id )
			) {
				return $item;
			}
		}

		return null;
	}

	/**
	 * Reorders layout sequentially.
	 *
	 * @param array<int, array<string, mixed>> $layout Layout.
	 *
	 * @return array<int, array<string, mixed>>
	 */
	private function reorder_layout(
		array $layout
	): array {
		$layout = array_values( $layout );

		foreach ( $layout as $index => &$block ) {
			$block['order'] = $index + 1;
		}

		unset( $block );

		return $layout;
	}

	/**
	 * Returns default block name.
	 *
	 * @param string $type Block type.
	 *
	 * @return string
	 */
	private function get_default_name(
		string $type
	): string {
		$definition = Kidia_Mobile_Block_Registry::get(
			$type
		);

		if (
			is_array( $definition )
			&& ! empty( $definition['label'] )
		) {
			return sanitize_text_field(
				(string) $definition['label']
			);
		}

		return ucwords(
			str_replace(
				'_',
				' ',
				$type
			)
		);
	}

	/**
	 * Returns a unique default name.
	 *
	 * @param string                           $type   Block type.
	 * @param array<int, array<string, mixed>> $layout Current layout.
	 *
	 * @return string
	 */
	private function get_unique_default_name(
		string $type,
		array $layout
	): string {
		$base_name = $this->get_default_name(
			$type
		);

		$count = 1;

		foreach ( $layout as $block ) {
			if (
				isset( $block['type'] )
				&& $block['type'] === $type
			) {
				$count++;
			}
		}

		return 1 === $count
			? $base_name
			: $base_name . ' ' . $count;
	}

	/**
	 * Sanitizes nested settings.
	 *
	 * @param array<string|int, mixed> $settings Raw settings.
	 *
	 * @return array<string|int, mixed>
	 */
	private function sanitize_settings(
		array $settings
	): array {
		$sanitized = array();

		foreach ( $settings as $key => $value ) {
			$clean_key = is_string( $key )
				? sanitize_key( $key )
				: absint( $key );

			if ( is_array( $value ) ) {
				$sanitized[ $clean_key ] =
					$this->sanitize_settings(
						$value
					);

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
				&& false !== strpos( $clean_key, 'url' )
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
						'text',
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
}