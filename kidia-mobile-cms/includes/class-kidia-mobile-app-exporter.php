<?php
/**
 * Portable application build-package exporter.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_App_Exporter {

	private const STATE_OPTION = 'kidia_mobile_app_export_state_v1';
	private const ASYNC_HOOK = 'kidia_mobile_process_app_build';
	private const START_TIMEOUT = 180;

	public function register(): void {
		add_action( 'admin_post_kidia_mobile_export_app', array( $this, 'handle_export' ) );
		add_action( 'admin_post_kidia_mobile_build_app', array( $this, 'handle_build' ) );
		add_action( 'admin_post_kidia_mobile_download_apk', array( $this, 'handle_download_apk' ) );
		add_action( 'wp_ajax_kidia_mobile_app_build_start', array( $this, 'handle_build_start' ) );
		add_action( 'wp_ajax_kidia_mobile_app_build_status', array( $this, 'handle_build_status' ) );
		add_action( 'wp_ajax_kidia_mobile_app_build_cancel', array( $this, 'handle_build_cancel' ) );
		add_action( self::ASYNC_HOOK, array( $this, 'process_queued_build' ), 10, 1 );
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

		$result = $this->queue_build();
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
		return $this->queue_build();
	}

	/**
	 * Saves the build locally before dispatching the slow remote request.
	 *
	 * Action Scheduler is bundled with WooCommerce and keeps the Overview AJAX
	 * response fast even when the remote build provider takes time to enqueue
	 * the Android job. WordPress Cron remains available as a safe fallback.
	 *
	 * @return array<string,mixed>|WP_Error
	 */
	public function queue_build() {
		$license = new Kidia_Mobile_License_Manager();
		if ( ! $license->is_active() ) {
			return new WP_Error( 'license_required', __( 'Activate the website license before building the application.', 'kidia-mobile-cms' ) );
		}
		$existing = self::state();
		if ( in_array( (string) $existing['status'], array( 'queued', 'building' ), true ) ) {
			return new WP_Error( 'build_already_active', __( 'A build is already running. Cancel it before starting another build.', 'kidia-mobile-cms' ) );
		}

		$request_token = wp_generate_uuid4();
		$state         = array_merge(
			self::default_state(),
			array(
				'hash'          => self::configuration_hash(),
				'status'        => 'queued',
				'progress'      => 1,
				'message'       => __( 'Preparing your APK build…', 'kidia-mobile-cms' ),
				'started_at'    => time(),
				'request_token' => $request_token,
			)
		);
		update_option( self::STATE_OPTION, $state, false );

		$scheduled = false;
		if ( function_exists( 'as_enqueue_async_action' ) ) {
			$scheduled = (bool) as_enqueue_async_action(
				self::ASYNC_HOOK,
				array( $request_token ),
				'kidia-mobile-cms',
				true
			);
		} else {
			$scheduled = (bool) wp_schedule_single_event(
				time(),
				self::ASYNC_HOOK,
				array( $request_token )
			);
			if ( $scheduled && function_exists( 'spawn_cron' ) ) {
				spawn_cron( time() );
			}
		}

		if ( ! $scheduled ) {
			$error = new WP_Error( 'build_queue_failed', __( 'The APK build could not be queued. Please try again.', 'kidia-mobile-cms' ) );
			$this->save_build_error( $error->get_error_message() );
			return $error;
		}

		return $state;
	}

	/**
	 * Starts the remote build outside the request that rendered Overview.
	 */
	public function process_queued_build( string $request_token ): void {
		$state = self::state();
		if (
			'' === $request_token
			|| ! hash_equals( (string) $state['request_token'], $request_token )
			|| '' !== (string) $state['build_id']
			|| 'queued' !== (string) $state['status']
		) {
			return;
		}

		$this->dispatch_build( $request_token );
	}

	/**
	 * Queues a real Android APK build with the WooMobile build service.
	 *
	 * @return array<string,mixed>|WP_Error
	 */
	private function dispatch_build( string $request_token ) {
		$license = new Kidia_Mobile_License_Manager();
		if ( ! $license->is_active() ) {
			$error = new WP_Error( 'license_required', __( 'Activate the website license before building the application.', 'kidia-mobile-cms' ) );
			$this->save_build_error( $error->get_error_message() );
			return $error;
		}

		$manifest = self::manifest();
		$response = $license->build_service_request(
			'',
			'POST',
			$this->build_request_payload( $manifest, true )
		);
		if ( is_wp_error( $response ) && $this->can_retry_without_push( $response ) ) {
			$response = $license->build_service_request(
				'',
				'POST',
				$this->build_request_payload( $manifest, false )
			);
		}
		if ( is_wp_error( $response ) ) {
			$this->save_build_error( $response->get_error_message() );
			return $response;
		}

		$state = self::state();
		if ( ! hash_equals( (string) $state['request_token'], $request_token ) ) {
			return new WP_Error( 'build_replaced', __( 'A newer APK build has already started.', 'kidia-mobile-cms' ) );
		}

		$build = $this->normalize_build_response( $response, (string) $state['hash'], $state );
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
	public function refresh_build( bool $force = false ) {
		$state    = self::state();
		$build_id = sanitize_text_field( (string) $state['build_id'] );
		if ( '' === $build_id ) {
			if (
				in_array( (string) $state['status'], array( 'queued', 'building' ), true )
				&& absint( $state['started_at'] ) > 0
				&& absint( $state['started_at'] ) < ( time() - self::START_TIMEOUT )
			) {
				$this->save_build_error( __( 'The APK build service did not start in time. Please try again.', 'kidia-mobile-cms' ) );
				return self::state();
			}
			return $state;
		}
		if ( in_array( (string) $state['status'], array( 'failed', 'cancelled' ), true ) || ( 'ready' === (string) $state['status'] && ! $force ) ) {
			return $state;
		}

		$path     = rawurlencode( $build_id );
		$method   = 'GET';
		if ( $force ) {
			$path  .= '/download-link';
			$method = 'POST';
		}
		$response = ( new Kidia_Mobile_License_Manager() )->build_service_request( $path, $method );
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

	public function handle_build_start(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_send_json_error( array( 'message' => __( 'You do not have permission to build this application.', 'kidia-mobile-cms' ) ), 403 );
		}
		check_ajax_referer( 'kidia_mobile_build_app', 'nonce' );

		$license = new Kidia_Mobile_License_Manager();
		if ( ! $license->is_active() ) {
			wp_send_json_error( array( 'message' => __( 'Activate the website license before building the application.', 'kidia-mobile-cms' ) ), 403 );
		}
		$existing = self::state();
		if ( in_array( (string) $existing['status'], array( 'queued', 'building' ), true ) ) {
			wp_send_json_success( $this->browser_state( $existing ) );
		}

		$request_token = wp_generate_uuid4();
		$state         = array_merge(
			self::default_state(),
			array(
				'hash'          => self::configuration_hash(),
				'status'        => 'building',
				'progress'      => 2,
				'message'       => __( 'Connecting to the APK build service…', 'kidia-mobile-cms' ),
				'started_at'    => time(),
				'request_token' => $request_token,
			)
		);
		update_option( self::STATE_OPTION, $state, false );

		/*
		 * The interactive card must confirm that the provider accepted the
		 * request before returning success. This prevents a local "Queued"
		 * state from being mistaken for a real Codemagic build.
		 */
		$result = $this->dispatch_build( $request_token );
		if ( is_wp_error( $result ) ) {
			wp_send_json_error( array( 'message' => $result->get_error_message() ), 502 );
		}
		wp_send_json_success( $this->browser_state( $result ) );
	}

	public function handle_build_cancel(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_send_json_error( array( 'message' => __( 'You do not have permission to cancel this build.', 'kidia-mobile-cms' ) ), 403 );
		}
		check_ajax_referer( 'kidia_mobile_app_build_cancel', 'nonce' );

		$state = self::state();
		$build_id = sanitize_text_field( (string) $state['build_id'] );
		if ( '' !== $build_id ) {
			$result = ( new Kidia_Mobile_License_Manager() )->build_service_request( rawurlencode( $build_id ) . '/cancel', 'POST' );
			if ( is_wp_error( $result ) ) {
				wp_send_json_error( array( 'message' => $result->get_error_message() ), 502 );
			}
		}

		delete_option( self::STATE_OPTION );
		wp_send_json_success(
			array_merge(
				$this->browser_state( self::default_state() ),
				array( 'dismissed' => true )
			)
		);
	}

	public function handle_download_apk(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( esc_html__( 'You do not have permission to download this application.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_download_apk', 'kidia_mobile_download_nonce' );

		$result = $this->refresh_build( true );
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

		if ( ! $this->redirect_to_artifact( $url ) ) {
			wp_die( esc_html__( 'The application download could not be started. Please try again.', 'kidia-mobile-cms' ) );
		}
		exit;
	}

	/**
	 * Builds the canonical Laravel API payload.
	 *
	 * Build service validators use snake_case. Earlier plugin versions sent
	 * camelCase keys, so authenticated requests reached the service but failed
	 * validation before a build ID could be created.
	 *
	 * @param array<string,mixed> $manifest App build manifest.
	 * @return array<string,mixed>
	 */
	private function build_request_payload( array $manifest, bool $provision_push ): array {
		$application = is_array( $manifest['application'] ?? null ) ? $manifest['application'] : array();
		$store       = is_array( $manifest['store'] ?? null ) ? $manifest['store'] : array();
		$version     = defined( 'KIDIA_MOBILE_CMS_VERSION' ) ? KIDIA_MOBILE_CMS_VERSION : '1.0.0';
		$snapshot    = array_merge(
			$manifest,
			array(
				'schema_version' => (string) absint( $manifest['schemaVersion'] ?? 1 ),
				'pages'          => array_values( is_array( $application['enabledPages'] ?? null ) ? $application['enabledPages'] : array() ),
			)
		);

		return array(
			'store_url'          => esc_url_raw( (string) ( $store['url'] ?? home_url( '/' ) ) ),
			'app_name'           => sanitize_text_field( (string) ( $application['name'] ?? get_bloginfo( 'name' ) ) ),
			'package_name'       => sanitize_text_field( (string) ( $application['androidPackage'] ?? '' ) ),
			'version_name'       => sanitize_text_field( $version ),
			'version_code'       => time(),
			'settings_snapshot'  => $snapshot,
			'platform'           => 'android',
			'artifact'           => 'apk',
			'configuration_hash' => self::configuration_hash(),
			'plugin_version'     => $version,
			'provision_push'     => $provision_push,
			'manifest'           => $manifest,
		);
	}

	private function can_retry_without_push( WP_Error $error ): bool {
		return in_array(
			$error->get_error_code(),
			array(
				'build_request_failed',
				'build_validation_failed',
				'push_provisioning_failed',
				'push_provisioning_unavailable',
			),
			true
		);
	}

	/** Redirects the browser to a short-lived URL created by the build API. */
	private function redirect_to_artifact( string $url ): bool {
		$scheme = strtolower( (string) wp_parse_url( $url, PHP_URL_SCHEME ) );
		$host   = (string) wp_parse_url( $url, PHP_URL_HOST );
		if ( 'https' !== $scheme || '' === $host ) {
			return false;
		}

		nocache_headers();
		return wp_redirect( $url, 302, 'WooMobile Build Download' ); // phpcs:ignore WordPress.Security.SafeRedirect.wp_redirect_wp_redirect
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
				: ( isset( $response['data'] ) && is_array( $response['data'] )
					? $response['data']
					: ( isset( $response['result'] ) && is_array( $response['result'] ) ? $response['result'] : $response ) ) );
		if ( isset( $raw['build'] ) && is_array( $raw['build'] ) ) {
			$raw = $raw['build'];
		}
		$state = wp_parse_args( is_array( $previous ) ? $previous : array(), self::default_state() );

		$remote_status = sanitize_key(
			(string) (
				$raw['status']
				?? $raw['buildStatus']
				?? $raw['build_status']
				?? $raw['workflowStatus']
				?? $raw['workflow_status']
				?? 'queued'
			)
		);
		$status_map    = array(
			'pending'    => 'queued',
			'queued'     => 'queued',
			'running'    => 'building',
			'processing' => 'building',
			'building'   => 'building',
			'succeeded'  => 'ready',
			'success'    => 'ready',
			'completed'  => 'ready',
			'complete'   => 'ready',
			'done'       => 'ready',
			'finished'   => 'ready',
			'ready'      => 'ready',
			'failed'     => 'failed',
			'error'      => 'failed',
			'cancelled'  => 'cancelled',
			'canceled'   => 'cancelled',
		);
		$status        = $status_map[ $remote_status ] ?? 'queued';
		$download_url = (string) (
			$raw['downloadUrl']
			?? $raw['download_url']
			?? $raw['artifactUrl']
			?? $raw['artifact_url']
			?? $raw['artifact']['downloadUrl']
			?? $raw['artifact']['download_url']
			?? $raw['artifact']['url']
			?? $raw['download']['url']
			?? ''
		);
		$file_name     = (string) ( $raw['fileName'] ?? $raw['file_name'] ?? $raw['artifact']['fileName'] ?? $raw['artifact']['file_name'] ?? '' );
		$artifacts     = is_array( $raw['artifacts'] ?? null ) ? $raw['artifacts'] : array();
		$apk_fallback = array();
		foreach ( $artifacts as $artifact ) {
			if ( ! is_array( $artifact ) ) {
				continue;
			}
			$artifact_name = (string) ( $artifact['fileName'] ?? $artifact['file_name'] ?? $artifact['name'] ?? '' );
			$artifact_url  = (string) ( $artifact['downloadUrl'] ?? $artifact['download_url'] ?? $artifact['url'] ?? '' );
			if ( '' !== $artifact_url && preg_match( '/woomobile-build-files\.zip(?:$|\?)/i', $artifact_name . $artifact_url ) ) {
				$download_url = $artifact_url;
				$file_name    = $artifact_name ?: 'woomobile-build-files.zip';
				break;
			}
			if ( empty( $apk_fallback ) && '' !== $artifact_url && preg_match( '/\.apk(?:$|\?)/i', $artifact_name . $artifact_url ) ) {
				$apk_fallback = array( $artifact_url, $artifact_name );
			}
		}
		if ( '' === $download_url && ! empty( $apk_fallback ) ) {
			$download_url = (string) $apk_fallback[0];
			$file_name    = (string) ( $apk_fallback[1] ?: 'woomobile-app.apk' );
		}
		$progress      = max( 0, min( 100, absint( $raw['progress'] ?? ( 'ready' === $status ? 100 : 0 ) ) ) );

		$state['build_id']      = sanitize_text_field( (string) ( $raw['id'] ?? $raw['_id'] ?? $raw['buildId'] ?? $raw['build_id'] ?? $raw['codemagicBuildId'] ?? $raw['codemagic_build_id'] ?? $state['build_id'] ) );
		$state['status']        = $status;
		$state['progress']      = $progress;
		$state['message']       = sanitize_text_field( (string) ( $raw['message'] ?? ( 'queued' === $status ? __( 'Your APK build is queued.', 'kidia-mobile-cms' ) : '' ) ) );
		$state['stage']         = sanitize_text_field( (string) ( $raw['stage'] ?? $raw['currentStep'] ?? $raw['current_step'] ?? $state['message'] ) );
		$state['started_at']    = absint( $state['started_at'] ) ?: time();
		$state['completed_at']  = in_array( $status, array( 'ready', 'failed', 'cancelled' ), true ) ? time() : 0;
		$state['download_url']  = esc_url_raw( $download_url );
		$default_file_name      = preg_match( '/\.zip(?:$|\?)/i', $download_url )
			? 'woomobile-build-files.zip'
			: 'woomobile-app.apk';
		$state['apk_file_name'] = sanitize_file_name( $file_name ?: $default_file_name );
		$state['hash']          = $hash;
		$state['updated_at']    = time();

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
			'stage'        => sanitize_text_field( (string) $state['stage'] ),
			'buildId'      => sanitize_text_field( (string) $state['build_id'] ),
			'startedAt'    => absint( $state['started_at'] ),
			'updatedAt'    => absint( $state['updated_at'] ),
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
			'stage'         => '',
			'started_at'    => 0,
			'completed_at'  => 0,
			'updated_at'    => 0,
			'download_url'  => '',
			'apk_file_name' => '',
			'request_token' => '',
		);
	}
}
