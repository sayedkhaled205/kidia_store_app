<?php
/**
 * Plugin Name: Kidia Login Page
 * Plugin URI:  https://kidiastore.com/
 * Description: Branded WooCommerce login and registration page for Kidia Store, ready for phone OTP integration.
 * Version:     0.6.15
 * Author:      Kidia Store
 * Text Domain: kidia-login-page
 * Requires Plugins: woocommerce
 */

defined( 'ABSPATH' ) || exit;

/* A new Google sign-in must show the account chooser. Nextend otherwise
 * reuses an anonymous OAuth token retained after a previous login/logout.
 * Leave OAuth callbacks and account-linking requests untouched. */
add_action( 'google_login_action_before', static function ( $provider ): void {
	if ( is_user_logged_in() || isset( $_GET['code'] ) || isset( $_GET['error'] ) || isset( $_GET['state'] ) ) {
		return;
	}
	if ( class_exists( '\NSL\Persistent\Persistent' ) ) {
		\NSL\Persistent\Persistent::delete( 'google_at' );
	}
} );

require_once plugin_dir_path( __FILE__ ) . 'includes/class-kidia-shipping-addresses.php';
Kidia_Shipping_Addresses::boot();

/*
 * Register runtime hooks before the class guard. Some persistent PHP workers
 * keep class definitions between requests while WordPress rebuilds its hooks.
 * Registering here guarantees the shortcode and page hooks exist every time.
 */
add_shortcode(
	'kidia_login_page',
	static function (): string {
		return Kidia_Store_Custom_Login_Page_V020::instance()->render_shortcode();
	}
);

add_action(
	'wp_enqueue_scripts',
	static function (): void {
		Kidia_Store_Custom_Login_Page_V020::instance()->enqueue_assets();
	}
);

add_action(
	'wp_footer',
	static function (): void {
		Kidia_Store_Custom_Login_Page_V020::instance()->render_header_login_redirect_script();
	},
	100
);

add_action(
	'init',
	static function (): void {
		Kidia_Store_Custom_Login_Page_V020::instance()->ensure_setup();
	},
	20
);

add_action(
	'woocommerce_checkout_order_processed',
	static function ( int $order_id ): void {
		Kidia_Store_Custom_Login_Page_V020::instance()->sync_order_email_to_customer( $order_id );
	},
	20
);

add_action(
	'woocommerce_store_api_checkout_order_processed',
	static function ( $order ): void {
		if ( is_object( $order ) && method_exists( $order, 'get_id' ) ) {
			Kidia_Store_Custom_Login_Page_V020::instance()->sync_order_email_to_customer( (int) $order->get_id() );
		}
	},
	20
);

add_filter( 'nsl_google_auto_link_allowed', '__return_true', 20 );
add_filter( 'nsl_facebook_auto_link_allowed', '__return_true', 20 );

add_filter(
	'woocommerce_get_myaccount_page_permalink',
	static function ( string $url ): string {
		if ( is_user_logged_in() ) {
			return $url;
		}

		return Kidia_Store_Custom_Login_Page_V020::instance()->get_login_url();
	},
	20
);

add_filter(
	'woocommerce_checkout_fields',
	static function ( array $fields ): array {
		/* Final safeguard if a theme or cached checkout template attempts to
		 * render account creation despite the login redirect. */
		unset( $fields['account']['account_password'] );
		return $fields;
	},
	100
);

/* Pending social accounts now require explicit sign-in; never auto-merge on cookie issue. */

add_action(
	'user_register',
	static function ( int $user_id ): void {
		Kidia_Store_Custom_Login_Page_V020::instance()->capture_verified_phone_on_registration( $user_id );
	},
	20
);

add_action(
	'user_register',
	static function ( int $user_id ): void {
		Kidia_Store_Custom_Login_Page_V020::instance()->require_phone_after_account_creation( $user_id );
	},
	30
);

add_action(
	'woocommerce_edit_account_form_start',
	static function (): void {
		Kidia_Store_Custom_Login_Page_V020::instance()->render_account_login_phone();
	}
);

add_action(
	'init',
	static function (): void {
		Kidia_Store_Custom_Login_Page_V020::instance()->prepare_phone_account_match();
	},
	1
);

add_action(
	'template_redirect',
	static function (): void {
		Kidia_Store_Custom_Login_Page_V020::instance()->handle_template_redirect();
	},
	1
);

add_filter(
	'template_include',
	static function ( string $template ): string {
		return Kidia_Store_Custom_Login_Page_V020::instance()->use_login_template( $template );
	},
	99
);

add_filter(
	'login_redirect',
	static function ( string $redirect_to, string $requested_redirect_to, $user ): string {
		return Kidia_Store_Custom_Login_Page_V020::instance()->filter_login_redirect( $redirect_to, $requested_redirect_to, $user );
	},
	20,
	3
);

add_action(
	'wp_ajax_nopriv_kidia_check_email',
	static function (): void {
		Kidia_Store_Custom_Login_Page_V020::instance()->ajax_check_email();
	}
);

add_action(
	'wp_ajax_nopriv_kidia_check_phone',
	static function (): void {
		Kidia_Store_Custom_Login_Page_V020::instance()->ajax_check_phone();
	}
);

add_action(
	'wp_ajax_nopriv_kidia_phone_send_permission',
	static function (): void {
		Kidia_Store_Custom_Login_Page_V020::instance()->ajax_phone_send_permission();
	}
);

add_action(
	'wp_ajax_kidia_phone_send_permission',
	static function (): void {
		Kidia_Store_Custom_Login_Page_V020::instance()->ajax_phone_send_permission();
	}
);

add_filter(
	'plugin_action_links_' . plugin_basename( __FILE__ ),
	static function ( array $links ): array {
		return Kidia_Store_Custom_Login_Page_V020::instance()->plugin_action_links( $links );
	}
);

register_activation_hook( __FILE__, array( 'Kidia_Store_Custom_Login_Page_V020', 'activate' ) );

if ( class_exists( 'Kidia_Store_Custom_Login_Page_V020', false ) ) {
	return;
}

final class Kidia_Store_Custom_Login_Page_V020 {

	private const VERSION        = '0.6.15';
	private const PHONE_SEND_WINDOW = HOUR_IN_SECONDS;
	private const PHONE_SEND_COOLDOWN = MINUTE_IN_SECONDS;
	private const PHONE_SEND_LIMIT = 3;
	private const OPTION_PAGE_ID = 'kidia_login_page_id';
	private const OPTION_SETUP_VERSION = 'kidia_login_setup_version';
	private const PAGE_META_KEY  = '_kidia_login_page';
	private const PHONE_TAG      = 'fme_lwp_display_login_form';
	private const LOGIN_PHONE_META = 'kidia_login_phone';

	private static ?self $instance = null;

	public static function instance(): self {
		if ( null === self::$instance ) {
			self::$instance = new self();
		}

		return self::$instance;
	}

	private function __construct() {}

	public static function activate(): void {
		self::configure_woocommerce_accounts();
		Kidia_Shipping_Addresses::register_endpoint();
		$page_id = self::find_login_page_id();

		if ( ! $page_id ) {
			$page_id = wp_insert_post(
				array(
					'post_title'   => 'تسجيل الدخول',
					'post_name'    => 'login-register',
					'post_content' => '[kidia_login_page]',
					'post_status'  => 'publish',
					'post_type'    => 'page',
					'comment_status' => 'closed',
				),
				true
			);

			if ( is_wp_error( $page_id ) ) {
				update_option( self::OPTION_SETUP_VERSION, self::VERSION, false );
				return;
			}

			update_post_meta( $page_id, self::PAGE_META_KEY, '1' );
		}

		update_option( self::OPTION_PAGE_ID, (int) $page_id, false );
		update_option( self::OPTION_SETUP_VERSION, self::VERSION, false );
		flush_rewrite_rules();
		/* A plugin upgrade changes the versioned login assets. Clear WordPress
		 * and WP Rocket caches so customers cannot keep receiving an older JS
		 * file with stale OTP messages or keyboard behaviour. */
		wp_cache_flush();
		if ( function_exists( 'rocket_clean_domain' ) ) {
			rocket_clean_domain();
		}
	}

