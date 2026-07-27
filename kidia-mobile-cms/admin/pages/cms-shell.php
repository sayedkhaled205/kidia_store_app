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
			<a href="<?php echo esc_url( $item['url'] ); ?>" class="<?php echo $key === $active_sidebar ? 'is-active' : ''; ?>">
				<span class="dashicons <?php echo esc_attr( $item['icon'] ); ?>"></span>
				<span><?php echo esc_html( $item['label'] ); ?></span>
			</a>
		<?php endforeach; ?>
	</nav>
</aside>
<?php if ( $show_page_tabs ) : ?>
	<div class="kidia-cms-shell" data-kidia-cms-shell>
		<nav class="kidia-cms-tabs" aria-label="<?php esc_attr_e( 'Application pages', 'kidia-mobile-cms' ); ?>">
			<?php foreach ( $tabs as $key => $tab ) : ?>
				<?php if ( 'overview' === $key ) { continue; } ?>
				<a href="<?php echo esc_url( $tab['url'] ); ?>" class="<?php echo $key === $active_tab ? 'is-active' : ''; ?>">
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
			<button type="submit" class="button button-primary"><span class="dashicons dashicons-saved" aria-hidden="true"></span><?php esc_html_e( 'Save Theme', 'kidia-mobile-cms' ); ?></button>
		</form>
	</div>
<?php endif; ?>
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
