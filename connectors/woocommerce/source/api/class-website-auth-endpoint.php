<?php
/** Reuse the store's verified web login in a native authentication session. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Website_Auth_Endpoint {

	private const COOKIE = '__Host-mobishop_login';
	private const PREFIX = '_mobishop_web_login_';
	private const TTL = 600;
	private $issue;
	private $allowed;

	public function __construct( callable $issue, callable $allowed ) {
		$this->issue = $issue;
		$this->allowed = $allowed;
	}

	public function register(): void {
		add_action( 'rest_api_init', array( $this, 'routes' ) );
		add_action( 'init', array( $this, 'register_assets' ) );
		add_action( 'template_redirect', array( $this, 'browser' ), -100 );
		add_action( 'wp_login', function ( $login, $user ) { $this->verified( $user ); }, 99, 2 );
		add_action( 'nsl_login', function ( $id ) { $this->verified( get_user_by( 'id', $id ) ); }, 99 );
		add_action( 'mobishop_web_login_cleanup', function ( $id ) { delete_option( self::PREFIX . $id ); } );
	}

	public function register_assets(): void {
		wp_register_style( 'mobishop-website-auth-confirmation', MOBISHOP_URL . 'public/css/mobishop-website-auth-confirmation.css', array(), MOBISHOP_VERSION );
	}

	public function routes(): void {
		foreach ( array( 'config' => 'GET', 'start' => 'POST', 'exchange' => 'POST' ) as $method => $verb ) {
			register_rest_route( 'mobishop/v1', '/auth/website/' . $method, array(
				'methods' => $verb, 'callback' => array( $this, $method ), 'permission_callback' => '__return_true',
			) );
		}
	}

	private function login_url(): string {
		$id = (int) get_option( 'kidia_login_page_id', 0 );
		$verified_flow = $id > 0 && class_exists( 'Kidia_Firebase_OTP_265' );
		// Reuse installed website authentication, including its OTP/social/account picker.
		// Other WooCommerce stores need no Kidia-specific plugin or manual setup.
		$url = $verified_flow ? get_permalink( $id ) : '';
		if ( ! $url && function_exists( 'wc_get_page_permalink' )
			&& function_exists( 'wc_get_page_id' ) && wc_get_page_id( 'myaccount' ) > 0 ) {
			$url = wc_get_page_permalink( 'myaccount' );
		}
		$url = (string) apply_filters( 'mobishop_verified_website_login_url', $url );
		$home = wp_parse_url( home_url( '/' ) );
		$parts = wp_parse_url( $url );
		return is_array( $home ) && ( $home['scheme'] ?? '' ) === 'https'
			&& is_array( $parts ) && ( $parts['scheme'] ?? '' ) === 'https'
			&& strtolower( (string) ( $parts['host'] ?? '' ) ) === strtolower( (string) ( $home['host'] ?? '' ) )
			&& ( $parts['port'] ?? 443 ) === ( $home['port'] ?? 443 )
			&& empty( $parts['user'] ) && empty( $parts['pass'] )
			&& ! isset( $parts['fragment'] ) ? $url : '';
	}

	/** Reuse only an enabled provider's own same-store authorization URL. */
	public static function facebook_login_url( string $redirect ): string {
		if ( ! function_exists( 'shortcode_exists' ) || ! shortcode_exists( 'nextend_social_login' ) ) return '';
		$html = do_shortcode( sprintf( '[nextend_social_login provider="facebook" redirect="%s"]', esc_url_raw( $redirect ) ) );
		if ( ! preg_match( '/<a\b[^>]*\bhref=(["\'])(.*?)\1/i', $html, $matches ) ) return '';
		$url = html_entity_decode( $matches[2], ENT_QUOTES | ENT_HTML5, 'UTF-8' );
		if ( str_starts_with( $url, '/' ) && ! str_starts_with( $url, '//' ) ) $url = home_url( $url );
		$target = wp_parse_url( $url ); $home = wp_parse_url( home_url( '/' ) );
		if ( ! is_array( $target ) || ! is_array( $home )
			|| ( $target['scheme'] ?? '' ) !== 'https' || ( $home['scheme'] ?? '' ) !== 'https'
			|| strtolower( (string) ( $target['host'] ?? '' ) ) !== strtolower( (string) ( $home['host'] ?? '' ) )
			|| ( $target['port'] ?? 443 ) !== ( $home['port'] ?? 443 )
			|| isset( $target['user'] ) || isset( $target['pass'] ) || isset( $target['fragment'] ) ) return '';
		parse_str( (string) ( $target['query'] ?? '' ), $query );
		return ( $query['loginSocial'] ?? '' ) === 'facebook' ? $url : '';
	}

	public function config() {
		return $this->response( array( 'enabled' => $this->login_url() !== '', 'version' => 1, 'providers' => array( 'facebook' => $this->facebook_enabled() ) ) );
	}

	public function facebook_enabled(): bool {
		return $this->login_url() !== '' && self::facebook_login_url( $this->login_url() ) !== '';
	}

	private function destination( array $row ): string {
		// An existing browser account must be explicitly confirmed or switched.
		// Nextend hides sign-in buttons for signed-in users; never link providers here.
		if ( ( $row['provider'] ?? null ) !== 'facebook' || is_user_logged_in() ) return $this->login_url();
		$url = self::facebook_login_url( $this->login_url() );
		if ( $url === '' ) wp_die( 'Facebook sign-in is currently unavailable. Please return to the app.' );
		return $url;
	}

	public function start( WP_REST_Request $request ) {
		$provider = $request->get_param( 'provider' );
		if ( $provider !== null && ( $provider !== 'facebook' || self::facebook_login_url( $this->login_url() ) === '' ) ) return $this->error( 'provider_unavailable', 400 );
		$state = (string) $request->get_param( 'state' );
		$challenge = (string) $request->get_param( 'challenge' );
		if ( ! $this->login_url() ) return $this->error( 'unavailable', 404 );
		if ( ! preg_match( '/^[a-f0-9]{64}\z/', $state ) || ! preg_match( '/^[a-f0-9]{64}\z/', $challenge ) ) return $this->error( 'invalid', 400 );
		$ip = filter_var( wp_unslash( $_SERVER['REMOTE_ADDR'] ?? '' ), FILTER_VALIDATE_IP );
		$rate = 'mobishop_web_rate_' . hash_hmac( 'sha256', $ip !== false ? $ip : '', wp_salt() );
		$count = (int) get_transient( $rate );
		if ( $count >= 30 ) return $this->error( 'rate_limited', 429 );
		set_transient( $rate, $count + 1, self::TTL );
		$id = bin2hex( random_bytes( 32 ) );
		$row = array( 'provider' => $provider, 'state' => $state, 'challenge' => $challenge, 'expires' => time() + self::TTL, 'binding' => '', 'user' => 0, 'code' => '' );
		if ( ! add_option( self::PREFIX . $id, $row, '', false ) ) return $this->error( 'unavailable', 503 );
		wp_schedule_single_event( time() + self::TTL + 60, 'mobishop_web_login_cleanup', array( $id ) );
		return $this->response( array( 'authorize_url' => add_query_arg( 'mobishop_login', $id, home_url( '/' ) ) ) );
	}

	private function read( string $id ): ?array {
		if ( ! preg_match( '/^[a-f0-9]{64}\z/', $id ) ) return null;
		$row = get_option( self::PREFIX . $id );
		return is_array( $row ) && (int) $row['expires'] > time() ? $row : null;
	}

	/** Compare-and-swap prevents binding theft and duplicate code redemption. */
	private function change( string $id, array $old, ?array $next ): bool {
		global $wpdb;
		if ( $next === null ) {
			$changed = 1 === $wpdb->query( $wpdb->prepare( "DELETE FROM {$wpdb->options} WHERE option_name=%s AND option_value=%s", self::PREFIX . $id, maybe_serialize( $old ) ) );
		} else {
			$changed = 1 === $wpdb->query( $wpdb->prepare( "UPDATE {$wpdb->options} SET option_value=%s WHERE option_name=%s AND option_value=%s", maybe_serialize( $next ), self::PREFIX . $id, maybe_serialize( $old ) ) );
		}
		wp_cache_delete( self::PREFIX . $id, 'options' );
		return $changed;
	}

	private function bound(): ?array {
		$cookie = filter_var( wp_unslash( $_COOKIE[ self::COOKIE ] ?? '' ), FILTER_VALIDATE_REGEXP, array( 'options' => array( 'regexp' => '/\A[a-f0-9]{64}\.[a-f0-9]{64}\z/' ) ) );
		if ( $cookie === false || ! preg_match( '/\A([a-f0-9]{64})\.([a-f0-9]{64})\z/', $cookie, $match ) ) return null;
		$row = $this->read( $match[1] );
		return $row && hash_equals( (string) $row['binding'], hash( 'sha256', $match[2] ) ) ? array( $match[1], $row ) : null;
	}

	private function cookie( string $value, int $expires ): void {
		setcookie( self::COOKIE, $value, array( 'expires' => $expires, 'path' => '/', 'secure' => true, 'httponly' => true, 'samesite' => 'Lax' ) );
	}

	public function verified( $user ): void {
		$bound = $this->bound();
		if ( ! $bound || ! $user instanceof WP_User || ! ( $this->allowed )( $user ) ) return;
		list( $id, $row ) = $bound;
		if ( $row['code'] !== '' ) return;
		$next = $row;
		$next['user'] = $user->ID;
		$next['generation'] = (string) get_user_meta( $user->ID, '_mobishop_auth_generation_v1', true );
		$this->change( $id, $row, $next );
	}

	private function customer_ready( WP_User $user ): bool {
		return (bool) apply_filters( 'mobishop_website_auth_customer_ready',
			! get_user_meta( $user->ID, 'kidia_phone_setup_required', true ), $user );
	}

	public function browser(): void {
		if ( isset( $_GET['mobishop_login'] ) ) {
			$id = filter_var( wp_unslash( $_GET['mobishop_login'] ), FILTER_VALIDATE_REGEXP, array( 'options' => array( 'regexp' => '/\A[a-f0-9]{64}\z/' ) ) );
			if ( $id === false ) wp_die( 'Invalid sign-in request.', '', array( 'response' => 400 ) );
			$row = $this->read( $id );
			if ( ! $row || $row['binding'] !== '' || ! $this->login_url() ) wp_die( 'انتهت محاولة الدخول. ارجع للتطبيق وحاول مرة أخرى.', '', array( 'response' => 400 ) );
			$secret = bin2hex( random_bytes( 32 ) );
			$next = $row;
			$next['binding'] = hash( 'sha256', $secret );
			if ( ! $this->change( $id, $row, $next ) ) wp_die( 'ابدأ محاولة جديدة من التطبيق.' );
			$this->cookie( $id . '.' . $secret, $row['expires'] );
			nocache_headers();
			$this->browser_headers();
			wp_safe_redirect( $this->destination( $row ) );
			exit;
		}
		$bound = $this->bound();
		if ( ! $bound || ! is_user_logged_in() ) return;
		list( $id, $row ) = $bound;
		$user = wp_get_current_user();
		nocache_headers();
		$this->browser_headers();
		if ( ! ( $this->allowed )( $user ) ) {
			if ( $this->handle_switch( $id ) ) {
				wp_safe_redirect( $this->destination( $row ) ); exit;
			}
			if ( $this->request_method() === 'POST'
				&& $this->request_choice() === 'switch' ) {
				wp_die( 'ارجع للتطبيق وابدأ محاولة دخول جديدة.' );
			}
			$this->confirmation( $id, $user, true ); exit;
		}
		// Let the website finish any required phone/profile setup first.
		if ( ! $this->customer_ready( $user ) ) return;
		// A pre-existing browser session needs an explicit confirmation. A fresh
		// verified phone/email/Google login already identifies the chosen account.
		if ( (int) $row['user'] !== $user->ID ) {
			if ( $this->handle_switch( $id ) ) {
				wp_safe_redirect( $this->destination( $row ) ); exit;
			}
			if ( $this->request_method() === 'POST'
				&& $this->request_choice() === 'switch' ) {
				wp_die( 'ارجع للتطبيق وابدأ محاولة دخول جديدة.' );
			}
			if ( $this->request_method() === 'POST'
				&& $this->request_choice() === 'continue'
				&& wp_verify_nonce( $this->request_nonce(), 'mobishop_continue_' . $id ) ) {
				$this->verified( $user );
				$row = $this->read( $id );
			} else {
				$this->confirmation( $id, $user, false ); exit;
			}
		}
		if ( ! $row || (int) $row['user'] !== $user->ID || $row['code'] !== '' ) wp_die( 'ارجع للتطبيق وابدأ محاولة دخول جديدة.' );
		$code = $id . '.' . bin2hex( random_bytes( 32 ) );
		$next = $row;
		$next['code'] = hash( 'sha256', $code );
		$next['expires'] = min( $row['expires'], time() + 120 );
		if ( ! $this->change( $id, $row, $next ) ) wp_die( 'ارجع للتطبيق وحاول مرة أخرى.' );
		$this->cookie( '', time() - 3600 );
		// Fixed native callback; no customer token or personal data in the URL.
		$host = strtolower( (string) wp_parse_url( home_url( '/' ), PHP_URL_HOST ) );
		$scheme = 'mobishop-login-' . substr( hash( 'sha256', $host ), 0, 16 );
		header( 'Location: ' . $scheme . '://auth/complete?code=' . rawurlencode( $code ) . '&state=' . rawurlencode( $row['state'] ), true, 302 );
		exit;
	}

	private function request_method(): string {
		$method = filter_var( wp_unslash( $_SERVER['REQUEST_METHOD'] ?? 'GET' ), FILTER_VALIDATE_REGEXP, array( 'options' => array( 'regexp' => '/\A(?:GET|POST)\z/' ) ) );
		return $method !== false ? $method : '';
	}

	private function request_choice(): string {
		$choice = filter_var( wp_unslash( $_POST['choice'] ?? '' ), FILTER_VALIDATE_REGEXP, array( 'options' => array( 'regexp' => '/\A(?:continue|switch)\z/' ) ) );
		return $choice !== false ? $choice : '';
	}

	private function request_nonce(): string {
		$nonce = filter_var( wp_unslash( $_POST['_wpnonce'] ?? '' ), FILTER_VALIDATE_REGEXP, array( 'options' => array( 'regexp' => '/\A[A-Za-z0-9_-]{1,128}\z/' ) ) );
		return $nonce !== false ? $nonce : '';
	}

	/** State-bound, nonce-validated request to drop the current browser identity and retry with another account. */
	private function handle_switch( string $id ): bool {
		if ( $this->request_method() !== 'POST' ) return false;
		if ( $this->request_choice() !== 'switch' ) return false;
		if ( ! wp_verify_nonce( $this->request_nonce(), 'mobishop_continue_' . $id ) ) return false;
		$bound = $this->bound();
		if ( ! $bound || $bound[0] !== $id ) return false;
		$row = $bound[1];
		if ( $row['code'] !== '' ) return false;
		$next = $row;
		$next['user'] = 0;
		// MySQL reports zero changed rows for an identical update. An admin has
		// no captured user, so record the switch to make the CAS meaningful too.
		$next['switches'] = (int) ( $row['switches'] ?? 0 ) + 1;
		// Only log the browser out once the captured proof is cleared, keeping the pending binding intact.
		if ( ! $this->change( $id, $row, $next ) ) return false;
		wp_logout();
		return true;
	}

	private function browser_headers(): void {
		header( 'Referrer-Policy: no-referrer' );
		header( 'X-Frame-Options: DENY' );
		header( "Content-Security-Policy: frame-ancestors 'none'" );
	}

	private function confirmation( string $id, WP_User $user, bool $privileged ): void {
		header( 'Content-Type: text/html; charset=utf-8' );
		echo '<!doctype html><html lang="ar" dir="rtl"><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>متابعة الدخول</title>';
		// This is a standalone security document, not a normal template. Print only
		// our own registered handle; wp_head() would also execute arbitrary
		// theme/plugin scripts and styles into this auth-sensitive page.
		wp_enqueue_style( 'mobishop-website-auth-confirmation' );
		wp_print_styles( array( 'mobishop-website-auth-confirmation' ) );
		echo '</head><body><main><h2>متابعة الدخول إلى التطبيق</h2><p>' . esc_html( $user->display_name ) . '</p>';
		if ( $privileged ) {
			echo '<p class="note">هذا حساب إدارة المتجر ولا يمكن استخدامه في التطبيق. اضغط لاستخدام حساب عميل آخر، وسيتم تسجيل خروجك من المتجر في هذا المتصفح فقط.</p><form method="post">';
			wp_nonce_field( 'mobishop_continue_' . $id );
			echo '<button name="choice" value="switch">استخدام حساب آخر</button></form></main></body></html>';
			return;
		}
		echo '<p class="note">اختيار "استخدام حساب آخر" سيسجل خروجك من المتجر في هذا المتصفح فقط.</p><form method="post">';
		wp_nonce_field( 'mobishop_continue_' . $id );
		echo '<button name="choice" value="continue">متابعة بهذا الحساب</button><button name="choice" value="switch">استخدام حساب آخر</button></form></main></body></html>';
	}

	public function exchange( WP_REST_Request $request ) {
		$code = (string) $request->get_param( 'code' );
		$state = (string) $request->get_param( 'state' );
		$verifier = (string) $request->get_param( 'verifier' );
		if ( ! preg_match( '/^([a-f0-9]{64})\.[a-f0-9]{64}\z/', $code, $match ) || ! preg_match( '/^[a-f0-9]{64}\z/', $verifier ) ) return $this->error( 'invalid', 400 );
		$row = $this->read( $match[1] );
		if ( ! $row || ! hash_equals( $row['code'], hash( 'sha256', $code ) ) || ! hash_equals( $row['state'], $state ) || ! hash_equals( $row['challenge'], hash( 'sha256', $verifier ) ) ) return $this->error( 'expired', 401 );
		$user = get_user_by( 'id', (int) $row['user'] );
		if ( ! $user instanceof WP_User || ! ( $this->allowed )( $user ) ) return $this->error( 'customer_required', 403 );
		wp_cache_delete( $user->ID, 'user_meta' );
		if ( (string) ( $row['generation'] ?? '' ) !== (string) get_user_meta( $user->ID, '_mobishop_auth_generation_v1', true ) ) return $this->error( 'expired', 401 );
		if ( ! $this->customer_ready( $user ) ) return $this->error( 'profile_required', 403 );
		if ( ! $this->change( $match[1], $row, null ) ) return $this->error( 'expired', 401 );
		return ( $this->issue )( $user );
	}

	private function response( array $data ) {
		$response = new WP_REST_Response( $data );
		$response->header( 'Cache-Control', 'no-store, private' );
		return $response;
	}

	private function error( string $code, int $status ) {
		return new WP_Error( 'mobishop_web_' . $code, 'تعذر إكمال الدخول. ارجع للتطبيق وحاول مرة أخرى.', array( 'status' => $status ) );
	}
}
