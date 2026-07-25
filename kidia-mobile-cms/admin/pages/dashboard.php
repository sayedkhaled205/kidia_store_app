<?php
/**
 * Kidia Mobile CMS Dashboard.
 *
 * Available variables:
 *
 * @var array<string, mixed> $api API monitor status.
 * @var array<string, mixed> $license License state.
 * @var bool                 $setup_complete Setup state.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

$api_online = ! empty( $api['online'] );

$api_url = isset( $api['url'] )
	? (string) $api['url']
	: '';

$api_status = isset( $api['status'] )
	? (string) $api['status']
	: '';

$api_time = isset( $api['time'] )
	? (string) $api['time']
	: '';

$api_message = isset( $api['message'] )
	? (string) $api['message']
	: '';

$license_active = ! empty( $license['active'] );
$license_plan   = '' !== (string) ( $license['plan'] ?? '' )
	? ucfirst( (string) $license['plan'] )
	: __( 'No active plan', 'kidia-mobile-cms' );
$license_expiry = ! empty( $license['expires_at'] )
	? wp_date( get_option( 'date_format' ), (int) $license['expires_at'] )
	: __( 'No expiry', 'kidia-mobile-cms' );
?>

<div class="wrap kidia-dashboard">

	<h1>
		<?php
		esc_html_e(
			'Kidia Mobile CMS',
			'kidia-mobile-cms'
		);
		?>
	</h1>

	<p>
		<?php
		esc_html_e(
			'Version:',
			'kidia-mobile-cms'
		);
		?>

		<strong>
			<?php
			echo esc_html(
				KIDIA_MOBILE_CMS_VERSION
			);
			?>
		</strong>
	</p>

	<?php if ( isset( $_GET['license_updated'] ) ) : ?>
		<div class="notice notice-success inline"><p><?php esc_html_e( 'License updated successfully.', 'kidia-mobile-cms' ); ?></p></div>
	<?php endif; ?>

	<?php if ( isset( $_GET['license_error'] ) ) : ?>
		<div class="notice notice-error inline"><p><?php echo esc_html( sanitize_text_field( wp_unslash( $_GET['license_error'] ) ) ); ?></p></div>
	<?php endif; ?>

	<div class="kidia-dashboard__grid">

		<section class="kidia-dashboard__card kidia-dashboard__card--license">
			<h2><?php esc_html_e( 'License', 'kidia-mobile-cms' ); ?></h2>

			<table class="widefat striped">
				<tbody>
					<tr>
						<th scope="row"><?php esc_html_e( 'Status', 'kidia-mobile-cms' ); ?></th>
						<td>
							<span class="kidia-status <?php echo $license_active ? 'kidia-status--online' : 'kidia-status--offline'; ?>">
								<?php echo $license_active ? esc_html__( 'Active', 'kidia-mobile-cms' ) : esc_html__( 'Inactive', 'kidia-mobile-cms' ); ?>
							</span>
						</td>
					</tr>
					<tr>
						<th scope="row"><?php esc_html_e( 'Plan', 'kidia-mobile-cms' ); ?></th>
						<td><?php echo esc_html( $license_plan ); ?></td>
					</tr>
					<tr>
						<th scope="row"><?php esc_html_e( 'Expires', 'kidia-mobile-cms' ); ?></th>
						<td><?php echo esc_html( $license_expiry ); ?></td>
					</tr>
					<?php if ( ! empty( $license['last_verified_at'] ) ) : ?>
						<tr>
							<th scope="row"><?php esc_html_e( 'Last verified', 'kidia-mobile-cms' ); ?></th>
							<td><?php echo esc_html( wp_date( get_option( 'date_format' ) . ' ' . get_option( 'time_format' ), (int) $license['last_verified_at'] ) ); ?></td>
						</tr>
					<?php endif; ?>
				</tbody>
			</table>

			<?php if ( $license_active ) : ?>
				<?php if ( empty( $license['signature_configured'] ) ) : ?>
					<div class="notice notice-warning inline">
						<p><?php esc_html_e( 'License transport is active. Add the production signing public key before release to enable local Ed25519 proof verification.', 'kidia-mobile-cms' ); ?></p>
					</div>
				<?php endif; ?>
				<div class="kidia-license-actions">
					<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
						<input type="hidden" name="action" value="kidia_mobile_verify_license">
						<?php wp_nonce_field( 'kidia_mobile_license_action', 'kidia_mobile_license_nonce' ); ?>
						<button class="button button-primary" type="submit"><?php esc_html_e( 'Verify now', 'kidia-mobile-cms' ); ?></button>
					</form>
					<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
						<input type="hidden" name="action" value="kidia_mobile_deactivate_license">
						<?php wp_nonce_field( 'kidia_mobile_license_action', 'kidia_mobile_license_nonce' ); ?>
						<button class="button" type="submit"><?php esc_html_e( 'Deactivate', 'kidia-mobile-cms' ); ?></button>
					</form>
				</div>
			<?php else : ?>
				<form class="kidia-license-form" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
					<input type="hidden" name="action" value="kidia_mobile_activate_license">
					<?php wp_nonce_field( 'kidia_mobile_license_action', 'kidia_mobile_license_nonce' ); ?>
					<label for="kidia-license-key"><?php esc_html_e( 'License key', 'kidia-mobile-cms' ); ?></label>
					<input id="kidia-license-key" name="license_key" type="password" autocomplete="off" required>
					<button class="button button-primary" type="submit"><?php esc_html_e( 'Activate license', 'kidia-mobile-cms' ); ?></button>
				</form>
			<?php endif; ?>
		</section>

		<section class="kidia-dashboard__card kidia-dashboard__card--quick-actions">
			<h2><?php esc_html_e( 'Get started', 'kidia-mobile-cms' ); ?></h2>
			<p><?php esc_html_e( 'Configure the app manually or choose one of the available themes.', 'kidia-mobile-cms' ); ?></p>
			<a
				class="button button-primary <?php echo $license_active ? '' : 'disabled'; ?>"
				href="<?php echo $license_active ? esc_url( admin_url( 'admin.php?page=kidia-mobile-setup' ) ) : '#'; ?>"
				<?php echo $license_active ? '' : 'aria-disabled="true"'; ?>
			>
				<?php echo $setup_complete ? esc_html__( 'Open Setup & Themes', 'kidia-mobile-cms' ) : esc_html__( 'Start Setup Wizard', 'kidia-mobile-cms' ); ?>
			</a>
			<?php if ( ! $license_active ) : ?>
				<p class="description"><?php esc_html_e( 'Activate a license to use Setup & Themes.', 'kidia-mobile-cms' ); ?></p>
			<?php endif; ?>
		</section>

		<section class="kidia-dashboard__card">

			<h2>
				<?php
				esc_html_e(
					'System Status',
					'kidia-mobile-cms'
				);
				?>
			</h2>

			<table class="widefat striped">

				<tbody>

					<tr>

						<th scope="row">
							<?php
							esc_html_e(
								'Plugin Status',
								'kidia-mobile-cms'
							);
							?>
						</th>

						<td>
							<span class="kidia-status kidia-status--online">
								<?php
								esc_html_e(
									'Running',
									'kidia-mobile-cms'
								);
								?>
							</span>
						</td>

					</tr>

					<tr>

						<th scope="row">
							<?php
							esc_html_e(
								'WordPress',
								'kidia-mobile-cms'
							);
							?>
						</th>

						<td>
							<?php
							echo esc_html(
								get_bloginfo( 'version' )
							);
							?>
						</td>

					</tr>

					<tr>

						<th scope="row">
							<?php
							esc_html_e(
								'PHP',
								'kidia-mobile-cms'
							);
							?>
						</th>

						<td>
							<?php
							echo esc_html(
								PHP_VERSION
							);
							?>
						</td>

					</tr>

					<tr>

						<th scope="row">
							<?php
							esc_html_e(
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

		</section>

		<section class="kidia-dashboard__card">

			<h2>
				<?php
				esc_html_e(
					'API Monitor',
					'kidia-mobile-cms'
				);
				?>
			</h2>

			<table class="widefat striped">

				<tbody>

					<tr>

						<th scope="row">
							<?php
							esc_html_e(
								'Status',
								'kidia-mobile-cms'
							);
							?>
						</th>

						<td>

							<?php if ( $api_online ) : ?>

								<span class="kidia-status kidia-status--online">
									<?php
									esc_html_e(
										'Online',
										'kidia-mobile-cms'
									);
									?>
								</span>

							<?php else : ?>

								<span class="kidia-status kidia-status--offline">
									<?php
									esc_html_e(
										'Offline',
										'kidia-mobile-cms'
									);
									?>
								</span>

							<?php endif; ?>

						</td>

					</tr>

					<tr>

						<th scope="row">
							<?php
							esc_html_e(
								'Endpoint',
								'kidia-mobile-cms'
							);
							?>
						</th>

						<td>
							<code>
								<?php echo esc_html( $api_url ); ?>
							</code>
						</td>

					</tr>

					<tr>

						<th scope="row">
							<?php
							esc_html_e(
								'HTTP Status',
								'kidia-mobile-cms'
							);
							?>
						</th>

						<td>
							<?php echo esc_html( $api_status ); ?>
						</td>

					</tr>

					<tr>

						<th scope="row">
							<?php
							esc_html_e(
								'Response Time',
								'kidia-mobile-cms'
							);
							?>
						</th>

						<td>
							<?php echo esc_html( $api_time ); ?> ms
						</td>

					</tr>

					<?php if ( '' !== $api_message ) : ?>

						<tr>

							<th scope="row">
								<?php
								esc_html_e(
									'Message',
									'kidia-mobile-cms'
								);
								?>
							</th>

							<td>
								<?php echo esc_html( $api_message ); ?>
							</td>

						</tr>

					<?php endif; ?>

				</tbody>

			</table>

			<?php if ( '' !== $api_url ) : ?>

				<p>

					<a
						class="button button-primary"
						href="<?php echo esc_url( $api_url ); ?>"
						target="_blank"
						rel="noopener noreferrer"
					>
						<?php
						esc_html_e(
							'Open API',
							'kidia-mobile-cms'
						);
						?>
					</a>

				</p>

			<?php endif; ?>

		</section>

	</div>

	<div class="notice notice-success inline">

		<p>
			<?php
			esc_html_e(
				'Kidia Mobile CMS initialized successfully.',
				'kidia-mobile-cms'
			);
			?>
		</p>

	</div>

</div>

<style>
	.kidia-dashboard {
		max-width: 1280px;
	}

	.kidia-dashboard__grid {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: 24px;
		margin: 24px 0;
	}

	.kidia-dashboard__card {
		padding: 22px;
		border: 1px solid #dcdcde;
		border-radius: 14px;
		background: #ffffff;
		box-shadow: 0 4px 16px rgba(0, 0, 0, 0.04);
	}

	.kidia-dashboard__card h2 {
		margin-top: 0;
	}

	.kidia-license-form {
		display: grid;
		gap: 10px;
		margin-top: 16px;
	}

	.kidia-license-form input {
		width: 100%;
	}

	.kidia-license-actions {
		display: flex;
		gap: 10px;
		margin-top: 16px;
	}

	.kidia-dashboard__card table th {
		width: 190px;
	}

	.kidia-status {
		display: inline-flex;
		align-items: center;
		padding: 5px 11px;
		border-radius: 999px;
		font-size: 12px;
		font-weight: 700;
	}

	.kidia-status--online {
		color: #146c2e;
		background: #dff6dd;
	}

	.kidia-status--offline {
		color: #b32d2e;
		background: #fde2e1;
	}

	@media (max-width: 960px) {
		.kidia-dashboard__grid {
			grid-template-columns: 1fr;
		}
	}
</style>
