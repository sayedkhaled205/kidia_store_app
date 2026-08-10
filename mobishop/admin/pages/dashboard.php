<?php
/**
 * MobiShop Dashboard.
 *
 * Available variables:
 *
 * @var array<string, mixed> $api API monitor status.
 * @var array<string, mixed> $license License state.
 * @var bool                 $setup_complete Setup state.
 * @var bool                 $website_connected Website connection state.
 * @var string               $connect_url MobiShop customer connection URL.
 *
 * @package MobiShop
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
	: __( 'No active plan', 'mobishop' );
$license_expiry = ! empty( $license['expires_at'] )
	? wp_date( get_option( 'date_format' ), (int) $license['expires_at'] )
	: __( 'No expiry', 'mobishop' );
$show_setup_choice = $license_active
	&& ! $setup_complete
	&& isset( $_GET['license_updated'] )
	&& 'activated' === sanitize_key( wp_unslash( $_GET['license_updated'] ) );
$connection_step_complete = $website_connected;
$license_step_complete    = $connection_step_complete && $license_active;
$setup_step_complete      = $license_step_complete && $setup_complete;
$build_step_complete      = $setup_step_complete && $app_export_current;
$build_state              = wp_parse_args(
	is_array( $app_export_state ?? null ) ? $app_export_state : array(),
	array(
		'status'        => 'idle',
		'progress'      => 0,
		'message'       => '',
		'apk_file_name' => '',
	)
);
$build_status             = sanitize_key( (string) $build_state['status'] );
if ( 'ready' === $build_status && ! $app_export_current ) {
	$build_status          = 'idle';
	$build_state['message'] = __( 'Application settings changed. Build a new APK to include the latest setup.', 'mobishop' );
}
$build_in_progress = in_array( $build_status, array( 'queued', 'building' ), true );
$build_auto_download = isset( $_GET['build_notice'] )
	&& 'started' === sanitize_key( wp_unslash( $_GET['build_notice'] ) );
$build_action = $build_step_complete
	? 'mobishop_download_apk'
	: 'mobishop_build_app';
$build_button_label = $build_step_complete
	? __( 'Download APK', 'mobishop' )
	: ( $build_in_progress
			? __( 'Building APK…', 'mobishop' )
			: __( 'Build Your App', 'mobishop' )
	);
$journey_steps = array(
	array(
		'title'       => __( 'Purchase and connect', 'mobishop' ),
		'description' => __( 'Open MobiShop to purchase a plan and connect this already-installed WordPress plugin.', 'mobishop' ),
		'complete'    => $connection_step_complete,
	),
	array(
		'title'       => __( 'Activate your license', 'mobishop' ),
		'description' => __( 'Enter the license issued for this website below to unlock the plugin.', 'mobishop' ),
		'complete'    => $license_step_complete,
	),
	array(
		'title'       => __( 'Set up your app', 'mobishop' ),
		'description' => __( 'Use the Setup Wizard or continue with manual configuration.', 'mobishop' ),
		'complete'    => $setup_step_complete,
	),
	array(
		'title'       => __( 'Build your app', 'mobishop' ),
		'description' => __( 'Build a real Android APK, then download it directly to install on your phone.', 'mobishop' ),
		'complete'    => $build_step_complete,
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

<div class="wrap mobishop-dashboard">

	<?php if ( isset( $_GET['license_updated'] ) ) : ?>
		<div class="notice notice-success inline"><p><?php esc_html_e( 'License updated successfully.', 'mobishop' ); ?></p></div>
	<?php endif; ?>

	<?php if ( isset( $_GET['license_error'] ) ) : ?>
		<div class="notice notice-error inline"><p><?php echo esc_html( sanitize_text_field( wp_unslash( $_GET['license_error'] ) ) ); ?></p></div>
	<?php endif; ?>

	<?php if ( isset( $_GET['build_notice'] ) && 'started' === sanitize_key( wp_unslash( $_GET['build_notice'] ) ) ) : ?>
		<div class="notice notice-success inline"><p><?php esc_html_e( 'Your APK build has started. You can leave this page and return later.', 'mobishop' ); ?></p></div>
	<?php elseif ( isset( $_GET['build_notice'] ) && 'error' === sanitize_key( wp_unslash( $_GET['build_notice'] ) ) ) : ?>
		<div class="notice notice-error inline"><p><?php echo esc_html( isset( $_GET['build_message'] ) ? sanitize_text_field( wp_unslash( $_GET['build_message'] ) ) : __( 'The APK build could not be started.', 'mobishop' ) ); ?></p></div>
	<?php endif; ?>

	<section class="mobishop-customer-journey" aria-labelledby="mobishop-customer-journey-title">
		<div class="mobishop-customer-journey__header">
			<div>
				<span class="mobishop-customer-journey__eyebrow"><?php esc_html_e( 'Your launch journey', 'mobishop' ); ?></span>
				<h2 id="mobishop-customer-journey-title"><?php esc_html_e( 'From website connection to ready mobile app', 'mobishop' ); ?></h2>
				<p><?php esc_html_e( 'MobiShop is already installed. Connect this website, activate its serial, then choose the wizard or manual setup.', 'mobishop' ); ?></p>
			</div>
			<?php if ( ! $license_active ) : ?>
				<a class="button button-primary button-hero" href="<?php echo esc_url( $website_connected ? '#mobishop-license-key' : $connect_url ); ?>">
					<?php echo $website_connected ? esc_html__( 'Enter your serial', 'mobishop' ) : esc_html__( 'Connect website', 'mobishop' ); ?>
				</a>
			<?php endif; ?>
		</div>

		<ol class="mobishop-customer-journey__steps">
			<?php foreach ( $journey_steps as $journey_index => $journey_step ) : ?>
				<?php
				$step_complete = ! empty( $journey_step['complete'] );
				$step_current  = ! $step_complete && $current_journey_step === $journey_index;
				$step_class    = $step_complete
					? 'is-complete'
					: ( $step_current ? 'is-current' : 'is-upcoming' );
				?>
				<?php if ( 3 === $journey_index ) : ?>
					<li
						class="<?php echo esc_attr( $step_class ); ?> mobishop-customer-journey__build-step"
						data-mobishop-app-build
						data-status="<?php echo esc_attr( $build_status ); ?>"
						data-build-id="<?php echo esc_attr( (string) ( $build_state['build_id'] ?? '' ) ); ?>"
						data-completed-at="<?php echo esc_attr( (string) absint( $build_state['completed_at'] ?? 0 ) ); ?>"
						data-can-build="<?php echo $setup_step_complete ? '1' : '0'; ?>"
						data-auto-download="<?php echo $build_auto_download ? '1' : '0'; ?>"
					>
						<form class="mobishop-app-build__card-form" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" data-build-form>
							<input type="hidden" name="action" value="<?php echo esc_attr( $build_action ); ?>" data-build-form-action>
							<?php wp_nonce_field( 'mobishop_build_app', 'mobishop_build_nonce', false ); ?>
							<?php wp_nonce_field( 'mobishop_download_apk', 'mobishop_download_nonce', false ); ?>
							<button
								type="submit"
								class="mobishop-app-build__card mobishop-app-build__card-button"
								data-build-action
								aria-busy="<?php echo $build_in_progress ? 'true' : 'false'; ?>"
								<?php disabled( ! $setup_step_complete || $build_in_progress ); ?>
							>
								<strong class="mobishop-app-build__title" data-build-action-label><?php echo esc_html( $build_button_label ); ?></strong>
								<p class="mobishop-app-build__message" data-build-message>
								<?php
								echo esc_html(
									(string) $build_state['message'] ?: (
										$build_step_complete
											? __( 'Your APK is ready to install.', 'mobishop' )
											: __( 'Build an APK after completing the application setup.', 'mobishop' )
									)
								);
								?>
								</p>
								<small class="mobishop-app-build__files" data-build-files><?php esc_html_e( 'Android &amp; iOS', 'mobishop' ); ?></small>
							</button>
						</form>
						<div class="mobishop-app-build__recent-choice" data-build-recent-choice hidden>
							<div class="mobishop-app-build__recent-choice-card" role="dialog" aria-modal="true" aria-labelledby="mobishop-recent-build-title">
								<h3 id="mobishop-recent-build-title"><?php esc_html_e( 'A successful build is available from the last 10 days', 'mobishop' ); ?></h3>
								<p><?php esc_html_e( 'Download the latest version again or create a new build.', 'mobishop' ); ?></p>
								<div class="mobishop-app-build__recent-choice-actions">
									<button type="button" class="button button-primary" data-build-download-again><?php esc_html_e( 'Download Again', 'mobishop' ); ?></button>
									<button type="button" class="button" data-build-new-version><?php esc_html_e( 'Build New Version', 'mobishop' ); ?></button>
									<button type="button" class="button" data-build-recent-cancel><?php esc_html_e( 'Cancel', 'mobishop' ); ?></button>
								</div>
							</div>
						</div>
					</li>
				<?php else : ?>
					<li class="<?php echo esc_attr( $step_class ); ?>">
						<span class="mobishop-customer-journey__number" aria-hidden="true">
							<?php echo $step_complete ? '&#10003;' : esc_html( (string) ( $journey_index + 1 ) ); ?>
						</span>
						<div>
							<h3><?php echo esc_html( (string) $journey_step['title'] ); ?></h3>
							<p><?php echo esc_html( (string) $journey_step['description'] ); ?></p>
							<?php if ( $step_current ) : ?>
								<strong><?php esc_html_e( 'Current step', 'mobishop' ); ?></strong>
							<?php elseif ( $step_complete ) : ?>
								<strong><?php esc_html_e( 'Complete', 'mobishop' ); ?></strong>
							<?php endif; ?>
						</div>
					</li>
				<?php endif; ?>
			<?php endforeach; ?>
		</ol>
	</section>

	<div class="mobishop-dashboard__grid">

		<section class="mobishop-dashboard__card mobishop-dashboard__card--license">
			<div class="mobishop-dashboard__card-header">
				<span class="mobishop-dashboard__card-icon dashicons dashicons-shield-alt" aria-hidden="true"></span>
				<div>
					<span class="mobishop-dashboard__card-eyebrow"><?php esc_html_e( 'Website access', 'mobishop' ); ?></span>
					<h2><?php esc_html_e( 'License', 'mobishop' ); ?></h2>
					<p><?php esc_html_e( 'Connect this website and activate its serial to unlock every builder tool.', 'mobishop' ); ?></p>
				</div>
			</div>

			<table class="widefat striped mobishop-license-summary">
				<tbody>
					<tr>
						<th scope="row"><?php esc_html_e( 'Status', 'mobishop' ); ?></th>
						<td>
							<span class="mobishop-status <?php echo $license_active ? 'mobishop-status--online' : 'mobishop-status--offline'; ?>">
								<?php echo $license_active ? esc_html__( 'Active', 'mobishop' ) : esc_html__( 'Inactive', 'mobishop' ); ?>
							</span>
						</td>
					</tr>
					<tr>
						<th scope="row"><?php esc_html_e( 'Plan', 'mobishop' ); ?></th>
						<td><?php echo esc_html( $license_plan ); ?></td>
					</tr>
					<tr>
						<th scope="row"><?php esc_html_e( 'Expires', 'mobishop' ); ?></th>
						<td><?php echo esc_html( $license_expiry ); ?></td>
					</tr>
					<tr>
						<th scope="row"><?php esc_html_e( 'Website', 'mobishop' ); ?></th>
						<td>
							<span class="mobishop-status <?php echo $website_connected ? 'mobishop-status--online' : 'mobishop-status--offline'; ?>">
								<?php echo $website_connected ? esc_html__( 'Connected', 'mobishop' ) : esc_html__( 'Not connected', 'mobishop' ); ?>
							</span>
						</td>
					</tr>
					<tr>
						<th scope="row"><?php esc_html_e( 'API', 'mobishop' ); ?></th>
						<td>
							<span class="mobishop-status <?php echo $api_online ? 'mobishop-status--online' : 'mobishop-status--offline'; ?>">
								<?php echo $api_online ? esc_html__( 'Online', 'mobishop' ) : esc_html__( 'Offline', 'mobishop' ); ?>
							</span>
						</td>
					</tr>
					<tr>
						<th scope="row"><?php esc_html_e( 'Plugin version', 'mobishop' ); ?></th>
						<td><?php echo esc_html( defined( 'MOBISHOP_VERSION' ) ? MOBISHOP_VERSION : '' ); ?></td>
					</tr>
					<?php if ( ! empty( $license['last_verified_at'] ) ) : ?>
						<tr>
							<th scope="row"><?php esc_html_e( 'Last verified', 'mobishop' ); ?></th>
							<td><?php echo esc_html( wp_date( get_option( 'date_format' ) . ' ' . get_option( 'time_format' ), (int) $license['last_verified_at'] ) ); ?></td>
						</tr>
					<?php endif; ?>
				</tbody>
			</table>

			<?php if ( $license_active ) : ?>
				<?php if ( empty( $license['signature_configured'] ) ) : ?>
					<div class="notice notice-warning inline">
						<p><?php esc_html_e( 'License transport is active. Add the production signing public key before release to enable local Ed25519 proof verification.', 'mobishop' ); ?></p>
					</div>
				<?php endif; ?>
			<?php else : ?>
				<form class="mobishop-license-form" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
					<input type="hidden" name="action" value="mobishop_activate_license">
					<?php wp_nonce_field( 'mobishop_license_action', 'mobishop_license_nonce' ); ?>
					<label for="mobishop-license-key"><?php esc_html_e( 'License key', 'mobishop' ); ?></label>
					<input id="mobishop-license-key" name="license_key" type="password" autocomplete="off" required>
					<button class="button button-primary" type="submit"><?php esc_html_e( 'Activate license', 'mobishop' ); ?></button>
				</form>
			<?php endif; ?>

		</section>

	</div>

	<?php if ( $show_setup_choice ) : ?>
		<div class="mobishop-setup-choice" role="dialog" aria-modal="true" aria-labelledby="mobishop-setup-choice-title">
			<div class="mobishop-setup-choice__panel">
				<h2 id="mobishop-setup-choice-title"><?php esc_html_e( 'Your license is active', 'mobishop' ); ?></h2>
				<p><?php esc_html_e( 'Would you like MobiShop to guide you through setup, or configure everything manually?', 'mobishop' ); ?></p>
				<div class="mobishop-setup-choice__actions">
					<a class="button button-primary button-hero" href="<?php echo esc_url( admin_url( 'admin.php?page=mobishop-setup' ) ); ?>">
						<?php esc_html_e( 'Start Setup Wizard', 'mobishop' ); ?>
					</a>
					<a class="button button-hero" href="<?php echo esc_url( admin_url( 'admin.php?page=mobishop&setup_choice=manual' ) ); ?>">
						<?php esc_html_e( 'Continue Manually', 'mobishop' ); ?>
					</a>
				</div>
			</div>
		</div>
		<style>
			.mobishop-setup-choice{position:fixed;inset:0;z-index:100100;display:grid;place-items:center;padding:24px;background:rgba(15,23,42,.64)}
			.mobishop-setup-choice__panel{width:min(560px,100%);padding:32px;border-radius:18px;background:#fff;box-shadow:0 24px 70px rgba(15,23,42,.3);text-align:center}
			.mobishop-setup-choice__panel h2{margin-top:0;font-size:28px}
			.mobishop-setup-choice__panel p{font-size:16px;color:#475569}
			.mobishop-setup-choice__actions{display:flex;flex-wrap:wrap;justify-content:center;gap:12px;margin-top:24px}
		</style>
	<?php endif; ?>

</div>

<style>
	.mobishop-dashboard {
		max-width: 1280px;
	}

	.mobishop-dashboard__grid {
		display: grid;
		grid-template-columns: minmax(0, 1fr);
		justify-items: center;
		gap: 24px;
		margin: 24px 0;
	}

	.mobishop-customer-journey {
		margin-top: 24px;
		padding: 26px;
		border: 1px solid #cfe2dc;
		border-radius: 18px;
		background: linear-gradient(135deg, #ffffff 0%, #eef8f5 100%);
		box-shadow: 0 8px 24px rgba(31, 71, 61, 0.06);
	}

	.mobishop-customer-journey__header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 24px;
	}

	.mobishop-customer-journey__header h2 {
		margin: 4px 0 8px;
		font-size: 25px;
	}

	.mobishop-customer-journey__header p {
		margin: 0;
		color: #60706c;
	}

	.mobishop-customer-journey__eyebrow {
		color: #2f806e;
		font-size: 12px;
		font-weight: 800;
		letter-spacing: .1em;
		text-transform: uppercase;
	}

	.mobishop-customer-journey__steps {
		display: grid;
		grid-template-columns: repeat(4, minmax(0, 1fr));
		gap: 12px;
		margin: 26px 0 0;
		padding: 0;
		list-style: none;
	}

	.mobishop-customer-journey__steps li {
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

	.mobishop-customer-journey__steps li.is-current {
		border-color: #2f806e;
		box-shadow: 0 0 0 2px rgba(47, 128, 110, .12);
	}

	.mobishop-customer-journey__steps li.is-upcoming {
		opacity: .66;
	}

	.mobishop-customer-journey__number {
		display: grid;
		place-items: center;
		width: 32px;
		height: 32px;
		border: 2px solid #b9cec8;
		border-radius: 50%;
		color: #60706c;
		font-weight: 800;
	}

	.is-complete .mobishop-customer-journey__number,
	.is-current .mobishop-customer-journey__number {
		border-color: #2f806e;
		background: #2f806e;
		color: #ffffff;
	}

	.mobishop-customer-journey__steps h3 {
		margin: 2px 0 7px;
		font-size: 14px;
	}

	.mobishop-customer-journey__steps p {
		margin: 0 0 8px;
		color: #60706c;
		font-size: 12px;
		line-height: 1.45;
	}

	.mobishop-customer-journey__steps strong {
		color: #2f806e;
		font-size: 11px;
	}

	.mobishop-customer-journey__steps li.mobishop-customer-journey__build-step {
		display: block;
		padding: 0;
		border-color: #cfe2dc;
		background: #f8fcfb;
		opacity: 1;
	}

	.mobishop-app-build__card {
		display: flex;
		min-height: 120px;
		box-sizing: border-box;
		flex-direction: column;
		justify-content: center;
		padding: 15px;
	}

	.mobishop-app-build__title {
		color: #173f36;
		font-size: 14px;
	}

	.mobishop-app-build__message {
		min-height: 32px;
		margin: 5px 0 9px !important;
		color: #60706c !important;
		font-size: 11px !important;
		line-height: 1.4 !important;
	}

	.mobishop-app-build__actions {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.mobishop-app-build__card-form {
		flex: 1;
		height: 100%;
		margin: 0;
	}

	.mobishop-app-build__card-button {
		display: flex;
		width: 100%;
		height: 100%;
		min-height: 120px;
		box-sizing: border-box;
		align-items: flex-start;
		flex-direction: column;
		justify-content: center;
		padding: 15px;
		border: 1px solid #2f806e;
		border-radius: inherit;
		background: #2f806e;
		color: #ffffff;
		font-family: "Segoe UI", Inter, -apple-system, BlinkMacSystemFont, sans-serif;
		text-align: center;
		cursor: pointer;
		transition: background .18s ease, border-color .18s ease, box-shadow .18s ease, transform .18s ease;
	}

	.mobishop-app-build__card-button .mobishop-app-build__title {
		width: 100%;
		font-size: 15px;
		font-weight: 800;
		text-align: center;
	}

	.mobishop-app-build__files {
		width: 100%;
		margin-top: 5px;
		color: #e7f5f1;
		font-size: 11px;
		font-weight: 400;
		line-height: 1.4;
		text-align: center;
	}

	.mobishop-app-build__recent-choice {
		position: fixed;
		z-index: 100200;
		inset: 0;
		display: grid;
		place-items: center;
		padding: 20px;
		background: rgba(12, 31, 27, .42);
	}

	.mobishop-app-build__recent-choice[hidden] { display: none; }

	.mobishop-app-build__recent-choice-card {
		width: min(420px, 100%);
		box-sizing: border-box;
		padding: 24px;
		border-radius: 16px;
		background: #fff;
		box-shadow: 0 22px 60px rgba(12, 31, 27, .22);
		text-align: center;
	}

	.mobishop-app-build__recent-choice-card h3 { margin: 0 0 8px; }
	.mobishop-app-build__recent-choice-card p { margin: 0 0 18px; }
	.mobishop-app-build__recent-choice-actions { display: flex; justify-content: center; gap: 10px; }
	.mobishop-app-build__recent-choice-actions .button {
		min-height: 44px;
		padding: 7px 20px;
		border-color: #2f806e;
		border-radius: 10px;
		background: #fff;
		color: #2f806e;
		font-weight: 700;
	}
	.mobishop-app-build__recent-choice-actions .button:hover,
	.mobishop-app-build__recent-choice-actions .button:focus {
		border-color: #246b5c;
		background: #edf7f4;
		color: #246b5c;
	}
	.mobishop-app-build__recent-choice-actions .button-primary,
	.mobishop-app-build__recent-choice-actions .button-primary:hover,
	.mobishop-app-build__recent-choice-actions .button-primary:focus {
		border-color: #2f806e;
		background: #2f806e;
		color: #fff;
	}

	.mobishop-app-build__card-button .mobishop-app-build__title {
		color: #ffffff;
	}

	.mobishop-app-build__card-button .mobishop-app-build__message {
		min-height: 0;
		margin-bottom: 0 !important;
		color: #e7f5f1 !important;
		text-align: start;
	}

	[data-mobishop-app-build][data-status="idle"] .mobishop-app-build__message,
	[data-mobishop-app-build][data-status="downloaded"] .mobishop-app-build__message {
		display: none;
	}

	.mobishop-app-build__card-button:hover,
	.mobishop-app-build__card-button:focus {
		border-color: #287260;
		background: #287260;
		color: #ffffff;
		box-shadow: 0 10px 24px rgba(47, 128, 110, .24);
	}

	.mobishop-app-build__card-button:focus-visible {
		outline: 3px solid rgba(47, 128, 110, .28);
		outline-offset: 2px;
	}

	.mobishop-app-build__card-button:active {
		transform: translateY(1px);
	}

	.mobishop-app-build__card-button:disabled {
		background: #2f806e;
		color: #ffffff;
		cursor: not-allowed;
		opacity: .68;
	}

	.mobishop-app-build__card-label {
		display: block;
		font-size: clamp(11px, .85vw, 12px);
		font-weight: 700;
		line-height: 1.3;
		text-wrap: balance;
	}

	.mobishop-app-build__modal {
		z-index: 100100;
	}

	.mobishop-app-build__modal[hidden] {
		display: none;
	}

	.mobishop-app-build__modal-card {
		box-sizing: border-box;
	}

	.mobishop-app-build__modal-card .mobishop-app-build__message {
		min-height: 0;
		margin: 0 !important;
	}

	.mobishop-app-build__progress {
		margin: 0;
	}

	.mobishop-app-build__progress span {
		display: block;
		height: 100%;
		border-radius: inherit;
		background: #2f806e;
		transition: width .25s ease;
	}

	.mobishop-app-build__cancel {
		font-weight: 700 !important;
	}

	.mobishop-app-build__modal.is-docked .mobishop-app-build__modal-card {
		cursor: grab;
	}

	.mobishop-app-build__modal.is-docked.is-dragging .mobishop-app-build__modal-card {
		cursor: grabbing;
	}

	.mobishop-app-build__modal.is-docked .mobishop-app-build__modal-card :is(button, a) {
		cursor: pointer;
	}

	.mobishop-app-build__cancel:hover,
	.mobishop-app-build__cancel:focus {
		border-color: #b45a5a;
		background: #fff5f5;
		color: #8c1f1f;
	}

	[data-mobishop-app-build][data-status="downloaded"] .mobishop-app-build__cancel {
		border-color: #2f806e;
		background: #2f806e;
		color: #ffffff;
	}

	[data-mobishop-app-build][data-status="downloaded"] .mobishop-app-build__cancel:hover,
	[data-mobishop-app-build][data-status="downloaded"] .mobishop-app-build__cancel:focus {
		border-color: #287260;
		background: #287260;
		color: #ffffff;
	}

	.mobishop-app-build__cancel:disabled {
		cursor: wait;
		opacity: .62;
	}

	.mobishop-app-build__cancel[hidden] {
		display: none;
	}

	.mobishop-dashboard__card {
		padding: 26px;
		border: 1px solid #d8e3e0;
		border-radius: 18px;
		background: linear-gradient(180deg, #ffffff 0%, #fbfdfc 100%);
		box-shadow: 0 10px 30px rgba(31, 71, 61, 0.07);
	}

	.mobishop-dashboard__card h2 {
		margin: 2px 0 6px;
		font-size: 23px;
		line-height: 1.2;
	}

	.mobishop-dashboard__card-header {
		display: flex;
		align-items: flex-start;
		gap: 15px;
		margin-bottom: 22px;
	}

	.mobishop-dashboard__card-header > div {
		flex: 1;
	}

	.mobishop-dashboard__card-header p {
		max-width: 560px;
		margin: 0;
		color: #60706c;
		line-height: 1.55;
	}

	.mobishop-dashboard__card-icon {
		display: grid;
		flex: 0 0 48px;
		place-items: center;
		width: 48px;
		height: 48px;
		border-radius: 14px;
		background: #e4f3ef;
		color: #2f806e;
		font-size: 24px;
	}

	.mobishop-dashboard__card-eyebrow {
		color: #2f806e;
		font-size: 11px;
		font-weight: 800;
		letter-spacing: .09em;
		text-transform: uppercase;
	}

	.mobishop-license-summary {
		overflow: hidden;
		margin: 0;
		border: 1px solid #dbe6e3;
		border-radius: 12px;
		box-shadow: none;
	}

	.mobishop-license-summary th,
	.mobishop-license-summary td {
		padding: 13px 16px;
		border-bottom-color: #e8efed;
	}

	.mobishop-connect-prompt,
	.mobishop-setup-overview {
		display: flex;
		align-items: center;
		gap: 13px;
		margin-top: 18px;
		padding: 15px 16px;
		border: 1px solid #cfe2dc;
		border-radius: 13px;
		background: #f1f8f6;
	}

	.mobishop-connect-prompt__icon,
	.mobishop-setup-overview > .dashicons {
		display: grid;
		flex: 0 0 36px;
		place-items: center;
		width: 36px;
		height: 36px;
		border-radius: 10px;
		background: #ffffff;
		color: #2f806e;
		box-shadow: 0 3px 10px rgba(31, 71, 61, .08);
	}

	.mobishop-connect-prompt strong,
	.mobishop-setup-overview strong {
		display: block;
		margin-bottom: 3px;
		color: #173f36;
		font-size: 14px;
	}

	.mobishop-connect-prompt p,
	.mobishop-setup-overview > div > span {
		display: block;
		margin: 0;
		color: #60706c;
		font-size: 12px;
		line-height: 1.45;
	}

	.mobishop-setup-overview {
		margin: 0 0 16px;
	}

	.mobishop-setup-overview.is-locked {
		border-color: #e0e5e4;
		background: #f6f7f7;
	}

	.mobishop-setup-overview.is-locked > .dashicons {
		color: #7a8683;
	}

	.mobishop-dashboard__primary-action {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		min-height: 48px;
		margin-top: 14px;
		padding: 0 18px;
		border: 1px solid #2f806e;
		border-radius: 12px;
		background: #2f806e;
		color: #ffffff;
		font-size: 14px;
		font-weight: 700;
		text-decoration: none;
		box-shadow: 0 7px 18px rgba(47, 128, 110, .18);
		transition: transform .18s ease, background .18s ease, box-shadow .18s ease;
	}

	.mobishop-dashboard__primary-action:hover,
	.mobishop-dashboard__primary-action:focus {
		background: #256b5c;
		color: #ffffff;
		box-shadow: 0 9px 22px rgba(47, 128, 110, .24);
		transform: translateY(-1px);
	}

	.mobishop-dashboard__primary-action:focus {
		outline: none;
		box-shadow: 0 0 0 3px rgba(47, 128, 110, .16), 0 9px 22px rgba(47, 128, 110, .2);
	}

	.mobishop-dashboard__primary-action .dashicons {
		width: 18px;
		height: 18px;
		font-size: 18px;
	}

	.mobishop-dashboard__primary-action.is-disabled {
		pointer-events: none;
		border-color: #d7dcda;
		background: #e8ebea;
		color: #8a9390;
		box-shadow: none;
	}

	.mobishop-license-form {
		display: grid;
		gap: 10px;
		margin-top: 16px;
	}

	.mobishop-license-form input {
		width: 100%;
		min-height: 44px;
		border-color: #cfdad7;
		border-radius: 9px;
	}

	.mobishop-license-form .button-primary {
		min-height: 44px;
		border-color: #2f806e;
		border-radius: 9px;
		background: #2f806e;
	}

	.mobishop-dashboard__card--license {
		box-sizing: border-box;
		width: min(100%, 780px);
		padding: 16px;
		border-radius: 16px;
	}

	.mobishop-dashboard__card--license .mobishop-dashboard__card-header {
		gap: 10px;
		margin-bottom: 12px;
	}

	.mobishop-dashboard__card--license .mobishop-dashboard__card-icon {
		flex-basis: 36px;
		width: 36px;
		height: 36px;
		border-radius: 10px;
		font-size: 18px;
	}

	.mobishop-dashboard__card--license h2 {
		font-size: 18px;
	}

	.mobishop-dashboard__card--license .mobishop-dashboard__card-header p {
		font-size: 12px;
		line-height: 1.35;
	}

	.mobishop-dashboard__card--license .mobishop-license-summary {
		display: block;
		overflow: visible;
		border: 0;
		border-radius: 0;
		background: transparent;
	}

	.mobishop-dashboard__card--license .mobishop-license-summary tbody {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 8px;
	}

	.mobishop-dashboard__card--license .mobishop-license-summary tr {
		display: flex;
		min-width: 0;
		flex-direction: column;
		gap: 4px;
		padding: 9px 10px;
		border: 1px solid #e0ebe7;
		border-radius: 10px;
		background: #f8fbfa;
	}

	.mobishop-dashboard__card--license .mobishop-license-summary th,
	.mobishop-dashboard__card--license .mobishop-license-summary td {
		display: block;
		width: auto;
		padding: 0;
		border: 0;
		background: transparent;
	}

	.mobishop-dashboard__card--license .mobishop-license-summary th {
		color: #6b7b77;
		font-size: 11px;
		font-weight: 600;
	}

	.mobishop-dashboard__card--license .mobishop-license-summary td {
		overflow: hidden;
		color: #173f36;
		font-size: 12px;
		font-weight: 700;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.mobishop-dashboard__card--license .mobishop-connect-prompt {
		gap: 10px;
		margin-top: 12px;
		padding: 9px 10px;
		border-radius: 10px;
	}

	.mobishop-dashboard__card--license .mobishop-connect-prompt__icon {
		flex-basis: 31px;
		width: 31px;
		height: 31px;
		border-radius: 8px;
	}

	.mobishop-dashboard__card--license .mobishop-dashboard__primary-action {
		width: fit-content;
		min-height: 34px;
		margin-top: 0;
		margin-inline-start: auto;
		padding: 0 12px;
		border-radius: 8px;
		font-size: 12px;
	}

	.mobishop-dashboard__card--license .mobishop-license-form {
		grid-template-columns: minmax(0, 1fr) auto;
		gap: 8px;
		margin-top: 12px;
	}

	.mobishop-dashboard__card--license .mobishop-license-form label {
		grid-column: 1 / -1;
		margin: 0;
		font-size: 12px;
	}

	.mobishop-dashboard__card--license .mobishop-license-form input,
	.mobishop-dashboard__card--license .mobishop-license-form .button-primary {
		min-height: 34px;
	}

	.mobishop-dashboard__card--license .mobishop-license-form .button-primary {
		padding: 0 14px;
		border-radius: 8px;
		font-size: 12px;
	}

	.mobishop-dashboard__card--license .mobishop-setup-overview {
		flex-wrap: wrap;
		gap: 9px;
		margin: 12px 0 8px;
		padding: 9px 10px;
		border-radius: 10px;
	}

	.mobishop-dashboard__card--license .mobishop-setup-overview > .dashicons {
		flex-basis: 31px;
		width: 31px;
		height: 31px;
		border-radius: 8px;
	}

	.mobishop-dashboard__card--license .mobishop-status {
		padding: 3px 8px;
		font-size: 11px;
	}

	.mobishop-license-actions {
		display: flex;
		gap: 10px;
		margin-top: 16px;
	}

	.mobishop-dashboard__card table th {
		width: 190px;
	}

	.mobishop-status {
		display: inline-flex;
		align-items: center;
		padding: 5px 11px;
		border-radius: 999px;
		font-size: 12px;
		font-weight: 700;
	}

	.mobishop-status--online {
		color: #146c2e;
		background: #dff6dd;
	}

	.mobishop-status--offline {
		color: #b32d2e;
		background: #fde2e1;
	}

	@media (max-width: 960px) {
		.mobishop-dashboard__grid {
			grid-template-columns: 1fr;
		}

		.mobishop-customer-journey__steps {
			grid-template-columns: 1fr;
		}

		.mobishop-customer-journey__steps li {
			min-height: 0;
		}

		.mobishop-app-build__card-button {
			min-height: 86px;
		}
	}

	@media (max-width: 782px) {
		.mobishop-customer-journey__header {
			align-items: flex-start;
			flex-direction: column;
		}

		.mobishop-dashboard__card--license .mobishop-license-summary tbody {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
	}

	@media (max-width: 520px) {
		.mobishop-dashboard__card--license {
			padding: 13px;
		}

		.mobishop-dashboard__card--license .mobishop-license-summary tbody,
		.mobishop-dashboard__card--license .mobishop-license-form {
			grid-template-columns: 1fr;
		}

		.mobishop-dashboard__card--license .mobishop-dashboard__primary-action,
		.mobishop-dashboard__card--license .mobishop-license-form .button-primary {
			width: 100%;
			justify-content: center;
		}
	}
</style>