	public function ensure_setup(): void {
		if ( self::VERSION === get_option( self::OPTION_SETUP_VERSION ) ) {
			return;
		}

		self::activate();
	}

	private static function configure_woocommerce_accounts(): void {
		$settings = array(
			// Every order must belong to an account.
			'woocommerce_enable_guest_checkout'                   => 'no',
			// Registration happens on Kidia's login page, never inside checkout.
			'woocommerce_enable_signup_and_login_from_checkout'  => 'no',
			// Keep WooCommerce's own My Account registration available too.
			'woocommerce_enable_myaccount_registration'           => 'yes',
			// Fail-safe: never expose an account-password field in checkout.
			'woocommerce_registration_generate_password'          => 'yes',
			// WooCommerce can safely derive the username from the email.
			'woocommerce_registration_generate_username'          => 'yes',
		);

		foreach ( $settings as $option => $value ) {
			update_option( $option, $value, false );
		}

		/* A successful OTP is the complete phone login flow. Existing customers
		 * are matched by prepare_phone_account_match(); unknown numbers are
		 * created by the phone extension immediately. Do not ask the customer to
		 * choose between linking and registration after verification. */
		delete_option( 'fma_lwp_enable_login_email_restriction' );
		update_option( 'fma_lwp_disable_checkout', 'on', false );
		/* Egypt only. The dial code stays internal and is hidden by Kidia's UI. */
		update_option( 'fma_lwp_country_code', 'EG(+20)', false );
		update_option( 'fma_lwp_form_heading', 'تسجيل الدخول برقم الهاتف', false );
		update_option( 'fma_lwp_verify_code_btn_txt', 'تأكيد الكود', false );
		update_option( 'fma_lwp_code_sent', 'تم إرسال كود التحقق إلى هاتفك.', false );
		update_option( 'fma_lwp_err_otp_countdown', 'الكود صالح لمدة', false );
		/* Firebase still performs invisible bot protection; only its floating
		 * badge is replaced with the required privacy/terms disclosure. */
		update_option( 'fma_lwp_hide_recap_chkbx', 'on', false );
		update_option( 'fma_lwp_front_modal_text', '', false );
	}

	/**
	 * Make an existing WooCommerce billing phone discoverable by the phone
	 * extension before it decides that a second customer must be created.
	 */
	public function prepare_phone_account_match(): void {
		if ( ! wp_doing_ajax() || 'POST' !== strtoupper( (string) ( $_SERVER['REQUEST_METHOD'] ?? '' ) ) ) {
			return;
		}

		$action = isset( $_POST['action'] ) ? sanitize_key( wp_unslash( $_POST['action'] ) ) : '';
		if ( 'fme_lwp_process_otp_validation' !== $action ) {
			return;
		}

		$phone = isset( $_POST['phone_number'] ) ? sanitize_text_field( wp_unslash( $_POST['phone_number'] ) ) : '';
		$forms = $this->phone_variants( $phone );
		if ( empty( $forms ) ) {
			return;
		}

		$users = $this->find_users_by_phone_meta( array( self::LOGIN_PHONE_META ), $forms );

		/* One-time migration for accounts created before Kidia had a separate
		 * immutable login-phone field. Never use shipping data again after the
		 * dedicated identity has been stored. */
		if ( empty( $users ) ) {
			$users = $this->find_users_by_phone_meta( array( 'fme_billing_phone', 'billing_phone' ), $forms );
		}

		/* Never guess when the same phone is already present on two accounts. */
		if ( 1 !== count( $users ) ) {
			return;
		}

		$canonical = $this->canonical_phone( $phone );
		if ( '' === $canonical ) {
			return;
		}

		$this->store_login_phone( absint( $users[0] ), $canonical );
	}

	private function find_users_by_phone_meta( array $keys, array $forms ): array {
		$meta_query = array( 'relation' => 'OR' );
		foreach ( $keys as $key ) {
			$meta_query[] = array(
				'key'     => sanitize_key( $key ),
				'value'   => $forms,
				'compare' => 'IN',
			);
		}

		return get_users(
			array(
				'fields'      => 'ids',
				'number'      => 2,
				'count_total' => false,
				'meta_query'  => $meta_query,
			)
		);
	}

	/** Return one unambiguous customer account for a local Egyptian phone. */
	private function find_customer_by_phone( string $phone ) {
		$forms = $this->phone_variants( $phone );
		if ( empty( $forms ) ) {
			return false;
		}

		$users = $this->find_users_by_phone_meta( array( self::LOGIN_PHONE_META ), $forms );
		if ( empty( $users ) ) {
			$users = $this->find_users_by_phone_meta( array( 'fme_billing_phone', 'billing_phone' ), $forms );
		}

		if ( 1 !== count( $users ) ) {
			return false;
		}

		$user = get_user_by( 'id', absint( $users[0] ) );
		if ( ! $user || user_can( $user, 'manage_options' ) ) {
			return false;
		}

		$this->store_login_phone( (int) $user->ID, $phone );
		return $user;
	}

	/** Resolve eligible identities without publishing account details or changing phone metadata. */
	private function phone_signin_candidates( string $phone ): array {
		if ( class_exists( 'Kidia_Firebase_OTP_265' ) ) {
			$canonical = $this->canonical_phone( $phone );
			return array_values( array_filter(
				Kidia_Firebase_OTP_265::matching_users( $canonical ),
				static fn( $user ): bool => Kidia_Firebase_OTP_265::eligible_customer( $user, $canonical )
			) );
		}
		$user = $this->find_customer_by_phone( $phone );
		return $user ? array( $user ) : array();
	}

	/**
	 * Verified sign-in identities plus unverified contact-only phones for
	 * password login. This never touches store_login_phone or any verified
	 * phone meta key, and never changes OTP matching (phone_signin_candidates).
	 */
	private function phone_password_candidates( string $phone ): array {
		$candidates = $this->phone_signin_candidates( $phone );

		$forms = $this->phone_variants( $phone );
		if ( empty( $forms ) ) {
			return $candidates;
		}

		$known_ids = array_map( static fn( $user ): int => (int) $user->ID, $candidates );
		$contact_ids = $this->find_users_by_phone_meta( array( 'kidia_unverified_phone' ), $forms );

		foreach ( $contact_ids as $contact_id ) {
			$contact_id = absint( $contact_id );
			if ( in_array( $contact_id, $known_ids, true ) ) {
				continue;
			}
			$user = get_user_by( 'id', $contact_id );
			if ( $user && ! user_can( $user, 'manage_options' ) && ! user_can( $user, 'edit_users' ) && ! user_can( $user, 'manage_woocommerce' ) ) {
				$has_identity = false;
				foreach ( array( self::LOGIN_PHONE_META, 'fme_billing_phone', 'billing_phone' ) as $key ) if ( get_user_meta( $contact_id, $key, true ) ) $has_identity = true;
				if ( $has_identity ) continue;
				$candidates[] = $user;
				$known_ids[]  = $contact_id;
			}
		}

		return $candidates;
	}

	private function phone_password_customer( string $phone, string $email ) {
		$users = $this->phone_password_candidates( $phone );
		if ( count( $users ) === 1 ) { return $users[0]; }
		if ( ! is_email( $email ) ) { return false; }
		foreach ( $users as $user ) {
			if ( strcasecmp( (string) $user->user_email, $email ) === 0 ) { return $user; }
		}
		return false;
	}

	private function store_login_phone( int $user_id, string $phone ): void {
		$canonical = $this->canonical_phone( $phone );
		if ( ! $user_id || '' === $canonical ) {
			return;
		}

		update_user_meta( $user_id, self::LOGIN_PHONE_META, $canonical );
		/* The vendor extension reads this key to locate the verified customer.
		 * It is identity data, not the editable WooCommerce shipping number. */
		update_user_meta( $user_id, 'fme_billing_phone', $canonical );

		/* Use the account phone as the first checkout default only. Subsequent
		 * customer edits to billing_phone remain shipping-only. */
		if ( '' === (string) get_user_meta( $user_id, 'billing_phone', true ) ) {
			update_user_meta( $user_id, 'billing_phone', $this->local_phone( $canonical ) );
		}
	}

