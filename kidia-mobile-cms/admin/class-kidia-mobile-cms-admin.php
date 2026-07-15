<?php
/**
 * Admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-api-monitor.php';

final class Kidia_Mobile_CMS_Admin {

	/**
	 * Required WordPress capability.
	 *
	 * @var string
	 */
	private const CAPABILITY = 'manage_options';

	/**
	 * Registers admin hooks.
	 *
	 * @return void
	 */
	public function register(): void {
		add_action(
			'admin_menu',
			array( $this, 'register_menu' )
		);
		add_action(
        	'admin_enqueue_scripts',
        	array( $this, 'enqueue_assets' )
        );

		add_action(
			'admin_post_kidia_mobile_save_home_builder',
			array( $this, 'save_home_builder' )
		);
	}

	/**
	 * Registers the CMS menu and pages.
	 *
	 * @return void
	 */
	public function register_menu(): void {
		add_menu_page(
			__( 'Kidia Mobile CMS', 'kidia-mobile-cms' ),
			__( 'Kidia Mobile CMS', 'kidia-mobile-cms' ),
			self::CAPABILITY,
			'kidia-mobile-cms',
			array( $this, 'dashboard_page' ),
			'dashicons-smartphone',
			56
		);

		add_submenu_page(
			'kidia-mobile-cms',
			__( 'Dashboard', 'kidia-mobile-cms' ),
			__( 'Dashboard', 'kidia-mobile-cms' ),
			self::CAPABILITY,
			'kidia-mobile-cms',
			array( $this, 'dashboard_page' )
		);

		add_submenu_page(
			'kidia-mobile-cms',
			__( 'Home Builder', 'kidia-mobile-cms' ),
			__( 'Home Builder', 'kidia-mobile-cms' ),
			self::CAPABILITY,
			'kidia-mobile-home-builder',
			array( $this, 'home_builder_page' )
		);
	}

	/**
	 * Renders the Dashboard page.
	 *
	 * @return void
	 */
	public function dashboard_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die(
				esc_html__(
					'You do not have permission to access this page.',
					'kidia-mobile-cms'
				)
			);
		}

		$monitor = new Kidia_Mobile_CMS_API_Monitor();
		$api     = $monitor->get_status();

		?>
		<div class="wrap">
			<h1>
				<?php
				echo esc_html__(
					'Kidia Mobile CMS',
					'kidia-mobile-cms'
				);
				?>
			</h1>

			<p>
				<?php
				echo esc_html__(
					'Version:',
					'kidia-mobile-cms'
				);
				?>

				<strong>
					<?php echo esc_html( KIDIA_MOBILE_CMS_VERSION ); ?>
				</strong>
			</p>

			<table class="widefat striped">
				<tbody>
					<tr>
						<th width="220">
							<?php
							echo esc_html__(
								'Plugin Status',
								'kidia-mobile-cms'
							);
							?>
						</th>

						<td>
							<?php
							echo esc_html__(
								'Running',
								'kidia-mobile-cms'
							);
							?>
							✅
						</td>
					</tr>

					<tr>
						<th>
							<?php
							echo esc_html__(
								'WordPress',
								'kidia-mobile-cms'
							);
							?>
						</th>

						<td>
							<?php echo esc_html( get_bloginfo( 'version' ) ); ?>
						</td>
					</tr>

					<tr>
						<th>
							<?php
							echo esc_html__(
								'PHP',
								'kidia-mobile-cms'
							);
							?>
						</th>

						<td>
							<?php echo esc_html( PHP_VERSION ); ?>
						</td>
					</tr>

					<tr>
						<th>
							<?php
							echo esc_html__(
								'WooCommerce',
								'kidia-mobile-cms'
							);
							?>
						</th>

						<td>
							<?php
							echo defined( 'WC_VERSION' )
								? esc_html( WC_VERSION )
								: esc_html__(
									'Not installed',
									'kidia-mobile-cms'
								);
							?>
						</td>
					</tr>
				</tbody>
			</table>

			<br>

			<h2>
				<?php
				echo esc_html__(
					'API Monitor',
					'kidia-mobile-cms'
				);
				?>
			</h2>

			<table class="widefat striped">
				<tbody>
					<tr>
						<th width="220">
							<?php
							echo esc_html__(
								'Status',
								'kidia-mobile-cms'
							);
							?>
						</th>

						<td>
							<?php if ( true === $api['online'] ) : ?>
								<span style="color: #008a20; font-weight: 700;">
									🟢
									<?php
									echo esc_html__(
										'Online',
										'kidia-mobile-cms'
									);
									?>
								</span>
							<?php else : ?>
								<span style="color: #b32d2e; font-weight: 700;">
									🔴
									<?php
									echo esc_html__(
										'Offline',
										'kidia-mobile-cms'
									);
									?>
								</span>
							<?php endif; ?>
						</td>
					</tr>

					<tr>
						<th>
							<?php
							echo esc_html__(
								'Endpoint',
								'kidia-mobile-cms'
							);
							?>
						</th>

						<td>
							<code>
								<?php echo esc_html( (string) $api['url'] ); ?>
							</code>
						</td>
					</tr>

					<tr>
						<th>
							<?php
							echo esc_html__(
								'HTTP Status',
								'kidia-mobile-cms'
							);
							?>
						</th>

						<td>
							<?php echo esc_html( (string) $api['status'] ); ?>
						</td>
					</tr>

					<tr>
						<th>
							<?php
							echo esc_html__(
								'Response Time',
								'kidia-mobile-cms'
							);
							?>
						</th>

						<td>
							<?php echo esc_html( (string) $api['time'] ); ?> ms
						</td>
					</tr>

					<?php if ( ! empty( $api['message'] ) ) : ?>
						<tr>
							<th>
								<?php
								echo esc_html__(
									'Message',
									'kidia-mobile-cms'
								);
								?>
							</th>

							<td>
								<?php
								echo esc_html(
									(string) $api['message']
								);
								?>
							</td>
						</tr>
					<?php endif; ?>
				</tbody>
			</table>

			<p>
				<a
					class="button button-primary"
					target="_blank"
					rel="noopener noreferrer"
					href="<?php echo esc_url( (string) $api['url'] ); ?>"
				>
					<?php
					echo esc_html__(
						'Open API',
						'kidia-mobile-cms'
					);
					?>
				</a>
			</p>

			<div class="notice notice-success inline">
				<p>
					<?php
					echo esc_html__(
						'Kidia Mobile CMS initialized successfully.',
						'kidia-mobile-cms'
					);
					?>
				</p>
			</div>
		</div>
		<?php
	}

	/**
	 * Renders the Home Builder page.
	 *
	 * @return void
	 */
	public function home_builder_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die(
				esc_html__(
					'You do not have permission to access this page.',
					'kidia-mobile-cms'
				)
			);
		}

		$store  = new Kidia_Mobile_Layout_Store();
		$blocks = $store->get_layout();

		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/home-builder.php';
	}

	/**
	 * Saves the Home Builder configuration.
	 *
	 * @return void
	 */
	public function save_home_builder(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die(
				esc_html__(
					'You do not have permission to perform this action.',
					'kidia-mobile-cms'
				)
			);
		}

		check_admin_referer(
			'kidia_mobile_save_home_builder',
			'kidia_mobile_home_builder_nonce'
		);

		$submitted_blocks = isset( $_POST['blocks'] )
			? wp_unslash( $_POST['blocks'] )
			: array();

		if ( ! is_array( $submitted_blocks ) ) {
			$submitted_blocks = array();
		}

		$store = new Kidia_Mobile_Layout_Store();

		$store->save_layout(
			$submitted_blocks
		);

		$redirect_url = add_query_arg(
			array(
				'page'    => 'kidia-mobile-home-builder',
				'updated' => '1',
			),
			admin_url( 'admin.php' )
		);

		wp_safe_redirect( $redirect_url );
		exit;
	}
	/**
     * Loads Home Builder assets.
     *
     * @param string $hook_suffix Current admin page hook.
     *
     * @return void
     */
    public function enqueue_assets(
    	string $hook_suffix
    ): void {
    	if (
    		'kidia-mobile-cms_page_kidia-mobile-home-builder'
    		!== $hook_suffix
    	) {
    		return;
    	}

    	wp_enqueue_style(
    		'kidia-mobile-home-builder',
    		KIDIA_MOBILE_CMS_URL . 'admin/assets/home-builder.css',
    		array(),
    		KIDIA_MOBILE_CMS_VERSION
    	);

    	wp_enqueue_script(
    		'kidia-mobile-home-builder',
    		KIDIA_MOBILE_CMS_URL . 'admin/assets/home-builder.js',
    		array(),
    		KIDIA_MOBILE_CMS_VERSION,
    		true
    	);

    	wp_enqueue_media();
    }
}