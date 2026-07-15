<?php
/**
 * API Monitor.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_CMS_API_Monitor', false ) ) {
	return;
}

final class Kidia_Mobile_CMS_API_Monitor {

	private const ROUTE = '/wp-json/kidia/v1/home-layout';

	/**
	 * Tests the Home Layout API.
	 *
	 * @return array<string, mixed>
	 */
	public function get_status(): array {
		$url   = home_url( self::ROUTE );
		$start = microtime( true );

		$response = wp_remote_get(
			$url,
			array(
				'timeout'     => 10,
				'redirection' => 3,
				'headers'     => array(
					'Accept' => 'application/json',
				),
			)
		);

		$response_time = round(
			( microtime( true ) - $start ) * 1000,
			2
		);

		if ( is_wp_error( $response ) ) {
			return array(
				'online'  => false,
				'message' => $response->get_error_message(),
				'status'  => 0,
				'time'    => $response_time,
				'url'     => $url,
			);
		}

		$status_code = wp_remote_retrieve_response_code( $response );

		return array(
			'online'  => 200 === $status_code,
			'message' => 200 === $status_code
				? ''
				: wp_remote_retrieve_response_message( $response ),
			'status'  => $status_code,
			'time'    => $response_time,
			'url'     => $url,
		);
	}
}
