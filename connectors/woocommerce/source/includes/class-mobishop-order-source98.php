<?php
/** Shared mobile-order filtering. Existing Store API creation semantics stay intact. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Order_Source98 {
	const CHANNEL = 'mobishop-mobile';

	public function register(): void {
		add_action( 'woocommerce_order_list_table_restrict_manage_orders', array( $this, 'control' ), 40, 2 );
		add_action( 'restrict_manage_posts', array( $this, 'control' ), 40, 2 );
		add_filter( 'woocommerce_order_list_table_prepare_items_query_args', array( $this, 'hpos_query' ), 50 );
		add_action( 'pre_get_posts', array( $this, 'legacy_query' ), 50 );
		add_filter( 'manage_woocommerce_page_wc-orders_columns', array( $this, 'order_columns' ) );
		add_filter( 'manage_edit-shop_order_columns', array( $this, 'order_columns' ) );
		add_action( 'manage_woocommerce_page_wc-orders_custom_column', array( $this, 'order_cell' ), 10, 2 );
		add_action( 'manage_shop_order_posts_custom_column', array( $this, 'order_cell' ), 10, 2 );
		add_action( 'woocommerce_admin_order_data_after_billing_address', array( $this, 'order_detail' ) );
		add_filter( 'woocommerce_email_order_meta_fields', array( $this, 'email_source' ), 10, 3 );
		add_action( 'admin_enqueue_scripts', array( $this, 'enqueue_assets' ) );
	}

	private function label( string $arabic, string $english ): string {
		return 0 === strpos( determine_locale(), 'ar' ) ? $arabic : $english;
	}

	private function badge( string $description ): string {
		return '<span class="mobishop-app-badge98" title="' . esc_attr( $description ) . '"><span class="dashicons dashicons-smartphone" aria-hidden="true"></span> ' . esc_html( $this->label( 'التطبيق', 'App' ) ) . '</span>';
	}

	private function mobile_order( $order ): bool {
		return $order instanceof WC_Order && 'mobile' === (string) $order->get_meta( '_mobishop_order_source' );
	}

	public function order_columns( array $columns ): array {
		$result = array();
		foreach ( $columns as $key => $title ) {
			$result[ $key ] = $title;
			if ( 'order_number' === $key ) $result['mobishop_app_source'] = $this->label( 'مصدر الطلب', 'Order source' );
		}
		if ( ! isset( $result['mobishop_app_source'] ) ) $result['mobishop_app_source'] = $this->label( 'مصدر الطلب', 'Order source' );
		return $result;
	}

	public function order_cell( $column, $order ): void {
		if ( 'mobishop_app_source' !== $column ) return;
		if ( ! $order instanceof WC_Order ) $order = wc_get_order( $order );
		if ( $this->mobile_order( $order ) ) {
			echo wp_kses_post( $this->badge( $this->label( 'الطلب تم من التطبيق', 'Order placed in the app' ) ) );
		} else { echo '&mdash;'; }
	}

	public function order_detail( $order ): void {
		if ( $this->mobile_order( $order ) ) echo '<p><strong>' . esc_html( $this->label( 'مصدر الطلب: ', 'Order source: ' ) ) . '</strong>' . wp_kses_post( $this->badge( $this->label( 'الطلب تم من التطبيق', 'Order placed in the app' ) ) ) . '</p>';
	}

	public function email_source( array $fields, $sent_to_admin, $order ): array {
		if ( $sent_to_admin && $this->mobile_order( $order ) ) {
			$fields['mobishop_app_source'] = array( 'label' => $this->label( 'مصدر الطلب', 'Order source' ), 'value' => $this->label( 'التطبيق', 'App' ) );
		}
		return $fields;
	}

	public function enqueue_assets(): void {
		$screen = get_current_screen();
		if ( ! $screen ) return;
		if ( in_array( $screen->id, array( 'woocommerce_page_wc-orders', 'edit-shop_order', 'shop_order', 'users', 'user-edit', 'profile' ), true ) ) {
			wp_enqueue_style( 'mobishop-order-source98', MOBISHOP_URL . 'public/css/mobishop-order-source98.css', array(), MOBISHOP_VERSION );
		}
		if ( 'woocommerce_page_wc-orders' === $screen->id ) {
			wp_enqueue_script( 'mobishop-order-source98', MOBISHOP_URL . 'public/js/mobishop-order-source98.js', array(), MOBISHOP_VERSION, true );
		}
	}

	private function selected(): bool {
		return self::CHANNEL === ( $_GET['_created_via'] ?? '' ) || 'mobile' === ( $_GET['mobishop_order_source'] ?? '' );
	}

	public function control( $type, $which ): void {
		if ( 'shop_order' !== $type || 'top' !== $which ) return;
		$arabic = strpos( determine_locale(), 'ar' ) === 0;
		echo '<select name="mobishop_order_source" id="mobishop-order-source98" aria-label="' . esc_attr( $arabic ? 'مصدر الطلب' : 'Order source' ) . '">';
		echo '<option value="">' . esc_html( $arabic ? 'كل مصادر الطلبات' : 'All order sources' ) . '</option>';
		echo '<option value="mobile"' . selected( $this->selected(), true, false ) . '>' . esc_html( $arabic ? 'تطبيق الموبايل' : 'Mobile app' ) . '</option></select>';
	}

	public function hpos_query( array $args ): array {
		if ( ! $this->selected() ) return $args;
		// The HPOS sales-channel menu is otherwise a created_via filter. App
		// orders retain store-api for Woo's checkout hooks and use source metadata.
		if ( self::CHANNEL === ( $_GET['_created_via'] ?? '' ) ) unset( $args['created_via'] );
		$args['meta_query'] = $this->with_source( $args['meta_query'] ?? array() );
		return $args;
	}

	private function with_source( array $existing ): array {
		$source = array( 'key' => '_mobishop_order_source', 'value' => 'mobile', 'compare' => '=' );
		return $existing ? array( 'relation' => 'AND', $existing, $source ) : array( $source );
	}

	public function legacy_query( $query ): void {
		if ( ! is_admin() || ! $query->is_main_query() || 'shop_order' !== $query->get( 'post_type' ) || ! $this->selected() ) return;
		$query->set( 'meta_query', $this->with_source( (array) $query->get( 'meta_query' ) ) );
	}

}
