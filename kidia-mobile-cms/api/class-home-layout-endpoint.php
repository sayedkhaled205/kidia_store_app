<?php
/**
 * Server-driven Home Layout REST endpoint.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if (
	class_exists(
		'Kidia_Mobile_CMS_Home_Layout_Endpoint_V4',
		false
	)
) {
	return;
}

final class Kidia_Mobile_CMS_Home_Layout_Endpoint_V4 {

	/**
	 * Layout store.
	 *
	 * @var Kidia_Mobile_Layout_Store
	 */
	private Kidia_Mobile_Layout_Store $layout_store;

	/**
	 * Creates the endpoint.
	 */
	public function __construct() {
		$this->layout_store =
			new Kidia_Mobile_Layout_Store();
	}

	/**
	 * Registers REST API hooks.
	 *
	 * @return void
	 */
	public function register(): void {
		add_action(
			'rest_api_init',
			array(
				$this,
				'register_routes',
			)
		);
	}

	/**
	 * Registers REST API routes.
	 *
	 * @return void
	 */
	public function register_routes(): void {
		$default_locale = sanitize_key( (string) get_locale() );

		if ( '' === $default_locale ) {
			$default_locale = 'en';
		}

		register_rest_route(
			'woo-mobile/v1',
			'/home-layout',
			array(
				'methods'             =>
					WP_REST_Server::READABLE,

				'callback'            => array(
					$this,
					'get_home_layout',
				),

				'permission_callback' =>
					'__return_true',

				'args'                => array(
					'locale' => array(
						'description'       => __(
							'Application locale.',
							'mobishop'
						),

						'type'              => 'string',

							'default'           => $default_locale,

						'sanitize_callback' =>
							'sanitize_key',

						'validate_callback' => array(
							$this,
							'validate_locale',
						),
					),
				),
			)
		);

		register_rest_route(
			'woomobileapp/v1',
			'/home-layout',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array(
					$this,
					'get_home_layout',
				),
				'permission_callback' => '__return_true',
				'args'                => array(
					'locale' => array(
						'type'              => 'string',
							'default'           => $default_locale,
						'sanitize_callback' => 'sanitize_key',
						'validate_callback' => array(
							$this,
							'validate_locale',
						),
					),
				),
			)
		);

		register_rest_route(
			'woomobileapp/v1',
			'/home-layout/preview',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'preview_home_layout' ),
				'permission_callback' => static function (): bool {
					return current_user_can( 'manage_woocommerce' ) || current_user_can( 'manage_options' );
				},
			)
		);
	}

	/** Builds the real runtime payload from unsaved Builder values without persisting them. */
	public function preview_home_layout( WP_REST_Request $request ): WP_REST_Response {
		$submitted = $request->get_param( 'blocks' );
		$submitted = is_array( $submitted ) ? $submitted : array();
		$demo_catalog = $request->get_param( 'demo_catalog' );
		$demo_catalog = is_array( $demo_catalog ) ? $demo_catalog : array();
		$demo_products = $this->sanitize_demo_products( $demo_catalog['products'] ?? array() );
		$demo_categories = $this->sanitize_demo_categories( $demo_catalog['categories'] ?? array() );
		$blocks    = array();

		foreach ( array_values( $submitted ) as $order => $instance ) {
			if ( ! is_array( $instance ) || empty( $instance['enabled'] ) ) {
				continue;
			}
			$normalized = Kidia_Mobile_Block_Registry::normalize( $instance, $order + 1 );
			if ( null === $normalized ) {
				continue;
			}
			$normalized['status'] = 'published';
			try {
				$api_block = Kidia_Mobile_Block_Registry::build_api_block( $normalized );
			} catch ( Throwable $error ) {
				$api_block = null;
			}
			if ( is_array( $api_block ) ) {
				if ( in_array( (string) ( $api_block['type'] ?? '' ), array( 'product_grid', 'product_carousel' ), true ) && ! empty( $demo_products ) ) {
					$api_block['data']['items'] = $demo_products;
				}
				if ( 'category_grid' === (string) ( $api_block['type'] ?? '' ) && ! empty( $demo_categories ) ) {
					$api_block['data']['items'] = array_map(
						static fn ( array $category ): array => array(
							'id'        => $category['id'],
							'name'      => $category['name'],
							'image_url' => $category['image_url'],
							'action'    => array( 'type' => 'category', 'value' => (string) $category['id'] ),
						),
						$demo_categories
					);
				}
				$blocks[] = $api_block;
			}
		}

		$response = new WP_REST_Response(
			array(
				'version'    => 4,
				'page'       => 'home',
				'locale'     => sanitize_key( (string) get_locale() ) ?: 'en',
				'updated_at' => current_time( 'c', true ),
				'blocks'     => array_values( $blocks ),
			),
			200
		);
		$response->header( 'Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0' );
		return $response;
	}

	/** @param mixed $items @return array<int,array<string,mixed>> */
	private function sanitize_demo_products( $items ): array {
		if ( ! is_array( $items ) ) {
			return array();
		}
		$products = array();
		foreach ( array_slice( array_values( $items ), 0, 12 ) as $item ) {
			if ( ! is_array( $item ) ) {
				continue;
			}
			$id        = absint( $item['id'] ?? 0 );
			$name      = sanitize_text_field( (string) ( $item['name'] ?? '' ) );
			$image_url = esc_url_raw( (string) ( $item['image_url'] ?? '' ) );
			$price     = is_numeric( $item['price'] ?? null ) ? number_format( (float) $item['price'], 2, '.', '' ) : '';
			if ( 0 === $id || '' === $name || '' === $image_url || '' === $price ) {
				continue;
			}
			$image_urls = array_values( array_filter( array_map( 'esc_url_raw', is_array( $item['image_urls'] ?? null ) ? $item['image_urls'] : array( $image_url ) ) ) );
			$products[] = array(
				'id'              => $id,
				'name'            => $name,
				'image_url'       => $image_url,
				'image_urls'      => $image_urls,
				'price'           => $price,
				'regular_price'   => is_numeric( $item['regular_price'] ?? null ) ? number_format( (float) $item['regular_price'], 2, '.', '' ) : null,
				'currency_code'   => sanitize_text_field( (string) ( $item['currency_code'] ?? 'USD' ) ),
				'currency_symbol' => sanitize_text_field( (string) ( $item['currency_symbol'] ?? '$' ) ),
				'in_stock'        => ! empty( $item['in_stock'] ),
				'badge'           => empty( $item['badge'] ) ? null : sanitize_text_field( (string) $item['badge'] ),
				'rating'          => max( 0, min( 5, (float) ( $item['rating'] ?? 0 ) ) ),
				'review_count'    => absint( $item['review_count'] ?? 0 ),
				'discount_percent'=> empty( $item['regular_price'] ) ? 0 : max( 0, min( 99, (int) round( ( ( (float) $item['regular_price'] - (float) $price ) / max( 0.01, (float) $item['regular_price'] ) ) * 100 ) ) ),
				'action'          => array( 'type' => 'product', 'value' => (string) $id ),
			);
		}
		return $products;
	}

	/** @param mixed $items @return array<int,array<string,mixed>> */
	private function sanitize_demo_categories( $items ): array {
		if ( ! is_array( $items ) ) {
			return array();
		}
		$categories = array();
		foreach ( array_slice( array_values( $items ), 0, 12 ) as $item ) {
			if ( ! is_array( $item ) ) {
				continue;
			}
			$id        = absint( $item['id'] ?? 0 );
			$name      = sanitize_text_field( (string) ( $item['name'] ?? '' ) );
			$image_url = esc_url_raw( (string) ( $item['image_url'] ?? '' ) );
			if ( 0 < $id && '' !== $name && '' !== $image_url ) {
				$categories[] = array( 'id' => $id, 'name' => $name, 'image_url' => $image_url );
			}
		}
		return $categories;
	}

	/**
	 * Validates the requested locale.
	 *
	 * @param mixed           $value   Locale value.
	 * @param WP_REST_Request $request REST request.
	 * @param string          $param   Parameter name.
	 *
	 * @return bool
	 */
	public function validate_locale(
		$value,
		WP_REST_Request $request,
		string $param
	): bool {
		unset( $request, $param );

		$locale = sanitize_key(
			(string) $value
		);

		return '' !== $locale
			&& 20 >= strlen( $locale );
	}

	/**
	 * Returns the complete Home Layout.
	 *
	 * @param WP_REST_Request $request REST request.
	 *
	 * @return WP_REST_Response
	 */
	public function get_home_layout(
		WP_REST_Request $request
	): WP_REST_Response {
		$locale = sanitize_key(
			(string) $request->get_param(
				'locale'
			)
		);

		if ( '' === $locale ) {
			$locale = sanitize_key( (string) get_locale() );
		}

		if ( '' === $locale ) {
			$locale = 'en';
		}

		$layout = $this->layout_store->get_runtime_layout();

		$blocks = array();

		foreach ( $layout as $instance ) {
			if (
				! is_array( $instance )
				|| empty( $instance['enabled'] )
				|| 'published' !== ( $instance['status'] ?? 'published' )
			) {
				continue;
			}

			try {
				$api_block = Kidia_Mobile_Block_Registry::build_api_block(
					$instance
				);
			} catch ( Throwable $error ) {
				error_log(
					sprintf(
						'Woomobi CMS skipped invalid Home element %s (%s): %s',
						(string) ( $instance['type'] ?? 'unknown' ),
						(string) ( $instance['id'] ?? 'unknown' ),
						$error->getMessage()
					)
				);
				continue;
			}

			if ( null === $api_block ) {
				$api_block =
					$this->build_generic_api_block(
						$instance
					);
			}

			if ( null === $api_block ) {
				continue;
			}

			$blocks[] = $api_block;
		}

		$response = new WP_REST_Response(
			array(
				'version'    => 4,

				'page'       => 'home',

				'locale'     => $locale,

				'updated_at' => current_time(
					'c',
					true
				),

				'blocks'     => array_values(
					$blocks
				),
			),
			200
		);

		$response->header(
			'Cache-Control',
			'no-store, no-cache, must-revalidate, max-age=0'
		);
		$response->header( 'Pragma', 'no-cache' );

		return $response;
	}

	/**
	 * Builds a generic API block for schema-based elements.
	 *
	 * This fallback allows a schema-only element to appear in the API when it
	 * does not have a custom block builder. A registered builder returning
	 * null has deliberately rejected or omitted its payload and must never be
	 * replaced with unspecialized raw settings.
	 *
	 * @param array<string, mixed> $instance Block instance.
	 *
	 * @return array<string, mixed>|null
	 */
	private function build_generic_api_block(
		array $instance
	): ?array {
		$type = isset( $instance['type'] )
			? sanitize_key(
				(string) $instance['type']
			)
			: '';

		if (
			'' === $type
			|| Kidia_Mobile_Block_Registry::is_registered(
				$type
			)
			|| ! Kidia_Mobile_Block_Registry::exists(
				$type
			)
		) {
			return null;
		}

		$id = isset( $instance['id'] )
			? sanitize_key(
				(string) $instance['id']
			)
			: '';

		if ( '' === $id ) {
			$id =
				Kidia_Mobile_Block_Registry::generate_id(
					$type
				);
		}

		$name = isset( $instance['name'] )
			? sanitize_text_field(
				(string) $instance['name']
			)
			: '';

		$settings = isset( $instance['settings'] )
			&& is_array( $instance['settings'] )
				? $instance['settings']
				: array();

		$settings = wp_parse_args(
			$settings,
			Kidia_Mobile_Block_Registry::defaults(
				$type
			)
		);

		return array(
			'id'      => $id,

			'type'    => $type,

			'name'    => $name,

			'enabled' => true,

			'data'    => $this->sanitize_api_data(
				$settings
			),
		);
	}

	/**
	 * Sanitizes nested API data.
	 *
	 * @param array<string|int, mixed> $data Raw data.
	 *
	 * @return array<string|int, mixed>
	 */
	private function sanitize_api_data(
		array $data
	): array {
		$sanitized = array();

		foreach ( $data as $key => $value ) {
			$clean_key = is_string( $key )
				? sanitize_key( $key )
				: absint( $key );

			if ( is_array( $value ) ) {
				$sanitized[ $clean_key ] =
					$this->sanitize_api_data(
						$value
					);

				continue;
			}

			if (
				is_bool( $value )
				|| is_int( $value )
				|| is_float( $value )
				|| null === $value
			) {
				$sanitized[ $clean_key ] = $value;

				continue;
			}

			$string_value = (string) $value;

			if (
				is_string( $clean_key )
				&& false !== strpos(
					$clean_key,
					'url'
				)
			) {
				$sanitized[ $clean_key ] =
					esc_url_raw(
						$string_value
					);

				continue;
			}

			$sanitized[ $clean_key ] =
				wp_strip_all_tags(
					$string_value
				);
		}

		return $sanitized;
	}
}
