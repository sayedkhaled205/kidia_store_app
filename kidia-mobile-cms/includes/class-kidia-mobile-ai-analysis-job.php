<?php
/**
 * Incremental AI Studio analysis jobs.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_AI_Analysis_Job {

	private const JOB_PREFIX = 'kidia_mobile_ai_job_v4_';

	private const CANCEL_PREFIX = 'kidia_mobile_ai_cancel_v1_';

	private const STEP_LOCK_PREFIX = 'kidia_mobile_ai_step_lock_v1_';

	private const ACTIVE_JOB_META = '_kidia_mobile_active_ai_job_v1';

	private const BACKGROUND_HOOK = 'kidia_mobile_run_ai_analysis_job';

	private const ORDER_BATCH = 200;

	private const PRODUCT_BATCH = 120;

	private const MAX_PAIR_KEYS = 1200;

	private const CUSTOMER_BITMAP_BYTES = 8192;

	/** Registers the server-side runner used after an analysis is parked. */
	public static function register(): void {
		add_action( self::BACKGROUND_HOOK, array( self::class, 'run_background' ), 10, 1 );
	}

	/** Starts one user-owned analysis job without scanning the store. */
	public static function start( int $from, int $to, string $source, int $user_id ): array {
		$source = in_array( $source, array( 'website', 'mobile' ), true ) ? $source : 'all';
		if ( ! function_exists( 'wc_get_orders' ) || ! function_exists( 'wc_get_products' ) ) {
			return array( 'error' => __( 'WooCommerce is required to analyse store data.', 'kidia-mobile-cms' ) );
		}
		$existing_job_id = self::active_job_id( $user_id );
		if ( '' !== $existing_job_id ) {
			$existing_job = get_transient( self::key( $existing_job_id ) );
			if ( is_array( $existing_job ) && ! in_array( (string) ( $existing_job['phase'] ?? '' ), array( 'complete', 'cancelled' ), true ) ) {
				self::cancel( $existing_job_id, $user_id );
			}
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
			'products'          => array(),
			'pairs'             => array(),
			'hours'             => array(),
			'customer_bitmap'   => str_repeat( "\0", self::CUSTOMER_BITMAP_BYTES ),
			'background'        => false,
			'started_at'        => time(),
			'updated_at'        => time(),
		);
		set_transient( self::key( $job_id ), $job, 2 * HOUR_IN_SECONDS );
		update_user_meta( $user_id, self::ACTIVE_JOB_META, $job_id );

		return self::payload( $job, false );
	}

	/** Processes exactly one bounded batch and returns measured progress. */
	public static function step( string $job_id, int $user_id ): array {
		$job = get_transient( self::key( $job_id ) );
		if ( ! is_array( $job ) || absint( $job['user_id'] ?? 0 ) !== $user_id ) {
			return array( 'error' => __( 'The analysis job expired. Start the analysis again.', 'kidia-mobile-cms' ) );
		}
		if ( self::is_cancelled( $job_id ) || 'cancelled' === (string) ( $job['phase'] ?? '' ) ) {
			$job['phase'] = 'cancelled';
			set_transient( self::key( $job_id ), $job, HOUR_IN_SECONDS );
			return self::payload( $job, true );
		}
		if ( 'complete' === (string) ( $job['phase'] ?? '' ) ) {
			return self::payload( $job, true );
		}
		$lock = get_transient( self::step_lock_key( $job_id ) );
		if ( $lock ) {
			$lock_started = is_array( $lock ) ? absint( $lock['started_at'] ?? 0 ) : time();
			if ( $lock_started > 0 && time() - $lock_started < 45 ) {
				return self::payload( $job, false );
			}
			delete_transient( self::step_lock_key( $job_id ) );
		}
		set_transient(
			self::step_lock_key( $job_id ),
			array(
				'started_at' => time(),
				'token'      => wp_generate_uuid4(),
			),
			MINUTE_IN_SECONDS
		);

		$phase = (string) ( $job['phase'] ?? '' );
		if ( 'orders' === $phase ) {
			self::process_order_batch( $job );
		} elseif ( 'products' === $phase ) {
			self::process_product_batch( $job );
		} elseif ( 'finalize' === $phase ) {
			self::finalize( $job );
			$job['completed_at'] = time();
			set_transient( self::key( $job_id ), $job, 6 * HOUR_IN_SECONDS );
			delete_transient( self::step_lock_key( $job_id ) );
			return self::payload( $job, true );
		}

		if ( self::is_cancelled( $job_id ) ) {
			$job['phase'] = 'cancelled';
		}
		$job['updated_at'] = time();
		set_transient( self::key( $job_id ), $job, 2 * HOUR_IN_SECONDS );
		delete_transient( self::step_lock_key( $job_id ) );
		return self::payload( $job, 'cancelled' === (string) $job['phase'] );
	}

	/** Returns the current state and can safely advance one batch as a scheduler fallback. */
	public static function status( string $job_id, int $user_id, bool $advance = false ): array {
		$job = get_transient( self::key( $job_id ) );
		if ( ! is_array( $job ) || absint( $job['user_id'] ?? 0 ) !== $user_id ) {
			return array( 'error' => __( 'The analysis job expired. Start the analysis again.', 'kidia-mobile-cms' ) );
		}
		$done = in_array( (string) ( $job['phase'] ?? '' ), array( 'complete', 'cancelled' ), true );
		if ( $advance && ! $done ) {
			return self::step( $job_id, $user_id );
		}
		return self::payload( $job, $done );
	}

	/** Parks a browser-owned job and schedules it on the server. */
	public static function continue_in_background( string $job_id, int $user_id ): array {
		$job = get_transient( self::key( $job_id ) );
		if ( ! is_array( $job ) || absint( $job['user_id'] ?? 0 ) !== $user_id ) {
			return array( 'error' => __( 'The analysis job expired. Start the analysis again.', 'kidia-mobile-cms' ) );
		}
		if ( in_array( (string) ( $job['phase'] ?? '' ), array( 'complete', 'cancelled' ), true ) ) {
			return self::payload( $job, true );
		}
		$job['background'] = true;
		set_transient( self::key( $job_id ), $job, 2 * HOUR_IN_SECONDS );
		self::schedule_background( $job_id );
		return self::payload( $job, false );
	}

	/** Cancels future batches without publishing a partial result. */
	public static function cancel( string $job_id, int $user_id ): array {
		$job = get_transient( self::key( $job_id ) );
		if ( ! is_array( $job ) || absint( $job['user_id'] ?? 0 ) !== $user_id ) {
			return array( 'error' => __( 'The analysis job expired. Start the analysis again.', 'kidia-mobile-cms' ) );
		}
		set_transient( self::cancel_key( $job_id ), 1, HOUR_IN_SECONDS );
		$job['phase']        = 'cancelled';
		$job['cancelled_at'] = time();
		set_transient( self::key( $job_id ), $job, HOUR_IN_SECONDS );
		delete_user_meta( $user_id, self::ACTIVE_JOB_META, $job_id );
		return self::payload( $job, true );
	}

	/** Returns the current user's last running or completed background job id. */
	public static function active_job_id( int $user_id ): string {
		$job_id = sanitize_text_field( (string) get_user_meta( $user_id, self::ACTIVE_JOB_META, true ) );
		if ( '' !== $job_id && ! is_array( get_transient( self::key( $job_id ) ) ) ) {
			delete_user_meta( $user_id, self::ACTIVE_JOB_META, $job_id );
			return '';
		}
		return $job_id;
	}

	/** Removes a completed job from the user's global progress dock. */
	public static function dismiss( string $job_id, int $user_id ): void {
		delete_user_meta( $user_id, self::ACTIVE_JOB_META, $job_id );
	}

	/** Runs one queued batch, then queues the next one until completion. */
	public static function run_background( string $job_id ): void {
		$job = get_transient( self::key( $job_id ) );
		if ( ! is_array( $job ) ) {
			return;
		}
		$user_id = absint( $job['user_id'] ?? 0 );
		if ( $user_id <= 0 ) {
			return;
		}
		$result = self::step( $job_id, $user_id );
		if ( isset( $result['error'] ) || ! empty( $result['done'] ) || ! empty( $result['cancelled'] ) ) {
			return;
		}
		self::schedule_background( $job_id, true );
	}

	/** Enqueues the next server-side batch with Action Scheduler when available. */
	private static function schedule_background( string $job_id, bool $from_runner = false ): void {
		$args = array( $job_id );
		if ( ! $from_runner && function_exists( 'as_has_scheduled_action' ) && as_has_scheduled_action( self::BACKGROUND_HOOK, $args, 'kidia-mobile-cms' ) ) {
			return;
		}
		if ( function_exists( 'as_enqueue_async_action' ) ) {
			as_enqueue_async_action( self::BACKGROUND_HOOK, $args, 'kidia-mobile-cms', false );
			return;
		}
		if ( ! wp_next_scheduled( self::BACKGROUND_HOOK, $args ) ) {
			wp_schedule_single_event( time() + 1, self::BACKGROUND_HOOK, $args );
		}
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
					'paginate' => true,
					'return'   => 'objects',
				)
			)
		);
		$batch          = is_object( $result ) && isset( $result->orders )
			? (array) $result->orders
			: ( is_array( $result ) ? $result : array() );
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
			self::bitmap_add( $job['customer_bitmap'], $customer_key );
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
						'id'             => $product_id,
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
		if ( count( $job['pairs'] ) > self::MAX_PAIR_KEYS * 2 ) {
			arsort( $job['pairs'] );
			$job['pairs'] = array_slice( $job['pairs'], 0, self::MAX_PAIR_KEYS, true );
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
			$sales_row = is_array( $job['products'][ $product->get_id() ] ?? null )
				? $job['products'][ $product->get_id() ]
				: array(
					'id'             => $product->get_id(),
					'object_id'      => $product->get_id(),
					'event_label'    => $product->get_name(),
					'event_count'    => 0,
					'unique_clients' => 0,
					'order_count'    => 0,
					'revenue'        => 0.0,
				);
			$job['products'][ $product->get_id() ] = array_merge( $sales_row, $row );
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
		$snapshot['customers'] = self::bitmap_estimate( (string) $job['customer_bitmap'] );
		$snapshot['average_order_value'] = $snapshot['orders'] > 0
			? round( $snapshot['revenue'] / $snapshot['orders'], 2 )
			: 0.0;
		foreach ( $job['products'] as $product_id => &$product_row ) {
			$product_row['unique_clients'] = absint( $product_row['order_count'] ?? 0 );
			$product_row['order_share'] = $snapshot['orders'] > 0
				? round( 100 * absint( $product_row['order_count'] ) / $snapshot['orders'], 1 )
				: 0.0;
		}
		unset( $product_row );
		$catalog_rows = array_values( $job['products'] );
		$sold_rows    = array_filter(
			$job['products'],
			static fn( $row ) => absint( $row['event_count'] ?? 0 ) > 0
		);
		uasort( $sold_rows, static fn( $left, $right ) => $right['event_count'] <=> $left['event_count'] );
		$snapshot['products']      = array_values( $sold_rows );
		$snapshot['product_sales'] = array();
		foreach ( $job['products'] as $product_id => $product_row ) {
			$snapshot['product_sales'][ absint( $product_id ) ] = absint( $product_row['event_count'] ?? 0 );
		}
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
		$snapshot['catalog_in_stock'] = count( $catalog_rows );
		$snapshot['catalog_rows']     = $catalog_rows;
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
		$cancelled = 'cancelled' === (string) ( $job['phase'] ?? '' );
		$progress = $done && ! $cancelled
			? 100
			: min( 99.9, round( 10 * ( 100 * $processed / $total ) ) / 10 );
		$phase    = (string) ( $job['phase'] ?? 'orders' );
		$stage    = __( 'Reading paid WooCommerce orders', 'kidia-mobile-cms' );
		if ( 'products' === $phase ) {
			$stage = __( 'Checking every currently in-stock product', 'kidia-mobile-cms' );
		} elseif ( in_array( $phase, array( 'finalize', 'complete' ), true ) ) {
			$stage = __( 'Ranking data-backed offers and decisions', 'kidia-mobile-cms' );
		} elseif ( 'cancelled' === $phase ) {
			$stage = __( 'Analysis cancelled. No partial result was published.', 'kidia-mobile-cms' );
		}
		return array(
			'job_id'             => (string) $job['id'],
			'done'               => $done,
			'cancelled'          => $cancelled,
			'background'         => ! empty( $job['background'] ),
			'phase'              => $phase,
			'stage'              => $stage,
			'progress'           => $progress,
			'processed'          => $processed,
			'total'              => $total,
			'orders_processed'   => absint( $job['orders_processed'] ?? 0 ),
			'orders_total'       => $order_total,
			'products_processed' => absint( $job['products_processed'] ?? 0 ),
			'products_total'     => $product_total,
			'result_url'         => add_query_arg(
				array(
					'page'        => 'kidia-mobile-ai-insights',
					'ai_source'   => (string) ( $job['source'] ?? 'all' ),
					'ai_kind'     => 'all',
					'date_preset' => 'custom',
					'date_from'   => wp_date( 'Y-m-d', absint( $job['from'] ?? 0 ) ),
					'date_to'     => wp_date( 'Y-m-d', absint( $job['to'] ?? 0 ) ),
					'ai_generate' => '1',
					'ai_ready'    => '1',
				),
				admin_url( 'admin.php' )
			),
		);
	}

	private static function key( string $job_id ): string {
		return self::JOB_PREFIX . md5( $job_id );
	}

	private static function cancel_key( string $job_id ): string {
		return self::CANCEL_PREFIX . md5( $job_id );
	}

	private static function step_lock_key( string $job_id ): string {
		return self::STEP_LOCK_PREFIX . md5( $job_id );
	}

	private static function is_cancelled( string $job_id ): bool {
		return (bool) get_transient( self::cancel_key( $job_id ) );
	}

	/** Adds a customer identifier to a fixed-size probabilistic set. */
	private static function bitmap_add( string &$bitmap, string $customer_key ): void {
		if ( strlen( $bitmap ) !== self::CUSTOMER_BITMAP_BYTES ) {
			$bitmap = str_repeat( "\0", self::CUSTOMER_BITMAP_BYTES );
		}
		$hash       = unpack( 'Nvalue', substr( hash( 'sha256', $customer_key, true ), 0, 4 ) );
		$bit        = absint( $hash['value'] ?? 0 ) % ( self::CUSTOMER_BITMAP_BYTES * 8 );
		$byte_index = intdiv( $bit, 8 );
		$mask       = 1 << ( $bit % 8 );
		$bitmap[ $byte_index ] = chr( ord( $bitmap[ $byte_index ] ) | $mask );
	}

	/** Estimates distinct customers without storing thousands of hashes in one transient. */
	private static function bitmap_estimate( string $bitmap ): int {
		$bits      = self::CUSTOMER_BITMAP_BYTES * 8;
		$set_bits  = 0;
		$byte_count = min( self::CUSTOMER_BITMAP_BYTES, strlen( $bitmap ) );
		for ( $index = 0; $index < $byte_count; ++$index ) {
			$value = ord( $bitmap[ $index ] );
			while ( $value > 0 ) {
				$set_bits += $value & 1;
				$value >>= 1;
			}
		}
		$zero_bits = max( 1, $bits - $set_bits );
		return max( 0, (int) round( -$bits * log( $zero_bits / $bits ) ) );
	}
}
