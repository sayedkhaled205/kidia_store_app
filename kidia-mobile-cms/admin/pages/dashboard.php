<?php
/**
 * Kidia Mobile CMS Dashboard.
 *
 * Available variables:
 *
 * @var array<string, mixed> $api API monitor status.
 * @var array<string, mixed> $license License state.
 * @var bool                 $setup_complete Setup state.
 * @var bool                 $website_connected Website connection state.
 * @var string               $connect_url WooMobile customer connection URL.
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
$show_setup_choice = $license_active
	&& ! $setup_complete
	&& isset( $_GET['license_updated'] )
	&& 'activated' === sanitize_key( wp_unslash( $_GET['license_updated'] ) );
$journey_steps = array(
	array(
		'title'       => __( 'Purchase and connect', 'kidia-mobile-cms' ),
		'description' => __( 'Open WooMobile to purchase a plan and connect this already-installed WordPress plugin.', 'kidia-mobile-cms' ),
		'complete'    => $website_connected,
	),
	array(
		'title'       => __( 'Activate your license', 'kidia-mobile-cms' ),
		'description' => __( 'Enter the license issued for this website below to unlock the plugin.', 'kidia-mobile-cms' ),
		'complete'    => $license_active,
	),
	array(
		'title'       => __( 'Set up your app', 'kidia-mobile-cms' ),
		'description' => __( 'Use the Setup Wizard or continue with manual configuration.', 'kidia-mobile-cms' ),
		'complete'    => $setup_complete,
	),
	array(
		'title'       => __( 'Build your app', 'kidia-mobile-cms' ),
		'description' => __( 'Review your configuration and generate a new application build.', 'kidia-mobile-cms' ),
		'complete'    => false,
	),
);
$current_journey_step = 0;
foreach ( $journey_steps as $journey_index => $journey_step ) {
	if ( empty( $journey_step['complete'] ) ) {
		$current_journey_step = $journey_index;
		break;
	}

	$current_journey_step = $journey_index + 1;
}
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

	<section class="kidia-customer-journey" aria-labelledby="kidia-customer-journey-title">
		<div class="kidia-customer-journey__header">
			<div>
				<span class="kidia-customer-journey__eyebrow"><?php esc_html_e( 'Your launch journey', 'kidia-mobile-cms' ); ?></span>
				<h2 id="kidia-customer-journey-title"><?php esc_html_e( 'From website connection to ready mobile app', 'kidia-mobile-cms' ); ?></h2>
				<p><?php esc_html_e( 'Woo Mobile CMS is already installed. Connect this website, activate its serial, then choose the wizard or manual setup.', 'kidia-mobile-cms' ); ?></p>
			</div>
			<?php if ( ! $license_active ) : ?>
				<a class="button button-primary button-hero" href="<?php echo esc_url( $website_connected ? '#kidia-license-key' : $connect_url ); ?>">
					<?php echo $website_connected ? esc_html__( 'Enter your serial', 'kidia-mobile-cms' ) : esc_html__( 'Connect website', 'kidia-mobile-cms' ); ?>
				</a>
			<?php endif; ?>
		</div>

		<ol class="kidia-customer-journey__steps">
			<?php foreach ( $journey_steps as $journey_index => $journey_step ) : ?>
				<?php
				$step_complete = ! empty( $journey_step['complete'] );
				$step_current  = ! $step_complete && $current_journey_step === $journey_index;
				$step_class    = $step_complete
					? 'is-complete'
					: ( $step_current ? 'is-current' : 'is-upcoming' );
				?>
				<li class="<?php echo esc_attr( $step_class ); ?>">
					<span class="kidia-customer-journey__number" aria-hidden="true">
						<?php echo $step_complete ? '&#10003;' : esc_html( (string) ( $journey_index + 1 ) ); ?>
					</span>
					<div>
						<h3><?php echo esc_html( (string) $journey_step['title'] ); ?></h3>
						<p><?php echo esc_html( (string) $journey_step['description'] ); ?></p>
						<?php if ( $step_current ) : ?>
							<strong><?php esc_html_e( 'Current step', 'kidia-mobile-cms' ); ?></strong>
						<?php elseif ( $step_complete ) : ?>
							<strong><?php esc_html_e( 'Complete', 'kidia-mobile-cms' ); ?></strong>
						<?php endif; ?>
					</div>
				</li>
			<?php endforeach; ?>
		</ol>
	</section>

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
				</div>
			<?php else : ?>
				<?php if ( ! $website_connected ) : ?>
					<p><?php esc_html_e( 'Start by purchasing a plan and connecting this website. You will return here to enter the serial issued for it.', 'kidia-mobile-cms' ); ?></p>
					<p><a class="button button-secondary" href="<?php echo esc_url( $connect_url ); ?>"><?php esc_html_e( 'Purchase and connect website', 'kidia-mobile-cms' ); ?></a></p>
				<?php endif; ?>
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

	<?php if ( $show_setup_choice ) : ?>
		<div class="kidia-setup-choice" role="dialog" aria-modal="true" aria-labelledby="kidia-setup-choice-title">
			<div class="kidia-setup-choice__panel">
				<h2 id="kidia-setup-choice-title"><?php esc_html_e( 'Your license is active', 'kidia-mobile-cms' ); ?></h2>
				<p><?php esc_html_e( 'Would you like Woo Mobile CMS to guide you through setup, or configure everything manually?', 'kidia-mobile-cms' ); ?></p>
				<div class="kidia-setup-choice__actions">
					<a class="button button-primary button-hero" href="<?php echo esc_url( admin_url( 'admin.php?page=kidia-mobile-setup' ) ); ?>">
						<?php esc_html_e( 'Start Setup Wizard', 'kidia-mobile-cms' ); ?>
					</a>
					<a class="button button-hero" href="<?php echo esc_url( admin_url( 'admin.php?page=kidia-mobile-cms&setup_choice=manual' ) ); ?>">
						<?php esc_html_e( 'Continue Manually', 'kidia-mobile-cms' ); ?>
					</a>
				</div>
			</div>
		</div>
		<style>
			.kidia-setup-choice{position:fixed;inset:0;z-index:100100;display:grid;place-items:center;padding:24px;background:rgba(15,23,42,.64)}
			.kidia-setup-choice__panel{width:min(560px,100%);padding:32px;border-radius:18px;background:#fff;box-shadow:0 24px 70px rgba(15,23,42,.3);text-align:center}
			.kidia-setup-choice__panel h2{margin-top:0;font-size:28px}
			.kidia-setup-choice__panel p{font-size:16px;color:#475569}
			.kidia-setup-choice__actions{display:flex;flex-wrap:wrap;justify-content:center;gap:12px;margin-top:24px}
		</style>
	<?php endif; ?>

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

	.kidia-customer-journey {
		margin-top: 24px;
		padding: 26px;
		border: 1px solid #cfe2dc;
		border-radius: 18px;
		background: linear-gradient(135deg, #ffffff 0%, #eef8f5 100%);
		box-shadow: 0 8px 24px rgba(31, 71, 61, 0.06);
	}

	.kidia-customer-journey__header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 24px;
	}

	.kidia-customer-journey__header h2 {
		margin: 4px 0 8px;
		font-size: 25px;
	}

	.kidia-customer-journey__header p {
		margin: 0;
		color: #60706c;
	}

	.kidia-customer-journey__eyebrow {
		color: #2f806e;
		font-size: 12px;
		font-weight: 800;
		letter-spacing: .1em;
		text-transform: uppercase;
	}

	.kidia-customer-journey__steps {
		display: grid;
		grid-template-columns: repeat(5, minmax(0, 1fr));
		gap: 12px;
		margin: 26px 0 0;
		padding: 0;
		list-style: none;
	}

	.kidia-customer-journey__steps li {
		position: relative;
		display: grid;
		grid-template-columns: 34px 1fr;
		gap: 10px;
		min-height: 120px;
		padding: 16px;
		border: 1px solid #dce8e5;
		border-radius: 14px;
		background: #ffffff;
	}

	.kidia-customer-journey__steps li.is-current {
		border-color: #2f806e;
		box-shadow: 0 0 0 2px rgba(47, 128, 110, .12);
	}

	.kidia-customer-journey__steps li.is-upcoming {
		opacity: .66;
	}

	.kidia-customer-journey__number {
		display: grid;
		place-items: center;
		width: 32px;
		height: 32px;
		border: 2px solid #b9cec8;
		border-radius: 50%;
		color: #60706c;
		font-weight: 800;
	}

	.is-complete .kidia-customer-journey__number,
	.is-current .kidia-customer-journey__number {
		border-color: #2f806e;
		background: #2f806e;
		color: #ffffff;
	}

	.kidia-customer-journey__steps h3 {
		margin: 2px 0 7px;
		font-size: 14px;
	}

	.kidia-customer-journey__steps p {
		margin: 0 0 8px;
		color: #60706c;
		font-size: 12px;
		line-height: 1.45;
	}

	.kidia-customer-journey__steps strong {
		color: #2f806e;
		font-size: 11px;
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

		.kidia-customer-journey__steps {
			grid-template-columns: 1fr;
		}

		.kidia-customer-journey__steps li {
			min-height: 0;
		}
	}

	@media (max-width: 782px) {
		.kidia-customer-journey__header {
			align-items: flex-start;
			flex-direction: column;
		}
	}
</style>
