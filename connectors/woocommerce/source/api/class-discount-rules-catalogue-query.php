<?php
/**
 * Repairs the Woo Store API on_sale filter for the mobile product collection so it reflects
 * FlyCart's dynamic quantity-one quote, not only a stored sale price. Reuses
 * MobiShop_Discount_Rules_Prices::prices() for every arithmetic decision; never recomputes a quote itself.
 */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Discount_Rules_Catalogue_Query {

	public static function register(): void {
		add_filter( 'rest_dispatch_request', array( self::class, 'dispatch' ), 20, 4 );
	}

	private static bool $in_dispatch = false;

	/**
	 * Short-circuits the Store API products collection only for an explicit boolean on_sale
	 * request on the mobile channel, running the original handler under a temporary,
	 * request-scoped pre_get_posts correction instead of re-implementing it.
	 */
	public static function dispatch( $result, $request, $route, $handler ) {
		if ( null !== $result || self::$in_dispatch ) {
			return $result;
		}
		if ( ! ( $request instanceof WP_REST_Request ) || 'GET' !== $request->get_method() ) {
			return $result;
		}
		if ( ! is_string( $route ) || ! preg_match( '#^/wc/store/v[0-9]+/products/?$#', $route ) ) {
			return $result;
		}
		if ( 'mobile' !== strtolower( (string) $request->get_header( 'X-MobiShop-Channel' ) ) ) {
			return $result;
		}
		$on_sale = $request->get_param( 'on_sale' );
		if ( ! is_bool( $on_sale ) ) {
			return $result;
		}
		if ( ! MobiShop_Discount_Rules_Prices::available() ) {
			return $result;
		}
		if ( ! is_array( $handler ) || empty( $handler['callback'] ) || ! is_callable( $handler['callback'] ) ) {
			return $result;
		}
		if ( ! class_exists( '\\Automattic\\WooCommerce\\StoreApi\\Utilities\\ProductQuery' ) ) {
			return $result;
		}

		self::$in_dispatch = true;
		try {
			$final_ids = self::resolve_ids( $request, $on_sale );
		} catch ( Throwable $error ) {
			self::$in_dispatch = false;
			return $result;
		}

		$correction = static function ( $query ) use ( $final_ids ) {
			if ( self::is_target_query( $query ) ) {
				$query->set( 'post__in', $final_ids ? array_values( $final_ids ) : array( 0 ) );
				$query->set( 'post__not_in', array() );
			}
		};

		add_action( 'pre_get_posts', $correction, 20 );
		try {
			return call_user_func( $handler['callback'], $request );
		} finally {
			remove_action( 'pre_get_posts', $correction, 20 );
			self::$in_dispatch = false;
		}
	}

	/**
	 * Computes the corrected on_sale product id set once for this request: the baseline
	 * collection Q (every other filter, on_sale ignored), minus the stored-sale members that a
	 * conservative, active, channel-allowed rule target actually re-quotes away from sale, plus
	 * any such target that the same quote newly puts on sale.
	 */
	private static function resolve_ids( WP_REST_Request $request, bool $on_sale ): array {
		$product_query = new \Automattic\WooCommerce\StoreApi\Utilities\ProductQuery();

		$baseline_request = clone $request;
		$baseline_request->set_param( 'on_sale', null );
		$args = $product_query->prepare_objects_query( $baseline_request );

		$args['posts_per_page'] = -1;
		$args['paged']          = 1;
		$args['offset']         = 0;
		$args['fields']         = 'ids';
		$args['no_found_rows']  = true;

		// Woo's WP_Query ignores post__not_in once post__in is set; resolve the intersection ourselves.
		if ( ! empty( $args['post__in'] ) && ! empty( $args['post__not_in'] ) ) {
			$args['post__in']     = array_values( array_diff( $args['post__in'], $args['post__not_in'] ) );
			$args['post__not_in'] = array();
			if ( ! $args['post__in'] ) { return array(); }
		}

		$clauses_callback = array( $product_query, 'add_query_clauses' );
		add_filter( 'posts_clauses', $clauses_callback, 10, 2 );
		try {
			$baseline_query = new WP_Query();
			$q_ids          = (array) $baseline_query->query( $args );
		} finally {
			remove_filter( 'posts_clauses', $clauses_callback, 10 );
		}
		$q_ids = array_values( array_unique( array_map( 'intval', $q_ids ) ) );

		if ( ! $q_ids ) {
			return array();
		}

		$stored_on_sale = array_map( 'intval', (array) wc_get_product_ids_on_sale() );
		$w              = array_values( array_intersect( $q_ids, $stored_on_sale ) );

		$candidates = self::conservative_targets( $q_ids );
		$evaluated  = array();
		$dynamic    = array();

		if ( $candidates ) {
			self::prime_caches( $candidates );
			$rules = self::active_allowed_rules();
			// Use Woo's price-only schema, without building descriptions, images or extensions.
			$container = \Automattic\WooCommerce\StoreApi\StoreApi::container();
			$schema = new class(
				$container->get( \Automattic\WooCommerce\StoreApi\Schemas\ExtendSchema::class ),
				$container->get( \Automattic\WooCommerce\StoreApi\SchemaController::class )
			) extends \Automattic\WooCommerce\StoreApi\Schemas\V1\ProductSchema {
				public function price_fields( $product ): array { return $this->prepare_product_price_response( $product ); }
			};
			foreach ( $candidates as $id ) {
				$product = wc_get_product( $id );
				if ( ! $product ) {
					continue;
				}
				if ( ! self::matches_rule_scope( $product, $rules ) ) {
					continue;
				}
				$original_sale = $product->is_on_sale();
				$before = $schema->price_fields( $product );
				$quoted = MobiShop_Discount_Rules_Prices::prices( $product, $before );
				$evaluated[] = $id;
				if ( MobiShop_Discount_Rules_Prices::sale_state( $before, $quoted, $original_sale ) ) {
					$dynamic[] = $id;
				}
			}
		}

		$final_set = array_values( array_unique( array_merge( array_diff( $w, $evaluated ), $dynamic ) ) );

		$result_ids = $on_sale
			? array_values( array_intersect( $q_ids, $final_set ) )
			: array_values( array_diff( $q_ids, $final_set ) );

		return self::preserve_include_order( $result_ids, $args );
	}

	/** If the client asked for order=include, the corrected id list must keep that relative order. */
	private static function preserve_include_order( array $result_ids, array $args ): array {
		if ( 'post__in' !== ( $args['orderby'] ?? '' ) || empty( $args['post__in'] ) ) {
			return $result_ids;
		}
		$order_map = array_flip( array_map( 'intval', $args['post__in'] ) );
		usort(
			$result_ids,
			static function ( $a, $b ) use ( $order_map ) {
				return ( $order_map[ $a ] ?? PHP_INT_MAX ) <=> ( $order_map[ $b ] ?? PHP_INT_MAX );
			}
		);
		return $result_ids;
	}

	private static function prime_caches( array $candidates ): void {
		_prime_post_caches( $candidates, true, true );
		$child_ids = array();
		foreach ( $candidates as $id ) {
			$product = wc_get_product( $id );
			if ( $product && $product->is_type( 'variable' ) ) {
				$child_ids = array_merge( $child_ids, $product->get_children() );
			}
		}
		if ( $child_ids ) {
			_prime_post_caches( array_values( array_unique( $child_ids ) ), true, true );
		}
	}

	/** Avoid FlyCart's expensive HTML/sale-badge calculation for products no rule can match.
	 * Use the rule engine itself, including both quote and badge modes and every child.
	 * An unknown engine shape or error retains the product for the original calculation.
	 */
	private static function matches_rule_scope( $product, array $rules ): bool {
		try {
			global $wp_filter;
			foreach ( array( 'woocommerce_product_is_on_sale' => 'isProductInSale', 'advanced_woo_discount_rules_get_product_discount_price' => 'getDiscountPriceOfAProduct' ) as $hook => $method ) {
				foreach ( ( $wp_filter[ $hook ]->callbacks ?? array() ) as $callbacks ) {
					foreach ( $callbacks as $entry ) {
						$callback = $entry['function'];
						if ( ! is_array( $callback ) || ! ( $callback[0] instanceof \Wdr\App\Controllers\ManageDiscount ) || $method !== $callback[1] ) { return true; }
					}
				}
			}
			foreach ( $rules as $rule ) {
				if ( ! is_callable( array( $rule, 'isFilterPassed' ) ) ) { return true; }
			}
			$products = array( $product );
			if ( $product->is_type( 'variable' ) ) {
				foreach ( $product->get_children() as $id ) {
					$child = wc_get_product( $id );
					if ( ! $child ) { return true; }
					$products[] = $child;
				}
			}
			foreach ( $products as $candidate ) {
				foreach ( $rules as $rule ) {
					if ( $rule->isFilterPassed( $candidate, false ) || $rule->isFilterPassed( $candidate, true ) ) {
						return true;
					}
				}
			}
			return false;
		} catch ( Throwable $error ) {
			return true;
		}
	}

	/**
	 * Narrows the quote-eligible candidate set to products a currently active, channel-allowed
	 * rule could plausibly target. Any rule shape, filter type or method this cannot confidently
	 * interpret broadens back to the full baseline set rather than risk dropping an eligible
	 * product; only a recognised, positive (`in_list`) products/category/tag/custom-taxonomy
	 * filter narrows.
	 */
	private static function conservative_targets( array $q_ids ): array {
		$rules = self::active_allowed_rules();
		if ( ! $rules ) {
			return array();
		}

		$q_lookup           = array_flip( $q_ids );
		$custom_taxonomies  = function_exists( 'get_taxonomies' )
			? get_taxonomies( array( 'object_type' => array( 'product' ) ), 'names' )
			: array();
		$union              = array();

		foreach ( $rules as $rule ) {
			if ( ! is_object( $rule ) || ! method_exists( $rule, 'getFilter' ) ) {
				return $q_ids;
			}
			$filters = $rule->getFilter();
			if ( empty( $filters ) ) {
				return $q_ids;
			}
			$rule_union = array();
			$rule_excluded = array();
			$has_positive = false;
			foreach ( (array) $filters as $filter ) {
				$type   = is_object( $filter ) ? ( $filter->type ?? null ) : ( $filter['type'] ?? null );
				$method = is_object( $filter ) ? ( $filter->method ?? 'in_list' ) : ( $filter['method'] ?? 'in_list' );
				$values = is_object( $filter ) ? ( $filter->value ?? array() ) : ( $filter['value'] ?? array() );

				$known = in_array( $type, array( 'products', 'product_category', 'product_tags' ), true ) || in_array( $type, $custom_taxonomies, true );
				// Ignoring a recognised exclusion only widens candidates. With no positive filter
				// the rule could affect all products, so do not narrow at all.
				if ( 'not_in_list' === $method && $known ) {
					if ( is_array( $values ) && self::can_narrow_taxonomy_exclusion( $type ) ) {
						$rule_excluded = array_merge( $rule_excluded, self::term_filter_targets( $values, 'product_category' === $type ? 'product_cat' : 'product_tag', $q_lookup ) );
					}
					continue;
				}
				if ( 'in_list' !== $method || ! is_array( $values ) || ! $values ) {
					return $q_ids;
				}
				$has_positive = true;
				$variants = is_object( $filter ) ? ( $filter->product_variants ?? array() ) : ( $filter['product_variants'] ?? array() );
				if ( is_array( $variants ) ) { $values = array_merge( $values, $variants ); }
				if ( 'products' === $type ) {
					$rule_union = array_merge( $rule_union, self::product_filter_targets( $values, $q_lookup ) );
				} elseif ( 'product_category' === $type ) {
					$rule_union = array_merge( $rule_union, self::term_filter_targets( $values, 'product_cat', $q_lookup ) );
				} elseif ( 'product_tags' === $type ) {
					$rule_union = array_merge( $rule_union, self::term_filter_targets( $values, 'product_tag', $q_lookup ) );
				} elseif ( is_string( $type ) && in_array( $type, $custom_taxonomies, true ) ) {
					$rule_union = array_merge( $rule_union, self::term_filter_targets( $values, $type, $q_lookup ) );
				} else {
					return $q_ids;
				}
			}
			if ( ! $has_positive ) { return $q_ids; }
			$union = array_merge( $union, array_diff( $rule_union, $rule_excluded ) );
		}

		return array_values( array_unique( $union ) );
	}

	/** Category/tag exclusions are unconditional in FlyCart and inherited by all children.
	 * Keep broader candidates whenever another extension can change those memberships.
	 */
	private static function can_narrow_taxonomy_exclusion( $type ): bool {
		if ( ! in_array( $type, array( 'product_category', 'product_tags' ), true ) ) { return false; }
		foreach ( array( 'advanced_woo_discount_rules_filter_passed', 'advanced_woo_discount_rules_customer_condition_filter_passed', 'advanced_woo_discount_rules_get_product_categories', 'woocommerce_product_get_category_ids', 'woocommerce_product_get_tag_ids', 'woocommerce_product_variation_get_parent_id' ) as $hook ) {
			if ( has_filter( $hook ) ) { return false; }
		}
		return true;
	}

	private static function product_filter_targets( array $values, array $q_lookup ): array {
		global $wpdb;
		$targets = array();
		$values = array_values( array_filter( array_map( 'intval', $values ), static fn( $id ) => $id > 0 ) );
		if ( ! $values ) { return array(); }
		// Read only ID/parent pairs, without loading thousands of off-screen product objects.
		$lookup_ids = array_unique( array_merge( array_keys( $q_lookup ), $values ) );
		$parents = array();
		foreach ( $wpdb->get_results( 'SELECT ID, post_parent FROM ' . $wpdb->posts . ' WHERE ID IN (' . implode( ',', array_map( 'intval', $lookup_ids ) ) . ')' ) as $row ) {
			$parents[ (int) $row->ID ] = (int) $row->post_parent;
		}
		$value_lookup = array_fill_keys( $values, true );
		foreach ( $q_lookup as $id => $_ ) {
			if ( isset( $value_lookup[ $parents[ $id ] ?? 0 ] ) ) { $targets[] = (int) $id; }
		}
		foreach ( $values as $value ) {
			$id = (int) $value;
			if ( $id <= 0 ) {
				continue;
			}
			if ( isset( $q_lookup[ $id ] ) ) {
				$targets[] = $id;
			}
			// A targeted variation inherits the parent's terms; the parent is the quoted/served entry.
			$parent_id = $parents[ $id ] ?? 0;
			if ( $parent_id && isset( $q_lookup[ $parent_id ] ) ) {
				$targets[] = $parent_id;
			}
		}
		return $targets;
	}

	private static function term_filter_targets( array $values, string $taxonomy, array $q_lookup ): array {
		$term_ids = array_map( 'intval', array_filter( $values, 'is_numeric' ) );
		if ( ! $term_ids || ! taxonomy_exists( $taxonomy ) ) {
			return array();
		}
		// Direct term ids only: no include_children, matching the rule's own flat match.
		$object_ids = get_objects_in_term( $term_ids, $taxonomy );
		if ( is_wp_error( $object_ids ) || ! $object_ids ) {
			return array();
		}
		return self::product_filter_targets( $object_ids, $q_lookup );
	}

	/** Only currently active, date/usage/language-valid rules allowed on this request's channel. */
	private static function active_allowed_rules(): array {
		if ( ! class_exists( '\\Wdr\\App\\Controllers\\ManageDiscount' ) || ! method_exists( '\\Wdr\\App\\Controllers\\ManageDiscount', 'getDiscountRules' ) ) {
			return array();
		}
		try {
			$rules = ( new \Wdr\App\Controllers\ManageDiscount() )->getDiscountRules();
		} catch ( Throwable $error ) {
			return array();
		}
		if ( ! is_array( $rules ) && ! ( $rules instanceof Traversable ) ) {
			return array();
		}
		$allowed = array();
		foreach ( $rules as $rule ) {
			if ( MobiShop_Discount_Channel::allowed( $rule ) ) {
				$allowed[] = $rule;
			}
		}
		return $allowed;
	}

	/** Matches only the product listing WP_Query made by Woo's own Store API product query. */
	private static function is_target_query( $query ): bool {
		if ( ! ( $query instanceof WP_Query ) || 'ids' !== $query->get( 'fields' ) ) {
			return false;
		}
		if ( ! array_intersect( array( 'product', 'product_variation' ), (array) $query->get( 'post_type' ) ) ) {
			return false;
		}
		$trace = debug_backtrace( DEBUG_BACKTRACE_IGNORE_ARGS, 16 ); // phpcs:ignore WordPress.PHP.DevelopmentFunctions.error_log_debug_backtrace
		foreach ( $trace as $index => $frame ) {
			if ( 'WP_Query' === ( $frame['class'] ?? '' ) && 'query' === ( $frame['function'] ?? '' ) ) {
				$caller = $trace[ $index + 1 ] ?? array();
				return 'Automattic\\WooCommerce\\StoreApi\\Utilities\\ProductQuery' === ( $caller['class'] ?? '' )
					&& 'get_results' === ( $caller['function'] ?? '' );
			}
		}
		return false;
	}
}
MobiShop_Discount_Rules_Catalogue_Query::register();
