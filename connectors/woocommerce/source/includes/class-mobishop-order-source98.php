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
		add_action( 'admin_footer', array( $this, 'merge_channel_control' ) );
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

	public function merge_channel_control(): void {
		$screen = get_current_screen();
		if ( ! $screen || 'woocommerce_page_wc-orders' !== $screen->id ) return;
		?>
		<script>
		(function () {
			var source = document.getElementById('mobishop-order-source98');
			var channels = document.getElementById('filter-by-created-via');
			if (!source || !channels) return;
			var option = document.createElement('option');
			option.value = 'mobishop-mobile';
			option.textContent = source.options[1].textContent;
			channels.appendChild(option);
			if (source.value === 'mobile') channels.value = option.value;
			source.remove();
		}());
		</script>
		<?php
	}
}
