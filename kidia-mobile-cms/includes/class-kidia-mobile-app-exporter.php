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
	}

	/** @return array<string,mixed> */
	public static function state(): array {
		$state = get_option( self::STATE_OPTION, array() );
		return wp_parse_args(
			is_array( $state ) ? $state : array(),
			array(
				'exported_at' => 0,
				'hash'        => '',
				'file_name'   => '',
			)
		);
	}

	public static function is_current(): bool {
		$state = self::state();
		return '' !== (string) $state['hash']
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
				'logoUrl'       => esc_url_raw( (string) ( $identity['logo_url'] ?? '' ) ),
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
				'Push provider: ' . (string) ( $push['provider'] ?? 'none' ),
				'Push ready: ' . ( ! empty( $push['enabled'] ) ? 'yes' : 'no' ),
				'Push config endpoint: ' . (string) ( $push['configUrl'] ?? '' ),
				'',
				'Server credentials never leave WordPress. FCM or OneSignal must be connected once in Push Notifications;',
				'every later app export automatically receives the matching public client configuration.',
			)
		);
	}

	private function mark_exported( string $file_name ): void {
		update_option(
			self::STATE_OPTION,
			array(
				'exported_at' => time(),
				'hash'        => self::configuration_hash(),
				'file_name'   => sanitize_file_name( $file_name ),
			),
			false
		);
	}
}
