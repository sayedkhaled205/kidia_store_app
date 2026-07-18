<?php defined( 'ABSPATH' ) || exit;
final class Kidia_Mobile_CMS_Splash_Screen_Endpoint {
	public function register(): void { add_action( 'rest_api_init', array( $this, 'register_routes' ) ); }
	public function register_routes(): void { register_rest_route( 'woo-mobile/v1', '/splash-screen', array( 'methods' => WP_REST_Server::READABLE, 'callback' => array( $this, 'get_settings' ), 'permission_callback' => '__return_true' ) ); }
	public function get_settings() { $defaults=array('enabled'=>true,'image_url'=>'','background_color'=>'#2F806E','background_color_end'=>'#236B59','duration_ms'=>2000,'image_width'=>140,'image_height'=>140,'image_fit'=>'contain','image_shape'=>'none','show_store_name'=>true,'store_name'=>get_bloginfo('name'),'text_color'=>'#FFFFFF','show_loader'=>true,'loader_color'=>'#FFFFFF'); $saved=get_option('kidia_mobile_splash_screen',array()); $response=rest_ensure_response(array_merge($defaults,is_array($saved)?$saved:array())); $response->header('Cache-Control','no-store, no-cache, must-revalidate, max-age=0'); return $response; }
}