	public function capture_verified_phone_on_registration( int $user_id ): void {
		$action = isset( $_POST['action'] ) ? sanitize_key( wp_unslash( $_POST['action'] ) ) : '';
		if ( 'fme_lwp_process_otp_validation' !== $action ) {
			return;
		}

		$phone = isset( $_POST['phone_number'] ) ? sanitize_text_field( wp_unslash( $_POST['phone_number'] ) ) : '';
		$this->store_login_phone( $user_id, $phone );
		update_user_meta( $user_id, 'kidia_phone_setup_required', 'otp' );

		/* The phone extension creates a first-time customer inside its OTP AJAX
		 * request. At that point WordPress has created the account but some
		 * versions of the extension do not persist the authentication cookie
		 * before reloading /login-register/. Establish the session here so the
		 * reload opens the account-completion stage instead of the first screen. */
		$user = get_user_by( 'id', $user_id );
		if ( $user && ! user_can( $user, 'manage_options' ) ) {
			wp_set_current_user( $user_id );
			wp_set_auth_cookie( $user_id, true, is_ssl() );
			do_action( 'wp_login', (string) $user->user_login, $user );
		}
	}

	/** Require phone/password completion for email and social registrations. */
	public function require_phone_after_account_creation( int $user_id ): void {
		$user = get_user_by( 'id', $user_id );
		if ( ! $user || user_can( $user, 'manage_options' ) ) {
			return;
		}

		$action = isset( $_POST['action'] ) ? sanitize_key( wp_unslash( $_POST['action'] ) ) : '';
		if ( 'fme_lwp_process_otp_validation' === $action ) {
			return;
		}

		if ( ! $this->find_customer_phone_for_user( $user_id ) ) {
			update_user_meta( $user_id, 'kidia_phone_setup_required', 'account' );
		}
	}

	private function find_customer_phone_for_user( int $user_id ): string {
		foreach ( array( self::LOGIN_PHONE_META, 'fme_billing_phone', 'billing_phone' ) as $key ) {
			$phone = $this->local_phone( (string) get_user_meta( $user_id, $key, true ) );
			if ( preg_match( '/^01[0125][0-9]{8}$/', $phone ) ) {
				return $phone;
			}
		}
		return '';
	}

	private function local_phone( string $phone ): string {
		$canonical = $this->canonical_phone( $phone );
		$digits    = ltrim( $canonical, '+' );
		if ( str_starts_with( $digits, '20' ) && 12 === strlen( $digits ) ) {
			return '0' . substr( $digits, 2 );
		}

		return $canonical;
	}

	public function render_account_login_phone(): void {
		$user_id = get_current_user_id();
		if ( ! $user_id ) {
			return;
		}

		$phone = (string) get_user_meta( $user_id, self::LOGIN_PHONE_META, true );
		if ( '' === $phone ) {
			$legacy = (string) get_user_meta( $user_id, 'fme_billing_phone', true );
			if ( '' === $legacy ) {
				$legacy = (string) get_user_meta( $user_id, 'billing_phone', true );
			}
			if ( '' !== $this->canonical_phone( $legacy ) ) {
				$this->store_login_phone( $user_id, $legacy );
				$phone = (string) get_user_meta( $user_id, self::LOGIN_PHONE_META, true );
			}
		}

		/* No verified login phone yet. An unverified contact number may still be
		 * on file; show it for reference only. Never promote it to the verified
		 * login-phone meta via store_login_phone(). */
		$unverified = '';
		if ( '' === $phone ) {
			$unverified = (string) get_user_meta( $user_id, 'kidia_unverified_phone', true );
		}
		?>
		<p class="woocommerce-form-row woocommerce-form-row--wide form-row form-row-wide kidia-account-login-phone">
			<label for="kidia_account_login_phone"><?php echo '' !== $unverified ? 'رقم الهاتف (غير مؤكد برسالة)' : 'رقم تليفون الحساب'; ?></label>
			<input type="tel" id="kidia_account_login_phone" value="<?php echo esc_attr( $this->local_phone( '' !== $unverified ? $unverified : $phone ) ); ?>" readonly aria-readonly="true">
			<?php if ( '' !== $unverified ) : ?>
				<span class="kidia-account-phone-help">هذا رقم للتواصل فقط ولم يتم تأكيده برسالة نصية. يمكنك الدخول بكلمة المرور أو جوجل؛ الدخول بالكود يحتاج توثيق الرقم.</span>
			<?php else : ?>
				<span class="kidia-account-phone-help">هذا هو رقم تسجيل الدخول الثابت. تغيير رقم الشحن في الطلبات لا يغيّره.</span>
			<?php endif; ?>
		</p>
		<?php
	}

	private function canonical_phone( string $phone ): string {
		$digits = preg_replace( '/\D+/', '', $phone );
		if ( ! is_string( $digits ) || strlen( $digits ) < 8 || strlen( $digits ) > 15 ) {
			return '';
		}

		if ( str_starts_with( $digits, '00' ) ) {
			$digits = substr( $digits, 2 );
		}

		/* The public store currently accepts Egyptian numbers. */
		if ( str_starts_with( $digits, '01' ) && 11 === strlen( $digits ) ) {
			$digits = '20' . substr( $digits, 1 );
		} elseif ( str_starts_with( $digits, '1' ) && 10 === strlen( $digits ) ) {
			$digits = '20' . $digits;
		}

		return '+' . $digits;
	}

	private function phone_variants( string $phone ): array {
		$canonical = $this->canonical_phone( $phone );
		if ( '' === $canonical ) {
			return array();
		}

		$digits   = ltrim( $canonical, '+' );
		$variants = array( $canonical, $digits );

		if ( str_starts_with( $digits, '20' ) && 12 === strlen( $digits ) ) {
			$national  = substr( $digits, 2 );
			$variants[] = $national;
			$variants[] = '0' . $national;
		}

		return array_values( array_unique( $variants ) );
	}

	/**
	 * Keep the verified phone customer's checkout email on the same WordPress
	 * account. Nextend can then auto-link Google/Facebook by that verified email.
	 * Never take an email that already belongs to another WordPress account.
	 */
	public function sync_order_email_to_customer( int $order_id ): void {
		if ( ! function_exists( 'wc_get_order' ) ) {
			return;
		}

		$order = wc_get_order( $order_id );
		if ( ! $order ) {
			return;
		}

		$user_id = absint( $order->get_customer_id() );
		$email   = sanitize_email( (string) $order->get_billing_email() );
		if ( ! $user_id || ! is_email( $email ) ) {
			return;
		}

		$owner_id = email_exists( $email );
		if ( $owner_id && absint( $owner_id ) !== $user_id ) {
			return;
		}

		$user = get_user_by( 'id', $user_id );
		if ( ! $user || user_can( $user, 'manage_options' ) ) {
			return;
		}

		update_user_meta( $user_id, 'billing_email', $email );
		if ( strtolower( (string) $user->user_email ) !== strtolower( $email ) ) {
			wp_update_user(
				array(
					'ID'         => $user_id,
					'user_email' => $email,
				)
			);
		}
	}

	/** Find one account by its WordPress email or WooCommerce billing email. */
	private function find_customer_by_email( string $email ) {
		$email = sanitize_email( $email );
		if ( ! is_email( $email ) ) {
			return false;
		}

		$user = get_user_by( 'email', $email );
		if ( $user ) {
			return $user;
		}

		$users = get_users(
			array(
				'number'     => 2,
				'count_total'=> false,
				'meta_key'   => 'billing_email',
				'meta_value' => $email,
			)
		);

		return 1 === count( $users ) ? $users[0] : false;
	}

