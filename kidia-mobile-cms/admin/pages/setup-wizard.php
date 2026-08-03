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
			<?php $progress_steps = 5; ?>
			<?php for ( $progress_step = 1; $progress_step <= $progress_steps; $progress_step++ ) : ?>
				<span class="<?php echo 1 === $progress_step ? 'is-active' : ''; ?>"><?php echo esc_html( (string) $progress_step ); ?></span>
				<?php if ( $progress_step < $progress_steps ) : ?><i></i><?php endif; ?>
			<?php endfor; ?>
		</div>
	</div>

	<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" class="kidia-setup-form">
		<input type="hidden" name="action" value="kidia_mobile_apply_setup_wizard">
		<?php wp_nonce_field( 'kidia_mobile_apply_setup_wizard', 'kidia_mobile_setup_nonce' ); ?>

		<section class="kidia-setup-step is-active" data-step="1" data-step-kind="identity">
			<div class="kidia-setup-step-heading">
				<span data-step-number>01</span>
				<div><h2><?php esc_html_e( 'Application identity', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Name, logo, language and brand colors are detected from the connected site and remain editable.', 'kidia-mobile-cms' ); ?></p></div>
			</div>
			<div class="kidia-setup-identity-grid">
				<label><span><?php esc_html_e( 'Application name', 'kidia-mobile-cms' ); ?></span><input type="text" name="setup[app_name]" value="<?php echo esc_attr( (string) $identity['app_name'] ); ?>" required></label>
				<label><span><?php esc_html_e( 'Language', 'kidia-mobile-cms' ); ?></span><select name="setup[language]"><option value="ar" <?php selected( 'ar', $identity['language'] ); ?>>العربية</option><option value="en" <?php selected( 'en', $identity['language'] ); ?>>English</option></select></label>
				<label><span><?php esc_html_e( 'Direction', 'kidia-mobile-cms' ); ?></span><select name="setup[direction]"><option value="rtl" <?php selected( 'rtl', $identity['direction'] ); ?>>RTL</option><option value="ltr" <?php selected( 'ltr', $identity['direction'] ); ?>>LTR</option></select></label>
				<label class="kidia-setup-color-field">
					<span><?php esc_html_e( 'Brand color', 'kidia-mobile-cms' ); ?></span>
					<span class="kidia-setup-color-control">
						<input type="color" name="setup[primary_color]" value="<?php echo esc_attr( (string) $identity['primary_color'] ); ?>" data-color-picker="primary">
						<input type="text" value="<?php echo esc_attr( strtoupper( (string) $identity['primary_color'] ) ); ?>" data-color-code="primary" aria-label="<?php esc_attr_e( 'Brand color code', 'kidia-mobile-cms' ); ?>" maxlength="7" spellcheck="false">
					</span>
				</label>
				<label class="kidia-setup-color-field">
					<span><?php esc_html_e( 'Secondary color', 'kidia-mobile-cms' ); ?></span>
					<span class="kidia-setup-color-control">
						<input type="color" name="setup[secondary_color]" value="<?php echo esc_attr( (string) $identity['secondary_color'] ); ?>" data-color-picker="secondary">
						<input type="text" value="<?php echo esc_attr( strtoupper( (string) $identity['secondary_color'] ) ); ?>" data-color-code="secondary" aria-label="<?php esc_attr_e( 'Secondary color code', 'kidia-mobile-cms' ); ?>" maxlength="7" spellcheck="false">
					</span>
				</label>
				<div class="kidia-setup-logo-field">
					<span><?php esc_html_e( 'Application logo', 'kidia-mobile-cms' ); ?></span>
					<div class="kidia-setup-logo-preview"><?php if ( ! empty( $identity['logo_url'] ) ) : ?><img src="<?php echo esc_url( (string) $identity['logo_url'] ); ?>" alt=""><?php else : ?><span class="dashicons dashicons-format-image"></span><?php endif; ?></div>
					<input type="hidden" name="setup[logo_id]" value="<?php echo esc_attr( (string) $identity['logo_id'] ); ?>">
					<input type="hidden" name="setup[logo_url]" value="<?php echo esc_url( (string) $identity['logo_url'] ); ?>">
					<button type="button" class="button kidia-setup-choose-logo"><?php esc_html_e( 'Choose logo', 'kidia-mobile-cms' ); ?></button>
				</div>
			</div>
		</section>

		<?php
		$saved_enabled_pages = is_array( $identity['enabled_pages'] ?? null ) ? $identity['enabled_pages'] : array_keys( $setup_pages );
		?>
		<section class="kidia-setup-step" data-step="2" data-step-kind="pages">
			<div class="kidia-setup-step-heading">
				<span data-step-number>02</span>
				<div><h2><?php esc_html_e( 'Choose application pages', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Required store pages are always included. Choose the optional pages you want to create and customize.', 'kidia-mobile-cms' ); ?></p></div>
			</div>
			<div class="kidia-page-selection-grid">
				<?php foreach ( $setup_pages as $page_key => $page_details ) : ?>
					<?php $is_required = ! empty( $page_details['required'] ); ?>
					<label class="kidia-page-choice <?php echo $is_required ? 'is-required' : ''; ?>">
						<?php if ( $is_required ) : ?>
							<input type="hidden" name="setup[enabled_pages][<?php echo esc_attr( $page_key ); ?>]" value="1" data-page-toggle="<?php echo esc_attr( $page_key ); ?>" data-required-page="1">
						<?php else : ?>
							<input type="checkbox" name="setup[enabled_pages][<?php echo esc_attr( $page_key ); ?>]" value="1" data-page-toggle="<?php echo esc_attr( $page_key ); ?>" <?php checked( in_array( $page_key, $saved_enabled_pages, true ) ); ?>>
						<?php endif; ?>
						<span class="kidia-page-choice__icon dashicons <?php echo esc_attr( (string) $page_details['icon'] ); ?>"></span>
						<span class="kidia-page-choice__copy"><strong><?php echo esc_html( (string) $page_details['name'] ); ?></strong><small><?php echo esc_html( (string) $page_details['description'] ); ?></small></span>
						<span class="kidia-page-choice__status"><?php echo $is_required ? esc_html__( 'Required', 'kidia-mobile-cms' ) : esc_html__( 'Optional', 'kidia-mobile-cms' ); ?></span>
						<?php if ( ! $is_required ) : ?><span class="kidia-page-choice__switch" aria-hidden="true"></span><?php endif; ?>
					</label>
				<?php endforeach; ?>
			</div>
			<p class="kidia-page-selection-note"><span class="dashicons dashicons-info-outline"></span><?php esc_html_e( 'The complete theme will be installed only on the selected pages. Unselected pages stay hidden and keep their saved design.', 'kidia-mobile-cms' ); ?></p>
		</section>

		<?php
		$setup_step = 3;
		$selected_theme = sanitize_key( (string) ( $identity['theme'] ?? 'fashion' ) );
		if ( ! isset( $themes[ $selected_theme ] ) ) {
			$selected_theme = 'fashion';
		}
		?>
		<section class="kidia-setup-step" data-step="3" data-step-kind="theme">
			<div class="kidia-setup-step-heading">
				<span data-step-number>03</span>
				<div><h2><?php esc_html_e( 'Choose a complete store theme', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Each theme is a ready-made store with its own real banner, page layout, colors, cards, navigation and product presentation.', 'kidia-mobile-cms' ); ?></p></div>
			</div>
			<div class="kidia-theme-gallery">
				<?php foreach ( $themes as $key => $theme ) : ?>
					<?php $hero_url = Kidia_Mobile_Setup_Wizard::hero_url( $theme ); ?>
					<label class="kidia-theme-card" data-theme-key="<?php echo esc_attr( $key ); ?>" data-theme-name="<?php echo esc_attr( (string) $theme['name'] ); ?>" data-theme-hero="<?php echo esc_url( $hero_url ); ?>" data-theme-copy="<?php echo esc_attr( wp_json_encode( array_values( $theme['sample_copy'] ) ) ); ?>" style="--theme-primary:<?php echo esc_attr( $theme['primary'] ); ?>;--theme-soft:<?php echo esc_attr( $theme['soft'] ); ?>;--theme-ink:<?php echo esc_attr( $theme['ink'] ); ?>;--theme-surface:<?php echo esc_attr( $theme['surface'] ); ?>">
						<input type="radio" name="setup[theme]" value="<?php echo esc_attr( $key ); ?>" <?php checked( $selected_theme, $key ); ?> required>
						<div class="kidia-theme-preview">
							<div class="kidia-theme-phone">
								<div class="kidia-theme-phone-top"><b><?php echo esc_html( (string) $theme['name'] ); ?></b><i></i></div>
								<div class="kidia-theme-search"></div>
								<div class="kidia-theme-hero" style="background-image:linear-gradient(0deg,rgba(0,0,0,.46),rgba(0,0,0,.02)),url('<?php echo esc_url( $hero_url ); ?>')"><span><?php echo esc_html( (string) $theme['sample_copy'][0] ); ?></span></div>
								<div class="kidia-theme-categories">
									<?php for ( $sample_index = 1; $sample_index <= 3; $sample_index++ ) : ?>
										<i style="background-image:url('<?php echo esc_url( Kidia_Mobile_Setup_Wizard::asset_url( $theme, 'category', $sample_index ) ); ?>')"></i>
									<?php endfor; ?>
								</div>
								<div class="kidia-theme-products">
									<?php for ( $sample_index = 1; $sample_index <= 2; $sample_index++ ) : ?>
										<i style="background-image:url('<?php echo esc_url( Kidia_Mobile_Setup_Wizard::asset_url( $theme, 'product', $sample_index ) ); ?>')"></i>
									<?php endfor; ?>
								</div>
								<div class="kidia-theme-footer"><i></i><i></i><i></i><i></i></div>
							</div>
						</div>
						<div class="kidia-theme-card-copy">
							<span class="kidia-theme-check dashicons dashicons-yes-alt"></span>
							<h3><?php echo esc_html( (string) $theme['name'] ); ?></h3>
							<p><?php echo esc_html( (string) $theme['description'] ); ?></p>
							<small><?php echo esc_html( implode( ' · ', array_map( 'strval', $theme['sample_copy'] ) ) ); ?></small>
							<button type="button" class="button kidia-theme-preview-button"><?php esc_html_e( 'Preview full theme', 'kidia-mobile-cms' ); ?></button>
						</div>
					</label>
				<?php endforeach; ?>
			</div>
		</section>

		<?php ++$setup_step; ?>
		<section class="kidia-setup-step" data-step="<?php echo esc_attr( (string) $setup_step ); ?>">
			<div class="kidia-setup-step-heading">
				<span data-step-number><?php echo esc_html( str_pad( (string) $setup_step, 2, '0', STR_PAD_LEFT ) ); ?></span>
				<div><h2><?php esc_html_e( 'Review and apply', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'A snapshot of the current application is created before the new theme is applied.', 'kidia-mobile-cms' ); ?></p></div>
			</div>
			<div class="kidia-review-card">
				<div class="kidia-review-icon"><span class="dashicons dashicons-smartphone"></span></div>
				<div><h3 data-review-name><?php echo esc_html( (string) $identity['app_name'] ); ?></h3><strong data-review-theme><?php echo esc_html( (string) $themes[ $selected_theme ]['name'] ); ?></strong><p><?php esc_html_e( 'The preview uses the theme package only. After applying it, live product sections connect to your WooCommerce catalog.', 'kidia-mobile-cms' ); ?></p><div class="kidia-review-tags"><?php foreach ( $setup_pages as $page_key => $page_details ) : ?><span data-review-page="<?php echo esc_attr( $page_key ); ?>"><?php echo esc_html( (string) $page_details['name'] ); ?></span><?php endforeach; ?></div></div>
			</div>
			<div class="kidia-catalog-summary">
				<div><span class="dashicons dashicons-products"></span><strong><?php echo esc_html( number_format_i18n( $catalog_stats['products'] ) ); ?></strong><small><?php esc_html_e( 'Products ready', 'kidia-mobile-cms' ); ?></small></div>
				<div><span class="dashicons dashicons-category"></span><strong><?php echo esc_html( number_format_i18n( $catalog_stats['categories'] ) ); ?></strong><small><?php esc_html_e( 'Categories ready', 'kidia-mobile-cms' ); ?></small></div>
				<div><span class="dashicons dashicons-format-gallery"></span><strong><?php echo esc_html( number_format_i18n( $catalog_stats['images'] ) ); ?></strong><small><?php esc_html_e( 'Product images ready', 'kidia-mobile-cms' ); ?></small></div>
			</div>
		</section>

		<?php ++$setup_step; ?>
		<section class="kidia-setup-step" data-step="<?php echo esc_attr( (string) $setup_step ); ?>">
			<div class="kidia-setup-step-heading">
				<span data-step-number><?php echo esc_html( str_pad( (string) $setup_step, 2, '0', STR_PAD_LEFT ) ); ?></span>
				<div><h2><?php esc_html_e( 'Finish setup', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Apply the selected storefront, then continue to Customize Your Pages.', 'kidia-mobile-cms' ); ?></p></div>
			</div>
			<div class="kidia-export-ready-card is-ready">
				<span class="kidia-review-icon"><span class="dashicons dashicons-admin-customizer"></span></span>
				<div>
					<h3><?php esc_html_e( 'Your storefront is ready to customize', 'kidia-mobile-cms' ); ?></h3>
					<p><?php esc_html_e( 'WooMobile will apply the selected theme, identity and pages, then open the visual page customizer.', 'kidia-mobile-cms' ); ?></p>
					<ul>
						<li><span class="dashicons dashicons-yes-alt"></span><?php esc_html_e( 'Every selected page receives the complete theme design.', 'kidia-mobile-cms' ); ?></li>
						<li><span class="dashicons dashicons-yes-alt"></span><?php esc_html_e( 'You can fine-tune every element from Customize Your Pages.', 'kidia-mobile-cms' ); ?></li>
						<li><span class="dashicons dashicons-yes-alt"></span><?php esc_html_e( 'Build and download remain available from Overview when you are ready.', 'kidia-mobile-cms' ); ?></li>
					</ul>
				</div>
			</div>
		</section>

		<div class="kidia-setup-actions">
			<button type="button" class="button kidia-setup-back" hidden><?php esc_html_e( 'Back', 'kidia-mobile-cms' ); ?></button>
			<div></div>
			<a href="<?php echo esc_url( admin_url( 'admin.php?page=kidia-mobile-cms' ) ); ?>" class="button kidia-setup-skip"><?php esc_html_e( 'Exit setup', 'kidia-mobile-cms' ); ?></a>
			<button type="button" class="button button-primary kidia-setup-next"><?php esc_html_e( 'Continue', 'kidia-mobile-cms' ); ?></button>
			<button type="submit" name="finish_setup" value="1" class="button button-primary kidia-setup-apply" hidden><span class="dashicons dashicons-yes-alt" aria-hidden="true"></span><?php esc_html_e( 'Finish', 'kidia-mobile-cms' ); ?></button>
		</div>
	</form>

	<div class="kidia-theme-modal" hidden>
		<div class="kidia-theme-modal__backdrop" data-theme-modal-close></div>
		<div class="kidia-theme-modal__dialog" role="dialog" aria-modal="true" aria-labelledby="kidia-theme-modal-title">
			<button type="button" class="kidia-theme-modal__close" data-theme-modal-close aria-label="<?php esc_attr_e( 'Close preview', 'kidia-mobile-cms' ); ?>"><span class="dashicons dashicons-no-alt"></span></button>
			<div class="kidia-theme-modal__heading"><span><?php esc_html_e( 'Complete theme preview', 'kidia-mobile-cms' ); ?></span><h2 id="kidia-theme-modal-title" data-theme-modal-name></h2><p><?php esc_html_e( 'Browse every real Flutter page generated from this theme’s own settings and store imagery.', 'kidia-mobile-cms' ); ?></p></div>
			<div class="kidia-theme-modal__workspace">
				<div class="kidia-theme-modal__controls">
					<nav class="kidia-theme-modal__pages" aria-label="<?php esc_attr_e( 'Theme preview pages', 'kidia-mobile-cms' ); ?>">
						<button type="button" data-theme-modal-page="splash" class="is-active" aria-current="page">
							<span class="dashicons dashicons-format-image" aria-hidden="true"></span>
							<?php esc_html_e( 'Splash', 'kidia-mobile-cms' ); ?>
						</button>
						<?php foreach ( $setup_pages as $preview_page => $preview_page_data ) : ?>
							<button type="button" data-theme-modal-page="<?php echo esc_attr( (string) $preview_page ); ?>">
								<span class="dashicons <?php echo esc_attr( (string) $preview_page_data['icon'] ); ?>" aria-hidden="true"></span>
								<?php echo esc_html( (string) $preview_page_data['name'] ); ?>
							</button>
						<?php endforeach; ?>
					</nav>
					<button type="button" class="button button-primary kidia-theme-modal__select"><?php esc_html_e( 'Use this complete theme', 'kidia-mobile-cms' ); ?></button>
				</div>
				<div class="kidia-theme-modal__stage">
					<div class="kidia-theme-modal__device">
						<iframe data-theme-modal-frame title="<?php esc_attr_e( 'Real Flutter theme preview', 'kidia-mobile-cms' ); ?>" loading="eager" allow="clipboard-read; clipboard-write"></iframe>
					</div>
					<div class="kidia-theme-modal__loading" data-theme-modal-loading role="status">
						<span class="spinner is-active" aria-hidden="true"></span>
						<b><?php esc_html_e( 'Loading real theme page…', 'kidia-mobile-cms' ); ?></b>
					</div>
				</div>
			</div>
		</div>
	</div>
</div>
