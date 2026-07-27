<?php
/**
 * Incremental AI Studio analysis jobs.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_AI_Analysis_Job {

	private const JOB_PREFIX = 'kidia_mobile_ai_job_v2_';

	private const ORDER_BATCH = 200;

	private const PRODUCT_BATCH = 120;

	/** Starts one user-owned analysis job without scanning the store. */
	public static function start( int $from, int $to, string $source, int $user_id ): array {
		$source = in_array( $source, array( 'website', 'mobile' ), true ) ? $source : 'all';
		if ( ! function_exists( 'wc_get_orders' ) || ! function_exists( 'wc_get_products' ) ) {
			return array( 'error' => __( 'WooCommerce is required to analyse store data.', 'kidia-mobile-cms' ) );
		}

		$count_query = wc_get_orders(
			self::order_args(
				$from,
				$to,
				$source,
				array(
					'limit'    => 1,
					'page'     => 1,
					'paginate' => true,
					'return'   => 'ids',
				)
			)
		);
		$order_total = is_object( $count_query ) && isset( $count_query->total )
			? absint( $count_query->total )
			: count( (array) $count_query );
		$product_ids = array_values(
			array_filter(
				array_map(
					'absint',
					(array) wc_get_products(
						array(
							'status'       => 'publish',
							'stock_status' => 'instock',
							'limit'        => -1,
							'return'       => 'ids',
							'orderby'      => 'ID',
							'order'        => 'ASC',
						)
					)
				)
			)
		);
		$job_id = wp_generate_uuid4();
		$job    = array(
			'id'                => $job_id,
			'user_id'           => $user_id,
			'from'              => $from,
			'to'                => $to,
			'source'            => $source,
			'phase'             => $order_total > 0 ? 'orders' : 'products',
			'order_page'        => 1,
			'orders_processed'  => 0,
			'order_total'       => $order_total,
			'product_ids'       => $product_ids,
			'product_offset'    => 0,
			'products_processed'=> 0,
			'snapshot'          => Kidia_Mobile_Analytics::empty_commerce_snapshot(),
			'customers'         => array(),
			'products'          => array(),
			'product_customers' => array(),
			'pairs'             => array(),
			'hours'             => array(),
			'catalog_rows'      => array(),
			'started_at'        => time(),
		);
		set_transient( self::key( $job_id ), $job, 2 * HOUR_IN_SECONDS );

		return self::payload( $job, false );
	}

	/** Processes exactly one bounded batch and returns measured progress. */
	public static function step( string $job_id, int $user_id ): array {
		$job = get_transient( self::key( $job_id ) );
		if ( ! is_array( $job ) || absint( $job['user_id'] ?? 0 ) !== $user_id ) {
			return array( 'error' => __( 'The analysis job expired. Start the analysis again.', 'kidia-mobile-cms' ) );
		}

		$phase = (string) ( $job['phase'] ?? '' );
		if ( 'orders' === $phase ) {
			self::process_order_batch( $job );
		} elseif ( 'products' === $phase ) {
			self::process_product_batch( $job );
		} elseif ( 'finalize' === $phase ) {
			self::finalize( $job );
			delete_transient( self::key( $job_id ) );
			return self::payload( $job, true );
		}

		set_transient( self::key( $job_id ), $job, 2 * HOUR_IN_SECONDS );
		return self::payload( $job, false );
	}

	/** Adds a real WooCommerce order batch to the analytical accumulator. */
	private static function process_order_batch( array &$job ): void {
		$result = wc_get_orders(
			self::order_args(
				absint( $job['from'] ),
				absint( $job['to'] ),
				(string) $job['source'],
				array(
					'limit'    => self::ORDER_BATCH,
					'page'     => max( 1, absint( $job['order_page'] ) ),
					'paginate' => false,
					'return'   => 'objects',
				)
			)
		);
		$batch          = is_array( $result ) ? $result : array();
		$available      = array_fill_keys( array_map( 'absint', (array) $job['product_ids'] ), true );
		$processed_rows = 0;
		foreach ( $batch as $order ) {
			if ( ! $order instanceof WC_Order ) {
				continue;
			}
			++$processed_rows;
			++$job['snapshot']['orders'];
			$job['snapshot']['revenue'] += max( 0, (float) $order->get_total() );
			$customer_key = $order->get_customer_id() > 0
				? 'user-' . $order->get_customer_id()
				: 'email-' . hash( 'sha256', strtolower( (string) $order->get_billing_email() ) );
			$job['customers'][ $customer_key ] = true;
			$order_product_ids = array();
			foreach ( $order->get_items() as $item ) {
				$product_id = absint( $item->get_product_id() );
				if ( $product_id <= 0 || ! isset( $available[ $product_id ] ) ) {
					continue;
				}
				$quantity = max( 1, absint( $item->get_quantity() ) );
				$job['snapshot']['units'] += $quantity;
				if ( ! isset( $job['products'][ $product_id ] ) ) {
					$job['products'][ $product_id ] = array(
						'object_id'      => $product_id,
						'event_label'    => sanitize_text_field( $item->get_name() ),
						'event_count'    => 0,
						'unique_clients' => 0,
						'order_count'    => 0,
						'revenue'        => 0.0,
					);
				}
				$job['products'][ $product_id ]['event_count'] += $quantity;
				$job['products'][ $product_id ]['order_count'] += 1;
				$job['products'][ $product_id ]['revenue'] += max( 0, (float) $item->get_total() );
				$job['product_customers'][ $product_id ][ $customer_key ] = true;
				$order_product_ids[] = $product_id;
			}
			$order_product_ids = array_values( array_unique( $order_product_ids ) );
			sort( $order_product_ids );
			for ( $left = 0; $left < count( $order_product_ids ); ++$left ) {
				for ( $right = $left + 1; $right < count( $order_product_ids ); ++$right ) {
					$key = $order_product_ids[ $left ] . ':' . $order_product_ids[ $right ];
					$job['pairs'][ $key ] = ( $job['pairs'][ $key ] ?? 0 ) + 1;
				}
			}
			$created = $order->get_date_created();
			if ( $created ) {
				$hour = absint( wp_date( 'G', $created->getTimestamp() ) );
				$job['hours'][ $hour ] = ( $job['hours'][ $hour ] ?? 0 ) + 1;
			}
		}
		$job['orders_processed'] = min(
			absint( $job['order_total'] ),
			absint( $job['orders_processed'] ) + $processed_rows
		);
		++$job['order_page'];
		if (
			empty( $batch )
			|| absint( $job['orders_processed'] ) >= absint( $job['order_total'] )
		) {
			$job['phase'] = 'products';
		}
	}

	/** Reads the next in-stock catalog batch and records live product evidence. */
	private static function process_product_batch( array &$job ): void {
		$offset = absint( $job['product_offset'] );
		$ids    = array_slice( (array) $job['product_ids'], $offset, self::PRODUCT_BATCH );
		foreach ( $ids as $product_id ) {
			$product = function_exists( 'wc_get_product' ) ? wc_get_product( absint( $product_id ) ) : null;
			if ( ! $product instanceof WC_Product || ! $product->is_in_stock() ) {
				continue;
			}
			$created = $product->get_date_created();
			$stock   = $product->managing_stock() ? max( 0, (int) $product->get_stock_quantity() ) : null;
			$row     = array(
				'id'            => $product->get_id(),
				'name'          => $product->get_name(),
				'price'         => max( 0, (float) $product->get_price() ),
				'regular_price' => max( 0, (float) $product->get_regular_price() ),
				'stock'         => $stock,
				'age_days'      => $created ? max( 1, (int) floor( ( time() - $created->getTimestamp() ) / DAY_IN_SECONDS ) ) : 1,
				'image_url'     => $product->get_image_id() ? (string) wp_get_attachment_image_url( $product->get_image_id(), 'woocommerce_thumbnail' ) : '',
			);
			$job['catalog_rows'][] = $row;
			if ( isset( $job['products'][ $product->get_id() ] ) ) {
				$job['products'][ $product->get_id() ] = array_merge(
					$job['products'][ $product->get_id() ],
					array(
						'price'         => $row['price'],
						'regular_price' => $row['regular_price'],
						'stock'         => $row['stock'],
						'image_url'     => $row['image_url'],
					)
				);
			}
		}
		$job['product_offset']     = $offset + count( $ids );
		$job['products_processed'] = min( count( (array) $job['product_ids'] ), absint( $job['product_offset'] ) );
		if ( empty( $ids ) || absint( $job['product_offset'] ) >= count( (array) $job['product_ids'] ) ) {
			$job['phase'] = 'finalize';
		}
	}

	/** Stores the complete snapshot, clears derived caches and generates decisions. */
	private static function finalize( array &$job ): void {
		$snapshot = $job['snapshot'];
		$snapshot['customers'] = count( (array) $job['customers'] );
		$snapshot['average_order_value'] = $snapshot['orders'] > 0
			? round( $snapshot['revenue'] / $snapshot['orders'], 2 )
			: 0.0;
		foreach ( $job['products'] as $product_id => &$product_row ) {
			$product_row['unique_clients'] = count( $job['product_customers'][ $product_id ] ?? array() );
			$product_row['order_share'] = $snapshot['orders'] > 0
				? round( 100 * absint( $product_row['order_count'] ) / $snapshot['orders'], 1 )
				: 0.0;
		}
		unset( $product_row );
		uasort( $job['products'], static fn( $left, $right ) => $right['event_count'] <=> $left['event_count'] );
		$snapshot['products']      = array_values( $job['products'] );
		$snapshot['product_sales'] = array_map(
			static fn( $row ) => absint( $row['event_count'] ?? 0 ),
			$job['products']
		);
		arsort( $job['pairs'] );
		foreach ( array_slice( $job['pairs'], 0, 50, true ) as $key => $count ) {
			$ids = array_map( 'absint', explode( ':', (string) $key ) );
			$snapshot['pairs'][] = array(
				'product_ids' => $ids,
				'names'       => array_map(
					static fn( int $id ): string => sanitize_text_field( (string) ( $job['products'][ $id ]['event_label'] ?? '#' . $id ) ),
					$ids
				),
				'count'       => absint( $count ),
			);
		}
		arsort( $job['hours'] );
		foreach ( array_slice( $job['hours'], 0, 24, true ) as $hour => $count ) {
			$snapshot['activity_hours'][] = array( 'hour' => absint( $hour ), 'event_count' => absint( $count ) );
		}
		$snapshot['catalog_products'] = function_exists( 'wp_count_posts' ) ? absint( wp_count_posts( 'product' )->publish ?? 0 ) : 0;
		$snapshot['catalog_in_stock'] = count( $job['catalog_rows'] );
		$snapshot['catalog_rows']     = array_values( $job['catalog_rows'] );
		$snapshot['orders_scanned']   = absint( $job['orders_processed'] );
		$snapshot['orders_available'] = absint( $job['order_total'] );
		$snapshot['truncated']        = $snapshot['orders_scanned'] < $snapshot['orders_available'];
		Kidia_Mobile_Analytics::store_commerce_snapshot(
			absint( $job['from'] ),
			absint( $job['to'] ),
			(string) $job['source'],
			$snapshot
		);
		Kidia_Mobile_AI_Offer_Engine::clear_cache( absint( $job['from'] ), absint( $job['to'] ), (string) $job['source'] );
		Kidia_Mobile_AI_Offer_Engine::recommendations( absint( $job['from'] ), absint( $job['to'] ), (string) $job['source'] );
		$job['snapshot'] = $snapshot;
		$job['phase']    = 'complete';
	}

	/** Common WooCommerce order query. */
	private static function order_args( int $from, int $to, string $source, array $override ): array {
		$args = array_merge(
			array(
				'status'       => function_exists( 'wc_get_is_paid_statuses' ) ? wc_get_is_paid_statuses() : array( 'processing', 'completed' ),
				'date_created' => $from . '...' . $to,
				'orderby'      => 'date',
				'order'        => 'DESC',
			),
			$override
		);
		if ( 'mobile' === $source ) {
			$args['meta_query'] = array( array( 'key' => '_kidia_order_source', 'value' => 'mobile' ) );
		} elseif ( 'website' === $source ) {
			$args['meta_query'] = array(
				'relation' => 'OR',
				array( 'key' => '_kidia_order_source', 'compare' => 'NOT EXISTS' ),
				array( 'key' => '_kidia_order_source', 'value' => 'website' ),
			);
		}
		return $args;
	}

	/** Builds a measured progress payload for the browser. */
	private static function payload( array $job, bool $done ): array {
		$order_total   = absint( $job['order_total'] ?? 0 );
		$product_total = count( (array) ( $job['product_ids'] ?? array() ) );
		$total         = max( 1, $order_total + $product_total );
		$processed     = min(
			$total,
			absint( $job['orders_processed'] ?? 0 ) + absint( $job['products_processed'] ?? 0 )
		);
		$progress = $done ? 100 : min( 99, (int) floor( 100 * $processed / $total ) );
		$phase    = (string) ( $job['phase'] ?? 'orders' );
		$stage    = __( 'Reading paid WooCommerce orders', 'kidia-mobile-cms' );
		if ( 'products' === $phase ) {
			$stage = __( 'Checking every currently in-stock product', 'kidia-mobile-cms' );
		} elseif ( in_array( $phase, array( 'finalize', 'complete' ), true ) ) {
			$stage = __( 'Ranking data-backed offers and decisions', 'kidia-mobile-cms' );
		}
		return array(
			'job_id'             => (string) $job['id'],
			'done'               => $done,
			'phase'              => $phase,
			'stage'              => $stage,
			'progress'           => $progress,
			'processed'          => $processed,
			'total'              => $total,
			'orders_processed'   => absint( $job['orders_processed'] ?? 0 ),
			'orders_total'       => $order_total,
			'products_processed' => absint( $job['products_processed'] ?? 0 ),
			'products_total'     => $product_total,
		);
	}

	private static function key( string $job_id ): string {
		return self::JOB_PREFIX . md5( $job_id );
	}
}