	private static function find_login_page_id(): int {
		$stored_id = absint( get_option( self::OPTION_PAGE_ID ) );

		if ( $stored_id && 'page' === get_post_type( $stored_id ) && 'trash' !== get_post_status( $stored_id ) ) {
			return $stored_id;
		}

		$pages = get_posts(
			array(
				'post_type'      => 'page',
				'post_status'    => array( 'publish', 'draft', 'private' ),
				'posts_per_page' => 1,
				'fields'         => 'ids',
				'meta_key'       => self::PAGE_META_KEY,
				'meta_value'     => '1',
			)
		);

		if ( ! empty( $pages ) ) {
			return absint( $pages[0] );
		}

		$manual_page = get_page_by_path( 'login-register', OBJECT, 'page' );
		if ( $manual_page instanceof WP_Post && 'trash' !== $manual_page->post_status ) {
			update_post_meta( $manual_page->ID, self::PAGE_META_KEY, '1' );
			update_option( self::OPTION_PAGE_ID, (int) $manual_page->ID, false );
			return (int) $manual_page->ID;
		}

		return 0;
	}

	public function get_page_id(): int {
		return self::find_login_page_id();
	}

	public function is_login_page(): bool {
		$page_id = $this->get_page_id();

		if ( $page_id > 0 && is_page( $page_id ) ) {
			return true;
		}

		if ( ! is_page() ) {
			return false;
		}

		$content = (string) get_post_field( 'post_content', get_queried_object_id() );
		return has_shortcode( $content, 'kidia_login_page' );
	}

	public function get_login_url( string $redirect_to = '' ): string {
		$page_id = $this->get_page_id();
		$url     = $page_id ? get_permalink( $page_id ) : wp_login_url();

		if ( $redirect_to ) {
			$redirect_to = $this->validate_local_redirect( $redirect_to, '' );
			if ( $redirect_to ) {
				$url = add_query_arg( 'redirect_to', $redirect_to, $url );
			}
		}

		return $url;
	}

	/** Complete social sign-in without sending administrators back to the login editor preview. */
	public function get_authenticated_return_url(): string {
		if ( ! is_user_logged_in() || ( ! current_user_can( 'manage_options' )
			&& get_user_meta( get_current_user_id(), 'kidia_phone_setup_required', true ) ) ) {
			return $this->get_login_url();
		}
		$target = $this->get_redirect_target();
		$this->clear_redirect_cookie();
		return $target;
	}

	public function render_header_login_redirect_script(): void {
		if ( is_user_logged_in() || is_admin() ) {
			return;
		}

		?>
		<script id="kidia-header-login-redirect">
		(function () {
			'use strict';

			var loginUrl = <?php echo wp_json_encode( $this->get_login_url() ); ?>;
			var loginPath = new URL(loginUrl, location.origin).pathname;
			var selector = 'a.account-link.account-login, a[data-open="#login-form-popup"], .header-account-title, a[href]';
			document.addEventListener('click', function (event) {
				if (event.defaultPrevented || event.button > 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) { return; }
				var target = event.target.closest(selector);
				var link = target && target.closest('a');
				if (!link) { return; }
				var href;
				try { href = new URL(link.href, location.origin); } catch (error) { return; }
				if (href.origin !== location.origin || href.searchParams.get('action')) { return; }
				var accountLink = link.matches('.account-link.account-login, [data-open="#login-form-popup"]') || link.querySelector('.header-account-title');
				if (!accountLink && href.pathname !== loginPath && !/^\/my-account\/?$/.test(href.pathname)) { return; }
				if (location.pathname === loginPath || /\/wp-(admin|login)/.test(location.pathname)) { return; }
				event.preventDefault();
				event.stopImmediatePropagation();
				var destination = new URL(loginUrl, location.origin);
				destination.searchParams.set('redirect_to', location.href);
				window.location.assign(destination.href);
			}, true);
		}());
		</script>
		<?php
	}

	public function enqueue_assets(): void {
		if ( function_exists( 'is_account_page' ) && is_account_page() ) {
			wp_enqueue_style(
				'kidia-account-page',
				plugin_dir_url( __FILE__ ) . 'assets/css/account.css',
				array(),
				self::VERSION
			);
			wp_enqueue_script(
				'kidia-account-page',
				plugin_dir_url( __FILE__ ) . 'assets/js/account.js',
				array(),
				self::VERSION,
				true
			);
		}

		if ( ! $this->is_login_page() ) {
			return;
		}

		$base_url = plugin_dir_url( __FILE__ );

		wp_enqueue_style(
			'kidia-login-page',
			$base_url . 'assets/css/login.css',
			array(),
			self::VERSION
		);

		wp_enqueue_script(
			'kidia-login-page',
			$base_url . 'assets/js/login.js',
			array(),
			self::VERSION,
			true
		);

		wp_localize_script(
			'kidia-login-page',
			'KidiaLogin',
			array(
				'ajaxUrl'     => admin_url( 'admin-ajax.php' ),
				'nonce'       => wp_create_nonce( 'kidia_login_identifier' ),
				'homeUrl'     => home_url( '/' ),
				'loginUrl'    => $this->get_login_url(),
				'returnUrl'   => $this->get_redirect_target(),
				'phoneReady'  => shortcode_exists( self::PHONE_TAG ),
				'initialEmail'=> isset( $_GET['kidia_email'] ) ? sanitize_email( wp_unslash( $_GET['kidia_email'] ) ) : '',
				'strings'     => array(
					'invalidIdentifier' => 'اكتب بريدًا إلكترونيًا صحيحًا أو رقم هاتف صحيحًا.',
					'checking'          => 'جاري التحقق…',
					'networkError'      => 'تعذر الاتصال الآن. حاول مرة أخرى.',
					'phonePending'      => 'سيتم تفعيل إرسال الكود فور تثبيت إضافة تسجيل الهاتف.',
					'loginTitle'        => 'أدخل كلمة المرور',
					'registerTitle'     => 'أنشئ كلمة مرور جديدة',
					'loginButton'       => 'تسجيل الدخول',
					'registerButton'    => 'إنشاء الحساب',
				),
			)
		);
	}

	/**
	 * Authorise one Firebase send before the browser contacts Firebase.
	 *
	 * The vendor extension sends directly from JavaScript, so this small
	 * server-side gate is required to make the hourly limit survive refreshes,
	 * new tabs and cleared browser storage.
	 */
	public function ajax_phone_send_permission(): void {
		check_ajax_referer( 'kidia_login_identifier', 'nonce' );

		$raw_phone = isset( $_POST['phone'] )
			? sanitize_text_field( wp_unslash( $_POST['phone'] ) )
			: '';
		$local_phone = $this->local_phone( $raw_phone );
		$phone       = $this->canonical_phone( $raw_phone );

		if ( '' === $phone || ! preg_match( '/^01[0125][0-9]{8}$/', $local_phone ) ) {
			wp_send_json_error(
				array( 'message' => 'اكتب رقم هاتف مصريًا صحيحًا مكوّنًا من 11 رقمًا.' ),
				400
			);
		}

		$key       = 'kidia_otp_send_' . hash( 'sha256', $phone );
		$now       = time();
		$timestamps = get_transient( $key );
		$timestamps = is_array( $timestamps ) ? array_map( 'absint', $timestamps ) : array();
		$timestamps = array_values(
			array_filter(
				$timestamps,
				static fn( int $timestamp ): bool => $timestamp > ( $now - self::PHONE_SEND_WINDOW )
			)
		);

		$last_send = empty( $timestamps ) ? 0 : max( $timestamps );
		if ( $last_send && ( $now - $last_send ) < self::PHONE_SEND_COOLDOWN ) {
			$retry_after = self::PHONE_SEND_COOLDOWN - ( $now - $last_send );
			wp_send_json_error(
				array(
					'message'    => 'انتظر ' . $retry_after . ' ثانية قبل إعادة إرسال الكود.',
					'retryAfter' => $retry_after,
				),
				429
			);
		}

		if ( count( $timestamps ) >= self::PHONE_SEND_LIMIT ) {
			$retry_after = self::PHONE_SEND_WINDOW - ( $now - min( $timestamps ) );
			wp_send_json_error(
				array(
					'message'    => 'وصلت إلى 3 محاولات لطلب الكود خلال ساعة. انتظر انتهاء الساعة ثم حاول مرة أخرى.',
					'retryAfter' => max( 1, $retry_after ),
				),
				429
			);
		}

		$timestamps[] = $now;
		set_transient( $key, $timestamps, self::PHONE_SEND_WINDOW );

		wp_send_json_success(
			array(
				'allowed'   => true,
				'remaining' => max( 0, self::PHONE_SEND_LIMIT - count( $timestamps ) ),
			)
		);
	}

