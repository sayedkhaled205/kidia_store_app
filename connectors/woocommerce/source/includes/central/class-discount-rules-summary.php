<?php
defined( 'ABSPATH' ) || exit;

/**
 * Read-only summary of FlyCart "Advanced Woo Discount Rules" rows for the
 * private merchant Discounts page. Never touches product pricing, never
 * writes to the rules table, and only reads a whitelisted set of columns.
 */
final class MobiShop_Discount_Rules_Summary {

	private const PER_PAGE = 20;

	/**
	 * @return array{available:bool,rows:array,total:int,pages:int,page:int,error:bool}
	 */
	public static function query( array $filters = array() ): array {
		$empty = array(
			'available' => false,
			'rows'      => array(),
			'total'     => 0,
			'pages'     => 1,
			'page'      => 1,
			'error'     => false,
		);

		if ( ! self::current_user_authorized() ) {
			$empty['error'] = true;
			return $empty;
		}

		if ( ! self::plugin_active() ) {
			return $empty;
		}

		global $wpdb;
		if ( ! isset( $wpdb ) || ! self::table_exists( $wpdb ) ) {
			return $empty;
		}

		$search = self::filter_value( $filters, 'search', 'coupon_search' );
		$type   = self::filter_value( $filters, 'type', 'coupon_type' );
		$status = self::filter_value( $filters, 'status', 'coupon_status' );
		$page   = max( 1, (int) self::filter_value( $filters, 'page', 'coupon_page', 1 ) );

		$table = $wpdb->prefix . 'wdr_rules';
		$where = array( 'deleted = 0' );
		$args  = array();
		$now = (int) current_time( 'timestamp' );
		if ( in_array( $status, array( 'active', 'disabled', 'scheduled', 'expired', 'exhausted' ), true ) ) {
			$where[] = "(CASE WHEN enabled <> 1 OR enabled IS NULL THEN 'disabled' WHEN date_from > %d THEN 'scheduled' WHEN date_to < %d THEN 'expired' WHEN usage_limits > 0 AND used_limits >= usage_limits THEN 'exhausted' ELSE 'active' END) = %s";
			$args = array( $now, $now, $status );
		}

		if ( '' !== $search ) {
			$where[] = 'title LIKE %s';
			$args[]  = '%' . $wpdb->esc_like( $search ) . '%';
		}

		$known_types = array_keys( self::type_labels() );
		if ( in_array( $type, $known_types, true ) ) {
			$where[] = 'discount_type = %s';
			$args[]  = $type;
		}

		$where_sql = implode( ' AND ', $where );

		$count_sql = "SELECT COUNT(*) FROM {$table} WHERE {$where_sql}";
		$total_raw = empty( $args ) ? $wpdb->get_var( $count_sql ) : $wpdb->get_var( $wpdb->prepare( $count_sql, $args ) );
		if ( false === $total_raw || null === $total_raw ) {
			$empty['error'] = true;
			return $empty;
		}

		$total = absint( $total_raw );
		$pages = max( 1, (int) ceil( $total / self::PER_PAGE ) );
		$page  = min( $page, $pages );
		$offset = ( $page - 1 ) * self::PER_PAGE;

		$rows = array();
		if ( $total > 0 ) {
			// Merchant-only raw rows stay server-side; the browser receives the
			// summary and a revision hash, never customer targeting conditions.
			$columns = '*';
			$sql     = "SELECT {$columns} FROM {$table} WHERE {$where_sql} ORDER BY priority ASC, id ASC LIMIT %d OFFSET %d";
			$query_args = array_merge( $args, array( self::PER_PAGE, $offset ) );
			$results = $wpdb->get_results( $wpdb->prepare( $sql, $query_args ), ARRAY_A );

			if ( ! is_array( $results ) || ! empty( $wpdb->last_error ) ) {
				$empty['error'] = true;
				return $empty;
			}

			$now = (int) current_time( 'timestamp' );
			foreach ( (array) $results as $row ) {
				if ( is_array( $row ) ) {
					$normalized = self::normalize_row( $row, $now );
					$normalized['channel'] = MobiShop_Discount_Channel::scope( $row );
					$normalized['enabled'] = (int) ( $row['enabled'] ?? 0 ) === 1;
					$normalized['revision'] = MobiShop_Discount_Rules_Admin::revision( $row );
					$rows[] = $normalized;
				}
			}
		}

		return array(
			'available' => true,
			'rows'      => $rows,
			'total'     => $total,
			'pages'     => $pages,
			'page'      => $page,
			'error'     => false,
		);
	}

