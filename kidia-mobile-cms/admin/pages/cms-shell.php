<?php
/** Unified CMS navigation shell. */
defined( 'ABSPATH' ) || exit;
?>
<aside class="kidia-cms-sidebar" data-kidia-cms-sidebar>
	<div class="kidia-cms-shell__brand">
		<span class="dashicons dashicons-smartphone"></span>
		<div><strong><?php esc_html_e( 'Woo Mobile CMS', 'kidia-mobile-cms' ); ?></strong><small><?php esc_html_e( 'Application workspace', 'kidia-mobile-cms' ); ?></small></div>
	</div>
	<nav class="kidia-cms-sidebar__nav" aria-label="<?php esc_attr_e( 'Woo Mobile CMS sections', 'kidia-mobile-cms' ); ?>">
		<?php foreach ( $sidebar_items as $key => $item ) : ?>
			<a href="<?php echo esc_url( $item['url'] ); ?>" data-kidia-sidebar-view="<?php echo esc_attr( $key ); ?>" class="<?php echo $key === $active_sidebar ? 'is-active' : ''; ?>">
				<span class="dashicons <?php echo esc_attr( $item['icon'] ); ?>"></span>
				<span><?php echo esc_html( $item['label'] ); ?></span>
			</a>
		<?php endforeach; ?>
	</nav>
</aside>
<?php
$shell_build_state  = wp_parse_args(
	is_array( $app_build_state ?? null ) ? $app_build_state : array(),
	array( 'status' => 'idle', 'progress' => 0, 'message' => '', 'stage' => '', 'build_id' => '', 'updated_at' => 0 )
);
$shell_build_status = sanitize_key( (string) $shell_build_state['status'] );
$shell_has_build    = ! in_array( $shell_build_status, array( 'idle', 'cancelled' ), true );
$shell_build_active = in_array( $shell_build_status, array( 'queued', 'building' ), true );
$shell_abandoned_import = wp_parse_args(
	is_array( $abandoned_import_state ?? null ) ? $abandoned_import_state : array(),
	array( 'phase' => 'not_started', 'processed' => 0, 'total' => 0, 'imported' => 0 )
);
$shell_abandoned_phase = sanitize_key( (string) $shell_abandoned_import['phase'] );
$shell_has_abandoned   = in_array( $shell_abandoned_phase, array( 'running', 'complete' ), true );
$shell_abandoned_total = absint( $shell_abandoned_import['total'] );
$shell_abandoned_done  = absint( $shell_abandoned_import['processed'] );
$shell_abandoned_completed_at = absint( $shell_abandoned_import['completed_at'] ?? 0 );
$shell_abandoned_progress = $shell_abandoned_total > 0
	? min( 100, (int) floor( 100 * $shell_abandoned_done / $shell_abandoned_total ) )
	: 100;
