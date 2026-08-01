<?php
/**
 * Incremental AI Studio analysis jobs.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_AI_Analysis_Job {

	private const JOB_PREFIX = 'kidia_mobile_ai_job_v6_';

	private const CANCEL_PREFIX = 'kidia_mobile_ai_cancel_v1_';

	private const STEP_LOCK_PREFIX = 'kidia_mobile_ai_step_lock_v2_';

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
	public static function start( int $from, int $to, string $source, int $user_id, string $date_preset = 'custom' ): array {
		$source = in_array( $source, array( 'website', 'mobile' ), true ) ? $source : 'all';
		$date_preset = self::sanitize_date_preset( $date_preset );
		if ( ! function_exists( 'wc_get_orders' ) ) {
			return array( 'error' => __( 'WooCommerce is required to analyse store data.', 'kidia-mobile-cms' ) );
		}
		$existing_job_id = self::active_job_id( $user_id );
		if ( '' !== $existing_job_id ) {
			$existing_job = self::read_job( $existing_job_id );
			if ( is_array( $existing_job ) && ! in_array( (string) ( $existing_job['phase'] ?? '' ), array( 'complete', 'cancelled' ), true ) ) {
				self::cancel( $existing_job_id, $user_id );
			} else {
				self::delete_job( $existing_job_id );
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
					'return'   => 'objects',
				)
			)
		);
		$order_total = is_object( $count_query ) && isset( $count_query->total )
			? absint( $count_query->total )
			: count( (array) $count_query );
		$product_ids = self::in_stock_product_ids();
		$job_id = wp_generate_uuid4();
		$job    = array(
			'id'                => $job_id,
			'user_id'           => $user_id,
			'from'              => $from,
			'to'                => $to,
			'date_preset'       => $date_preset,
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
			/*
			 * Keep the bitmap database-safe. Raw binary eventually contains
			 * invalid utf8mb4 bytes and makes update_option() fail on MySQL.
			 */
			'customer_bitmap'   => str_repeat( '00', self::CUSTOMER_BITMAP_BYTES ),
			'background'        => false,
			'revision'          => 0,
			'started_at'        => time(),
			'updated_at'        => time(),
		);
		if ( ! self::write_job( $job, 2 * HOUR_IN_SECONDS ) ) {
			return array( 'error' => __( 'The analysis could not be started because its durable state could not be saved.', 'kidia-mobile-cms' ) );
		}
		update_user_meta( $user_id, self::ACTIVE_JOB_META, $job_id );

		return self::payload( $job, false );
	}

	/** Processes exactly one bounded batch and returns measured progress. */
	public static function step( string $job_id, int $user_id ): array {
		$job = self::read_job( $job_id );
		if ( ! is_array( $job ) || absint( $job['user_id'] ?? 0 ) !== $user_id ) {
			return array( 'error' => __( 'The analysis job expired. Start the analysis again.', 'kidia-mobile-cms' ) );
		}
		if ( self::is_cancelled( $job_id ) || 'cancelled' === (string) ( $job['phase'] ?? '' ) ) {
			$job['phase'] = 'cancelled';
			self::write_job( $job, HOUR_IN_SECONDS );
			return self::payload( $job, true );
		}
		if ( in_array( (string) ( $job['phase'] ?? '' ), array( 'complete', 'failed' ), true ) ) {
			return self::payload( $job, true );
		}

		$lock_token = self::acquire_step_lock( $job_id );
		if ( '' === $lock_token ) {
			$latest = self::read_job( $job_id );
			$latest = is_array( $latest ) ? $latest : $job;
			return self::payload( $latest, false, true );
		}

		/*
		 * A scheduler request and a browser request can arrive together. Always
		 * reload after owning the atomic lock so an older request can never
		 * overwrite a batch that another runner has already saved.
		 */
		$latest = self::read_job( $job_id );
		if ( ! is_array( $latest ) || absint( $latest['user_id'] ?? 0 ) !== $user_id ) {
			self::release_step_lock( $job_id, $lock_token );
			return array( 'error' => __( 'The analysis job expired. Start the analysis again.', 'kidia-mobile-cms' ) );
		}
		$job = $latest;
		if ( self::is_cancelled( $job_id ) || 'cancelled' === (string) ( $job['phase'] ?? '' ) ) {
			$job['phase'] = 'cancelled';
			self::write_job( $job, HOUR_IN_SECONDS );
			self::release_step_lock( $job_id, $lock_token );
			return self::payload( $job, true );
		}
		if ( in_array( (string) ( $job['phase'] ?? '' ), array( 'complete', 'failed' ), true ) ) {
			self::release_step_lock( $job_id, $lock_token );
			return self::payload( $job, true );
		}

		$phase = (string) ( $job['phase'] ?? '' );
		if ( 'orders' === $phase ) {
			self::process_order_batch( $job );
		} elseif ( 'products' === $phase ) {
			self::process_product_batch( $job );
		} elseif ( 'finalize' === $phase ) {
			self::finalize( $job );
			$job['completed_at'] = time();
			$job['revision'] = absint( $job['revision'] ?? 0 ) + 1;
			if ( ! self::write_job( $job, 6 * HOUR_IN_SECONDS ) ) {
				self::release_step_lock( $job_id, $lock_token );
				return array( 'error' => __( 'The completed analysis could not be saved. No partial result was published.', 'kidia-mobile-cms' ) );
			}
			self::release_step_lock( $job_id, $lock_token );
			return self::payload( $job, true );
		}

		if ( self::is_cancelled( $job_id ) ) {
			$job['phase'] = 'cancelled';
		}
		$job['updated_at'] = time();
		$job['revision'] = absint( $job['revision'] ?? 0 ) + 1;
		if ( ! self::write_job( $job, 2 * HOUR_IN_SECONDS ) ) {
			self::release_step_lock( $job_id, $lock_token );
			return array( 'error' => __( 'This analysis batch could not be saved. Completed records were not reset.', 'kidia-mobile-cms' ) );
		}
		self::release_step_lock( $job_id, $lock_token );
		return self::payload( $job, 'cancelled' === (string) $job['phase'] );
	}

	/** Returns the current state and can safely advance one batch as a scheduler fallback. */
	public static function status( string $job_id, int $user_id, bool $advance = false ): array {
		$job = self::read_job( $job_id );
		if ( ! is_array( $job ) || absint( $job['user_id'] ?? 0 ) !== $user_id ) {
			return array( 'error' => __( 'The analysis job expired. Start the analysis again.', 'kidia-mobile-cms' ) );
		}
		$done = in_array( (string) ( $job['phase'] ?? '' ), array( 'complete', 'cancelled', 'failed' ), true );
		if ( $advance && ! $done ) {
			return self::step( $job_id, $user_id );
		}
		return self::payload( $job, $done );
	}

	/** Parks a browser-owned job and schedules it on the server. */
	public static function continue_in_background( string $job_id, int $user_id ): array {
		$job = self::read_job( $job_id );
		if ( ! is_array( $job ) || absint( $job['user_id'] ?? 0 ) !== $user_id ) {
			return array( 'error' => __( 'The analysis job expired. Start the analysis again.', 'kidia-mobile-cms' ) );
		}
		if ( in_array( (string) ( $job['phase'] ?? '' ), array( 'complete', 'cancelled', 'failed' ), true ) ) {
			return self::payload( $job, true );
		}

		/*
		 * Parking often happens while the first browser batch is still in
		 * flight. Never write the earlier copy read above over a newly saved
		 * batch. If that batch owns the lock, scheduling is enough: the
		 * background runner will continue from its saved revision.
		 */
		$lock_token = self::acquire_step_lock( $job_id );
		if ( '' === $lock_token ) {
			$latest = self::read_job( $job_id );
			self::schedule_background( $job_id );
			return self::payload( is_array( $latest ) ? $latest : $job, false, true );
		}
		$latest = self::read_job( $job_id );
		if ( ! is_array( $latest ) || absint( $latest['user_id'] ?? 0 ) !== $user_id ) {
			self::release_step_lock( $job_id, $lock_token );
			return array( 'error' => __( 'The analysis job expired. Start the analysis again.', 'kidia-mobile-cms' ) );
		}
		$job = $latest;
		if ( in_array( (string) ( $job['phase'] ?? '' ), array( 'complete', 'cancelled', 'failed' ), true ) ) {
			self::release_step_lock( $job_id, $lock_token );
			return self::payload( $job, true );
		}
		$job['background'] = true;
		if ( ! self::write_job( $job, 2 * HOUR_IN_SECONDS ) ) {
			self::release_step_lock( $job_id, $lock_token );
			return array( 'error' => __( 'The analysis could not be moved to the background without losing progress.', 'kidia-mobile-cms' ) );
		}
		self::release_step_lock( $job_id, $lock_token );
		self::schedule_background( $job_id );
		return self::payload( $job, false );
	}

	/** Cancels future batches without publishing a partial result. */
	public static function cancel( string $job_id, int $user_id ): array {
		$job = self::read_job( $job_id );
		if ( ! is_array( $job ) || absint( $job['user_id'] ?? 0 ) !== $user_id ) {
			return array( 'error' => __( 'The analysis job expired. Start the analysis again.', 'kidia-mobile-cms' ) );
		}
		set_transient( self::cancel_key( $job_id ), 1, HOUR_IN_SECONDS );
		$job['phase']        = 'cancelled';
		$job['cancelled_at'] = time();
		self::write_job( $job, HOUR_IN_SECONDS );
		delete_user_meta( $user_id, self::ACTIVE_JOB_META, $job_id );
		return self::payload( $job, true );
	}

	/** Returns the current user's last running or completed background job id. */
	public static function active_job_id( int $user_id ): string {
		$job_id = sanitize_text_field( (string) get_user_meta( $user_id, self::ACTIVE_JOB_META, true ) );
		if ( '' !== $job_id && ! is_array( self::read_job( $job_id ) ) ) {
			delete_user_meta( $user_id, self::ACTIVE_JOB_META, $job_id );
			return '';
		}
		return $job_id;
	}

	/** Removes a completed job from the user's global progress dock. */
	public static function dismiss( string $job_id, int $user_id ): void {
		delete_user_meta( $user_id, self::ACTIVE_JOB_META, $job_id );
		self::delete_job( $job_id );
	}

	/** Runs one queued batch, then queues the next one until completion. */
	public static function run_background( string $job_id ): void {
		$job = self::read_job( $job_id );
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
					'return'   => 'ids',
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
				$product_id = absint( $item->get_variation_id() );
				if ( $product_id <= 0 ) {
					$product_id = absint( $item->get_product_id() );
				}
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
		if ( absint( $job['orders_processed'] ) >= absint( $job['order_total'] ) ) {
			$job['phase'] = 'products';
		} elseif ( empty( $batch ) ) {
			$job['phase'] = 'failed';
			$job['error'] = __( 'WooCommerce ended order pagination before every paid order was returned. No incomplete result was published.', 'kidia-mobile-cms' );
		}
	}

	/**
	 * Returns the same in-stock product and variation population used by
	 * WooCommerce inventory screens. Product variations are independent SKUs
	 * and must not disappear behind their variable parent.
	 *
	 * @return int[]
	 */
	private static function in_stock_product_ids(): array {
		global $wpdb;
		$lookup_table = isset( $wpdb->wc_product_meta_lookup )
			? (string) $wpdb->wc_product_meta_lookup
			: $wpdb->prefix . 'wc_product_meta_lookup';
		$ids = $wpdb->get_col(
			"SELECT lookup.product_id
			FROM {$lookup_table} AS lookup
			INNER JOIN {$wpdb->posts} AS posts ON posts.ID = lookup.product_id
			WHERE lookup.stock_status = 'instock'
			AND posts.post_type IN ('product', 'product_variation')
			AND posts.post_status = 'publish'
			ORDER BY lookup.product_id ASC"
		);
		return array_values( array_unique( array_filter( array_map( 'absint', (array) $ids ) ) ) );
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
		$stored = Kidia_Mobile_Analytics::store_commerce_snapshot(
			absint( $job['from'] ),
			absint( $job['to'] ),
			(string) $job['source'],
			$snapshot
		);
		if ( ! $stored ) {
			$job['phase'] = 'failed';
			$job['error'] = __( 'The complete analysis was too large to save safely. No incomplete result was published.', 'kidia-mobile-cms' );
			return;
		}
		Kidia_Mobile_AI_Offer_Engine::clear_cache( absint( $job['from'] ), absint( $job['to'] ), (string) $job['source'] );
		Kidia_Mobile_AI_Offer_Engine::recommendations( absint( $job['from'] ), absint( $job['to'] ), (string) $job['source'] );
		$job['snapshot'] = $snapshot;
		$job['phase']    = 'complete';
	}

	/** Common WooCommerce order query. */
	private static function order_args( int $from, int $to, string $source, array $override ): array {
		$args = array_merge(
			array(
				/*
				 * Use the same revenue definition as Store Data. WooCommerce's
				 * wc_get_is_paid_statuses() only contains its core paid states,
				 * while many stores move paid orders into registered workflow
				 * states afterwards. Limiting this job to the core list makes a
				 * complete run publish only that small subset.
				 */
				'status'       => Kidia_Mobile_Analytics::revenue_order_statuses(),
				'date_created' => $from . '...' . $to,
				/* A unique order prevents equal timestamps moving across pages. */
				'orderby'      => 'ID',
				'order'        => 'ASC',
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
	private static function payload( array $job, bool $done, bool $busy = false ): array {
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
		} elseif ( 'failed' === $phase ) {
			$stage = sanitize_text_field( (string) ( $job['error'] ?? __( 'Analysis stopped before all records were read.', 'kidia-mobile-cms' ) ) );
		}
		$date_preset = self::sanitize_date_preset(
			(string) ( $job['date_preset'] ?? ( absint( $job['from'] ?? 0 ) <= 1 ? 'all_time' : 'custom' ) )
		);
		$result_args = array(
			'page'        => 'kidia-mobile-ai-insights',
			'ai_source'   => (string) ( $job['source'] ?? 'all' ),
			'ai_kind'     => 'all',
			'date_preset' => $date_preset,
			'ai_generate' => '1',
			'ai_ready'    => '1',
		);
		if ( 'custom' === $date_preset ) {
			$result_args['date_from'] = wp_date( 'Y-m-d', absint( $job['from'] ?? 0 ) );
			$result_args['date_to']   = wp_date( 'Y-m-d', absint( $job['to'] ?? 0 ) );
		}
		$payload = array(
			'job_id'             => (string) $job['id'],
			'done'               => $done,
			'cancelled'          => $cancelled,
			'background'         => ! empty( $job['background'] ),
			'busy'               => $busy,
			'revision'           => absint( $job['revision'] ?? 0 ),
			'phase'              => $phase,
			'stage'              => $stage,
			'progress'           => $progress,
			'processed'          => $processed,
			'total'              => $total,
			'orders_processed'   => absint( $job['orders_processed'] ?? 0 ),
			'orders_total'       => $order_total,
			'products_processed' => absint( $job['products_processed'] ?? 0 ),
			'products_total'     => $product_total,
			'result_url'         => add_query_arg( $result_args, admin_url( 'admin.php' ) ),
		);
		if ( 'failed' === $phase ) {
			$payload['error'] = sanitize_text_field( (string) ( $job['error'] ?? __( 'Analysis stopped before all records were read.', 'kidia-mobile-cms' ) ) );
		}
		return $payload;
	}

	/** Keeps result URLs on the same analytics snapshot key used by the job. */
	private static function sanitize_date_preset( string $preset ): string {
		$allowed = array( 'all_time', 'today', 'yesterday', 'last_7_days', 'last_30_days', 'this_month', 'previous_month', 'last_year', 'custom' );
		return in_array( $preset, $allowed, true ) ? $preset : 'custom';
	}

	private static function key( string $job_id ): string {
		return self::JOB_PREFIX . md5( $job_id );
	}

	/**
	 * Reads one analysis job from durable, non-autoloaded WordPress storage.
	 *
	 * Large stores quickly exceed the per-item limit used by Redis or
	 * Memcached-backed transients. Options are persisted to the database first,
	 * so a cache refusing the large value cannot discard completed batches.
	 */
	private static function read_job( string $job_id ) {
		$job = get_option( self::key( $job_id ), false );
		if ( ! is_array( $job ) ) {
			return false;
		}
		$expires_at = absint( $job['expires_at'] ?? 0 );
		if ( $expires_at > 0 && $expires_at <= time() ) {
			self::delete_job( $job_id );
			return false;
		}
		return $job;
	}

	/** Persists a complete batch in the database without autoloading it. */
	private static function write_job( array &$job, int $expiration ): bool {
		$key               = self::key( (string) ( $job['id'] ?? '' ) );
		$job['expires_at'] = time() + max( MINUTE_IN_SECONDS, $expiration );
		$existing          = get_option( $key, false );
		if ( false === $existing && add_option( $key, $job, '', 'no' ) ) {
			return true;
		}
		if ( update_option( $key, $job, false ) ) {
			return true;
		}

		/*
		 * WordPress returns false when update_option() receives an identical
		 * value. Treat a byte-for-byte-equivalent saved job as success.
		 */
		$saved = get_option( $key, false );
		return is_array( $saved ) && $saved === $job;
	}

	/** Removes persisted job state after dismissal or replacement. */
	private static function delete_job( string $job_id ): void {
		delete_option( self::key( $job_id ) );
	}

	private static function cancel_key( string $job_id ): string {
		return self::CANCEL_PREFIX . md5( $job_id );
	}

	private static function step_lock_key( string $job_id ): string {
		return self::STEP_LOCK_PREFIX . md5( $job_id );
	}

	/**
	 * Acquires a database-backed atomic lock for one batch.
	 *
	 * add_option() is atomic because option_name is unique. A transient
	 * get-then-set lock is not atomic and allowed the browser and scheduler to
	 * process stale copies of the same job at the same time.
	 */
	private static function acquire_step_lock( string $job_id ): string {
		$key   = self::step_lock_key( $job_id );
		$token = wp_generate_uuid4();
		$value = array(
			'started_at' => time(),
			'token'      => $token,
		);
		if ( add_option( $key, $value, '', 'no' ) ) {
			return $token;
		}
		$existing = get_option( $key, array() );
		$started  = is_array( $existing ) ? absint( $existing['started_at'] ?? 0 ) : 0;
		if ( $started > 0 && time() - $started < 90 ) {
			return '';
		}
		delete_option( $key );
		return add_option( $key, $value, '', 'no' ) ? $token : '';
	}

	/** Releases only the exact lock owned by this request. */
	private static function release_step_lock( string $job_id, string $token ): void {
		$key      = self::step_lock_key( $job_id );
		$existing = get_option( $key, array() );
		if ( is_array( $existing ) && hash_equals( (string) ( $existing['token'] ?? '' ), $token ) ) {
			delete_option( $key );
		}
	}

	private static function is_cancelled( string $job_id ): bool {
		return (bool) get_transient( self::cancel_key( $job_id ) );
	}

	/** Adds a customer identifier to an ASCII-hex probabilistic set. */
	private static function bitmap_add( string &$bitmap, string $customer_key ): void {
		$hex_length = self::CUSTOMER_BITMAP_BYTES * 2;
		if ( strlen( $bitmap ) !== $hex_length || 1 !== preg_match( '/\A[0-9a-f]+\z/D', $bitmap ) ) {
			$bitmap = str_repeat( '00', self::CUSTOMER_BITMAP_BYTES );
		}
		$hash       = unpack( 'Nvalue', substr( hash( 'sha256', $customer_key, true ), 0, 4 ) );
		$bit        = absint( $hash['value'] ?? 0 ) % ( self::CUSTOMER_BITMAP_BYTES * 8 );
		$byte_index = intdiv( $bit, 8 );
		$mask       = 1 << ( $bit % 8 );
		$hex_index  = $byte_index * 2;
		$value      = hexdec( $bitmap[ $hex_index ] . $bitmap[ $hex_index + 1 ] ) | $mask;
		$encoded    = str_pad( dechex( $value ), 2, '0', STR_PAD_LEFT );
		$bitmap[ $hex_index ]     = $encoded[0];
		$bitmap[ $hex_index + 1 ] = $encoded[1];
	}

	/** Estimates distinct customers without storing thousands of hashes in one transient. */
	private static function bitmap_estimate( string $bitmap ): int {
		$bits       = self::CUSTOMER_BITMAP_BYTES * 8;
		$set_bits   = 0;
		$hex_length = self::CUSTOMER_BITMAP_BYTES * 2;
		if ( strlen( $bitmap ) !== $hex_length || 1 !== preg_match( '/\A[0-9a-f]+\z/D', $bitmap ) ) {
			return 0;
		}
		for ( $index = 0; $index < self::CUSTOMER_BITMAP_BYTES; ++$index ) {
			$value = hexdec( substr( $bitmap, $index * 2, 2 ) );
			while ( $value > 0 ) {
				$set_bits += $value & 1;
				$value >>= 1;
			}
		}
		$zero_bits = max( 1, $bits - $set_bits );
		return max( 0, (int) round( -$bits * log( $zero_bits / $bits ) ) );
	}
}
