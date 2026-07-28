<?php
/** Saved theme library screen. */
defined( 'ABSPATH' ) || exit;
?>
<div class="wrap kidia-setup-wrap kidia-saved-themes-page">
	<div class="kidia-setup-hero">
		<div>
			<span class="kidia-setup-eyebrow"><?php esc_html_e( 'Reusable designs', 'kidia-mobile-cms' ); ?></span>
			<h1><?php esc_html_e( 'Saved Themes', 'kidia-mobile-cms' ); ?></h1>
			<p><?php esc_html_e( 'Apply, export or remove complete application designs saved from your page builders.', 'kidia-mobile-cms' ); ?></p>
		</div>
	</div>

	<?php if ( isset( $_GET['theme_notice'] ) ) : ?>
		<div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Saved theme action completed successfully.', 'kidia-mobile-cms' ); ?></p></div>
	<?php elseif ( isset( $_GET['theme_error'] ) ) : ?>
		<div class="notice notice-error is-dismissible"><p><?php esc_html_e( 'The saved theme action could not be completed. Check the file and try again.', 'kidia-mobile-cms' ); ?></p></div>
	<?php endif; ?>

	<section class="kidia-saved-themes">
		<?php if ( $saved_themes ) : ?>
			<div class="kidia-saved-themes__heading">
				<div>
					<h2><?php esc_html_e( 'Your saved themes', 'kidia-mobile-cms' ); ?></h2>
					<p><?php esc_html_e( 'Applying a theme replaces the current design and creates a new build.', 'kidia-mobile-cms' ); ?></p>
				</div>
				<form class="kidia-saved-themes__import-inline" method="post" enctype="multipart/form-data" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
					<input type="hidden" name="action" value="kidia_mobile_manage_saved_theme">
					<input type="hidden" name="theme_operation" value="import">
					<?php wp_nonce_field( 'kidia_mobile_manage_saved_theme', 'kidia_mobile_theme_nonce' ); ?>
					<label class="kidia-theme-file"><input type="file" name="theme_file" accept="application/json,.json" required><span class="button"><?php esc_html_e( 'Choose theme file', 'kidia-mobile-cms' ); ?></span><b data-theme-file-name><?php esc_html_e( 'No file selected', 'kidia-mobile-cms' ); ?></b></label>
					<button type="submit" class="button button-primary"><?php esc_html_e( 'Import Theme', 'kidia-mobile-cms' ); ?></button>
				</form>
			</div>
			<div class="kidia-saved-themes__grid">
				<?php foreach ( $saved_themes as $saved_theme_id => $saved_theme ) : ?>
					<?php
					$theme_preview = $wizard->saved_theme_preview( is_array( $saved_theme ) ? $saved_theme : array() );
					$theme_images  = is_array( $theme_preview['images'] ?? null ) ? $theme_preview['images'] : array();
					$theme_name    = (string) ( $saved_theme['name'] ?? __( 'Saved theme', 'kidia-mobile-cms' ) );
					?>
					<article data-saved-theme-card>
						<div
							class="kidia-saved-theme-phone<?php echo $theme_images ? ' has-theme-artwork' : ''; ?>"
							data-saved-theme-phone
							dir="<?php echo esc_attr( (string) $theme_preview['direction'] ); ?>"
							style="--theme-color:<?php echo esc_attr( (string) $theme_preview['primary'] ); ?>;--theme-soft:<?php echo esc_attr( (string) $theme_preview['soft'] ); ?>;--theme-ink:<?php echo esc_attr( (string) $theme_preview['ink'] ); ?>"
						>
							<div class="kidia-saved-theme-phone__bar"><i></i><i></i><i></i></div>
							<div class="kidia-saved-theme-phone__brand">
								<?php if ( ! empty( $theme_preview['logo_url'] ) ) : ?>
									<img src="<?php echo esc_url( (string) $theme_preview['logo_url'] ); ?>" alt="">
								<?php else : ?>
									<b><?php echo esc_html( (string) $theme_preview['app_name'] ); ?></b>
								<?php endif; ?>
								<i></i>
							</div>
							<div class="kidia-saved-theme-phone__hero">
								<?php if ( isset( $theme_images[0] ) ) : ?>
									<img src="<?php echo esc_url( (string) $theme_images[0] ); ?>" alt="<?php echo esc_attr( sprintf( __( '%s theme preview', 'kidia-mobile-cms' ), $theme_name ) ); ?>" loading="lazy">
								<?php endif; ?>
							</div>
							<div class="kidia-saved-theme-phone__dots"><i></i><i></i><i></i></div>
							<div class="kidia-saved-theme-phone__grid">
								<?php for ( $preview_tile = 1; $preview_tile <= 4; ++$preview_tile ) : ?>
									<i>
										<?php if ( isset( $theme_images[ $preview_tile ] ) ) : ?>
											<img src="<?php echo esc_url( (string) $theme_images[ $preview_tile ] ); ?>" alt="" loading="lazy">
										<?php endif; ?>
									</i>
								<?php endfor; ?>
							</div>
						</div>
						<div class="kidia-saved-theme-meta">
							<h3><?php echo esc_html( $theme_name ); ?></h3>
							<p><?php echo ! empty( $saved_theme['created_at'] ) ? esc_html( wp_date( get_option( 'date_format' ) . ' ' . get_option( 'time_format' ), absint( $saved_theme['created_at'] ) ) ) : ''; ?></p>
						</div>
						<div class="kidia-saved-themes__actions">
							<button
								type="button"
								class="button kidia-theme-action--preview"
								data-saved-theme-preview
								data-theme-name="<?php echo esc_attr( $theme_name ); ?>"
							><?php esc_html_e( 'Preview', 'kidia-mobile-cms' ); ?></button>
							<?php foreach ( array( 'apply' => __( 'Apply', 'kidia-mobile-cms' ), 'export' => __( 'Export', 'kidia-mobile-cms' ), 'delete' => __( 'Delete', 'kidia-mobile-cms' ) ) as $theme_operation => $theme_label ) : ?>
								<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" <?php if ( in_array( $theme_operation, array( 'apply', 'delete' ), true ) ) : ?>onsubmit="return window.confirm('<?php echo esc_js( 'apply' === $theme_operation ? __( 'Applying this theme replaces your current changes and creates a new build. Continue?', 'kidia-mobile-cms' ) : __( 'Delete this saved theme?', 'kidia-mobile-cms' ) ); ?>');"<?php endif; ?>>
									<input type="hidden" name="action" value="kidia_mobile_manage_saved_theme">
									<input type="hidden" name="theme_operation" value="<?php echo esc_attr( $theme_operation ); ?>">
									<input type="hidden" name="theme_id" value="<?php echo esc_attr( (string) $saved_theme_id ); ?>">
									<?php wp_nonce_field( 'kidia_mobile_manage_saved_theme', 'kidia_mobile_theme_nonce' ); ?>
									<button type="submit" class="button kidia-theme-action--<?php echo esc_attr( $theme_operation ); ?><?php echo 'apply' === $theme_operation ? ' button-primary' : ''; ?>"><?php echo esc_html( $theme_label ); ?></button>
								</form>
							<?php endforeach; ?>
						</div>
					</article>
				<?php endforeach; ?>
			</div>
			<dialog class="kidia-saved-theme-dialog" data-saved-theme-dialog aria-labelledby="kidia-saved-theme-dialog-title">
				<button type="button" class="kidia-saved-theme-dialog__close" data-saved-theme-dialog-close aria-label="<?php esc_attr_e( 'Close preview', 'kidia-mobile-cms' ); ?>">
					<span class="dashicons dashicons-no-alt" aria-hidden="true"></span>
				</button>
				<div class="kidia-saved-theme-dialog__content">
					<div class="kidia-saved-theme-dialog__phone" data-saved-theme-dialog-phone></div>
					<div>
						<span class="kidia-setup-eyebrow"><?php esc_html_e( 'Theme preview', 'kidia-mobile-cms' ); ?></span>
						<h2 id="kidia-saved-theme-dialog-title" data-saved-theme-dialog-title></h2>
						<p><?php esc_html_e( 'This preview uses the banners, branding and colors saved with this exact theme.', 'kidia-mobile-cms' ); ?></p>
					</div>
				</div>
			</dialog>
		<?php else : ?>
			<div class="kidia-saved-themes__empty">
				<span class="dashicons dashicons-upload" aria-hidden="true"></span>
				<h2><?php esc_html_e( 'Import Theme', 'kidia-mobile-cms' ); ?></h2>
				<p><?php esc_html_e( 'You do not have saved themes yet. Import a WooMobile theme file to start.', 'kidia-mobile-cms' ); ?></p>
				<form method="post" enctype="multipart/form-data" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
					<input type="hidden" name="action" value="kidia_mobile_manage_saved_theme">
					<input type="hidden" name="theme_operation" value="import">
					<?php wp_nonce_field( 'kidia_mobile_manage_saved_theme', 'kidia_mobile_theme_nonce' ); ?>
					<label class="kidia-theme-file"><input type="file" name="theme_file" accept="application/json,.json" required><span class="button"><?php esc_html_e( 'Choose theme file', 'kidia-mobile-cms' ); ?></span><b data-theme-file-name><?php esc_html_e( 'No file selected', 'kidia-mobile-cms' ); ?></b></label>
					<button type="submit" class="button button-primary"><?php esc_html_e( 'Import Theme', 'kidia-mobile-cms' ); ?></button>
				</form>
			</div>
		<?php endif; ?>
	</section>
</div>