	public static function render( array $filters = array() ): void {
		if ( ! self::current_user_authorized() ) {
			return;
		}

		$result = self::query( $filters );

		echo '<section class="mobishop-discount-rules-summary">';
		echo '<style>.mobishop-discount-rules-summary .mobishop-rule-dates{min-width:155px}.mobishop-rule-dates span{display:block;white-space:nowrap;direction:ltr;unicode-bidi:isolate}.mobishop-discount-rules-summary td{vertical-align:middle}.mobishop-discount-rules-summary td:first-child{min-width:160px}</style>';
		echo '<h3>' . esc_html__( 'Discount Rules', 'mobi2app-connector' ) . '</h3>';

		if ( $result['error'] ) {
			echo '<p>' . esc_html__( 'Discount rule data could not be loaded right now.', 'mobi2app-connector' ) . '</p></section>';
			return;
		}

		if ( ! $result['available'] ) {
			echo '<p>' . esc_html__( 'Advanced Woo Discount Rules is not active, so no discount rules are available to show.', 'mobi2app-connector' ) . '</p></section>';
			return;
		}
		echo '<button type="button" class="button button-primary" data-discount-action="create">' . esc_html__( 'Create offer', 'mobi2app-connector' ) . '</button>';

		$search = self::filter_value( $filters, 'search', 'coupon_search' );
		$type   = self::filter_value( $filters, 'type', 'coupon_type' );
		$base_url = function_exists( 'admin_url' ) ? admin_url( 'admin.php' ) : 'admin.php';
		$manage_url = function_exists( 'admin_url' ) ? admin_url( 'admin.php?page=woo_discount_rules' ) : 'admin.php?page=woo_discount_rules';
		$timezone_label = function_exists( 'wp_timezone_string' ) ? wp_timezone_string() : 'UTC';

		$passthrough_keys = array( 'store_source', 'date_preset', 'date_from', 'date_to' );

		echo '<form class="mobishop-coupon-filters mobishop-discount-rules-filters" method="get" action="' . esc_url( $base_url ) . '">';
		echo '<input type="hidden" name="page" value="mobishop-store-data"><input type="hidden" name="store_tab" value="discounts"><input type="hidden" name="coupon_scope" value="rules">';
		foreach ( $passthrough_keys as $key ) {
			if ( isset( $_GET[ $key ] ) && is_scalar( $_GET[ $key ] ) ) {
				echo '<input type="hidden" name="' . esc_attr( $key ) . '" value="' . esc_attr( sanitize_text_field( wp_unslash( $_GET[ $key ] ) ) ) . '">';
			}
		}
		echo '<input type="search" name="coupon_search" value="' . esc_attr( $search ) . '" placeholder="' . esc_attr__( 'Search rule name', 'mobi2app-connector' ) . '">';
		echo '<select name="coupon_type"><option value="all">' . esc_html__( 'All discount types', 'mobi2app-connector' ) . '</option>';
		foreach ( self::type_labels() as $type_key => $type_label ) {
			$selected = $type === $type_key ? ' selected' : '';
			echo '<option value="' . esc_attr( $type_key ) . '"' . $selected . '>' . esc_html( $type_label ) . '</option>';
		}
		echo '</select>';
		echo '<select name="coupon_status" aria-label="' . esc_attr__( 'Rule status', 'mobi2app-connector' ) . '"><option value="all">' . esc_html__( 'All statuses', 'mobi2app-connector' ) . '</option>';
		foreach ( array( 'active', 'disabled', 'scheduled', 'expired', 'exhausted' ) as $status ) {
			echo '<option value="' . esc_attr( $status ) . '"' . ( self::filter_value( $filters, 'status', 'coupon_status' ) === $status ? ' selected' : '' ) . '>' . esc_html( self::status_label( $status ) ) . '</option>';
		}
		echo '</select><input type="hidden" name="coupon_page" value="1">';
		echo '<button class="button button-primary" type="submit">' . esc_html__( 'Filter', 'mobi2app-connector' ) . '</button>';
		echo '<a class="button" href="' . esc_url( $manage_url ) . '">' . esc_html__( 'Manage rules', 'mobi2app-connector' ) . '</a>';
		echo '</form>';
		self::pagination( $result );

		echo '<p class="mobishop-discount-rules-note">' . esc_html(
			sprintf(
				/* translators: %s is a timezone label such as UTC or Europe/London. */
				__( 'Dates use the store timezone (%s). Each offer applies only in its selected channels when its conditions are met.', 'mobi2app-connector' ),
				$timezone_label
			)
		) . '</p>';

		echo '<div class="mobishop-data-table-wrap"><table class="mobishop-data-table mobishop-discount-rules-table"><thead><tr>';
		echo '<th>' . esc_html__( 'Rule', 'mobi2app-connector' ) . '</th>';
		echo '<th>' . esc_html__( 'Type', 'mobi2app-connector' ) . '</th>';
		echo '<th>' . esc_html__( 'Offer', 'mobi2app-connector' ) . '</th>';
		echo '<th>' . esc_html__( 'Status', 'mobi2app-connector' ) . '</th>';
		echo '<th>' . esc_html__( 'Dates', 'mobi2app-connector' ) . '</th>';
		echo '<th>' . esc_html__( 'Usage', 'mobi2app-connector' ) . '</th>';
		echo '<th>' . esc_html__( 'Sales channels', 'mobi2app-connector' ) . '</th><th>' . esc_html__( 'Controls', 'mobi2app-connector' ) . '</th>';
		echo '</tr></thead><tbody>';

		foreach ( $result['rows'] as $row ) {
			$title = '' !== $row['title'] ? $row['title'] : __( '(untitled rule)', 'mobi2app-connector' );
			echo '<tr data-discount-id="' . esc_attr( $row['id'] ) . '" data-discount-revision="' . esc_attr( $row['revision'] ) . '" data-discount-channel="' . esc_attr( $row['channel'] ) . '" data-discount-enabled="' . ( $row['enabled'] ? '1' : '0' ) . '" data-discount-title="' . esc_attr( $title ) . '"><td><strong>' . esc_html( $title ) . '</strong>';
			if ( $row['exclusive'] ) {
				echo '<small class="mobishop-discount-rules-badge">' . esc_html__( 'Exclusive', 'mobi2app-connector' ) . '</small>';
			}
			echo '</td>';
			echo '<td>' . esc_html( $row['type_label'] ) . '</td>';
			echo '<td><bdi dir="auto">' . esc_html( $row['offer'] ) . '</bdi></td>';
			echo '<td><span class="mobishop-status">' . esc_html( self::status_label( $row['status'] ) ) . '</span></td>';
			echo '<td class="mobishop-rule-dates"><span>' . esc_html( null === $row['date_from'] ? __( 'No start date', 'mobi2app-connector' ) : gmdate( 'Y-m-d H:i', $row['date_from'] ) ) . '</span><span>' . esc_html( null === $row['date_to'] ? __( 'No end date', 'mobi2app-connector' ) : gmdate( 'Y-m-d H:i', $row['date_to'] ) ) . '</span></td>';
			echo '<td>' . esc_html( self::format_usage( $row['usage_limits'], $row['used_limits'] ) ) . '</td>';
			$labels = array( 'all' => __( 'Website + Mobile', 'mobi2app-connector' ), 'website' => __( 'Website only', 'mobi2app-connector' ), 'mobile' => __( 'Mobile only', 'mobi2app-connector' ) );
			echo '<td>' . esc_html( $labels[ $row['channel'] ] ) . '</td><td><button type="button" class="button" data-discount-action="edit">' . esc_html__( 'Control', 'mobi2app-connector' ) . '</button> <button type="button" class="button" data-discount-action="clone">' . esc_html__( 'Copy offer', 'mobi2app-connector' ) . '</button></td>';
			echo '</tr>';
		}
		if ( ! $result['rows'] ) {
			echo '<tr><td colspan="8">' . esc_html__( 'No rules match these filters.', 'mobi2app-connector' ) . '</td></tr>';
		}

		echo '</tbody></table></div>';
		self::pagination( $result );
		echo '</section>';
	}

