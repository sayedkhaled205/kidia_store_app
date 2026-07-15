<?php
/**
 * Woo Mobile CMS Dashboard.
 *
 * Available variables:
 *
 * @var array<string, mixed> $api API monitor status.
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
?>

<div class="wrap kidia-dashboard">

	<h1>
		<?php
		esc_html_e(
			'Woo Mobile CMS',
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

	<div class="kidia-dashboard__grid">

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
				'Woo Mobile CMS initialized successfully.',
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