<?php
/** Setup wizard screen. */
defined( 'ABSPATH' ) || exit;
?>
<div class="wrap kidia-setup-wrap">
	<div class="kidia-setup-hero">
		<div>
			<span class="kidia-setup-eyebrow"><?php esc_html_e( 'Woo Mobile CMS', 'kidia-mobile-cms' ); ?></span>
			<h1><?php echo $wizard->is_complete() ? esc_html__( 'Setup & Themes', 'kidia-mobile-cms' ) : esc_html__( 'Build your application', 'kidia-mobile-cms' ); ?></h1>
			<p><?php esc_html_e( 'Choose a complete storefront, connect it to your WooCommerce catalog, then review the application before applying it.', 'kidia-mobile-cms' ); ?></p>
		</div>
		<div class="kidia-setup-progress" aria-label="<?php esc_attr_e( 'Setup progress', 'kidia-mobile-cms' ); ?>">
			<?php $progress_steps = count( $setup_pages ) + 2; ?>
			<?php for ( $progress_step = 1; $progress_step <= $progress_steps; $progress_step++ ) : ?>
				<span class="<?php echo 1 === $progress_step ? 'is-active' : ''; ?>"><?php echo esc_html( (string) $progress_step ); ?></span>
				<?php if ( $progress_step < $progress_steps ) : ?><i></i><?php endif; ?>
			<?php endfor; ?>
		</div>
	</div>

	<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" class="kidia-setup-form">
		<input type="hidden" name="action" value="kidia_mobile_apply_setup_wizard">
		<?php wp_nonce_field( 'kidia_mobile_apply_setup_wizard', 'kidia_mobile_setup_nonce' ); ?>

		<section class="kidia-setup-step is-active" data-step="1">
			<div class="kidia-setup-step-heading">
				<span>01</span>
				<div><h2><?php esc_html_e( 'Application identity', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Set the name, logo and language customers will see.', 'kidia-mobile-cms' ); ?></p></div>
			</div>
			<div class="kidia-setup-identity-grid">
				<label><span><?php esc_html_e( 'Application name', 'kidia-mobile-cms' ); ?></span><input type="text" name="setup[app_name]" value="<?php echo esc_attr( (string) $identity['app_name'] ); ?>" required></label>
				<label><span><?php esc_html_e( 'Language', 'kidia-mobile-cms' ); ?></span><select name="setup[language]"><option value="ar" <?php selected( 'ar', $identity['language'] ); ?>>العربية</option><option value="en" <?php selected( 'en', $identity['language'] ); ?>>English</option></select></label>
				<label><span><?php esc_html_e( 'Direction', 'kidia-mobile-cms' ); ?></span><select name="setup[direction]"><option value="rtl" <?php selected( 'rtl', $identity['direction'] ); ?>>RTL</option><option value="ltr" <?php selected( 'ltr', $identity['direction'] ); ?>>LTR</option></select></label>
				<label><span><?php esc_html_e( 'Brand color', 'kidia-mobile-cms' ); ?></span><input type="color" name="setup[primary_color]" value="<?php echo esc_attr( (string) $identity['primary_color'] ); ?>"></label>
				<div class="kidia-setup-logo-field">
					<span><?php esc_html_e( 'Application logo', 'kidia-mobile-cms' ); ?></span>
					<div class="kidia-setup-logo-preview"><?php if ( ! empty( $identity['logo_url'] ) ) : ?><img src="<?php echo esc_url( (string) $identity['logo_url'] ); ?>" alt=""><?php else : ?><span class="dashicons dashicons-format-image"></span><?php endif; ?></div>
					<input type="hidden" name="setup[logo_id]" value="<?php echo esc_attr( (string) $identity['logo_id'] ); ?>">
					<input type="hidden" name="setup[logo_url]" value="<?php echo esc_url( (string) $identity['logo_url'] ); ?>">
					<button type="button" class="button kidia-setup-choose-logo"><?php esc_html_e( 'Choose logo', 'kidia-mobile-cms' ); ?></button>
				</div>
			</div>
		</section>

		<?php $setup_step = 2; ?>
		<?php foreach ( $setup_pages as $page_key => $page_details ) : ?>
			<?php
			$saved_page_themes = is_array( $identity['page_themes'] ?? null ) ? $identity['page_themes'] : array();
			$selected_theme    = sanitize_key( (string) ( $saved_page_themes[ $page_key ] ?? $identity['theme'] ?? 'aurora' ) );
			?>
			<section class="kidia-setup-step" data-step="<?php echo esc_attr( (string) $setup_step ); ?>" data-theme-page="<?php echo esc_attr( $page_key ); ?>">
				<div class="kidia-setup-step-heading">
					<span><?php echo esc_html( str_pad( (string) $setup_step, 2, '0', STR_PAD_LEFT ) ); ?></span>
					<div><h2><?php echo esc_html( sprintf( __( 'Choose %s page design', 'kidia-mobile-cms' ), $page_details['name'] ) ); ?></h2><p><?php echo esc_html( $page_details['description'] ); ?></p></div>
				</div>
				<div class="kidia-theme-gallery">
					<?php foreach ( $themes as $key => $theme ) : ?>
						<label class="kidia-theme-card" style="--theme-primary:<?php echo esc_attr( $theme['primary'] ); ?>;--theme-soft:<?php echo esc_attr( $theme['soft'] ); ?>;--theme-ink:<?php echo esc_attr( $theme['ink'] ); ?>">
							<input type="radio" name="setup[page_themes][<?php echo esc_attr( $page_key ); ?>]" value="<?php echo esc_attr( $key ); ?>" <?php checked( $selected_theme, $key ); ?> required>
							<div class="kidia-theme-preview">
								<div class="kidia-theme-phone">
									<div class="kidia-theme-phone-top"><b><?php echo esc_html( $page_details['name'] ); ?></b><i></i></div>
									<div class="kidia-theme-search"></div>
									<div class="kidia-theme-hero"><span><?php echo esc_html( (string) $theme['sample_copy'][0] ); ?></span></div>
									<div class="kidia-theme-categories"><i></i><i></i><i></i></div>
									<div class="kidia-theme-products">
										<?php for ( $sample_index = 0; $sample_index < 2; $sample_index++ ) : ?>
											<i<?php if ( ! empty( $catalog_images[ $sample_index ] ) ) : ?> style="background-image:url('<?php echo esc_url( $catalog_images[ $sample_index ] ); ?>')"<?php endif; ?>></i>
										<?php endfor; ?>
									</div>
									<div class="kidia-theme-footer"><i></i><i></i><i></i><i></i></div>
								</div>
							</div>
							<div class="kidia-theme-card-copy"><span class="kidia-theme-check dashicons dashicons-yes-alt"></span><h3><?php echo esc_html( (string) $theme['name'] ); ?></h3><p><?php echo esc_html( (string) $theme['description'] ); ?></p><small><?php echo esc_html( $page_details['name'] . ' · ' . implode( ' · ', array_map( 'strval', $theme['sample_copy'] ) ) ); ?></small></div>
						</label>
					<?php endforeach; ?>
				</div>
			</section>
			<?php ++$setup_step; ?>
		<?php endforeach; ?>

		<section class="kidia-setup-step" data-step="<?php echo esc_attr( (string) $setup_step ); ?>">
			<div class="kidia-setup-step-heading">
				<span><?php echo esc_html( str_pad( (string) $setup_step, 2, '0', STR_PAD_LEFT ) ); ?></span>
				<div><h2><?php esc_html_e( 'Review and apply', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'A snapshot of the current application is created before the new theme is applied.', 'kidia-mobile-cms' ); ?></p></div>
			</div>
			<div class="kidia-review-card">
				<div class="kidia-review-icon"><span class="dashicons dashicons-smartphone"></span></div>
				<div><h3 data-review-name><?php echo esc_html( (string) $identity['app_name'] ); ?></h3><p><?php esc_html_e( 'Each application page will use the design selected in its own setup step.', 'kidia-mobile-cms' ); ?></p><div class="kidia-review-tags"><?php foreach ( $setup_pages as $page_details ) : ?><span><?php echo esc_html( $page_details['name'] ); ?></span><?php endforeach; ?></div></div>
			</div>
			<div class="kidia-catalog-summary">
				<div><span class="dashicons dashicons-products"></span><strong><?php echo esc_html( number_format_i18n( $catalog_stats['products'] ) ); ?></strong><small><?php esc_html_e( 'Products ready', 'kidia-mobile-cms' ); ?></small></div>
				<div><span class="dashicons dashicons-category"></span><strong><?php echo esc_html( number_format_i18n( $catalog_stats['categories'] ) ); ?></strong><small><?php esc_html_e( 'Categories ready', 'kidia-mobile-cms' ); ?></small></div>
				<div><span class="dashicons dashicons-format-gallery"></span><strong><?php echo esc_html( number_format_i18n( $catalog_stats['images'] ) ); ?></strong><small><?php esc_html_e( 'Product images ready', 'kidia-mobile-cms' ); ?></small></div>
			</div>
		</section>

		<div class="kidia-setup-actions">
			<button type="button" class="button kidia-setup-back" hidden><?php esc_html_e( 'Back', 'kidia-mobile-cms' ); ?></button>
			<div></div>
			<a href="<?php echo esc_url( admin_url( 'admin.php?page=kidia-mobile-cms' ) ); ?>" class="button kidia-setup-skip"><?php esc_html_e( 'Exit setup', 'kidia-mobile-cms' ); ?></a>
			<button type="button" class="button button-primary kidia-setup-next"><?php esc_html_e( 'Continue', 'kidia-mobile-cms' ); ?></button>
			<button type="submit" class="button button-primary kidia-setup-apply" hidden><?php esc_html_e( 'Apply theme', 'kidia-mobile-cms' ); ?></button>
		</div>
	</form>
</div>
