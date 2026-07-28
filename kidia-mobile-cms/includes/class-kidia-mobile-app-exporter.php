<?php
/**
 * Portable application build-package exporter.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_App_Exporter {

	private const STATE_OPTION = 'kidia_mobile_app_export_state_v1';

	public function register(): void {
		add_action( 'admin_post_kidia_mobile_export_app', array( $this, 'handle_export' ) );
		add_action( 'admin_post_kidia_mobile_build_app', array( $this, 'handle_build' ) );
		add_action( 'admin_post_kidia_mobile_download_apk', array( $this, 'handle_download_apk' ) );
		add_action( 'wp_ajax_kidia_mobile_app_build_status', array( $this, 'handle_build_status' ) );
	}

	/** @return array<string,mixed> */
	public static function state(): array {
		$state = get_option( self::STATE_OPTION, array() );
		return wp_parse_args(
			is_array( $state ) ? $state : array(),
			self::default_state()
		);
	}

	public static function is_current(): bool {
		$state = self::state();
		return 'ready' === (string) $state['status']
			&& '' !== (string) $state['download_url']
			&& '' !== (string) $state['hash']
			&& hash_equals( (string) $state['hash'], self::configuration_hash() );
	}

	public static function configuration_hash(): string {
		$identity = ( new Kidia_Mobile_Setup_Wizard() )->identity();
		$payload  = array(
			'plugin_version' => defined( 'KIDIA_MOBILE_CMS_VERSION' ) ? KIDIA_MOBILE_CMS_VERSION : '',
			'site_url'       => home_url( '/' ),
			'identity'       => $identity,
			'push'           => Kidia_Mobile_Push_Service::client_configuration(),
		);
		return hash( 'sha256', (string) wp_json_encode( $payload ) );
	}

	/** @return array<string,mixed> */
	public static function manifest(): array {
		$identity    = ( new Kidia_Mobile_Setup_Wizard() )->identity();
		$slug        = sanitize_title( (string) ( $identity['app_name'] ?? get_bloginfo( 'name' ) ) );
		$slug        = '' !== $slug ? $slug : 'store';
		$package_key = preg_replace( '/[^a-z0-9_]/', '_', strtolower( $slug ) );
		$package_key = trim( (string) $package_key, '_' );
		$package_key = '' !== $package_key ? $package_key : 'store';
		$package_key = preg_match( '/^[a-z]/', $package_key ) ? $package_key : 'store_' . $package_key;
		$push        = Kidia_Mobile_Push_Service::client_configuration();

		return array(
			'schema'       => 'woomobile-app-build-package',
			'schemaVersion' => 1,
			'generatedAt'  => gmdate( 'c' ),
			'configurationHash' => self::configuration_hash(),
			'application'  => array(
				'name'          => (string) ( $identity['app_name'] ?? get_bloginfo( 'name' ) ),
				'slug'          => $slug,
				'androidPackage' => 'app.woomobile.' . $package_key,
				'iosBundleId'   => 'app.woomobile.' . str_replace( '_', '-', $package_key ),
				'language'      => (string) ( $identity['language'] ?? 'en' ),
				'direction'     => (string) ( $identity['direction'] ?? 'ltr' ),
				'primaryColor'  => (string) ( $identity['primary_color'] ?? '#2F806E' ),
				'secondaryColor'=> (string) ( $identity['secondary_color'] ?? '#EAF6F2' ),
				'logoUrl'       => esc_url_raw( (string) ( $identity['logo_url'] ?? '' ) ),
				'enabledPages'  => array_values( is_array( $identity['enabled_pages'] ?? null ) ? $identity['enabled_pages'] : array_keys( Kidia_Mobile_Setup_Wizard::setup_pages() ) ),
			),
			'store'        => array(
				'url'      => home_url( '/' ),
				'apiBase'  => rest_url( 'woo-mobile/v1/' ),
				'homeApi'  => rest_url( 'woo-mobile/v1/home-layout' ),
			),
			'push'         => $push,
			'build'        => array(
				'dartDefines' => array(
					'STORE_URL'       => home_url( '/' ),
					'STORE_NAME'      => (string) ( $identity['app_name'] ?? get_bloginfo( 'name' ) ),
					'STORE_LOCALE'    => (string) ( $identity['language'] ?? 'en' ),
					'PUSH_CONFIG_URL' => rest_url( 'woo-mobile/v1/push/config' ),
				),
				'requiresNativePushSetup' => ! empty( $push['requiresNativeSetup'] ),
			),
		);
	}

	public function handle_export(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( esc_html__( 'You do not have permission to export this application.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_export_app', 'kidia_mobile_export_nonce' );
		if ( ! ( new Kidia_Mobile_License_Manager() )->is_active() ) {
			wp_die( esc_html__( 'Activate the website license before exporting the application.', 'kidia-mobile-cms' ) );
		}
		$this->download();
	}

	public function handle_build(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( esc_html__( 'You do not have permission to build this application.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_build_app', 'kidia_mobile_build_nonce' );

		$result = $this->start_build();
		$args   = array(
			'page'         => 'kidia-mobile-cms',
			'build_notice' => is_wp_error( $result ) ? 'error' : 'started',
		);
		if ( is_wp_error( $result ) ) {
			$args['build_message'] = $result->get_error_message();
		}
		wp_safe_redirect( add_query_arg( $args, admin_url( 'admin.php' ) ) );
		exit;
	}

	/**
	 * Queues a real Android APK build with the WooMobile build service.
	 *
	 * @return array<string,mixed>|WP_Error
	 */
	public function start_build() {
		$license = new Kidia_Mobile_License_Manager();
		if ( ! $license->is_active() ) {
			return new WP_Error( 'license_required', __( 'Activate the website license before building the application.', 'kidia-mobile-cms' ) );
		}

		$manifest = self::manifest();
		$response = $license->build_service_request(
			'',
			'POST',
			array(
				'platform'          => 'android',
				'artifact'          => 'apk',
				'configurationHash' => self::configuration_hash(),
				'pluginVersion'     => defined( 'KIDIA_MOBILE_CMS_VERSION' ) ? KIDIA_MOBILE_CMS_VERSION : '',
				'provisionPush'     => true,
				'manifest'          => $manifest,
			)
		);
		if ( is_wp_error( $response ) ) {
			$this->save_build_error( $response->get_error_message() );
			return $response;
		}

		$build = $this->normalize_build_response( $response, self::configuration_hash() );
		if ( '' === (string) $build['build_id'] ) {
			$error = new WP_Error( 'invalid_build_response', __( 'The build service did not return a build ID.', 'kidia-mobile-cms' ) );
			$this->save_build_error( $error->get_error_message() );
			return $error;
		}

		update_option( self::STATE_OPTION, $build, false );
		return $build;
	}

	/**
	 * Refreshes the active remote build.
	 *
	 * @return array<string,mixed>|WP_Error
	 */
	public function refresh_build() {
		$state    = self::state();
		$build_id = sanitize_text_field( (string) $state['build_id'] );
		if ( '' === $build_id ) {
			return $state;
		}
		if ( in_array( (string) $state['status'], array( 'ready', 'failed' ), true ) ) {
			return $state;
		}

		$response = ( new Kidia_Mobile_License_Manager() )->build_service_request( rawurlencode( $build_id ), 'GET' );
		if ( is_wp_error( $response ) ) {
			return $response;
		}

		$build = $this->normalize_build_response( $response, (string) $state['hash'], $state );
		update_option( self::STATE_OPTION, $build, false );
		return $build;
	}

	public function handle_build_status(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_send_json_error( array( 'message' => __( 'You do not have permission to view this build.', 'kidia-mobile-cms' ) ), 403 );
		}
		check_ajax_referer( 'kidia_mobile_app_build_status', 'nonce' );
		$result = $this->refresh_build();
		if ( is_wp_error( $result ) ) {
			wp_send_json_error( array( 'message' => $result->get_error_message() ), 502 );
		}
		wp_send_json_success( $this->browser_state( $result ) );
	}

	public function handle_download_apk(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( esc_html__( 'You do not have permission to download this application.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_download_apk', 'kidia_mobile_download_nonce' );

		$result = $this->refresh_build();
		if ( is_wp_error( $result ) ) {
			wp_die( esc_html( $result->get_error_message() ) );
		}
		if ( ! self::is_current() ) {
			wp_die( esc_html__( 'This APK is not ready or its application settings have changed. Start a new build.', 'kidia-mobile-cms' ) );
		}

		$url    = esc_url_raw( (string) $result['download_url'] );
		$scheme = strtolower( (string) wp_parse_url( $url, PHP_URL_SCHEME ) );
		$host   = (string) wp_parse_url( $url, PHP_URL_HOST );
		if ( 'https' !== $scheme || '' === $host ) {
			wp_die( esc_html__( 'The APK download link returned by the build service is invalid.', 'kidia-mobile-cms' ) );
		}

		wp_redirect( $url, 302, 'Woo Mobile CMS' ); // phpcs:ignore WordPress.Security.SafeRedirect.wp_redirect_wp_redirect
		exit;
	}

	public function download(): void {
		$manifest  = self::manifest();
		$app_slug  = sanitize_file_name( (string) $manifest['application']['slug'] );
		$file_name = 'woomobile-' . $app_slug . '-build-package.zip';
		$files     = array(
			'app-config.json'  => wp_json_encode( $manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE ),
			'push-config.json' => wp_json_encode( $manifest['push'], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE ),
			'dart-defines.json' => wp_json_encode( $manifest['build']['dartDefines'], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE ),
			'README.txt'       => $this->readme( $manifest ),
		);

		nocache_headers();
		if ( class_exists( 'ZipArchive' ) ) {
			$temp_file = wp_tempnam( $file_name );
			$zip       = new ZipArchive();
			if ( $temp_file && true === $zip->open( $temp_file, ZipArchive::CREATE | ZipArchive::OVERWRITE ) ) {
				foreach ( $files as $path => $contents ) {
					$zip->addFromString( $path, (string) $contents );
				}
				$zip->close();
				$this->mark_exported( $file_name );
				header( 'Content-Type: application/zip' );
				header( 'Content-Disposition: attachment; filename="' . $file_name . '"' );
				header( 'Content-Length: ' . (string) filesize( $temp_file ) );
				readfile( $temp_file );
				unlink( $temp_file );
				exit;
			}
		}

		$file_name = 'woomobile-' . $app_slug . '-app-config.json';
		$this->mark_exported( $file_name );
		header( 'Content-Type: application/json; charset=utf-8' );
		header( 'Content-Disposition: attachment; filename="' . $file_name . '"' );
		echo (string) $files['app-config.json']; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		exit;
	}

	/** @param array<string,mixed> $manifest */
	private function readme( array $manifest ): string {
		$push = is_array( $manifest['push'] ?? null ) ? $manifest['push'] : array();
		return implode(
			"\n",
			array(
				'WooMobile application build package',
				'===================================',
				'',
				'This package is generated by the WordPress plugin and is ready for the WooMobile build pipeline.',
				'The exported application reads store content and public push configuration from this website.',
				'',
				'Push mode: ' . (string) ( $push['mode'] ?? 'managed' ),
				'Push ready: ' . ( ! empty( $push['enabled'] ) ? 'yes' : 'no' ),
				'Push config endpoint: ' . (string) ( $push['configUrl'] ?? '' ),
				'',
				'WooMobile creates a private Push connection for this application during the build.',
				'No provider selection or Firebase credentials are required in WordPress.',
			)
		);
	}

	private function mark_exported( string $file_name ): void {
		$state = self::state();
		update_option(
			self::STATE_OPTION,
			array_merge(
				$state,
				array(
				'exported_at' => time(),
				'file_name'   => sanitize_file_name( $file_name ),
				)
			),
			false
		);
	}

	/**
	 * @param array<string,mixed>      $response Remote response.
	 * @param string                   $hash     Configuration hash used for the build.
	 * @param array<string,mixed>|null $previous Previous state.
	 * @return array<string,mixed>
	 */
	private function normalize_build_response( array $response, string $hash, ?array $previous = null ): array {
		$raw = isset( $response['build'] ) && is_array( $response['build'] )
			? $response['build']
			: ( isset( $response['data']['build'] ) && is_array( $response['data']['build'] )
				? $response['data']['build']
				: ( isset( $response['data'] ) && is_array( $response['data'] ) ? $response['data'] : $response ) );
		$state = wp_parse_args( is_array( $previous ) ? $previous : array(), self::default_state() );

		$remote_status = sanitize_key( (string) ( $raw['status'] ?? 'queued' ) );
		$status_map    = array(
			'pending'    => 'queued',
			'queued'     => 'queued',
			'running'    => 'building',
			'processing' => 'building',
			'building'   => 'building',
			'succeeded'  => 'ready',
			'success'    => 'ready',
			'completed'  => 'ready',
			'ready'      => 'ready',
			'failed'     => 'failed',
			'error'      => 'failed',
			'cancelled'  => 'failed',
			'canceled'   => 'failed',
		);
		$status        = $status_map[ $remote_status ] ?? 'queued';
		$download_url = (string) ( $raw['downloadUrl'] ?? $raw['download_url'] ?? $raw['artifact']['downloadUrl'] ?? $raw['artifact']['download_url'] ?? '' );
		$file_name     = (string) ( $raw['fileName'] ?? $raw['file_name'] ?? $raw['artifact']['fileName'] ?? $raw['artifact']['file_name'] ?? '' );
		$progress      = max( 0, min( 100, absint( $raw['progress'] ?? ( 'ready' === $status ? 100 : 0 ) ) ) );

		$state['build_id']      = sanitize_text_field( (string) ( $raw['id'] ?? $raw['buildId'] ?? $raw['build_id'] ?? $state['build_id'] ) );
		$state['status']        = $status;
		$state['progress']      = $progress;
		$state['message']       = sanitize_text_field( (string) ( $raw['message'] ?? ( 'queued' === $status ? __( 'Your APK build is queued.', 'kidia-mobile-cms' ) : '' ) ) );
		$state['started_at']    = absint( $state['started_at'] ) ?: time();
		$state['completed_at']  = in_array( $status, array( 'ready', 'failed' ), true ) ? time() : 0;
		$state['download_url']  = esc_url_raw( $download_url );
		$state['apk_file_name'] = sanitize_file_name( $file_name ?: 'woomobile-app.apk' );
		$state['hash']          = $hash;

		if ( 'ready' === $status && '' === $state['download_url'] ) {
			$state['status']  = 'failed';
			$state['message'] = __( 'The build finished without an APK download link.', 'kidia-mobile-cms' );
		}
		return $state;
	}

	private function save_build_error( string $message ): void {
		$state                 = self::state();
		$state['status']       = 'failed';
		$state['progress']     = 0;
		$state['message']      = sanitize_text_field( $message );
		$state['completed_at'] = time();
		$state['download_url'] = '';
		update_option( self::STATE_OPTION, $state, false );
	}

	/**
	 * Removes the remote signed URL before build state is returned to JavaScript.
	 *
	 * @param array<string,mixed> $state Build state.
	 * @return array<string,mixed>
	 */
	private function browser_state( array $state ): array {
		return array(
			'status'       => sanitize_key( (string) $state['status'] ),
			'progress'     => max( 0, min( 100, absint( $state['progress'] ) ) ),
			'message'      => sanitize_text_field( (string) $state['message'] ),
			'fileName'     => sanitize_file_name( (string) $state['apk_file_name'] ),
			'current'      => self::is_current(),
			'downloadReady'=> self::is_current(),
		);
	}

	/** @return array<string,mixed> */
	private static function default_state(): array {
		return array(
			'exported_at'   => 0,
			'hash'          => '',
			'file_name'     => '',
			'build_id'      => '',
			'status'        => 'idle',
			'progress'      => 0,
			'message'       => '',
			'started_at'    => 0,
			'completed_at'  => 0,
			'download_url'  => '',
			'apk_file_name' => '',
		);
	}
}
