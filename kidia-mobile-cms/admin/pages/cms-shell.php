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
		<form class="kidia-cms-save-theme" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" onsubmit="var themeName=window.prompt('<?php echo esc_js( __( 'Enter a name for this theme', 'kidia-mobile-cms' ) ); ?>','');if(themeName===null){return false;}themeName=themeName.trim();if(!themeName){window.alert('<?php echo esc_js( __( 'Please enter a theme name.', 'kidia-mobile-cms' ) ); ?>');return false;}var saveAction=document.querySelector('input[name=&quot;action&quot;][value^=&quot;kidia_mobile_save_&quot;]');var editorForm=saveAction?saveAction.form:null;if(editorForm&&editorForm!==this){var field=document.createElement('input');field.type='hidden';field.name='kidia_save_theme_name';field.value=themeName;editorForm.appendChild(field);if(typeof editorForm.requestSubmit==='function'){editorForm.requestSubmit();}else{editorForm.submit();}return false;}this.elements.theme_name.value=themeName;return true;">
			<input type="hidden" name="action" value="kidia_mobile_manage_saved_theme">
			<input type="hidden" name="theme_operation" value="save">
			<input type="hidden" name="theme_name" value="">
			<?php wp_nonce_field( 'kidia_mobile_manage_saved_theme', 'kidia_mobile_theme_nonce' ); ?>
			<button type="submit" class="button button-primary"><span class="dashicons dashicons-saved" aria-hidden="true"></span><?php esc_html_e( 'Save Theme', 'kidia-mobile-cms' ); ?></button>
		</form>
	</div>
<?php endif; ?>
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