	private static function pagination( array $result ): void {
		$from = $result['total'] ? ( $result['page'] - 1 ) * self::PER_PAGE + 1 : 0;
		$to = min( $result['total'], $result['page'] * self::PER_PAGE );
		echo '<div class="mobishop-rules-pagination"><p>' . esc_html( sprintf( __( 'Showing %1$d–%2$d of %3$d offers · Page %4$d of %5$d', 'mobi2app-connector' ), $from, $to, $result['total'], $result['page'], $result['pages'] ) ) . '</p>';

		if ( $result['pages'] > 1 && function_exists( 'paginate_links' ) && function_exists( 'add_query_arg' ) && function_exists( 'wp_kses_post' ) ) {
			echo '<nav class="mobishop-data-pagination">' . wp_kses_post(
				paginate_links(
					array(
						'base'    => add_query_arg( 'coupon_page', '%#%' ),
						'format'  => '',
						'current' => $result['page'],
						'total'   => $result['pages'],
					)
				)
			) . '</nav>';
		}

		echo '</div>';
	}

	/**
	 * Pure normalization of one raw whitelisted-column DB row into a safe,
	 * display-ready shape. No WordPress calls other than core PHP, so this
	 * is deterministic and unit-testable with a fixed $now.
	 */
	public static function normalize_row( array $row, int $now ): array {
		$id        = isset( $row['id'] ) ? (int) $row['id'] : 0;
		$title     = isset( $row['title'] ) ? (string) $row['title'] : '';
		$type      = isset( $row['discount_type'] ) ? (string) $row['discount_type'] : '';
		$enabled   = isset( $row['enabled'] ) && null !== $row['enabled'] ? (int) $row['enabled'] : 0;
		$priority  = isset( $row['priority'] ) && null !== $row['priority'] ? (int) $row['priority'] : 0;
		$exclusive = isset( $row['exclusive'] ) && 1 === (int) $row['exclusive'];

		$date_from = ( isset( $row['date_from'] ) && null !== $row['date_from'] && '' !== $row['date_from'] )
			? (int) $row['date_from']
			: null;
		$date_to = ( isset( $row['date_to'] ) && null !== $row['date_to'] && '' !== $row['date_to'] )
			? (int) $row['date_to']
			: null;
		$usage_limits = ( isset( $row['usage_limits'] ) && null !== $row['usage_limits'] && '' !== $row['usage_limits'] )
			? (int) $row['usage_limits']
			: 0;
		$used_limits = ( isset( $row['used_limits'] ) && null !== $row['used_limits'] && '' !== $row['used_limits'] )
			? (int) $row['used_limits']
			: null;

		if ( 1 !== $enabled ) {
			$status = 'disabled';
		} elseif ( null !== $date_from && $date_from > $now ) {
			$status = 'scheduled';
		} elseif ( null !== $date_to && $date_to < $now ) {
			$status = 'expired';
		} elseif ( $usage_limits > 0 && null !== $used_limits && $used_limits >= $usage_limits ) {
			$status = 'exhausted';
		} else {
			$status = 'active';
		}

		return array(
			'id'           => $id,
			'title'        => $title,
			'type'         => $type,
			'type_label'   => self::type_label( $type ),
			'offer'        => self::offer_summary( $row ),
			'status'       => $status,
			'priority'     => $priority,
			'exclusive'    => $exclusive,
			'date_from'    => $date_from,
			'date_to'      => $date_to,
			'usage_limits' => $usage_limits,
			'used_limits'  => $used_limits,
		);
	}

