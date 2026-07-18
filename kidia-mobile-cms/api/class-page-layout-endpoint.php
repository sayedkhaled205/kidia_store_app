<?php
/** Public REST endpoint for catalog, product, wishlist and account layouts. */
defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_CMS_Page_Layout_Endpoint {
	public function register(): void {
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
	}

	public function register_routes(): void {
		register_rest_route(
			'woo-mobile/v1',
			'/page-layout/(?P<page>[a-z-]+)',
			array(
				'methods' => WP_REST_Server::READABLE,
				'callback' => array( $this, 'get_layout' ),
				'permission_callback' => '__return_true',
				'args' => array(
					'page' => array( 'required' => true, 'sanitize_callback' => 'sanitize_key' ),
					'locale' => array( 'default' => '', 'sanitize_callback' => 'sanitize_key' ),
				),
			)
		);
	}

	public function get_layout( WP_REST_Request $request ) {
		$page = sanitize_key( (string) $request->get_param( 'page' ) );
		if ( ! Kidia_Mobile_Page_Layout_Store::is_page( $page ) ) {
			return new WP_Error( 'woo_mobile_unknown_page', __( 'Unknown application page.', 'kidia-mobile-cms' ), array( 'status' => 404 ) );
		}
		$layout = ( new Kidia_Mobile_Page_Layout_Store() )->get_layout( $page );
		$layout['locale'] = sanitize_key( (string) $request->get_param( 'locale' ) );
		$response = rest_ensure_response( $layout );
		$response->header( 'Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0' );
		$response->header( 'Pragma', 'no-cache' );
		return $response;
	}
}
