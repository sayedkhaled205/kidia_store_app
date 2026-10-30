<?php
/** Stock-aware attribute filtering shared by Store API and website catalogs. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Attribute_Stock_Filter {

	public function register(): void {
		add_filter( 'woocommerce_store_api_product_query', array( $this, 'store_query' ), 30, 2 );
		add_filter( 'woof_products_query', array( $this, 'website_query' ), 30 );
		add_filter( 'posts_clauses', array( $this, 'clauses' ), 40, 2 );
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
		$args['mobishop_stock_attributes'] = $this->website_selection();
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

	private function website_selection(): array {
		$selected = array();
		// WOOF's own parser covers its SEO URLs and AJAX requests as well as GET.
		$woof = $GLOBALS['WOOF'] ?? null;
		$values = is_object( $woof ) && is_callable( array( $woof, 'get_request_data' ) ) ? $woof->get_request_data() : array();
		$values = array_merge( wp_unslash( $_GET ), is_array( $values ) ? $values : array() ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended -- Public catalog filters.
		foreach ( $values as $key => $value ) {
			$key = rawurldecode( (string) $key );
			if ( str_starts_with( $key, 'filter_' ) ) $key = 'pa_' . substr( $key, 7 );
			if ( ! str_starts_with( $key, 'pa_' ) || ! is_scalar( $value ) ) continue;
			$entry = $this->selection( $key, str_replace( '-and-', ',', (string) $value ) );
			if ( $entry ) $selected[] = $entry;
		}
		return $selected;
	}

	/** Filter before LIMIT and FOUND_ROWS, so totals and pagination stay correct. */
	public function clauses( array $clauses, $query ): array {
		if ( is_admin() && ! wp_doing_ajax() ) return $clauses;
		$selected = $query->get( 'mobishop_stock_attributes' );
		if ( ! is_array( $selected ) ) {
			if ( ! ( $query->is_post_type_archive( 'product' ) || $query->is_tax() || 'product' === $query->get( 'post_type' ) ) ) return $clauses;
			$selected = $this->tax_selection( (array) $query->get('tax_query') );
			if ( !$selected && $query->is_main_query() ) $selected = $this->website_selection();
		}
		if ( ! array_filter( $selected, fn( $entry ) => $this->is_size( $entry['taxonomy'] ) ) ) return $clauses;
		global $wpdb;
		$stock = $wpdb->prefix . 'wc_product_meta_lookup';
		$conditions = array();
		$parent_conditions = array();
		foreach ( $selected as $index => $entry ) {
			if ( empty( $entry['terms'] ) ) { $clauses['where'] .= ' AND 1=0'; return $clauses; }
			$ids = implode( ',', array_map( 'absint', $entry['terms'] ) );
			$keys = array_unique( array( 'attribute_' . rawurldecode( $entry['taxonomy'] ), 'attribute_' . strtolower( rawurlencode( rawurldecode( $entry['taxonomy'] ) ) ) ) );
			$key_sql = implode( ',', array_map( fn($key) => $wpdb->prepare('%s', $key), $keys ) );
			$slugs = array( '' ); // WooCommerce's explicit "Any" variation value.
			foreach ( $entry['terms'] as $id ) { $term = get_term($id, $entry['taxonomy']); if ($term && !is_wp_error($term)) $slugs[] = $term->slug; }
			$value_sql = implode( ',', array_map( fn($value) => $wpdb->prepare('%s', $value), $slugs ) );
			$parent_conditions[] = "EXISTS (SELECT 1 FROM {$wpdb->term_relationships} msatr JOIN {$wpdb->term_taxonomy} msatt ON msatt.term_taxonomy_id=msatr.term_taxonomy_id WHERE msatr.object_id={$wpdb->posts}.ID AND msatt.term_id IN ({$ids}))";
			// Read the actual variation attributes, not the asynchronously rebuilt
			// attribute lookup table. All selected dimensions match the same variant.
			$conditions[] = "(EXISTS (SELECT 1 FROM {$wpdb->postmeta} msam WHERE msam.post_id=msav.ID AND msam.meta_key IN ({$key_sql}) AND msam.meta_value IN ({$value_sql})) OR NOT EXISTS (SELECT 1 FROM {$wpdb->posts} msac JOIN {$wpdb->postmeta} msacm ON msacm.post_id=msac.ID WHERE msac.post_parent={$wpdb->posts}.ID AND msac.post_type='product_variation' AND msacm.meta_key IN ({$key_sql})))";
		}
		$clauses['where'] .= ' AND ' . implode(' AND ', $parent_conditions);
		$clauses['where'] .= " AND (EXISTS (SELECT 1 FROM {$wpdb->posts} msav INNER JOIN {$stock} msas ON msas.product_id = msav.ID WHERE msav.post_parent = {$wpdb->posts}.ID AND msav.post_status = 'publish' AND msav.post_type = 'product_variation' AND msas.stock_status = 'instock' AND " . implode( ' AND ', $conditions ) . ") OR (EXISTS (SELECT 1 FROM {$stock} msasimple WHERE msasimple.product_id={$wpdb->posts}.ID AND msasimple.stock_status='instock') AND NOT EXISTS (SELECT 1 FROM {$wpdb->posts} msc WHERE msc.post_parent={$wpdb->posts}.ID AND msc.post_type='product_variation')))";
		return $clauses;
	}
}