	private static function current_user_authorized(): bool {
		return function_exists( 'current_user_can' )
			&& current_user_can( 'manage_woocommerce' )
			&& current_user_can( 'manage_options' );
	}

	private static function plugin_active(): bool {
		if ( function_exists( 'has_filter' ) && false !== has_filter( 'advanced_woo_discount_rules_get_product_discount_price' ) ) {
			return true;
		}
		return class_exists( 'Wdr\\App\\Models\\DBTable' );
	}

	private static function table_exists( $wpdb ): bool {
		$table = $wpdb->prefix . 'wdr_rules';
		if ( ! preg_match( '/^[A-Za-z0-9_]+$/D', $table ) ) { return false; }
		$found = $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $wpdb->esc_like( $table ) ) );
		return is_string( $found ) && strtolower( $found ) === strtolower( $table );
	}

	private static function filter_value( array $filters, string $filter_key, string $get_key, $default = '' ) {
		if ( array_key_exists( $filter_key, $filters ) ) {
			$value = $filters[ $filter_key ];
		} elseif ( isset( $_GET[ $get_key ] ) ) {
			$value = wp_unslash( $_GET[ $get_key ] );
		} else {
			return $default;
		}

		if ( ! is_scalar( $value ) ) { return $default; }
		if ( is_int( $default ) ) {
			return (int) $value;
		}

		return 'type' === $filter_key
			? sanitize_key( (string) $value )
			: sanitize_text_field( (string) $value );
	}

	/** Only offer amounts/quantities are formatted; never export raw JSON targeting. */
	private static function offer_summary( array $row ): string {
		$columns = array( 'wdr_simple_discount' => 'product_adjustments', 'wdr_cart_discount' => 'cart_adjustments', 'wdr_bulk_discount' => 'bulk_adjustments', 'wdr_set_discount' => 'set_adjustments', 'wdr_buy_x_get_x_discount' => 'buy_x_get_x_adjustments', 'wdr_buy_x_get_y_discount' => 'buy_x_get_y_adjustments' );
		$type = $row['discount_type'] ?? '';
		$column = $columns[ $type ] ?? '';
		$data = $column && is_string( $row[ $column ] ?? null ) ? json_decode( $row[ $column ], true ) : null;
		if ( ! is_array( $data ) ) { return __( 'See website rule', 'mobi2app-connector' ); }
		$amount = static function ( array $value ): string {
			$number = $value['value'] ?? null;
			if ( ! is_numeric( $number ) || ! is_finite( (float) $number ) || (float) $number < 0 ) { return ''; }
			$kind = $value['type'] ?? '';
			if ( 'percentage' === $kind ) { return sprintf( __( '%s%% off', 'mobi2app-connector' ), (string) $number ); }
			if ( in_array( $kind, array( 'flat', 'flat_in_subtotal', 'fixed_price', 'fixed_set_price' ), true ) ) {
				$money = (string) $number . ' ' . get_woocommerce_currency();
				$labels = array(
					'flat' => __( '%s off per item', 'mobi2app-connector' ),
					'flat_in_subtotal' => __( '%s off subtotal', 'mobi2app-connector' ),
					'fixed_price' => __( 'Final price: %s', 'mobi2app-connector' ),
					'fixed_set_price' => __( 'Set price: %s', 'mobi2app-connector' ),
				);
				return sprintf( $labels[ $kind ], $money );
			}
			return '';
		};
		if ( isset( $data['value'] ) ) { return $amount( $data ) ?: __( 'See website rule', 'mobi2app-connector' ); }
		$parts = array();
		foreach ( array_slice( (array) ( $data['ranges'] ?? array() ), 0, 20 ) as $range ) {
			if ( ! is_array( $range ) || ! is_numeric( $range['from'] ?? null ) ) { continue; }
			$from = (string) $range['from'];
			$to = is_numeric( $range['to'] ?? null ) ? '–' . $range['to'] : '+';
			if ( isset( $range['free_qty'] ) && is_numeric( $range['free_qty'] ) ) {
				$benefit = 'free_product' === ( $range['free_type'] ?? '' ) ? __( 'free', 'mobi2app-connector' ) : __( 'discounted', 'mobi2app-connector' );
				// The qualifying quantity can include the gift in cheapest-item modes.
				$parts[] = sprintf( __( 'From %1$s items: %2$s %3$s', 'mobi2app-connector' ), $from, $range['free_qty'], $benefit );
			} elseif ( $amount( $range ) ) { $parts[] = $from . $to . ': ' . $amount( $range ); }
		}
		return $parts ? implode( '; ', $parts ) : __( 'See website rule', 'mobi2app-connector' );
	}

	private static function type_labels(): array {
		return array(
			'wdr_simple_discount'       => __( 'Product discount', 'mobi2app-connector' ),
			'wdr_cart_discount'         => __( 'Cart discount', 'mobi2app-connector' ),
			'wdr_bulk_discount'         => __( 'Quantity discount', 'mobi2app-connector' ),
			'wdr_set_discount'          => __( 'Bundle / set discount', 'mobi2app-connector' ),
			'wdr_buy_x_get_x_discount'  => __( 'Buy X get X', 'mobi2app-connector' ),
			'wdr_buy_x_get_y_discount'  => __( 'Buy X get Y', 'mobi2app-connector' ),
			'wdr_free_shipping'         => __( 'Free shipping', 'mobi2app-connector' ),
		);
	}

	private static function type_label( string $type ): string {
		$labels = self::type_labels();
		return $labels[ $type ] ?? __( 'Other rule', 'mobi2app-connector' );
	}

	private static function status_label( string $status ): string {
		$labels = array(
			'disabled'  => __( 'Disabled', 'mobi2app-connector' ),
			'scheduled' => __( 'Scheduled', 'mobi2app-connector' ),
			'expired'   => __( 'Expired', 'mobi2app-connector' ),
			'exhausted' => __( 'Exhausted', 'mobi2app-connector' ),
			'active'    => __( 'Active', 'mobi2app-connector' ),
		);
		return $labels[ $status ] ?? __( 'Unknown', 'mobi2app-connector' );
	}

	private static function format_dates( ?int $date_from, ?int $date_to ): string {
		$from = null === $date_from ? __( 'No start date', 'mobi2app-connector' ) : gmdate( 'Y-m-d H:i', $date_from );
		$to   = null === $date_to ? __( 'No end date', 'mobi2app-connector' ) : gmdate( 'Y-m-d H:i', $date_to );
		return $from . ' – ' . $to;
	}

	private static function format_usage( int $usage_limits, ?int $used_limits ): string {
		$used = $used_limits ?? 0;
		if ( $usage_limits > 0 ) {
			return sprintf(
				/* translators: 1: times used, 2: usage limit. */
				__( '%1$d / %2$d used', 'mobi2app-connector' ),
				$used,
				$usage_limits
			);
		}
		return sprintf(
			/* translators: %d: times used. */
			__( '%d used, unlimited', 'mobi2app-connector' ),
			$used
		);
	}
}
