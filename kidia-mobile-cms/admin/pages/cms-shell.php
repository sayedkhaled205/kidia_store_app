<?php
/** Unified CMS navigation shell. */
defined( 'ABSPATH' ) || exit;
?>
<div class="kidia-cms-shell" data-kidia-cms-shell>
	<div class="kidia-cms-shell__brand">
		<span class="dashicons dashicons-smartphone"></span>
		<div><strong><?php esc_html_e( 'Woo Mobile CMS', 'kidia-mobile-cms' ); ?></strong><small><?php esc_html_e( 'Application workspace', 'kidia-mobile-cms' ); ?></small></div>
	</div>
	<nav class="kidia-cms-tabs" aria-label="<?php esc_attr_e( 'Application screens', 'kidia-mobile-cms' ); ?>">
		<?php foreach ( $tabs as $key => $tab ) : ?>
			<a href="<?php echo esc_url( $tab['url'] ); ?>" class="<?php echo $key === $active_tab ? 'is-active' : ''; ?>">
				<span class="dashicons <?php echo esc_attr( $tab['icon'] ); ?>"></span>
				<span><?php echo esc_html( $tab['label'] ); ?></span>
			</a>
		<?php endforeach; ?>
	</nav>
	<div class="kidia-cms-more">
		<button type="button" aria-expanded="false"><span class="dashicons dashicons-screenoptions"></span><span><?php esc_html_e( 'More', 'kidia-mobile-cms' ); ?></span><span class="dashicons dashicons-arrow-down-alt2"></span></button>
		<div class="kidia-cms-more__menu">
			<?php foreach ( $more_tabs as $key => $tab ) : ?>
				<a href="<?php echo esc_url( $tab['url'] ); ?>" class="<?php echo $key === $active_tab ? 'is-active' : ''; ?>"><span class="dashicons <?php echo esc_attr( $tab['icon'] ); ?>"></span><?php echo esc_html( $tab['label'] ); ?></a>
			<?php endforeach; ?>
		</div>
	</div>
	<a class="kidia-cms-setup-link <?php echo 'setup' === $active_tab ? 'is-active' : ''; ?>" href="<?php echo esc_url( admin_url( 'admin.php?page=kidia-mobile-setup' ) ); ?>"><span class="dashicons dashicons-admin-customizer"></span><?php esc_html_e( 'Setup & Themes', 'kidia-mobile-cms' ); ?></a>
</div>
