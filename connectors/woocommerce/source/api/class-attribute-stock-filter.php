<?php
/** Stock-aware attribute filtering shared by Store API and website catalogs. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Attribute_Stock_Filter {

	public function register(): void {
		add_filter( 'woocommerce_store_api_product_query', array( $this, 'store_query' ), 30, 2 );
		add_filter( 'woof_products_query', array( $this, 'website_query' ), 30 );
		add_filter( 'posts_clauses', array( $this, 'clauses' ), 40, 2 );
		add_filter( 'rest_request_after_callbacks', array( $this, 'available_sizes' ), 30, 3 );
	}

	/** Optional public facets, reusing Woo's validated collection scope and stock rules. */
	public function available_sizes( $response, $handler, $request ) {
		if ( 'GET' !== $request->get_method() || ! in_array( trim( $request->get_route(), '/' ), array( 'wc/store/products/collection-data', 'wc/store/v1/products/collection-data' ), true )
			|| ! in_array( $request->get_param( 'mobishop_available_sizes' ), array( true, 1, '1', 'true' ), true ) || is_wp_error( $response ) ) return $response;
		$response = rest_ensure_response( $response );
		if ( $response->get_status() >= 400 || ! is_array( $response->get_data() ) ) return $response;
		global $wpdb;
		try {
			$selects = array();
			foreach ( get_taxonomies() as $taxonomy ) {
				if ( ! str_starts_with( $taxonomy, 'pa_' ) || ! $this->is_size( $taxonomy ) ) continue;
				$scope = clone $request;
				$scope->set_param( 'attributes', array_values( array_filter( (array) $request->get_param( 'attributes' ), fn( $attribute ) => is_array( $attribute ) && $this->taxonomy( (string) ( $attribute['attribute'] ?? '' ) ) !== $taxonomy ) ) );
				list( $sql, $query ) = $this->compile_scope( $scope );
				$selected = (array) $query->get( 'mobishop_stock_attributes' );
				// The candidate term comes from the fixed SQL alias below, not user SQL.
				$selected[] = array( 'taxonomy' => $taxonomy, 'terms' => array(), 'facet' => true );
				$query->set( 'mobishop_stock_attributes', $selected );
				$predicate = $this->clauses( array( 'where' => '' ), $query )['where'];
				$tax = $wpdb->prepare( '%s', $taxonomy );
				// DISTINCT keeps the scoped IDs inside a materialized DB subquery.
				// Otherwise MySQL may evaluate every store term/variant before search.
				$selects[] = "SELECT DISTINCT {$tax} AS taxonomy, msfacet.slug AS term, msfacet.name AS label
					FROM (SELECT DISTINCT msraw.ID FROM ({$sql}) msraw) msscope
					INNER JOIN {$wpdb->posts} ON {$wpdb->posts}.ID=msscope.ID
					INNER JOIN {$wpdb->term_relationships} msfrel ON msfrel.object_id={$wpdb->posts}.ID
					INNER JOIN {$wpdb->term_taxonomy} msftax ON msftax.term_taxonomy_id=msfrel.term_taxonomy_id AND msftax.taxonomy={$tax}
					INNER JOIN {$wpdb->terms} msfacet ON msfacet.term_id=msftax.term_id
					WHERE 1=1 {$predicate}";
			}
			$rows = $selects ? $wpdb->get_results( implode( ' UNION ALL ', $selects ), ARRAY_A ) : array(); // phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared -- Woo-generated scope and fixed clauses with prepared taxonomy/meta/term values.
			if ( $wpdb->last_error || ! is_array( $rows ) ) throw new RuntimeException( 'Facet query failed.' );
			usort( $rows, fn( $a, $b ) => strnatcasecmp( $a['label'], $b['label'] ) );
			$data = $response->get_data();
			$data['available_sizes'] = $rows;
			$response->set_data( $data );
			return $response;
		} catch ( Throwable $error ) {
			// Do not turn an unavailable metadata read into an authoritative empty list.
			return new WP_Error( 'mobishop_facets_unavailable', __( 'Filters could not be loaded. Please try again.', 'mobishop' ), array( 'status' => 503 ) );
		}
	}

	/** Compile the existing Woo query without materializing every product ID. */
	private function compile_scope( $request ): array {
		$products = new \Automattic\WooCommerce\StoreApi\Utilities\ProductQuery();
		$query = new WP_Query();
		$args = $this->store_query( $products->prepare_objects_query( $request ), $request );
		// Woo omits zero bounds from prepared args; keep validated REST values.
		foreach ( array( 'min_price', 'max_price' ) as $key ) {
			if ( is_numeric( $request->get_param( $key ) ) ) $args[$key] = $request->get_param( $key );
		}
		$args = array_merge( $args, array( 'fields' => 'ids', 'posts_per_page' => -1, 'paged' => 1, 'offset' => 0, 'no_found_rows' => true, 'cache_results' => false, 'orderby' => '', 'order' => '' ) );
		$clauses = static fn( $parts, $current ) => $current === $query ? $products->add_query_clauses( $parts, $current ) : $parts;
		$skip = static fn( $posts, $current ) => $current === $query ? array() : $posts;
		add_filter( 'posts_clauses', $clauses, 10, 2 );
		add_filter( 'posts_pre_query', $skip, PHP_INT_MAX, 2 );
		try {
			$query->query( $args );
			if ( ! is_string( $query->request ) || '' === $query->request ) throw new RuntimeException( 'Missing collection scope.' );
			return array( $query->request, $query );
		} finally {
			remove_filter( 'posts_clauses', $clauses, 10 );
			remove_filter( 'posts_pre_query', $skip, PHP_INT_MAX );
		}
	}

	private function taxonomy( string $name ): string {
		$name = rawurldecode( $name );
		if ( ! str_starts_with( $name, 'pa_' ) ) return '';
		foreach ( get_taxonomies() as $registered ) {
			if ( str_starts_with( $registered, 'pa_' ) && rawurldecode( $registered ) === $name ) return $registered;
		}
		return '';
	}

	private function is_size( string $taxonomy ): bool {
		return (bool) preg_match( '/size|مقاس|taille|talla/iu', rawurldecode( $taxonomy ) . ' ' . wc_attribute_label( $taxonomy ) );
	}

	/** Resolve both translated taxonomy names and WooCommerce term identifiers. */
	private function selection( string $name, $terms, string $field = 'slug' ): ?array {
		$taxonomy = $this->taxonomy( $name );
		if ( '' === $taxonomy ) return null;
		$values = is_array( $terms ) ? $terms : explode( ',', (string) $terms );
		$ids = array();
		foreach ( $values as $value ) {
			if ( ! is_scalar( $value ) ) continue;
			$term = get_term_by( 'term_id' === $field ? 'id' : 'slug', 'term_id' === $field ? absint( $value ) : sanitize_title( (string) $value ), $taxonomy );
			if ( $term && ! is_wp_error( $term ) ) $ids[] = (int) $term->term_id;
		}
		return array( 'taxonomy' => $taxonomy, 'terms' => array_values( array_unique( $ids ) ) );
	}

	public function store_query( array $args, $request ): array {
		$selected = array();
		foreach ( (array) $request->get_param( 'attributes' ) as $attribute ) {
			if ( ! is_array( $attribute ) || 'in' !== strtolower( $attribute['operator'] ?? 'in' ) ) continue;
			$entry = $this->selection( (string) ( $attribute['attribute'] ?? '' ), $attribute['slug'] ?? $attribute['term_id'] ?? array(), isset( $attribute['slug'] ) ? 'slug' : 'term_id' );
			if ( $entry ) $selected[] = $entry;
		}
		$args['mobishop_stock_attributes'] = $selected;
		return $args;
	}

	public function website_query( array $args ): array {
		$args['mobishop_catalog_website'] = true;
		$filters = $this->website_filters();
		$args['mobishop_catalog_prices'] = array_intersect_key( $filters, array( 'min_price' => true, 'max_price' => true ) );
		$args['mobishop_stock_attributes'] = $this->website_selection( $filters );
		return $args;
	}

	private function tax_selection( array $queries ): array {
		$selected = array();
		foreach ( $queries as $item ) {
			if ( ! is_array($item) ) continue;
			if ( isset($item['taxonomy']) && str_starts_with($item['taxonomy'], 'pa_') && 'IN' === strtoupper($item['operator'] ?? 'IN') ) {
				$field = $item['field'] ?? 'term_id';
				if (!in_array($field, array('slug','term_id'), true)) continue;
				$entry = $this->selection($item['taxonomy'], $item['terms'] ?? array(), $field);
				if ($entry) $selected[] = $entry;
			} elseif ( !isset($item['taxonomy']) && 'OR' !== strtoupper($item['relation'] ?? 'AND') ) {
				$selected = array_merge($selected, $this->tax_selection($item));
			}
		}
		return $selected;
	}

	private function website_filters(): array {
		// WOOF's own parser covers its SEO URLs and AJAX requests as well as GET.
		$woof = $GLOBALS['WOOF'] ?? null;
		$values = is_object( $woof ) && is_callable( array( $woof, 'get_request_data' ) ) ? $woof->get_request_data() : array();
		return array_merge( wp_unslash( $_GET ), is_array( $values ) ? $values : array() ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended -- Public catalog filters.
	}

	private function website_selection( array $values ): array {
		$selected = array();
		foreach ( $values as $key => $value ) {
			$key = rawurldecode( (string) $key );
			if ( str_starts_with( $key, 'filter_' ) ) $key = 'pa_' . substr( $key, 7 );
			if ( ! str_starts_with( $key, 'pa_' ) || ! is_scalar( $value ) ) continue;
			$entry = $this->selection( $key, str_replace( '-and-', ',', (string) $value ) );
			if ( $entry ) $selected[] = $entry;
		}
		return $selected;
	}

	/** Only the Store API's public product collection, never cart, account, or individual products. */
	private function is_store_collection( $query ): bool {
		global $wp;
		if ( ! defined( 'REST_REQUEST' ) || ! REST_REQUEST || 'product' !== $query->get( 'post_type' )
			|| 'ids' !== $query->get( 'fields' ) || 'publish' !== $query->get( 'post_status' ) ) return false;
		$route = trim( (string) ( $wp->query_vars['rest_route'] ?? '' ), '/' );
		return in_array( $route, array( 'wc/store/products', 'wc/store/v1/products', 'wc/store/products/collection-data', 'wc/store/v1/products/collection-data' ), true );
	}

	private function is_website_catalog( $query ): bool {
		return ( ! defined( 'REST_REQUEST' ) || ! REST_REQUEST ) && (
			$query->get( 'mobishop_catalog_website' ) || 'product_query' === $query->get( 'wc_query' ) ||
			( $query->is_main_query() && ( $query->is_post_type_archive( 'product' ) || $query->is_tax( get_object_taxonomies( 'product' ) ) ) )
		);
	}

	/** Woo uses decimal prices on the web and minor currency units in the Store API. */
	private function variation_price( $query, bool $api ): string {
		global $wpdb;
		$where = "msprice.post_id = msav.ID AND msprice.meta_key = '_price' AND msprice.meta_value <> ''";
		foreach ( array( 'min_price' => '>=', 'max_price' => '<=' ) as $key => $operator ) {
			// Core can omit a zero bound from the WP_Query even when the public request supplied it.
			$value = $api ? $query->get( $key ) : ( $query->get( 'mobishop_catalog_prices' )[$key] ?? wp_unslash( $_GET[$key] ?? '' ) );
			if ( $api && ! is_numeric( $value ) && isset( $_GET[$key] ) && is_numeric( $_GET[$key] ) && 0.0 === (float) $_GET[$key] ) $value = 0;
			if ( ! is_numeric( $value ) ) continue;
			$limit = (float) $value;
			if ( $api ) $limit /= 10 ** wc_get_price_decimals();
			$price = 'CAST(msprice.meta_value AS DECIMAL(24,8))';
			if ( ! wc_tax_enabled() || ( 'incl' === get_option( 'woocommerce_tax_display_shop' ) ) === wc_prices_include_tax() ) {
				$where .= $wpdb->prepare( " AND {$price} {$operator} %f", $limit );
				continue;
			}
			if ( ! $api ) {
				// Match the core catalog price widget's standard tax class and direction.
				if ( ! wc_prices_include_tax() ) {
					$rates = WC_Tax::get_rates( apply_filters( 'woocommerce_price_filter_widget_tax_class', '' ) );
					$limit -= WC_Tax::get_tax_total( WC_Tax::calc_inclusive_tax( $limit, $rates ) );
				}
				$where .= $wpdb->prepare( " AND {$price} {$operator} %f", $limit );
				continue;
			}
			// The Store API adjusts taxable prices by tax class, separately from non-taxable prices.
			$adjusted = array();
			foreach ( array_merge( array( '' ), WC_Tax::get_tax_class_slugs() ) as $class ) {
				$inclusive = 'incl' === get_option( 'woocommerce_tax_display_shop' );
				$rates = $inclusive && apply_filters( 'woocommerce_adjust_non_base_location_prices', true )
					? WC_Tax::get_base_tax_rates( $class ) : WC_Tax::get_rates( $class );
				$tax = array_sum( WC_Tax::calc_tax( $limit, $rates, $inclusive ) );
				$adjusted[] = $wpdb->prepare( "(COALESCE(NULLIF(msas.tax_class,'parent'),msparent.tax_class) = %s AND {$price} {$operator} %f)", $class, $inclusive ? $limit - $tax : $limit + $tax );
			}
			$parent_test = "(msparent.tax_status='taxable' AND (" . implode( ' OR ', $adjusted ) . ')) OR ' .
				$wpdb->prepare( "(msparent.tax_status<>'taxable' AND {$price} {$operator} %f)", $limit );
			$where .= " AND EXISTS (SELECT 1 FROM {$wpdb->prefix}wc_product_meta_lookup msparent WHERE msparent.product_id=msav.post_parent AND ({$parent_test}))";
		}
		return "EXISTS (SELECT 1 FROM {$wpdb->postmeta} msprice WHERE {$where})";
	}

	/** Filter before LIMIT and FOUND_ROWS, so totals and pagination stay correct. */
	public function clauses( array $clauses, $query ): array {
		if ( is_admin() && ! wp_doing_ajax() ) return $clauses;
		$selected = $query->get( 'mobishop_stock_attributes' );
		if ( ! is_array( $selected ) ) {
			if ( ! ( $query->is_post_type_archive( 'product' ) || $query->is_tax() || 'product' === $query->get( 'post_type' ) ) ) return $clauses;
			$selected = $this->tax_selection( (array) $query->get('tax_query') );
			if ( !$selected && $query->is_main_query() ) $selected = $this->website_selection( $this->website_filters() );
		}
		$size = (bool) array_filter( $selected, fn( $entry ) => $this->is_size( $entry['taxonomy'] ) );
		$api = $this->is_store_collection( $query );
		$catalog = 'yes' === get_option( 'woocommerce_hide_out_of_stock_items' ) && ( $api || $this->is_website_catalog( $query ) );
		if ( ! $size && ! $catalog ) return $clauses;
		global $wpdb;
		$stock = $wpdb->prefix . 'wc_product_meta_lookup';
		$conditions = array();
		$parent_conditions = array();
		foreach ( $selected as $index => $entry ) {
			$facet = ! empty( $entry['facet'] );
			if ( ! $facet && empty( $entry['terms'] ) ) { $clauses['where'] .= ' AND 1=0'; return $clauses; }
			$ids = $facet ? 'msfacet.term_id' : implode( ',', array_map( 'absint', $entry['terms'] ) );
			$keys = array_unique( array( 'attribute_' . rawurldecode( $entry['taxonomy'] ), 'attribute_' . strtolower( rawurlencode( rawurldecode( $entry['taxonomy'] ) ) ) ) );
			$key_sql = implode( ',', array_map( fn($key) => $wpdb->prepare('%s', $key), $keys ) );
			$slugs = array( '' ); // WooCommerce's explicit "Any" variation value.
			foreach ( $entry['terms'] as $id ) { $term = get_term($id, $entry['taxonomy']); if ($term && !is_wp_error($term)) $slugs[] = $term->slug; }
			$value_sql = implode( ',', array_map( fn($value) => $wpdb->prepare('%s', $value), $slugs ) );
			if ( $facet ) $value_sql .= ',msfacet.slug';
			$parent_conditions[] = "EXISTS (SELECT 1 FROM {$wpdb->term_relationships} msatr JOIN {$wpdb->term_taxonomy} msatt ON msatt.term_taxonomy_id=msatr.term_taxonomy_id WHERE msatr.object_id={$wpdb->posts}.ID AND msatt.term_id IN ({$ids}))";
			// Read the actual variation attributes, not the asynchronously rebuilt
			// attribute lookup table. All selected dimensions match the same variant.
			$conditions[] = "(EXISTS (SELECT 1 FROM {$wpdb->postmeta} msam WHERE msam.post_id=msav.ID AND msam.meta_key IN ({$key_sql}) AND msam.meta_value IN ({$value_sql})) OR NOT EXISTS (SELECT 1 FROM {$wpdb->posts} msac JOIN {$wpdb->postmeta} msacm ON msacm.post_id=msac.ID WHERE msac.post_parent={$wpdb->posts}.ID AND msac.post_type='product_variation' AND msacm.meta_key IN ({$key_sql})))";
		}
		if ( $catalog ) {
			$type = get_term_by( 'slug', 'variable', 'product_type' );
			if ( ! $type || is_wp_error( $type ) ) return $clauses;
			// All non-variable types retain WooCommerce's own visibility and price rules.
			$other_products = $wpdb->prepare( "NOT EXISTS (SELECT 1 FROM {$wpdb->term_relationships} mst WHERE mst.object_id={$wpdb->posts}.ID AND mst.term_taxonomy_id=%d)", $type->term_taxonomy_id );
			// Woo drops a zero maximum from its Store API price clauses, including for simple products.
			$max_price = $query->get( 'max_price' );
			if ( ! is_numeric( $max_price ) ) $max_price = wp_unslash( $_GET['max_price'] ?? '' );
			if ( $api && is_numeric( $max_price ) && 0.0 === (float) $max_price ) {
				$other_products = "({$other_products} AND EXISTS (SELECT 1 FROM {$stock} msproduct WHERE msproduct.product_id={$wpdb->posts}.ID AND msproduct.min_price<=0))";
			}
			$conditions[] = $this->variation_price( $query, $api );
			$stock_test = "msas.stock_status IN ('instock','onbackorder')";
		} else {
			$other_products = "(EXISTS (SELECT 1 FROM {$stock} msasimple WHERE msasimple.product_id={$wpdb->posts}.ID AND msasimple.stock_status='instock') AND NOT EXISTS (SELECT 1 FROM {$wpdb->posts} msc WHERE msc.post_parent={$wpdb->posts}.ID AND msc.post_type='product_variation'))";
			$stock_test = "msas.stock_status = 'instock'";
			if ( array_filter( $selected, fn( $entry ) => ! empty( $entry['facet'] ) ) ) $conditions[] = $this->variation_price( $query, $api );
		}
		if ( array_filter( $selected, fn( $entry ) => ! empty( $entry['facet'] ) ) ) {
			$type = get_term_by( 'slug', 'variable', 'product_type' );
			if ( $type && ! is_wp_error( $type ) ) $other_products .= $wpdb->prepare( " AND NOT EXISTS (SELECT 1 FROM {$wpdb->term_relationships} msftype WHERE msftype.object_id={$wpdb->posts}.ID AND msftype.term_taxonomy_id=%d)", $type->term_taxonomy_id );
			$other_products = "({$other_products} AND EXISTS (SELECT 1 FROM {$wpdb->postmeta} msfprice WHERE msfprice.post_id={$wpdb->posts}.ID AND msfprice.meta_key='_price' AND msfprice.meta_value<>''))";
		}
		$matching_variant = "EXISTS (SELECT 1 FROM {$wpdb->posts} msav INNER JOIN {$stock} msas ON msas.product_id=msav.ID WHERE msav.post_parent={$wpdb->posts}.ID AND msav.post_status='publish' AND msav.post_type='product_variation' AND {$stock_test} AND " . implode( ' AND ', $conditions ) . ')';
		$parent_conditions[] = "({$matching_variant} OR {$other_products})";
		$predicate = implode( ' AND ', $parent_conditions );
		$woof_query = $query->get( 'mobishop_catalog_website' ) || 'product_count' === $query->get( 'woof_query' );
		if ( $size && $woof_query && $this->is_website_catalog( $query ) ) {
			// WOOF repeats the same variation checks for each category count in this request.
			static $request_matches = array();
			$key = md5( $wpdb->posts . '.' . $predicate );
			if ( ! array_key_exists( $key, $request_matches ) ) {
				$ids = $wpdb->get_col( "SELECT {$wpdb->posts}.ID FROM {$wpdb->posts} WHERE {$wpdb->posts}.post_type='product' AND {$predicate} LIMIT 10001" ); // phpcs:ignore PluginCheck.Security.DirectDB.UnescapedDBParameter,WordPress.DB.PreparedSQL.InterpolatedNotPrepared -- Predicates come from fixed fragments above, with integer term IDs and individually prepared keys, slugs and prices.
				$request_matches[$key] = false;
				if ( ! $wpdb->last_error && is_array( $ids ) && count( $ids ) <= 10000 ) {
					$request_matches[$key] = $ids ? "{$wpdb->posts}.ID IN (" . implode( ',', array_map( 'absint', $ids ) ) . ')' : '1=0';
				}
			}
			if ( false !== $request_matches[$key] ) $predicate = $request_matches[$key];
			$query->set( 'mobishop_stock_predicate_applied', true );
		}
		$clauses['where'] .= ' AND ' . $predicate;
		return $clauses;
	}
}