	public function use_login_template( string $template ): string {
		if ( ! $this->is_login_page() ) {
			return $template;
		}

		$plugin_template = plugin_dir_path( __FILE__ ) . 'templates/login-page.php';

		return is_readable( $plugin_template ) ? $plugin_template : $template;
	}

	public function handle_template_redirect(): void {
		if ( is_admin() || wp_doing_ajax() ) {
			return;
		}

		if ( $this->is_login_page() ) {
			$this->remember_redirect_target();

			// This is the public sign-in route, including when an administrator opens it.
			// Do not cache its forms or redirects across authentication changes.
			nocache_headers();
			$phone_setup_required = is_user_logged_in() && ! current_user_can( 'manage_options' )
				&& (bool) get_user_meta( get_current_user_id(), 'kidia_phone_setup_required', true );
			if ( is_user_logged_in() && ! $phone_setup_required ) {
				$target = $this->get_redirect_target();
				$this->clear_redirect_cookie();
				wp_safe_redirect( $target );
				exit;
			}

			if ( 'POST' === strtoupper( sanitize_text_field( wp_unslash( $_SERVER['REQUEST_METHOD'] ?? '' ) ) ) ) {
				$this->handle_authentication();
			}

			return;
		}

		if ( is_user_logged_in() || ! $this->should_redirect_current_page() ) {
			if ( is_user_logged_in() && ! current_user_can( 'manage_options' ) && get_user_meta( get_current_user_id(), 'kidia_phone_setup_required', true ) ) {
				wp_safe_redirect( add_query_arg( 'kidia_stage', 'phone-setup', get_permalink( $this->get_page_id() ) ) );
				exit;
			}
			return;
		}

		$current_url = $this->current_url();
		wp_safe_redirect( $this->get_login_url( $current_url ) );
		exit;
	}

	private function handle_authentication(): void {
		if ( ! empty( $_POST['kidia_phone_password_auth'] ) ) {
			$this->handle_phone_password_authentication();
			return;
		}

		if ( ! empty( $_POST['kidia_phone_setup'] ) ) {
			$this->handle_phone_account_setup();
			return;
		}

		$this->handle_email_authentication();
	}

	private function handle_phone_password_authentication(): void {
		$nonce = isset( $_POST['kidia_phone_password_nonce'] )
			? sanitize_text_field( wp_unslash( $_POST['kidia_phone_password_nonce'] ) )
			: '';
		$phone = isset( $_POST['kidia_phone'] ) ? sanitize_text_field( wp_unslash( $_POST['kidia_phone'] ) ) : '';
		$password = isset( $_POST['kidia_phone_password'] ) ? (string) wp_unslash( $_POST['kidia_phone_password'] ) : '';

		if ( ! wp_verify_nonce( $nonce, 'kidia_phone_password_auth' ) || ! preg_match( '/^01[0125][0-9]{8}$/', $this->local_phone( $phone ) ) ) {
			$this->redirect_back_to_phone( $phone, 'invalid_phone' );
		}

		$email = isset( $_POST['kidia_phone_account_email'] ) ? sanitize_email( wp_unslash( $_POST['kidia_phone_account_email'] ) ) : '';
		$user = $this->phone_password_customer( $phone, $email );
		if ( ! $user || '' === $password ) {
			$this->redirect_back_to_phone( $phone, 'invalid_password' );
		}

		$signed_in = wp_signon(
			array(
				'user_login'    => (string) $user->user_login,
				'user_password' => $password,
				'remember'      => true,
			),
			is_ssl()
		);

		if ( is_wp_error( $signed_in ) ) {
			$this->redirect_back_to_phone( $phone, 'invalid_password' );
		}

		wp_set_current_user( (int) $signed_in->ID );
		wp_safe_redirect( $this->get_authenticated_return_url() );
		exit;
	}

	private function redirect_back_to_phone( string $phone, string $error = '' ): void {
		$args = array(
			'kidia_stage' => 'phone',
			'kidia_phone' => $this->local_phone( $phone ),
			'kidia_phone_multiple' => count( $this->phone_signin_candidates( $phone ) ) > 1 ? '1' : '0',
		);
		if ( $error ) {
			$args['kidia_phone_error'] = sanitize_key( $error );
		}
		wp_safe_redirect( add_query_arg( $args, get_permalink( $this->get_page_id() ) ) );
		exit;
	}

	private function handle_phone_account_setup(): void {
		$id = get_current_user_id();
		if ( ! is_user_logged_in() || ! get_user_meta( $id, 'kidia_phone_setup_required', true ) ) return;
		$nonce = is_string( $_POST['kidia_phone_setup_nonce'] ?? null ) ? wp_unslash( $_POST['kidia_phone_setup_nonce'] ) : '';
		$name = is_string( $_POST['kidia_phone_username'] ?? null ) ? trim( sanitize_text_field( wp_unslash( $_POST['kidia_phone_username'] ) ) ) : '';
		$password = is_string( $_POST['kidia_phone_new_password'] ?? null ) ? wp_unslash( $_POST['kidia_phone_new_password'] ) : '';
		$confirm = is_string( $_POST['kidia_phone_new_password_confirm'] ?? null ) ? wp_unslash( $_POST['kidia_phone_new_password_confirm'] ) : '';
		// Non-OTP completion goes through the shared connector with phone proof or contact confirmation.
		if ( get_user_meta( $id, 'kidia_phone_setup_required', true ) !== 'otp' || ! wp_verify_nonce( $nonce, 'kidia_phone_setup' )
			|| $name === '' || strlen( $name ) > 120 || strlen( $password ) < 8 || strlen( $password ) > 4096 || ! hash_equals( $password, $confirm ) ) {
			wp_safe_redirect( add_query_arg( array( 'kidia_stage' => 'phone-setup', 'kidia_setup_error' => '1' ), get_permalink( $this->get_page_id() ) ) );
			exit;
		}
		$updated = wp_update_user( array( 'ID' => $id, 'display_name' => $name, 'first_name' => $name, 'user_pass' => $password ) );
		if ( is_wp_error( $updated ) ) {
			$this->add_error( 'تعذر حفظ الحساب. حاول مرة أخرى.' );
			return;
		}
		delete_user_meta( $id, 'kidia_phone_setup_required' );
		delete_user_meta( $id, 'kidia_profile_details_collected' );
		wp_set_current_user( $id );
		wp_set_auth_cookie( $id, true, is_ssl() );
		$target = $this->get_redirect_target();
		$this->clear_redirect_cookie();
		wp_safe_redirect( $target );
		exit;
	}

	/** Store a short-lived, browser-bound merge request until phone OTP succeeds. */
	private function start_pending_phone_merge( int $source_user_id, string $phone ): void {
		if ( ! get_user_meta( $source_user_id, 'kidia_phone_setup_required', true ) ) {
			return;
		}

		$token = wp_generate_password( 32, false, false );
		set_transient(
			'kidia_phone_merge_' . hash( 'sha256', $token ),
			array( 'source' => $source_user_id, 'phone' => $this->canonical_phone( $phone ) ),
			15 * MINUTE_IN_SECONDS
		);
		setcookie(
			'kidia_phone_merge',
			$token,
			array(
				'expires' => time() + 15 * MINUTE_IN_SECONDS,
				'path' => COOKIEPATH ? COOKIEPATH : '/',
				'domain' => defined( 'COOKIE_DOMAIN' ) ? COOKIE_DOMAIN : '',
				'secure' => is_ssl(),
				'httponly' => true,
				'samesite' => 'Lax',
			)
		);
	}

