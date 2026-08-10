<?php
/**
 * Woomobi CMS Dashboard.
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
	$build_state['message'] = __( 'Application settings changed. Build a new APK to include the latest setup.', 'kidia-mobile-cms' );
}
$build_in_progress = in_array( $build_status, array( 'queued', 'building' ), true );
$build_auto_download = isset( $_GET['build_notice'] )
	&& 'started' === sanitize_key( wp_unslash( $_GET['build_notice'] ) );
$build_action = $build_step_complete
	? 'kidia_mobile_download_apk'
	: 'kidia_mobile_build_app';
$build_button_label = $build_step_complete
	? __( 'Download APK', 'kidia-mobile-cms' )
	: ( $build_in_progress
			? __( 'Building APK…', 'kidia-mobile-cms' )
			: __( 'Build Your App', 'kidia-mobile-cms' )
	);
$journey_steps = array(
	array(
		'title'       => __( 'Purchase and connect', 'kidia-mobile-cms' ),
		'description' => __( 'Open WooMobile to purchase a plan and connect this already-installed WordPress plugin.', 'kidia-mobile-cms' ),
		'complete'    => $connection_step_complete,
	),
	array(
		'title'       => __( 'Activate your license', 'kidia-mobile-cms' ),
		'description' => __( 'Enter the license issued for this website below to unlock the plugin.', 'kidia-mobile-cms' ),
		'complete'    => $license_step_complete,
	),
	array(
		'title'       => __( 'Set up your app', 'kidia-mobile-cms' ),
		'description' => __( 'Use the Setup Wizard or continue with manual configuration.', 'kidia-mobile-cms' ),
		'complete'    => $setup_step_complete,
	),
	array(
		'title'       => __( 'Build your app', 'kidia-mobile-cms' ),
		'description' => __( 'Build a real Android APK, then download it directly to install on your phone.', 'kidia-mobile-cms' ),
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

<div class="wrap kidia-dashboard">

	<?php if ( isset( $_GET['license_updated'] ) ) : ?>
		<div class="notice notice-success inline"><p><?php esc_html_e( 'License updated successfully.', 'kidia-mobile-cms' ); ?></p></div>
	<?php endif; ?>

	<?php if ( isset( $_GET['license_error'] ) ) : ?>
		<div class="notice notice-error inline"><p><?php echo esc_html( sanitize_text_field( wp_unslash( $_GET['license_error'] ) ) ); ?></p></div>
	<?php endif; ?>

	<?php if ( isset( $_GET['build_notice'] ) && 'started' === sanitize_key( wp_unslash( $_GET['build_notice'] ) ) ) : ?>
		<div class="notice notice-success inline"><p><?php esc_html_e( 'Your APK build has started. You can leave this page and return later.', 'kidia-mobile-cms' ); ?></p></div>
	<?php elseif ( isset( $_GET['build_notice'] ) && 'error' === sanitize_key( wp_unslash( $_GET['build_notice'] ) ) ) : ?>
		<div class="notice notice-error inline"><p><?php echo esc_html( isset( $_GET['build_message'] ) ? sanitize_text_field( wp_unslash( $_GET['build_message'] ) ) : __( 'The APK build could not be started.', 'kidia-mobile-cms' ) ); ?></p></div>
	<?php endif; ?>

	<section class="kidia-customer-journey" aria-labelledby="kidia-customer-journey-title">
		<div class="kidia-customer-journey__header">
			<div>
				<span class="kidia-customer-journey__eyebrow"><?php esc_html_e( 'Your launch journey', 'kidia-mobile-cms' ); ?></span>
				<h2 id="kidia-customer-journey-title"><?php esc_html_e( 'From website connection to ready mobile app', 'kidia-mobile-cms' ); ?></h2>
				<p><?php esc_html_e( 'Woomobi CMS is already installed. Connect this website, activate its serial, then choose the wizard or manual setup.', 'kidia-mobile-cms' ); ?></p>
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
				<?php if ( 3 === $journey_index ) : ?>
					<li
						class="<?php echo esc_attr( $step_class ); ?> kidia-customer-journey__build-step"
						data-kidia-app-build
						data-status="<?php echo esc_attr( $build_status ); ?>"
						data-build-id="<?php echo esc_attr( (string) ( $build_state['build_id'] ?? '' ) ); ?>"
						data-completed-at="<?php echo esc_attr( (string) absint( $build_state['completed_at'] ?? 0 ) ); ?>"
						data-can-build="<?php echo $setup_step_complete ? '1' : '0'; ?>"
						data-auto-download="<?php echo $build_auto_download ? '1' : '0'; ?>"
					>
						<form class="kidia-app-build__card-form" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" data-build-form>
							<input type="hidden" name="action" value="<?php echo esc_attr( $build_action ); ?>" data-build-form-action>
							<?php wp_nonce_field( 'kidia_mobile_build_app', 'kidia_mobile_build_nonce', false ); ?>
							<?php wp_nonce_field( 'kidia_mobile_download_apk', 'kidia_mobile_download_nonce', false ); ?>
							<button
								type="submit"
								class="kidia-app-build__card kidia-app-build__card-button"
								data-build-action
								aria-busy="<?php echo $build_in_progress ? 'true' : 'false'; ?>"
								<?php disabled( ! $setup_step_complete || $build_in_progress ); ?>
							>
								<strong class="kidia-app-build__title" data-build-action-label><?php echo esc_html( $build_button_label ); ?></strong>
								<p class="kidia-app-build__message" data-build-message>
								<?php
								echo esc_html(
									(string) $build_state['message'] ?: (
										$build_step_complete
											? __( 'Your APK is ready to install.', 'kidia-mobile-cms' )
											: __( 'Build an APK after completing the application setup.', 'kidia-mobile-cms' )
									)
								);
								?>
								</p>
								<small class="kidia-app-build__files" data-build-files><?php esc_html_e( 'Android &amp; iOS', 'kidia-mobile-cms' ); ?></small>
							</button>
						</form>
						<div class="kidia-app-build__recent-choice" data-build-recent-choice hidden>
							<div class="kidia-app-build__recent-choice-card" role="dialog" aria-modal="true" aria-labelledby="kidia-recent-build-title">
								<h3 id="kidia-recent-build-title"><?php esc_html_e( 'A successful build is available from the last 10 days', 'kidia-mobile-cms' ); ?></h3>
								<p><?php esc_html_e( 'Download the latest version again or create a new build.', 'kidia-mobile-cms' ); ?></p>
								<div class="kidia-app-build__recent-choice-actions">
									<button type="button" class="button button-primary" data-build-download-again><?php esc_html_e( 'Download Again', 'kidia-mobile-cms' ); ?></button>
									<button type="button" class="button" data-build-new-version><?php esc_html_e( 'Build New Version', 'kidia-mobile-cms' ); ?></button>
									<button type="button" class="button" data-build-recent-cancel><?php esc_html_e( 'Cancel', 'kidia-mobile-cms' ); ?></button>
								</div>
							</div>
						</div>
					</li>
				<?php else : ?>
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
				<?php endif; ?>
			<?php endforeach; ?>
		</ol>
	</section>

	<div class="kidia-dashboard__grid">

		<section class="kidia-dashboard__card kidia-dashboard__card--license">
			<div class="kidia-dashboard__card-header">
				<span class="kidia-dashboard__card-icon dashicons dashicons-shield-alt" aria-hidden="true"></span>
				<div>
					<span class="kidia-dashboard__card-eyebrow"><?php esc_html_e( 'Website access', 'kidia-mobile-cms' ); ?></span>
					<h2><?php esc_html_e( 'License', 'kidia-mobile-cms' ); ?></h2>
					<p><?php esc_html_e( 'Connect this website and activate its serial to unlock every builder tool.', 'kidia-mobile-cms' ); ?></p>
				</div>
			</div>

			<table class="widefat striped kidia-license-summary">
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
					<tr>
						<th scope="row"><?php esc_html_e( 'Website', 'kidia-mobile-cms' ); ?></th>
						<td>
							<span class="kidia-status <?php echo $website_connected ? 'kidia-status--online' : 'kidia-status--offline'; ?>">
								<?php echo $website_connected ? esc_html__( 'Connected', 'kidia-mobile-cms' ) : esc_html__( 'Not connected', 'kidia-mobile-cms' ); ?>
							</span>
						</td>
					</tr>
					<tr>
						<th scope="row"><?php esc_html_e( 'API', 'kidia-mobile-cms' ); ?></th>
						<td>
							<span class="kidia-status <?php echo $api_online ? 'kidia-status--online' : 'kidia-status--offline'; ?>">
								<?php echo $api_online ? esc_html__( 'Online', 'kidia-mobile-cms' ) : esc_html__( 'Offline', 'kidia-mobile-cms' ); ?>
							</span>
						</td>
					</tr>
					<tr>
						<th scope="row"><?php esc_html_e( 'Plugin version', 'kidia-mobile-cms' ); ?></th>
						<td><?php echo esc_html( defined( 'KIDIA_MOBILE_CMS_VERSION' ) ? KIDIA_MOBILE_CMS_VERSION : '' ); ?></td>
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

	</div>

	<?php if ( $show_setup_choice ) : ?>
		<div class="kidia-setup-choice" role="dialog" aria-modal="true" aria-labelledby="kidia-setup-choice-title">
			<div class="kidia-setup-choice__panel">
				<h2 id="kidia-setup-choice-title"><?php esc_html_e( 'Your license is active', 'kidia-mobile-cms' ); ?></h2>
				<p><?php esc_html_e( 'Would you like Woomobi CMS to guide you through setup, or configure everything manually?', 'kidia-mobile-cms' ); ?></p>
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

</div>

<style>
	.kidia-dashboard {
		max-width: 1280px;
	}

	.kidia-dashboard__grid {
		display: grid;
		grid-template-columns: minmax(0, 1fr);
		justify-items: center;
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
		grid-template-columns: repeat(4, minmax(0, 1fr));
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

	.kidia-customer-journey__steps li.kidia-customer-journey__build-step {
		display: block;
		padding: 0;
		border-color: #cfe2dc;
		background: #f8fcfb;
		opacity: 1;
	}

	.kidia-app-build__card {
		display: flex;
		min-height: 120px;
		box-sizing: border-box;
		flex-direction: column;
		justify-content: center;
		padding: 15px;
	}

	.kidia-app-build__title {
		color: #173f36;
		font-size: 14px;
	}

	.kidia-app-build__message {
		min-height: 32px;
		margin: 5px 0 9px !important;
		color: #60706c !important;
		font-size: 11px !important;
		line-height: 1.4 !important;
	}

	.kidia-app-build__actions {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.kidia-app-build__card-form {
		flex: 1;
		height: 100%;
		margin: 0;
	}

	.kidia-app-build__card-button {
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

	.kidia-app-build__card-button .kidia-app-build__title {
		width: 100%;
		font-size: 15px;
		font-weight: 800;
		text-align: center;
	}

	.kidia-app-build__files {
		width: 100%;
		margin-top: 5px;
		color: #e7f5f1;
		font-size: 11px;
		font-weight: 400;
		line-height: 1.4;
		text-align: center;
	}

	.kidia-app-build__recent-choice {
		position: fixed;
		z-index: 100200;
		inset: 0;
		display: grid;
		place-items: center;
		padding: 20px;
		background: rgba(12, 31, 27, .42);
	}

	.kidia-app-build__recent-choice[hidden] { display: none; }

	.kidia-app-build__recent-choice-card {
		width: min(420px, 100%);
		box-sizing: border-box;
		padding: 24px;
		border-radius: 16px;
		background: #fff;
		box-shadow: 0 22px 60px rgba(12, 31, 27, .22);
		text-align: center;
	}

	.kidia-app-build__recent-choice-card h3 { margin: 0 0 8px; }
	.kidia-app-build__recent-choice-card p { margin: 0 0 18px; }
	.kidia-app-build__recent-choice-actions { display: flex; justify-content: center; gap: 10px; }
	.kidia-app-build__recent-choice-actions .button {
		min-height: 44px;
		padding: 7px 20px;
		border-color: #2f806e;
		border-radius: 10px;
		background: #fff;
		color: #2f806e;
		font-weight: 700;
	}
	.kidia-app-build__recent-choice-actions .button:hover,
	.kidia-app-build__recent-choice-actions .button:focus {
		border-color: #246b5c;
		background: #edf7f4;
		color: #246b5c;
	}
	.kidia-app-build__recent-choice-actions .button-primary,
	.kidia-app-build__recent-choice-actions .button-primary:hover,
	.kidia-app-build__recent-choice-actions .button-primary:focus {
		border-color: #2f806e;
		background: #2f806e;
		color: #fff;
	}

	.kidia-app-build__card-button .kidia-app-build__title {
		color: #ffffff;
	}

	.kidia-app-build__card-button .kidia-app-build__message {
		min-height: 0;
		margin-bottom: 0 !important;
		color: #e7f5f1 !important;
		text-align: start;
	}

	[data-kidia-app-build][data-status="idle"] .kidia-app-build__message,
	[data-kidia-app-build][data-status="downloaded"] .kidia-app-build__message {
		display: none;
	}

	.kidia-app-build__card-button:hover,
	.kidia-app-build__card-button:focus {
		border-color: #287260;
		background: #287260;
		color: #ffffff;
		box-shadow: 0 10px 24px rgba(47, 128, 110, .24);
	}

	.kidia-app-build__card-button:focus-visible {
		outline: 3px solid rgba(47, 128, 110, .28);
		outline-offset: 2px;
	}

	.kidia-app-build__card-button:active {
		transform: translateY(1px);
	}

	.kidia-app-build__card-button:disabled {
		background: #2f806e;
		color: #ffffff;
		cursor: not-allowed;
		opacity: .68;
	}

	.kidia-app-build__card-label {
		display: block;
		font-size: clamp(11px, .85vw, 12px);
		font-weight: 700;
		line-height: 1.3;
		text-wrap: balance;
	}

	.kidia-app-build__modal {
		z-index: 100100;
	}

	.kidia-app-build__modal[hidden] {
		display: none;
	}

	.kidia-app-build__modal-card {
		box-sizing: border-box;
	}

	.kidia-app-build__modal-card .kidia-app-build__message {
		min-height: 0;
		margin: 0 !important;
	}

	.kidia-app-build__progress {
		margin: 0;
	}

	.kidia-app-build__progress span {
		display: block;
		height: 100%;
		border-radius: inherit;
		background: #2f806e;
		transition: width .25s ease;
	}

	.kidia-app-build__cancel {
		font-weight: 700 !important;
	}

	.kidia-app-build__modal.is-docked .kidia-app-build__modal-card {
		cursor: grab;
	}

	.kidia-app-build__modal.is-docked.is-dragging .kidia-app-build__modal-card {
		cursor: grabbing;
	}

	.kidia-app-build__modal.is-docked .kidia-app-build__modal-card :is(button, a) {
		cursor: pointer;
	}

	.kidia-app-build__cancel:hover,
	.kidia-app-build__cancel:focus {
		border-color: #b45a5a;
		background: #fff5f5;
		color: #8c1f1f;
	}

	[data-kidia-app-build][data-status="downloaded"] .kidia-app-build__cancel {
		border-color: #2f806e;
		background: #2f806e;
		color: #ffffff;
	}

	[data-kidia-app-build][data-status="downloaded"] .kidia-app-build__cancel:hover,
	[data-kidia-app-build][data-status="downloaded"] .kidia-app-build__cancel:focus {
		border-color: #287260;
		background: #287260;
		color: #ffffff;
	}

	.kidia-app-build__cancel:disabled {
		cursor: wait;
		opacity: .62;
	}

	.kidia-app-build__cancel[hidden] {
		display: none;
	}

	.kidia-dashboard__card {
		padding: 26px;
		border: 1px solid #d8e3e0;
		border-radius: 18px;
		background: linear-gradient(180deg, #ffffff 0%, #fbfdfc 100%);
		box-shadow: 0 10px 30px rgba(31, 71, 61, 0.07);
	}

	.kidia-dashboard__card h2 {
		margin: 2px 0 6px;
		font-size: 23px;
		line-height: 1.2;
	}

	.kidia-dashboard__card-header {
		display: flex;
		align-items: flex-start;
		gap: 15px;
		margin-bottom: 22px;
	}

	.kidia-dashboard__card-header > div {
		flex: 1;
	}

	.kidia-dashboard__card-header p {
		max-width: 560px;
		margin: 0;
		color: #60706c;
		line-height: 1.55;
	}

	.kidia-dashboard__card-icon {
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

	.kidia-dashboard__card-eyebrow {
		color: #2f806e;
		font-size: 11px;
		font-weight: 800;
		letter-spacing: .09em;
		text-transform: uppercase;
	}

	.kidia-license-summary {
		overflow: hidden;
		margin: 0;
		border: 1px solid #dbe6e3;
		border-radius: 12px;
		box-shadow: none;
	}

	.kidia-license-summary th,
	.kidia-license-summary td {
		padding: 13px 16px;
		border-bottom-color: #e8efed;
	}

	.kidia-connect-prompt,
	.kidia-setup-overview {
		display: flex;
		align-items: center;
		gap: 13px;
		margin-top: 18px;
		padding: 15px 16px;
		border: 1px solid #cfe2dc;
		border-radius: 13px;
		background: #f1f8f6;
	}

	.kidia-connect-prompt__icon,
	.kidia-setup-overview > .dashicons {
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

	.kidia-connect-prompt strong,
	.kidia-setup-overview strong {
		display: block;
		margin-bottom: 3px;
		color: #173f36;
		font-size: 14px;
	}

	.kidia-connect-prompt p,
	.kidia-setup-overview > div > span {
		display: block;
		margin: 0;
		color: #60706c;
		font-size: 12px;
		line-height: 1.45;
	}

	.kidia-setup-overview {
		margin: 0 0 16px;
	}

	.kidia-setup-overview.is-locked {
		border-color: #e0e5e4;
		background: #f6f7f7;
	}

	.kidia-setup-overview.is-locked > .dashicons {
		color: #7a8683;
	}

	.kidia-dashboard__primary-action {
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

	.kidia-dashboard__primary-action:hover,
	.kidia-dashboard__primary-action:focus {
		background: #256b5c;
		color: #ffffff;
		box-shadow: 0 9px 22px rgba(47, 128, 110, .24);
		transform: translateY(-1px);
	}

	.kidia-dashboard__primary-action:focus {
		outline: none;
		box-shadow: 0 0 0 3px rgba(47, 128, 110, .16), 0 9px 22px rgba(47, 128, 110, .2);
	}

	.kidia-dashboard__primary-action .dashicons {
		width: 18px;
		height: 18px;
		font-size: 18px;
	}

	.kidia-dashboard__primary-action.is-disabled {
		pointer-events: none;
		border-color: #d7dcda;
		background: #e8ebea;
		color: #8a9390;
		box-shadow: none;
	}

	.kidia-license-form {
		display: grid;
		gap: 10px;
		margin-top: 16px;
	}

	.kidia-license-form input {
		width: 100%;
		min-height: 44px;
		border-color: #cfdad7;
		border-radius: 9px;
	}

	.kidia-license-form .button-primary {
		min-height: 44px;
		border-color: #2f806e;
		border-radius: 9px;
		background: #2f806e;
	}

	.kidia-dashboard__card--license {
		box-sizing: border-box;
		width: min(100%, 780px);
		padding: 16px;
		border-radius: 16px;
	}

	.kidia-dashboard__card--license .kidia-dashboard__card-header {
		gap: 10px;
		margin-bottom: 12px;
	}

	.kidia-dashboard__card--license .kidia-dashboard__card-icon {
		flex-basis: 36px;
		width: 36px;
		height: 36px;
		border-radius: 10px;
		font-size: 18px;
	}

	.kidia-dashboard__card--license h2 {
		font-size: 18px;
	}

	.kidia-dashboard__card--license .kidia-dashboard__card-header p {
		font-size: 12px;
		line-height: 1.35;
	}

	.kidia-dashboard__card--license .kidia-license-summary {
		display: block;
		overflow: visible;
		border: 0;
		border-radius: 0;
		background: transparent;
	}

	.kidia-dashboard__card--license .kidia-license-summary tbody {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 8px;
	}

	.kidia-dashboard__card--license .kidia-license-summary tr {
		display: flex;
		min-width: 0;
		flex-direction: column;
		gap: 4px;
		padding: 9px 10px;
		border: 1px solid #e0ebe7;
		border-radius: 10px;
		background: #f8fbfa;
	}

	.kidia-dashboard__card--license .kidia-license-summary th,
	.kidia-dashboard__card--license .kidia-license-summary td {
		display: block;
		width: auto;
		padding: 0;
		border: 0;
		background: transparent;
	}

	.kidia-dashboard__card--license .kidia-license-summary th {
		color: #6b7b77;
		font-size: 11px;
		font-weight: 600;
	}

	.kidia-dashboard__card--license .kidia-license-summary td {
		overflow: hidden;
		color: #173f36;
		font-size: 12px;
		font-weight: 700;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.kidia-dashboard__card--license .kidia-connect-prompt {
		gap: 10px;
		margin-top: 12px;
		padding: 9px 10px;
		border-radius: 10px;
	}

	.kidia-dashboard__card--license .kidia-connect-prompt__icon {
		flex-basis: 31px;
		width: 31px;
		height: 31px;
		border-radius: 8px;
	}

	.kidia-dashboard__card--license .kidia-dashboard__primary-action {
		width: fit-content;
		min-height: 34px;
		margin-top: 0;
		margin-inline-start: auto;
		padding: 0 12px;
		border-radius: 8px;
		font-size: 12px;
	}

	.kidia-dashboard__card--license .kidia-license-form {
		grid-template-columns: minmax(0, 1fr) auto;
		gap: 8px;
		margin-top: 12px;
	}

	.kidia-dashboard__card--license .kidia-license-form label {
		grid-column: 1 / -1;
		margin: 0;
		font-size: 12px;
	}

	.kidia-dashboard__card--license .kidia-license-form input,
	.kidia-dashboard__card--license .kidia-license-form .button-primary {
		min-height: 34px;
	}

	.kidia-dashboard__card--license .kidia-license-form .button-primary {
		padding: 0 14px;
		border-radius: 8px;
		font-size: 12px;
	}

	.kidia-dashboard__card--license .kidia-setup-overview {
		flex-wrap: wrap;
		gap: 9px;
		margin: 12px 0 8px;
		padding: 9px 10px;
		border-radius: 10px;
	}

	.kidia-dashboard__card--license .kidia-setup-overview > .dashicons {
		flex-basis: 31px;
		width: 31px;
		height: 31px;
		border-radius: 8px;
	}

	.kidia-dashboard__card--license .kidia-status {
		padding: 3px 8px;
		font-size: 11px;
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

		.kidia-app-build__card-button {
			min-height: 86px;
		}
	}

	@media (max-width: 782px) {
		.kidia-customer-journey__header {
			align-items: flex-start;
			flex-direction: column;
		}

		.kidia-dashboard__card--license .kidia-license-summary tbody {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
	}

	@media (max-width: 520px) {
		.kidia-dashboard__card--license {
			padding: 13px;
		}

		.kidia-dashboard__card--license .kidia-license-summary tbody,
		.kidia-dashboard__card--license .kidia-license-form {
			grid-template-columns: 1fr;
		}

		.kidia-dashboard__card--license .kidia-dashboard__primary-action,
		.kidia-dashboard__card--license .kidia-license-form .button-primary {
			width: 100%;
			justify-content: center;
		}
	}
</style>
