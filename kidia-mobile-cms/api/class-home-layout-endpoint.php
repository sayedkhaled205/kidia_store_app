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
			'kidia/v1',
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
							'kidia-mobile-cms'
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
			'woo-mobile/v1',
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
			'woo-mobile/v1',
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
						'Woo Mobile CMS skipped invalid Home element %s (%s): %s',
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
