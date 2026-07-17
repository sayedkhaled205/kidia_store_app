<?php
/**
 * Mobile Home Builder block registry.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Block_Registry', false ) ) {
	return;
}

final class Kidia_Mobile_Block_Registry {

	/**
	 * Registered block objects.
	 *
	 * @var array<string, Kidia_Mobile_Block>
	 */
	private static array $registered_blocks = array();

	/**
	 * Maps block types to schema file names.
	 *
	 * @var array<string, string>
	 */
	private const SCHEMA_FILES = array(
		'app_header'      => 'app-header',
		'hero_slider'     => 'hero-slider',
		'image_banner'    => 'image-banner',
		'product_carousel'=> 'product-carousel',
		'brand_carousel'  => 'brand-carousel',
		'category_grid'   => 'category-grid',
		'product_grid'    => 'product-grid',
		'section_header'  => 'section-header',
		'promo_strip'     => 'promo-strip',
		'coupon_banner'   => 'coupon-banner',
		'countdown'       => 'countdown',
		'video_banner'    => 'video-banner',
		'text_block'      => 'text-block',
		'divider'         => 'divider',
		'spacer'          => 'spacer',
	);

	/**
	 * Registers a Home Builder block.
	 *
	 * @param Kidia_Mobile_Block $block Block object.
	 *
	 * @return void
	 */
	public static function register(
		Kidia_Mobile_Block $block
	): void {
		$type = sanitize_key(
			$block->get_type()
		);

		if ( empty( $type ) ) {
			return;
		}

		self::$registered_blocks[ $type ] = $block;
	}

	/**
	 * Removes a registered block.
	 *
	 * @param string $type Block type.
	 *
	 * @return void
	 */
	public static function unregister(
		string $type
	): void {
		$type = sanitize_key( $type );

		unset(
			self::$registered_blocks[ $type ]
		);
	}

	/**
	 * Returns a registered block object.
	 *
	 * @param string $type Block type.
	 *
	 * @return Kidia_Mobile_Block|null
	 */
	public static function get_block(
		string $type
	): ?Kidia_Mobile_Block {
		$type = sanitize_key( $type );

		return self::$registered_blocks[ $type ] ?? null;
	}

	/**
	 * Returns all registered block objects.
	 *
	 * @return array<string, Kidia_Mobile_Block>
	 */
	public static function registered(): array {
		return self::$registered_blocks;
	}

	/**
	 * Returns definitions for all supported blocks.
	 *
	 * @return array<string, array<string, mixed>>
	 */
	public static function all(): array {
		$definitions = array();

		foreach ( self::SCHEMA_FILES as $type => $schema_file ) {
			$schema = self::load_schema( $type );

			if ( empty( $schema ) ) {
				continue;
			}

			$definitions[ $type ] = array(
				'type'        => $type,
				'label'       => isset( $schema['title'] )
					? (string) $schema['title']
					: $type,
				'description' => isset( $schema['description'] )
					? (string) $schema['description']
					: '',
				'icon'        => isset( $schema['icon'] )
					? (string) $schema['icon']
					: 'dashicons-screenoptions',
				'duplicable'  => true,
				'defaults'    => isset( $schema['defaults'] )
					&& is_array( $schema['defaults'] )
						? $schema['defaults']
						: array(),
			);
		}

		foreach ( self::$registered_blocks as $type => $block ) {
			$block_definition = $block->get_definition();

			$definitions[ $type ] = array_merge(
				$definitions[ $type ] ?? array(),
				$block_definition,
				array(
					'type'     => $type,
					'defaults' => array_merge(
						$block->get_presentation_defaults(),
						$block->get_default_settings()
					),
				)
			);
		}

		return $definitions;
	}
		/**
    	 * Returns one block definition.
    	 *
    	 * @param string $type Block type.
    	 *
    	 * @return array<string, mixed>|null
    	 */
    	public static function get(
    		string $type
    	): ?array {
    		$type        = sanitize_key( $type );
    		$definitions = self::all();

    		return $definitions[ $type ] ?? null;
    	}

    	/**
    	 * Checks whether a block type is supported.
    	 *
    	 * @param string $type Block type.
    	 *
    	 * @return bool
    	 */
    	public static function exists(
    		string $type
    	): bool {
    		$type = sanitize_key( $type );

    		return isset( self::SCHEMA_FILES[ $type ] )
    			&& ! empty( self::load_schema( $type ) );
    	}

    	/**
    	 * Checks whether a block object is registered.
    	 *
    	 * @param string $type Block type.
    	 *
    	 * @return bool
    	 */
    	public static function is_registered(
    		string $type
    	): bool {
    		return self::get_block( $type )
    			instanceof Kidia_Mobile_Block;
    	}

    	/**
    	 * Returns default settings for a block.
    	 *
    	 * @param string $type Block type.
    	 *
    	 * @return array<string, mixed>
    	 */
    	public static function defaults(
    		string $type
    	): array {
    		$type  = sanitize_key( $type );
    		$block = self::get_block( $type );

		if ( $block instanceof Kidia_Mobile_Block ) {
				return array_merge(
					$block->get_presentation_defaults(),
					$block->get_default_settings()
				);
    		}

    		$schema = self::load_schema( $type );

    		if (
    			empty( $schema['defaults'] )
    			|| ! is_array( $schema['defaults'] )
    		) {
    			return array();
    		}

    		return $schema['defaults'];
    	}

    	/**
    	 * Creates a new block instance.
    	 *
    	 * @param string $type  Block type.
    	 * @param int    $order Block order.
    	 *
    	 * @return array<string, mixed>|null
    	 */
    	public static function create(
    		string $type,
    		int $order = 1
    	): ?array {
    		$type = sanitize_key( $type );

    		if ( ! self::exists( $type ) ) {
    			return null;
    		}

    		$block = self::get_block( $type );

    		if ( $block instanceof Kidia_Mobile_Block ) {
    			return $block->create_instance(
    				max( 1, $order )
    			);
    		}

    		return array(
    			'id'       => self::generate_id( $type ),
    			'type'     => $type,
    			'name'     => self::get_default_name( $type ),
    			'enabled'  => true,
    			'order'    => max( 1, $order ),
    			'settings' => self::defaults( $type ),
    		);
    	}

    	/**
    	 * Normalizes a saved block instance.
    	 *
    	 * @param array<string, mixed> $instance Saved instance.
    	 * @param int                  $order    Block order.
    	 *
    	 * @return array<string, mixed>|null
    	 */
    	public static function normalize(
    		array $instance,
    		int $order
    	): ?array {
    		$type = isset( $instance['type'] )
    			? sanitize_key(
    				(string) $instance['type']
    			)
    			: '';

    		if (
    			empty( $type )
    			|| ! self::exists( $type )
    		) {
    			return null;
    		}

    		$block = self::get_block( $type );

    		if ( $block instanceof Kidia_Mobile_Block ) {
    			$normalized = $block->normalize_instance(
    				$instance,
    				max( 1, $order )
    			);

    			if ( null === $normalized ) {
    				return null;
    			}

    			$normalized['name'] = self::normalize_name(
    				$instance['name'] ?? '',
    				$type
    			);

    			return $normalized;
    		}

    		$id = isset( $instance['id'] )
    			? sanitize_key(
    				(string) $instance['id']
    			)
    			: '';

    		if ( empty( $id ) ) {
    			$id = self::generate_id( $type );
    		}

    		$settings = isset( $instance['settings'] )
    			&& is_array( $instance['settings'] )
    				? $instance['settings']
    				: array();

    		return array(
    			'id'       => $id,
    			'type'     => $type,
    			'name'     => self::normalize_name(
    				$instance['name'] ?? '',
    				$type
    			),
    			'enabled'  => ! empty( $instance['enabled'] ),
    			'order'    => max( 1, $order ),
    			'settings' => wp_parse_args(
    				$settings,
    				self::defaults( $type )
    			),
    		);
    	}
    		/**
        	 * Builds one complete REST API block.
        	 *
        	 * @param array<string, mixed> $instance Saved block instance.
        	 *
        	 * @return array<string, mixed>|null
        	 */
        	public static function build_api_block(
        		array $instance
        	): ?array {

        		$type = isset( $instance['type'] )
        			? sanitize_key(
        				(string) $instance['type']
        			)
        			: '';

        		if ( empty( $type ) ) {
        			return null;
        		}

        		$block = self::get_block( $type );

        		if ( ! $block instanceof Kidia_Mobile_Block ) {
        			return null;
        		}

        		return $block->build_api_block(
        			$instance
        		);
        	}

        	/**
        	 * Returns definitions used in Add Element.
        	 *
        	 * @return array<string,array<string,mixed>>
        	 */
        	public static function picker_definitions(): array {

        		$definitions = array();

        		foreach ( self::all() as $type => $definition ) {

        			$definitions[ $type ] = array(
        				'type'        => $type,
        				'label'       => (string) (
        					$definition['label']
        					?? $type
        				),
        				'description' => (string) (
        					$definition['description']
        					?? ''
        				),
        				'icon'        => (string) (
        					$definition['icon']
        					?? 'dashicons-screenoptions'
        				),
        				'duplicable'  => true,
        				'available'   => self::exists(
        					$type
        				),
        			);

        		}

        		return $definitions;
        	}

        	/**
        	 * Generates a block ID.
        	 *
        	 * @param string $type Block type.
        	 *
        	 * @return string
        	 */
        	public static function generate_id(
        		string $type
        	): string {

        		$type = sanitize_key( $type );

        		if ( empty( $type ) ) {
        			$type = 'block';
        		}

        		$uuid = function_exists(
        			'wp_generate_uuid4'
        		)
        			? wp_generate_uuid4()
        			: uniqid(
        				'',
        				true
        			);

        		return sanitize_key(
        			$type .
        			'_' .
        			str_replace(
        				array(
        					'-',
        					'.',
        				),
        				'',
        				$uuid
        			)
        		);
        	}

        	/**
        	 * Loads schema.
        	 *
        	 * @param string $type Block type.
        	 *
        	 * @return array<string,mixed>
        	 */
        	private static function load_schema(
        		string $type
        	): array {

        		if (
        			! isset(
        				self::SCHEMA_FILES[ $type ]
        			)
        		) {
        			return array();
        		}

        		$file =
        			KIDIA_MOBILE_CMS_PATH .
        			'includes/schema/' .
        			self::SCHEMA_FILES[ $type ] .
        			'.php';

        		if ( ! file_exists( $file ) ) {
        			return array();
        		}

			$schema = require $file;

			if ( ! is_array( $schema ) ) {
				return array();
			}

			$schema['defaults'] = array_merge(
				array(
					'margin_top'        => 0,
					'margin_bottom'     => 0,
					'margin_horizontal' => 0,
					'padding_vertical'   => 0,
					'padding_horizontal' => 0,
					'block_background'  => '',
					'block_radius'      => 0,
					'content_scale'     => 100,
				),
				is_array( $schema['defaults'] ?? null )
					? $schema['defaults']
					: array()
			);

			$schema['tabs']   = is_array( $schema['tabs'] ?? null ) ? $schema['tabs'] : array();
			$schema['tabs'][] = array(
				'id'    => 'responsive',
				'label' => __( 'Responsive layout', 'kidia-mobile-cms' ),
			);
			$schema['fields'] = array_merge(
				is_array( $schema['fields'] ?? null ) ? $schema['fields'] : array(),
				self::responsive_fields()
			);

			return $schema;
		}

		/**
		 * Shared responsive controls appended to every Home Builder block.
		 *
		 * @return array<int, array<string, mixed>>
		 */
		private static function responsive_fields(): array {
			$number = static function ( string $key, string $label, int $max, int $default = 0 ): array {
				return array(
					'key'     => $key,
					'label'   => $label,
					'type'    => 'number',
					'tab'     => 'responsive',
					'min'     => 0,
					'max'     => $max,
					'step'    => 1,
					'default' => $default,
				);
			};

			return array(
				$number( 'margin_top', __( 'Space above', 'kidia-mobile-cms' ), 80 ),
				$number( 'margin_bottom', __( 'Space below', 'kidia-mobile-cms' ), 80 ),
				$number( 'margin_horizontal', __( 'Outer side space', 'kidia-mobile-cms' ), 40 ),
				$number( 'padding_vertical', __( 'Inner vertical space', 'kidia-mobile-cms' ), 40 ),
				$number( 'padding_horizontal', __( 'Inner side space', 'kidia-mobile-cms' ), 40 ),
				array(
					'key'     => 'block_background',
					'label'   => __( 'Block background', 'kidia-mobile-cms' ),
					'type'    => 'color',
					'tab'     => 'responsive',
					'default' => '',
				),
				$number( 'block_radius', __( 'Block corner radius', 'kidia-mobile-cms' ), 50 ),
				array(
					'key'     => 'content_scale',
					'label'   => __( 'Responsive content scale (%)', 'kidia-mobile-cms' ),
					'type'    => 'number',
					'tab'     => 'responsive',
					'min'     => 80,
					'max'     => 120,
					'step'    => 1,
					'default' => 100,
				),
			);
		}

        	/**
        	 * Returns default display name.
        	 *
        	 * @param string $type Block type.
        	 *
        	 * @return string
        	 */
        	private static function get_default_name(
        		string $type
        	): string {

        		$definition = self::get(
        			$type
        		);

        		if (
        			null === $definition
        			|| empty(
        				$definition['label']
        			)
        		) {
        			return ucfirst(
        				str_replace(
        					'_',
        					' ',
        					$type
        				)
        			);
        		}

        		return (string)
        			$definition['label'];
        	}

        	/**
        	 * Normalizes block name.
        	 *
        	 * @param mixed  $name Name.
        	 * @param string $type Type.
        	 *
        	 * @return string
        	 */
        	private static function normalize_name(
        		$name,
        		string $type
        	): string {

        		$name = sanitize_text_field(
        			(string) $name
        		);

        		if ( '' !== $name ) {
        			return $name;
        		}

        		return self::get_default_name(
        			$type
        		);
        	}
        }