?>
	<div class="kidia-background-job-stack" data-kidia-background-job-stack aria-live="polite">
		<div
			class="kidia-app-build__persistent"
			data-kidia-app-build
			data-build-persistent
			data-kidia-background-job="app-build"
			data-status="<?php echo esc_attr( $shell_build_status ); ?>"
			data-build-id="<?php echo esc_attr( (string) $shell_build_state['build_id'] ); ?>"
			data-can-build="0"
		>
			<div class="kidia-app-build__modal kidia-ai-progress-overlay<?php echo $shell_has_build ? ' is-docked' : ''; ?>" data-build-modal <?php echo $shell_has_build ? '' : 'hidden'; ?>>
				<div class="kidia-app-build__modal-card kidia-ai-progress-card" role="dialog" aria-modal="true" aria-labelledby="kidia-persistent-build-title">
					<div class="kidia-ai-progress-ring" data-build-progress-ring style="--kidia-ai-progress:<?php echo esc_attr( (string) absint( $shell_build_state['progress'] ) ); ?>">
						<strong data-build-progress-label><?php echo esc_html( absint( $shell_build_state['progress'] ) . '%' ); ?></strong>
					</div>
					<h2 id="kidia-persistent-build-title" data-build-title><?php esc_html_e( 'Building your app', 'kidia-mobile-cms' ); ?></h2>
					<p class="kidia-app-build__message" data-build-message><?php echo esc_html( (string) $shell_build_state['message'] ); ?></p>
					<strong class="kidia-ai-progress-count" data-build-stage><?php echo esc_html( (string) ( $shell_build_state['stage'] ?: $shell_build_state['message'] ) ); ?></strong>
					<small class="kidia-app-build__meta" data-build-meta>
						<?php echo esc_html( '' !== (string) $shell_build_state['build_id'] ? 'Build ID: ' . (string) $shell_build_state['build_id'] : '' ); ?>
					</small>
					<div class="kidia-app-build__progress kidia-ai-progress-track" data-build-progress>
						<span data-build-progress-value role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="<?php echo esc_attr( (string) absint( $shell_build_state['progress'] ) ); ?>" style="width:<?php echo esc_attr( (string) absint( $shell_build_state['progress'] ) ); ?>%"></span>
					</div>
					<small data-build-note><?php esc_html_e( 'This card stays available across every CMS page until you cancel the running job or press OK after completion.', 'kidia-mobile-cms' ); ?></small>
					<div class="kidia-app-build__actions kidia-ai-progress-actions">
						<button type="button" class="button kidia-app-build__cancel kidia-ai-cancel-button<?php echo $shell_build_active ? '' : ' is-confirm'; ?>" data-build-cancel <?php echo $shell_has_build ? '' : 'hidden'; ?>><span class="dashicons <?php echo $shell_build_active ? 'dashicons-no-alt' : 'dashicons-yes-alt'; ?>"></span><span data-build-dismiss-label><?php echo esc_html( $shell_build_active ? __( 'Cancel Build', 'kidia-mobile-cms' ) : __( 'OK', 'kidia-mobile-cms' ) ); ?></span></button>
					</div>
				</div>
			</div>
		</div>
		<?php if ( $shell_has_abandoned ) : ?>
			<section class="kidia-cart-import-state kidia-background-job-card<?php echo 'complete' === $shell_abandoned_phase ? ' is-complete' : ''; ?>" data-kidia-background-job="abandoned-carts" data-abandoned-import-phase="<?php echo esc_attr( $shell_abandoned_phase ); ?>"<?php echo 'complete' === $shell_abandoned_phase ? ' data-complete-auto-dismiss="5000" data-completion-key="' . esc_attr( $shell_abandoned_completed_at > 0 ? (string) $shell_abandoned_completed_at : '' ) . '" hidden' : ''; ?>>
				<span class="dashicons <?php echo 'complete' === $shell_abandoned_phase ? 'dashicons-yes-alt' : 'dashicons-database-import'; ?>"></span>
				<div>
					<strong><?php echo esc_html( 'complete' === $shell_abandoned_phase ? __( 'Completed — WooCommerce cart history is synced', 'kidia-mobile-cms' ) : __( 'Importing all retained WooCommerce carts in the background', 'kidia-mobile-cms' ) ); ?></strong>
					<p>
						<?php
						echo esc_html(
							'complete' === $shell_abandoned_phase
								? sprintf(
									__( '%1$d retained sessions were checked and %2$d carts with products were imported. Results are available on Abandoned Carts.', 'kidia-mobile-cms' ),
									$shell_abandoned_done,
									absint( $shell_abandoned_import['imported'] )
								)
								: sprintf(
									__( '%1$d of %2$d stored sessions checked · %3$d carts imported. You can continue using every CMS page.', 'kidia-mobile-cms' ),
									$shell_abandoned_done,
									$shell_abandoned_total,
									absint( $shell_abandoned_import['imported'] )
								)
						);
						?>
					</p>
					<?php if ( 'running' === $shell_abandoned_phase ) : ?><i><b style="width:<?php echo esc_attr( (string) $shell_abandoned_progress ); ?>%"></b></i><?php endif; ?>
				</div>
			</section>
		<?php endif; ?>
	</div>
	<div class="kidia-cms-shell" data-kidia-cms-shell<?php echo $show_page_tabs ? '' : ' hidden'; ?>>
		<nav class="kidia-cms-tabs" aria-label="<?php esc_attr_e( 'Application pages', 'kidia-mobile-cms' ); ?>">
			<?php foreach ( $tabs as $key => $tab ) : ?>
				<?php if ( 'overview' === $key ) { continue; } ?>
				<a href="<?php echo esc_url( $tab['url'] ); ?>" data-kidia-page-view="<?php echo esc_attr( $key ); ?>" class="<?php echo $key === $active_tab ? 'is-active' : ''; ?>">
					<span class="dashicons <?php echo esc_attr( $tab['icon'] ); ?>"></span>
					<span><?php echo esc_html( $tab['label'] ); ?></span>
				</a>
			<?php endforeach; ?>
		</nav>
		<form class="kidia-cms-save-theme" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" data-kidia-save-theme>
			<input type="hidden" name="action" value="kidia_mobile_manage_saved_theme">
			<input type="hidden" name="theme_operation" value="save">
			<input type="hidden" name="theme_name" value="">
			<?php wp_nonce_field( 'kidia_mobile_manage_saved_theme', 'kidia_mobile_theme_nonce' ); ?>
			<button type="submit" class="button button-primary"><?php esc_html_e( 'Save Theme', 'kidia-mobile-cms' ); ?></button>
		</form>
	</div>