	/** Move the verified social identity to the old phone account after OTP. */
	public function complete_pending_phone_merge( int $target_user_id ): void {
		if ( empty( $_COOKIE['kidia_phone_merge'] ) || ! $target_user_id ) {
			return;
		}

		$token = sanitize_text_field( wp_unslash( $_COOKIE['kidia_phone_merge'] ) );
		$key   = 'kidia_phone_merge_' . hash( 'sha256', $token );
		$data  = get_transient( $key );
		if ( ! is_array( $data ) ) {
			return;
		}

		$source_user_id = absint( $data['source'] ?? 0 );
		$expected_phone = sanitize_text_field( (string) ( $data['phone'] ?? '' ) );
		$target_phone   = $this->find_customer_phone_for_user( $target_user_id );
		if ( ! $source_user_id || $source_user_id === $target_user_id || $this->canonical_phone( $target_phone ) !== $expected_phone ) {
			return;
		}

		/* Only merge the provisional account created by this completion flow. */
		if ( ! get_user_meta( $source_user_id, 'kidia_phone_setup_required', true ) ) {
			return;
		}

		global $wpdb;
		$table = $wpdb->prefix . 'social_users';
		if ( $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $table ) ) === $table ) {
			$wpdb->update( $table, array( 'user_id' => $target_user_id ), array( 'user_id' => $source_user_id ), array( '%d' ), array( '%d' ) );
		}

		$source = get_user_by( 'id', $source_user_id );
		if ( $source && is_email( $source->user_email ) ) {
			$email_owner = email_exists( $source->user_email );
			if ( ! $email_owner || (int) $email_owner === $source_user_id ) {
				$source_email = $source->user_email;
				wp_update_user( array( 'ID' => $source_user_id, 'user_email' => 'merge-' . $source_user_id . '@example.invalid' ) );
				wp_update_user( array( 'ID' => $target_user_id, 'user_email' => $source_email ) );
				update_user_meta( $target_user_id, 'billing_email', $source_email );
			}
		}

		delete_transient( $key );
		setcookie( 'kidia_phone_merge', '', time() - HOUR_IN_SECONDS, COOKIEPATH ? COOKIEPATH : '/' );
		if ( ! function_exists( 'wp_delete_user' ) ) {
			require_once ABSPATH . 'wp-admin/includes/user.php';
		}
		wp_delete_user( $source_user_id, $target_user_id );
	}

	private function handle_email_authentication(): void {
		if ( ! empty( $_POST['kidia_forgot_password'] ) ) {
			$this->handle_forgot_password();
			return;
		}

		if ( empty( $_POST['kidia_email_auth'] ) ) {
			return;
		}

		$nonce = isset( $_POST['kidia_email_nonce'] )
			? sanitize_text_field( wp_unslash( $_POST['kidia_email_nonce'] ) )
			: '';

		if ( ! wp_verify_nonce( $nonce, 'kidia_email_auth' ) ) {
			$this->add_error( 'انتهت صلاحية الصفحة. حدّث الصفحة وحاول مرة أخرى.' );
			$this->redirect_back_to_email();
		}

		$email    = isset( $_POST['kidia_email'] ) ? sanitize_email( wp_unslash( $_POST['kidia_email'] ) ) : '';
		$password = isset( $_POST['kidia_password'] ) ? (string) wp_unslash( $_POST['kidia_password'] ) : '';
		$action   = isset( $_POST['kidia_email_action'] )
			? sanitize_key( wp_unslash( $_POST['kidia_email_action'] ) )
			: 'login';

		if ( ! is_email( $email ) || '' === $password ) {
			$this->add_error( 'راجع البريد الإلكتروني وكلمة المرور.' );
			$this->redirect_back_to_email( $email );
		}

		if ( 'register' === $action ) {
			$name    = isset( $_POST['kidia_name'] ) ? sanitize_text_field( wp_unslash( $_POST['kidia_name'] ) ) : '';
			$confirm = isset( $_POST['kidia_password_confirm'] ) ? (string) wp_unslash( $_POST['kidia_password_confirm'] ) : '';
			$this->register_email_customer( $email, $password, $name, $confirm );
			return;
		}

		$matched_user = $this->find_customer_by_email( $email );
		$login_name   = $matched_user ? (string) $matched_user->user_login : $email;
		$user = wp_signon(
			array(
				'user_login'    => $login_name,
				'user_password' => $password,
				'remember'      => ! empty( $_POST['kidia_remember'] ),
			),
			is_ssl()
		);

		if ( is_wp_error( $user ) ) {
			$this->redirect_back_to_email( $email, 'login', 'invalid_password' );
		}

		wp_set_current_user( (int) $user->ID );
		wp_safe_redirect( $this->get_authenticated_return_url() );
		exit;
	}

	private function handle_forgot_password(): void {
		$nonce = isset( $_POST['kidia_forgot_nonce'] )
			? sanitize_text_field( wp_unslash( $_POST['kidia_forgot_nonce'] ) )
			: '';

		if ( ! wp_verify_nonce( $nonce, 'kidia_forgot_password' ) ) {
			$this->redirect_back_to_forgot( '', false );
		}

		$email = isset( $_POST['kidia_forgot_email'] )
			? sanitize_email( wp_unslash( $_POST['kidia_forgot_email'] ) )
			: '';

		if ( ! is_email( $email ) ) {
			$this->redirect_back_to_forgot( '', false );
		}

		// Use WordPress' signed, expiring password-reset flow. Keep the response
		// generic so the page does not reveal whether an address is registered.
		$customer = $this->find_customer_by_email( $email );
		$login    = $customer ? (string) $customer->user_login : $email;
		retrieve_password( $login );
		$this->redirect_back_to_forgot( $email, true );
	}

	private function redirect_back_to_forgot( string $email, bool $sent ): void {
		$url = add_query_arg(
			array(
				'kidia_stage'      => 'forgot',
				'kidia_email'      => $email,
				'kidia_reset_sent' => $sent ? '1' : '0',
			),
			get_permalink( $this->get_page_id() )
		);

		wp_safe_redirect( $url );
		exit;
	}

	private function register_email_customer( string $email, string $password, string $name, string $confirm ): void {
		$name = trim( $name );

		if ( '' === $name || strlen( $name ) > 120 ) {
			$this->add_error( 'اكتب اسمك (حتى 120 حرفًا).' );
			$this->redirect_back_to_email( $email, 'register' );
		}

		if ( strlen( $password ) < 8 || strlen( $password ) > 4096 ) {
			$this->add_error( 'كلمة المرور يجب أن تكون بين 8 و 4096 حرفًا أو رقمًا.' );
			$this->redirect_back_to_email( $email, 'register' );
		}

		if ( ! hash_equals( $password, $confirm ) ) {
			$this->add_error( 'كلمة المرور وتأكيدها غير متطابقين.' );
			$this->redirect_back_to_email( $email, 'register' );
		}

		if ( $this->find_customer_by_email( $email ) ) {
			$this->add_error( 'البريد مسجل بالفعل. استخدم تسجيل الدخول.' );
			$this->redirect_back_to_email( $email, 'login' );
		}

		if ( ! function_exists( 'wc_create_new_customer' ) ) {
			$this->add_error( 'تعذر إنشاء الحساب لأن ووكومرس غير متاح.' );
			$this->redirect_back_to_email( $email, 'register' );
		}

		// All validation above completes before the account is created.
		$user_id = wc_create_new_customer( $email, '', $password );

		if ( is_wp_error( $user_id ) ) {
			$this->add_error( 'تعذر إنشاء الحساب حاليًا. راجع البيانات وحاول مرة أخرى.' );
			$this->redirect_back_to_email( $email, 'register' );
		}

		wp_update_user( array( 'ID' => $user_id, 'display_name' => $name, 'nickname' => $name, 'first_name' => $name ) );
		update_user_meta( $user_id, 'kidia_profile_details_collected', '1' );

		wp_set_current_user( $user_id );
		wp_set_auth_cookie( $user_id, true, is_ssl() );
		update_user_meta( $user_id, 'kidia_phone_setup_required', 'account' );

		wp_safe_redirect( $this->get_authenticated_return_url() );
		exit;
	}

	private function redirect_back_to_email( string $email = '', string $mode = '', string $error = '' ): void {
		$url  = get_permalink( $this->get_page_id() );
		$args = array( 'kidia_stage' => 'email' );

		if ( $email ) {
			$args['kidia_email'] = $email;
		}

		if ( $mode ) {
			$args['kidia_mode'] = $mode;
		}

		if ( $error ) {
			$args['kidia_error'] = sanitize_key( $error );
		}

		wp_safe_redirect( add_query_arg( $args, $url ) );
		exit;
	}

	public function ajax_check_email(): void {
		check_ajax_referer( 'kidia_login_identifier', 'nonce' );

		if ( ! $this->allow_identifier_check() ) {
			wp_send_json_error( array( 'message' => 'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.' ), 429 );
		}

		$email = isset( $_POST['email'] ) ? sanitize_email( wp_unslash( $_POST['email'] ) ) : '';

		if ( ! is_email( $email ) ) {
			wp_send_json_error( array( 'message' => 'اكتب بريدًا إلكترونيًا صحيحًا.' ), 400 );
		}

		wp_send_json_success(
			array(
				'exists' => (bool) $this->find_customer_by_email( $email ),
			)
		);
	}

	public function ajax_check_phone(): void {
		check_ajax_referer( 'kidia_login_identifier', 'nonce' );

		if ( ! $this->allow_identifier_check() ) {
			wp_send_json_error( array( 'message' => 'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.' ), 429 );
		}

		$phone = isset( $_POST['phone'] ) ? sanitize_text_field( wp_unslash( $_POST['phone'] ) ) : '';
		$local = $this->local_phone( $phone );
		if ( ! preg_match( '/^01[0125][0-9]{8}$/', $local ) ) {
			wp_send_json_error( array( 'message' => 'اكتب رقم هاتف مصريًا صحيحًا مكوّنًا من 11 رقمًا.' ), 400 );
		}

		$candidates = $this->phone_password_candidates( $local );

		wp_send_json_success(
			array(
				'exists'   => count( $candidates ) > 0,
				'multiple' => count( $candidates ) > 1,
				'phone'    => $local,
			)
		);
	}

	private function allow_identifier_check(): bool {
		$ip    = isset( $_SERVER['REMOTE_ADDR'] ) ? sanitize_text_field( wp_unslash( $_SERVER['REMOTE_ADDR'] ) ) : 'unknown';
		$key   = 'kidia_login_check_' . md5( $ip );
		$count = absint( get_transient( $key ) );

		if ( $count >= 30 ) {
			return false;
		}

		set_transient( $key, $count + 1, 10 * MINUTE_IN_SECONDS );

		return true;
	}

	private function should_redirect_current_page(): bool {
		$redirect = false;

		if ( function_exists( 'is_account_page' ) && is_account_page() ) {
			$redirect = true;
		}

		if ( function_exists( 'is_checkout' ) && is_checkout() ) {
			$is_received = function_exists( 'is_order_received_page' ) && is_order_received_page();
			$is_order_pay = function_exists( 'is_wc_endpoint_url' ) && is_wc_endpoint_url( 'order-pay' );
			$redirect = ! $is_received && ! $is_order_pay;
		}

		return (bool) apply_filters( 'kidia_login_redirect_protected_page', $redirect );
	}

	private function current_url(): string {
		$request_uri = isset( $_SERVER['REQUEST_URI'] )
			? wp_unslash( $_SERVER['REQUEST_URI'] )
			: '/';

		return $this->validate_local_redirect( esc_url_raw( home_url( $request_uri ) ), home_url( '/' ) );
	}

	private function remember_redirect_target(): void {
		$requested = isset( $_GET['redirect_to'] ) && is_string( $_GET['redirect_to'] )
			? wp_unslash( $_GET['redirect_to'] )
			: ( is_string( $_SERVER['HTTP_REFERER'] ?? null ) ? wp_unslash( $_SERVER['HTTP_REFERER'] ) : '' );
		$requested = esc_url_raw( $requested );
		$target    = $this->validate_local_redirect( $requested, '' );

		if ( ! $target ) {
			return;
		}

		// Make the new target available to this same response and its Google button.
		$_COOKIE['kidia_login_redirect'] = rawurlencode( $target );
		setcookie(
			'kidia_login_redirect',
			rawurlencode( $target ),
			array(
				'expires'  => time() + HOUR_IN_SECONDS,
				'path'     => COOKIEPATH ? COOKIEPATH : '/',
				'domain'   => defined( 'COOKIE_DOMAIN' ) ? COOKIE_DOMAIN : '',
				'secure'   => is_ssl(),
				'httponly' => true,
				'samesite' => 'Lax',
			)
		);
	}

	private function get_redirect_target(): string {
		// An interrupted purchase resumes at its original URL, including the
		// checkout endpoint, query and fragment. Ordinary sign-in still goes home.
		foreach ( array( $_GET['redirect_to'] ?? null, $_POST['redirect_to'] ?? null ) as $requested ) {
			if ( is_string( $requested ) && '' !== $requested ) {
				return $this->get_purchase_return_target( wp_unslash( $requested ) ) ?: home_url( '/' );
			}
		}
		return $this->get_purchase_return_target( $this->get_remembered_redirect() ) ?: home_url( '/' );
	}

	private function get_purchase_return_target( string $url ): string {
		$url = $this->validate_local_redirect( $url, '' );
		if ( ! $url || ! function_exists( 'wc_get_checkout_url' ) || ! function_exists( 'wc_get_cart_url' ) ) {
			return '';
		}
		$home = wp_parse_url( home_url( '/' ) );
		$parts = wp_parse_url( $url );
		// Keep the redirect on the store's exact origin, including HTTPS/port.
		if ( isset( $parts['scheme'] ) && strtolower( $parts['scheme'] ) !== strtolower( $home['scheme'] ?? 'https' ) ) {
			return '';
		}
		if ( ( $parts['port'] ?? null ) !== ( $home['port'] ?? null ) ) {
			return '';
		}
		$path = rawurldecode( $parts['path'] ?? '' );
		if ( preg_match( '#(?:^|/)\.{1,2}(?:/|$)#', $path ) || false !== strpos( $path, '\\' ) ) {
			return '';
		}
		$path = untrailingslashit( $path );
		$cart = untrailingslashit( rawurldecode( (string) wp_parse_url( wc_get_cart_url(), PHP_URL_PATH ) ) );
		$checkout = untrailingslashit( rawurldecode( (string) wp_parse_url( wc_get_checkout_url(), PHP_URL_PATH ) ) );
		if ( $path !== $cart && $path !== $checkout && ( ! $checkout || 0 !== strpos( $path, $checkout . '/' ) ) ) {
			return '';
		}
		// Returning to a page must not replay a one-time cart action.
		return remove_query_arg( array( 'add-to-cart', 'remove_item', 'undo_item', 'empty-cart', 'wc-ajax', 'action', '_wpnonce' ), $url );
	}

	private function get_remembered_redirect(): string {
		if ( empty( $_COOKIE['kidia_login_redirect'] ) ) {
			return '';
		}

		$cookie_target = esc_url_raw( rawurldecode( wp_unslash( $_COOKIE['kidia_login_redirect'] ) ) );

		return $this->validate_local_redirect( $cookie_target, '' );
	}

	private function clear_redirect_cookie(): void {
		if ( empty( $_COOKIE['kidia_login_redirect'] ) ) {
			return;
		}

		setcookie(
			'kidia_login_redirect',
			'',
			array(
				'expires'  => time() - HOUR_IN_SECONDS,
				'path'     => COOKIEPATH ? COOKIEPATH : '/',
				'domain'   => defined( 'COOKIE_DOMAIN' ) ? COOKIE_DOMAIN : '',
				'secure'   => is_ssl(),
				'httponly' => true,
				'samesite' => 'Lax',
			)
		);
	}

	private function validate_local_redirect( string $url, string $fallback ): string {
		$validated = wp_validate_redirect( $url, $fallback );

		if ( ! $validated ) {
			return $fallback;
		}

		$home_host   = wp_parse_url( home_url( '/' ), PHP_URL_HOST );
		$target_host = wp_parse_url( $validated, PHP_URL_HOST );

		if ( $target_host && $home_host && strtolower( $target_host ) !== strtolower( $home_host ) ) {
			return $fallback;
		}

		$scheme = wp_parse_url( $validated, PHP_URL_SCHEME );
		$path = rawurldecode( (string) wp_parse_url( $validated, PHP_URL_PATH ) );
		$login_path = (string) wp_parse_url( get_permalink( $this->get_page_id() ), PHP_URL_PATH );
		if ( ( $scheme && ! in_array( strtolower( $scheme ), array( 'http', 'https' ), true ) )
			|| wp_parse_url( $validated, PHP_URL_USER ) || wp_parse_url( $validated, PHP_URL_PASS )
			|| untrailingslashit( $path ) === untrailingslashit( $login_path )
			|| preg_match( '#/(?:wp-admin(?:/|$)|wp-login\.php(?:/|$))#i', $path ) ) {
			return $fallback;
		}
		return $validated;
	}

	public function filter_login_redirect( string $redirect_to, string $requested_redirect_to, $user ): string {
		if ( is_wp_error( $user ) || ( $user instanceof WP_User && user_can( $user, 'manage_options' ) ) ) {
			return $redirect_to;
		}

		$remembered = $this->get_remembered_redirect();
		if ( ! $remembered ) {
			return $redirect_to;
		}

		if ( $user instanceof WP_User && get_user_meta( (int) $user->ID, 'kidia_phone_setup_required', true ) ) {
			return $this->get_login_url();
		}

		$target = $this->get_redirect_target();
		$this->clear_redirect_cookie();
		return $target;
	}

	public function render_shortcode(): string {
		$phone_setup_type = is_user_logged_in() && ! current_user_can( 'manage_options' )
			? (string) get_user_meta( get_current_user_id(), 'kidia_phone_setup_required', true ) : '';
		$phone_setup_required = '' !== $phone_setup_type;
		$profile_details_collected = is_user_logged_in() && ! current_user_can( 'manage_options' )
			&& (bool) get_user_meta( get_current_user_id(), 'kidia_profile_details_collected', true );
		if ( is_user_logged_in() && ! $phone_setup_required ) {
			return '';
		}

		$logo_url      = $this->get_logo_url();
		$redirect_to   = $this->get_redirect_target();
		$phone_ready   = shortcode_exists( self::PHONE_TAG );
		$phone_html    = $phone_ready ? $this->capture_phone_form() : '';
		$social_html   = $this->get_social_login_html( $redirect_to );
		$privacy_url   = get_privacy_policy_url();
		$initial_email = isset( $_GET['kidia_email'] ) ? sanitize_email( wp_unslash( $_GET['kidia_email'] ) ) : '';
		$initial_stage = isset( $_GET['kidia_stage'] ) ? sanitize_key( wp_unslash( $_GET['kidia_stage'] ) ) : '';
		$initial_mode  = isset( $_GET['kidia_mode'] ) ? sanitize_key( wp_unslash( $_GET['kidia_mode'] ) ) : '';
		$initial_error = isset( $_GET['kidia_error'] ) ? sanitize_key( wp_unslash( $_GET['kidia_error'] ) ) : '';
		$initial_phone = isset( $_GET['kidia_phone'] ) ? $this->local_phone( sanitize_text_field( wp_unslash( $_GET['kidia_phone'] ) ) ) : '';
		$phone_error   = isset( $_GET['kidia_phone_error'] ) ? sanitize_key( wp_unslash( $_GET['kidia_phone_error'] ) ) : '';
		$setup_error   = isset( $_GET['kidia_setup_error'] ) ? sanitize_key( wp_unslash( $_GET['kidia_setup_error'] ) ) : '';
		if ( $phone_setup_required ) {
			$initial_stage = 'phone-setup';
		}
		$reset_sent    = isset( $_GET['kidia_reset_sent'] ) && '1' === sanitize_text_field( wp_unslash( $_GET['kidia_reset_sent'] ) );

		ob_start();
		include plugin_dir_path( __FILE__ ) . 'templates/content-login.php';
		return (string) ob_get_clean();
	}

	/**
	 * The vendor shortcode prints its template instead of returning it. Capture
	 * both printed and returned output so it stays inside the Kidia card.
	 */
	private function capture_phone_form(): string {
		ob_start();
		$returned = do_shortcode( '[fme_lwp_display_login_form]' );
		$printed  = (string) ob_get_clean();
		$returned = is_string( $returned ) ? $returned : '';

		/* Some releases of the paid phone extension both echo and return the
		 * complete form. Concatenating both copies duplicates the recaptcha
		 * container and its inline next-tick renderer, which makes Firebase throw
		 * "reCAPTCHA has already been rendered in this element". Keep exactly one
		 * complete form, while retaining both fragments only when they are truly
		 * complementary. */
		$marker = 'fme_lwp_phone_number_field';
		if ( false !== strpos( $printed, $marker ) && false !== strpos( $returned, $marker ) ) {
			$html = strlen( $returned ) >= strlen( $printed ) ? $returned : $printed;
		} else {
			$html = $printed . $returned;
		}

		$html = preg_replace(
			'/(<button\b[^>]*id\s*=\s*[\'\"]fma_lwp_send_code_btn[\'\"][^>]*>).*?(<\/button>)/si',
			'$1إرسال الكود$2',
			$html
		);
		$html = preg_replace(
			'/(<h3\b[^>]*>)[^<]*Enter Verification code[^<]*(<\/h3>)/si',
			'$1أدخل كود التحقق$2',
			(string) $html
		);
		$html = str_replace( 'placeholder="Enter Verification code"', 'placeholder="كود التحقق"', (string) $html );

		return (string) $html;
	}

	private function get_social_login_html( string $redirect_to ): string {
		if ( ! shortcode_exists( 'nextend_social_login' ) ) {
			return '';
		}

		$redirect_attr = esc_url_raw( $redirect_to );
		$google_html = do_shortcode( '[nextend_social_login provider="google" style="default" customlabel="المتابعة باستخدام جوجل" redirect="' . $redirect_attr . '"]' );
		$facebook_html = do_shortcode( '[nextend_social_login provider="facebook" style="default" customlabel="المتابعة باستخدام فيسبوك" redirect="' . $redirect_attr . '"]' );
		return str_replace('class="nsl-container', 'class="kidia-google-provider nsl-container', $google_html)
		    . str_replace('class="nsl-container', 'class="kidia-facebook-provider nsl-container', $facebook_html);
	}

	private function get_logo_url(): string {
		$custom_logo_id = absint( get_theme_mod( 'custom_logo' ) );
		if ( $custom_logo_id ) {
			$url = wp_get_attachment_image_url( $custom_logo_id, 'full' );
			if ( $url ) {
				return $url;
			}
		}

		$flatsome_logo = get_theme_mod( 'site_logo' );
		if ( is_numeric( $flatsome_logo ) ) {
			$url = wp_get_attachment_image_url( absint( $flatsome_logo ), 'full' );
			if ( $url ) {
				return $url;
			}
		}

		if ( is_string( $flatsome_logo ) && filter_var( $flatsome_logo, FILTER_VALIDATE_URL ) ) {
			return esc_url_raw( $flatsome_logo );
		}

		$uploads = wp_get_upload_dir();
		$fallback_relative = '2025/05/WhatsApp-Image-2022-02-04-at-6.30-2.png';
		$fallback_file     = trailingslashit( $uploads['basedir'] ) . $fallback_relative;

		return file_exists( $fallback_file )
			? trailingslashit( $uploads['baseurl'] ) . $fallback_relative
			: '';
	}

	private function add_error( string $message ): void {
		if ( function_exists( 'wc_add_notice' ) ) {
			wc_add_notice( $message, 'error' );
		}
	}

	public function plugin_action_links( array $links ): array {
		$page_id = $this->get_page_id();

		if ( $page_id ) {
			array_unshift(
				$links,
				'<a href="' . esc_url( get_permalink( $page_id ) ) . '" target="_blank" rel="noopener">فتح الصفحة</a>'
			);
		}

		return $links;
	}
}

Kidia_Store_Custom_Login_Page_V020::instance();
