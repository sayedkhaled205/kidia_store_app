<?php
/** Setup wizard screen. */
defined( 'ABSPATH' ) || exit;
?>
<div class="wrap mobishop-setup-wrap">
	<div class="mobishop-setup-hero">
		<div>
			<span class="mobishop-setup-eyebrow"><?php esc_html_e( 'MobiShop', 'mobishop' ); ?></span>
			<h1><?php echo $wizard->is_complete() ? esc_html__( 'Setup & Themes', 'mobishop' ) : esc_html__( 'Build your application', 'mobishop' ); ?></h1>
			<p><?php esc_html_e( 'Choose a complete storefront, connect it to your WooCommerce catalog, then review the application before applying it.', 'mobishop' ); ?></p>
		</div>
		<div class="mobishop-setup-progress" aria-label="<?php esc_attr_e( 'Setup progress', 'mobishop' ); ?>">
			<?php $progress_steps = 5; ?>
			<?php for ( $progress_step = 1; $progress_step <= $progress_steps; $progress_step++ ) : ?>
				<span class="<?php echo 1 === $progress_step ? 'is-active' : ''; ?>"><?php echo esc_html( (string) $progress_step ); ?></span>
				<?php if ( $progress_step < $progress_steps ) : ?><i></i><?php endif; ?>
			<?php endfor; ?>
		</div>
	</div>

	<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" class="mobishop-setup-form">
		<input type="hidden" name="action" value="mobishop_apply_setup_wizard">
		<?php wp_nonce_field( 'mobishop_apply_setup_wizard', 'mobishop_setup_nonce' ); ?>

		<section class="mobishop-setup-step is-active" data-step="1" data-step-kind="identity">
			<div class="mobishop-setup-step-heading">
				<span data-step-number>01</span>
				<div><h2><?php esc_html_e( 'General Settings', 'mobishop' ); ?></h2><p><?php esc_html_e( 'Name, logo, language and brand colors are detected from the connected site and remain editable, alongside icon appearance and typography.', 'mobishop' ); ?></p></div>
			</div>
			<div class="mobishop-setup-identity-grid">
				<label><span><?php esc_html_e( 'Application name', 'mobishop' ); ?></span><input type="text" name="setup[app_name]" value="<?php echo esc_attr( (string) $identity['app_name'] ); ?>" required></label>
				<label><span><?php esc_html_e( 'Language', 'mobishop' ); ?></span><select name="setup[language]"><option value="ar" <?php selected( 'ar', $identity['language'] ); ?>>العربية</option><option value="en" <?php selected( 'en', $identity['language'] ); ?>>English</option></select></label>
				<label><span><?php esc_html_e( 'Direction', 'mobishop' ); ?></span><select name="setup[direction]"><option value="rtl" <?php selected( 'rtl', $identity['direction'] ); ?>>RTL</option><option value="ltr" <?php selected( 'ltr', $identity['direction'] ); ?>>LTR</option></select></label>
				<label><span><?php esc_html_e( 'Application icon shape', 'mobishop' ); ?></span><select name="setup[app_icon_shape]"><option value="rounded_square" <?php selected( 'rounded_square', $identity['app_icon_shape'] ?? 'rounded_square' ); ?>><?php esc_html_e( 'Rounded square', 'mobishop' ); ?></option><option value="circle" <?php selected( 'circle', $identity['app_icon_shape'] ?? '' ); ?>><?php esc_html_e( 'Circle', 'mobishop' ); ?></option><option value="square" <?php selected( 'square', $identity['app_icon_shape'] ?? '' ); ?>><?php esc_html_e( 'Square', 'mobishop' ); ?></option></select></label>
				<label class="mobishop-setup-font-field"><span><?php esc_html_e( 'Font collection', 'mobishop' ); ?></span><select name="setup[font_family]"><optgroup label="<?php esc_attr_e( 'Recommended', 'mobishop' ); ?>"><option value="system" <?php selected( 'system', $identity['font_family'] ?? 'system' ); ?>><?php esc_html_e( 'System font', 'mobishop' ); ?></option><option value="poppins" <?php selected( 'poppins', $identity['font_family'] ?? '' ); ?>>Poppins</option><option value="roboto" <?php selected( 'roboto', $identity['font_family'] ?? '' ); ?>>Roboto</option><option value="noto_sans_arabic" <?php selected( 'noto_sans_arabic', $identity['font_family'] ?? '' ); ?>>Noto Sans Arabic</option></optgroup><optgroup label="<?php esc_attr_e( 'Classic', 'mobishop' ); ?>"><option value="serif" <?php selected( 'serif', $identity['font_family'] ?? '' ); ?>>Serif</option><option value="monospace" <?php selected( 'monospace', $identity['font_family'] ?? '' ); ?>>Monospace</option></optgroup></select></label>
				<label class="mobishop-setup-color-field">
					<span><?php esc_html_e( 'Brand color', 'mobishop' ); ?></span>
					<span class="mobishop-setup-color-control">
						<input type="color" name="setup[primary_color]" value="<?php echo esc_attr( (string) $identity['primary_color'] ); ?>" data-color-picker="primary">
						<input type="text" value="<?php echo esc_attr( strtoupper( (string) $identity['primary_color'] ) ); ?>" data-color-code="primary" aria-label="<?php esc_attr_e( 'Brand color code', 'mobishop' ); ?>" maxlength="7" spellcheck="false">
					</span>
				</label>
				<label class="mobishop-setup-color-field">
					<span><?php esc_html_e( 'Secondary color', 'mobishop' ); ?></span>
					<span class="mobishop-setup-color-control">
						<input type="color" name="setup[secondary_color]" value="<?php echo esc_attr( (string) $identity['secondary_color'] ); ?>" data-color-picker="secondary">
						<input type="text" value="<?php echo esc_attr( strtoupper( (string) $identity['secondary_color'] ) ); ?>" data-color-code="secondary" aria-label="<?php esc_attr_e( 'Secondary color code', 'mobishop' ); ?>" maxlength="7" spellcheck="false">
					</span>
				</label>
				<div class="mobishop-setup-logo-field">
					<span><?php esc_html_e( 'Application logo', 'mobishop' ); ?></span>
					<div class="mobishop-setup-logo-preview"><?php if ( ! empty( $identity['logo_url'] ) ) : ?><img src="<?php echo esc_url( (string) $identity['logo_url'] ); ?>" alt=""><?php else : ?><span class="dashicons dashicons-format-image"></span><?php endif; ?></div>
					<input type="hidden" name="setup[logo_id]" value="<?php echo esc_attr( (string) $identity['logo_id'] ); ?>">
					<input type="hidden" name="setup[logo_url]" value="<?php echo esc_url( (string) $identity['logo_url'] ); ?>">
					<button type="button" class="button mobishop-setup-choose-logo"><?php esc_html_e( 'Choose logo', 'mobishop' ); ?></button>
				</div>
			</div>
		</section>

		<?php
		$saved_enabled_pages = is_array( $identity['enabled_pages'] ?? null ) ? $identity['enabled_pages'] : array_keys( $setup_pages );
		?>
		<section class="mobishop-setup-step" data-step="2" data-step-kind="pages">
			<div class="mobishop-setup-step-heading">
				<span data-step-number>02</span>
				<div><h2><?php esc_html_e( 'Choose application pages', 'mobishop' ); ?></h2><p><?php esc_html_e( 'Required store pages are always included. Choose the optional pages you want to create and customize.', 'mobishop' ); ?></p></div>
			</div>
			<div class="mobishop-page-selection-grid">
				<?php foreach ( $setup_pages as $page_key => $page_details ) : ?>
					<?php $is_required = ! empty( $page_details['required'] ); ?>
					<label class="mobishop-page-choice <?php echo $is_required ? 'is-required' : ''; ?>">
						<?php if ( $is_required ) : ?>
							<input type="hidden" name="setup[enabled_pages][<?php echo esc_attr( $page_key ); ?>]" value="1" data-page-toggle="<?php echo esc_attr( $page_key ); ?>" data-required-page="1">
						<?php else : ?>
							<input type="checkbox" name="setup[enabled_pages][<?php echo esc_attr( $page_key ); ?>]" value="1" data-page-toggle="<?php echo esc_attr( $page_key ); ?>" <?php checked( in_array( $page_key, $saved_enabled_pages, true ) ); ?>>
						<?php endif; ?>
						<span class="mobishop-page-choice__icon dashicons <?php echo esc_attr( (string) $page_details['icon'] ); ?>"></span>
						<span class="mobishop-page-choice__copy"><strong><?php echo esc_html( (string) $page_details['name'] ); ?></strong><small><?php echo esc_html( (string) $page_details['description'] ); ?></small></span>
						<span class="mobishop-page-choice__status"><?php echo $is_required ? esc_html__( 'Required', 'mobishop' ) : esc_html__( 'Optional', 'mobishop' ); ?></span>
						<?php if ( ! $is_required ) : ?><span class="mobishop-page-choice__switch" aria-hidden="true"></span><?php endif; ?>
					</label>
				<?php endforeach; ?>
			</div>
			<p class="mobishop-page-selection-note"><span class="dashicons dashicons-info-outline"></span><?php esc_html_e( 'The complete theme will be installed only on the selected pages. Unselected pages stay hidden and keep their saved design.', 'mobishop' ); ?></p>
		</section>

		<?php
		$setup_step = 3;
		$selected_theme = sanitize_key( (string) ( $identity['theme'] ?? 'fashion' ) );
		if ( ! isset( $themes[ $selected_theme ] ) ) {
			$selected_theme = 'fashion';
		}
		?>
		<section class="mobishop-setup-step" data-step="3" data-step-kind="theme">
			<div class="mobishop-setup-step-heading">
				<span data-step-number>03</span>
				<div><h2><?php esc_html_e( 'Choose a complete store theme', 'mobishop' ); ?></h2><p><?php esc_html_e( 'Each theme is a ready-made store with its own real banner, page layout, colors, cards, navigation and product presentation.', 'mobishop' ); ?></p></div>
			</div>
			<div class="mobishop-theme-gallery">
				<?php foreach ( $themes as $key => $theme ) : ?>
					<?php $hero_url = MobiShop_Setup_Wizard::hero_url( $theme ); ?>
					<label class="mobishop-theme-card" data-theme-key="<?php echo esc_attr( $key ); ?>" data-theme-name="<?php echo esc_attr( (string) $theme['name'] ); ?>" data-theme-hero="<?php echo esc_url( $hero_url ); ?>" data-theme-copy="<?php echo esc_attr( wp_json_encode( array_values( $theme['sample_copy'] ) ) ); ?>" style="--theme-primary:<?php echo esc_attr( $theme['primary'] ); ?>;--theme-soft:<?php echo esc_attr( $theme['soft'] ); ?>;--theme-ink:<?php echo esc_attr( $theme['ink'] ); ?>;--theme-surface:<?php echo esc_attr( $theme['surface'] ); ?>">
						<input type="radio" name="setup[theme]" value="<?php echo esc_attr( $key ); ?>" <?php checked( $selected_theme, $key ); ?> required>
						<div class="mobishop-theme-preview">
							<div class="mobishop-theme-phone">
								<div class="mobishop-theme-phone-top"><b><?php echo esc_html( (string) $theme['name'] ); ?></b><i></i></div>
								<div class="mobishop-theme-search"></div>
								<div class="mobishop-theme-hero" style="background-image:linear-gradient(0deg,rgba(0,0,0,.46),rgba(0,0,0,.02)),url('<?php echo esc_url( $hero_url ); ?>')"><span><?php echo esc_html( (string) $theme['sample_copy'][0] ); ?></span></div>
								<div class="mobishop-theme-categories">
									<?php for ( $sample_index = 1; $sample_index <= 3; $sample_index++ ) : ?>
										<i style="background-image:url('<?php echo esc_url( MobiShop_Setup_Wizard::asset_url( $theme, 'category', $sample_index ) ); ?>')"></i>
									<?php endfor; ?>
								</div>
								<div class="mobishop-theme-products">
									<?php for ( $sample_index = 1; $sample_index <= 2; $sample_index++ ) : ?>
										<i style="background-image:url('<?php echo esc_url( MobiShop_Setup_Wizard::asset_url( $theme, 'product', $sample_index ) ); ?>')"></i>
									<?php endfor; ?>
								</div>
								<div class="mobishop-theme-footer"><i></i><i></i><i></i><i></i></div>
							</div>
						</div>
						<div class="mobishop-theme-card-copy">
							<span class="mobishop-theme-check dashicons dashicons-yes-alt"></span>
							<h3><?php echo esc_html( (string) $theme['name'] ); ?></h3>
							<p><?php echo esc_html( (string) $theme['description'] ); ?></p>
							<small><?php echo esc_html( implode( ' · ', array_map( 'strval', $theme['sample_copy'] ) ) ); ?></small>
							<button type="button" class="button mobishop-theme-preview-button"><?php esc_html_e( 'Preview full theme', 'mobishop' ); ?></button>
						</div>
					</label>
				<?php endforeach; ?>
			</div>
		</section>

		<?php ++$setup_step; ?>
		<section class="mobishop-setup-step" data-step="<?php echo esc_attr( (string) $setup_step ); ?>">
			<div class="mobishop-setup-step-heading">
				<span data-step-number><?php echo esc_html( str_pad( (string) $setup_step, 2, '0', STR_PAD_LEFT ) ); ?></span>
				<div><h2><?php esc_html_e( 'Review and apply', 'mobishop' ); ?></h2><p><?php esc_html_e( 'A snapshot of the current application is created before the new theme is applied.', 'mobishop' ); ?></p></div>
			</div>
			<div class="mobishop-review-card">
				<div class="mobishop-review-icon"><span class="dashicons dashicons-smartphone"></span></div>
				<div><h3 data-review-name><?php echo esc_html( (string) $identity['app_name'] ); ?></h3><strong data-review-theme><?php echo esc_html( (string) $themes[ $selected_theme ]['name'] ); ?></strong><p><?php esc_html_e( 'The preview uses the theme package only. After applying it, live product sections connect to your WooCommerce catalog.', 'mobishop' ); ?></p><div class="mobishop-review-tags"><?php foreach ( $setup_pages as $page_key => $page_details ) : ?><span data-review-page="<?php echo esc_attr( $page_key ); ?>"><?php echo esc_html( (string) $page_details['name'] ); ?></span><?php endforeach; ?></div></div>
			</div>
			<div class="mobishop-catalog-summary">
				<div><span class="dashicons dashicons-products"></span><strong><?php echo esc_html( number_format_i18n( $catalog_stats['products'] ) ); ?></strong><small><?php esc_html_e( 'Products ready', 'mobishop' ); ?></small></div>
				<div><span class="dashicons dashicons-category"></span><strong><?php echo esc_html( number_format_i18n( $catalog_stats['categories'] ) ); ?></strong><small><?php esc_html_e( 'Categories ready', 'mobishop' ); ?></small></div>
				<div><span class="dashicons dashicons-format-gallery"></span><strong><?php echo esc_html( number_format_i18n( $catalog_stats['images'] ) ); ?></strong><small><?php esc_html_e( 'Product images ready', 'mobishop' ); ?></small></div>
			</div>
		</section>

		<?php ++$setup_step; ?>
		<section class="mobishop-setup-step" data-step="<?php echo esc_attr( (string) $setup_step ); ?>">
			<div class="mobishop-setup-step-heading">
				<span data-step-number><?php echo esc_html( str_pad( (string) $setup_step, 2, '0', STR_PAD_LEFT ) ); ?></span>
				<div><h2><?php esc_html_e( 'Finish setup', 'mobishop' ); ?></h2><p><?php esc_html_e( 'Apply the selected storefront, then continue to Customize Your Pages.', 'mobishop' ); ?></p></div>
			</div>
			<div class="mobishop-export-ready-card is-ready">
				<span class="mobishop-review-icon"><span class="dashicons dashicons-admin-customizer"></span></span>
				<div>
					<h3><?php esc_html_e( 'Your storefront is ready to customize', 'mobishop' ); ?></h3>
					<p><?php esc_html_e( 'MobiShop will apply the selected theme, identity and pages, then open the visual page customizer.', 'mobishop' ); ?></p>
					<ul>
						<li><span class="dashicons dashicons-yes-alt"></span><?php esc_html_e( 'Every selected page receives the complete theme design.', 'mobishop' ); ?></li>
						<li><span class="dashicons dashicons-yes-alt"></span><?php esc_html_e( 'You can fine-tune every element from Customize Your Pages.', 'mobishop' ); ?></li>
						<li><span class="dashicons dashicons-yes-alt"></span><?php esc_html_e( 'Build and download remain available from Overview when you are ready.', 'mobishop' ); ?></li>
					</ul>
				</div>
			</div>
		</section>

		<div class="mobishop-setup-actions">
			<button type="button" class="button mobishop-setup-back" hidden><?php esc_html_e( 'Back', 'mobishop' ); ?></button>
			<div></div>
			<a href="<?php echo esc_url( admin_url( 'admin.php?page=mobishop' ) ); ?>" class="button mobishop-setup-skip"><?php esc_html_e( 'Exit setup', 'mobishop' ); ?></a>
			<button type="button" class="button button-primary mobishop-setup-next"><?php esc_html_e( 'Continue', 'mobishop' ); ?></button>
			<button type="submit" name="finish_setup" value="1" class="button button-primary mobishop-setup-apply" hidden><span class="dashicons dashicons-yes-alt" aria-hidden="true"></span><?php esc_html_e( 'Finish', 'mobishop' ); ?></button>
		</div>
	</form>

	<div class="mobishop-theme-modal" hidden>
		<div class="mobishop-theme-modal__backdrop" data-theme-modal-close></div>
		<div class="mobishop-theme-modal__dialog" role="dialog" aria-modal="true" aria-labelledby="mobishop-theme-modal-title">
			<button type="button" class="mobishop-theme-modal__close" data-theme-modal-close aria-label="<?php esc_attr_e( 'Close preview', 'mobishop' ); ?>"><span class="dashicons dashicons-no-alt"></span></button>
			<div class="mobishop-theme-modal__heading"><span><?php esc_html_e( 'Complete theme preview', 'mobishop' ); ?></span><h2 id="mobishop-theme-modal-title" data-theme-modal-name></h2><p><?php esc_html_e( 'Browse every real Flutter page generated from this theme’s own settings and store imagery.', 'mobishop' ); ?></p></div>
			<div class="mobishop-theme-modal__workspace">
				<div class="mobishop-theme-modal__controls">
					<nav class="mobishop-theme-modal__pages" aria-label="<?php esc_attr_e( 'Theme preview pages', 'mobishop' ); ?>">
						<button type="button" data-theme-modal-page="splash" class="is-active" aria-current="page">
							<span class="dashicons dashicons-format-image" aria-hidden="true"></span>
							<?php esc_html_e( 'Splash', 'mobishop' ); ?>
						</button>
						<?php foreach ( $setup_pages as $preview_page => $preview_page_data ) : ?>
							<button type="button" data-theme-modal-page="<?php echo esc_attr( (string) $preview_page ); ?>">
								<span class="dashicons <?php echo esc_attr( (string) $preview_page_data['icon'] ); ?>" aria-hidden="true"></span>
								<?php echo esc_html( (string) $preview_page_data['name'] ); ?>
							</button>
						<?php endforeach; ?>
					</nav>
					<button type="button" class="button button-primary mobishop-theme-modal__select"><?php esc_html_e( 'Use this complete theme', 'mobishop' ); ?></button>
				</div>
				<div class="mobishop-theme-modal__stage">
					<div class="mobishop-theme-modal__device">
						<iframe data-theme-modal-frame title="<?php esc_attr_e( 'Real Flutter theme preview', 'mobishop' ); ?>" loading="eager" allow="clipboard-read; clipboard-write"></iframe>
					</div>
					<div class="mobishop-theme-modal__loading" data-theme-modal-loading role="status">
						<span class="spinner is-active" aria-hidden="true"></span>
						<b><?php esc_html_e( 'Loading real theme page…', 'mobishop' ); ?></b>
					</div>
				</div>
			</div>
		</div>
	</div>
</div>