<div class="kidia-theme-name-modal" data-kidia-theme-modal hidden>
	<div class="kidia-theme-name-modal__backdrop" data-kidia-theme-cancel></div>
	<div class="kidia-theme-name-modal__dialog" role="dialog" aria-modal="true" aria-labelledby="kidia-theme-name-title">
		<span class="kidia-theme-name-modal__icon dashicons dashicons-saved"></span>
		<h2 id="kidia-theme-name-title"><?php esc_html_e( 'Save your theme', 'kidia-mobile-cms' ); ?></h2>
		<p><?php esc_html_e( 'Enter a clear name so you can find and apply this design later.', 'kidia-mobile-cms' ); ?></p>
		<input type="text" maxlength="80" data-kidia-theme-name placeholder="<?php esc_attr_e( 'Theme name', 'kidia-mobile-cms' ); ?>">
		<small data-kidia-theme-error hidden><?php esc_html_e( 'Please enter a theme name.', 'kidia-mobile-cms' ); ?></small>
		<div><button type="button" class="button" data-kidia-theme-cancel><?php esc_html_e( 'Cancel', 'kidia-mobile-cms' ); ?></button><button type="button" class="button button-primary" data-kidia-theme-confirm><?php esc_html_e( 'Save Theme', 'kidia-mobile-cms' ); ?></button></div>
	</div>
</div>
<?php if ( 'past_due' === (string) ( $license_status['payment_status'] ?? '' ) ) : ?>
	<div class="kidia-cms-billing-warning" role="alert">
		<span class="dashicons dashicons-warning" aria-hidden="true"></span>
		<div>
			<strong><?php esc_html_e( 'Your subscription payment is overdue.', 'kidia-mobile-cms' ); ?></strong>
			<span>
				<?php
				printf(
					/* translators: 1: remaining grace days, 2: grace end date. */
					esc_html__( 'Woo Mobile CMS remains active for %1$d more day(s), until %2$s. Payment automatically restores normal service.', 'kidia-mobile-cms' ),
					(int) ( $license_status['grace_days_remaining'] ?? 0 ),
					esc_html( wp_date( get_option( 'date_format' ), (int) ( $license_status['grace_ends_at'] ?? time() ) ) )
				);
				?>
			</span>
		</div>
	</div>
<?php endif; ?>
