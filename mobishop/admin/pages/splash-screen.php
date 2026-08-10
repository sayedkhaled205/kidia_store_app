<?php defined( 'ABSPATH' ) || exit; ?>
<div class="wrap mobishop-page-builder mobishop-splash-builder">
	<?php if ( isset( $_GET['updated'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Splash Screen saved successfully.', 'mobishop' ); ?></p></div><?php endif; ?>
	<div class="mobishop-page-workspace">
		<aside class="mobishop-page-preview">
			<div class="mobishop-page-phone">
				<div id="mobishop-splash-preview" class="mobishop-page-phone__screen mobishop-splash-preview">
					<div class="mobishop-splash-destination" aria-hidden="true">
						<header><span></span><b></b><span></span></header>
						<i></i>
						<section><b></b><b></b></section>
						<section><b></b><b></b><b></b><b></b></section>
					</div>
					<div class="mobishop-splash-preview__overlay" data-splash-overlay>
						<img alt="">
						<strong></strong>
						<span class="spinner is-active"></span>
						<i class="mobishop-splash-progress" aria-hidden="true"></i>
					</div>
				</div>
			</div>
			<p><?php esc_html_e( 'Live mobile preview', 'mobishop' ); ?></p>
		</aside>
		<form class="mobishop-page-editor" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
			<input type="hidden" name="action" value="mobishop_save_splash_screen"><?php wp_nonce_field( 'mobishop_save_splash_screen', 'mobishop_splash_nonce' ); ?>
			<div class="mobishop-page-toolbar">
				<strong><?php esc_html_e( 'Splash Screen', 'mobishop' ); ?></strong>
				<div class="mobishop-splash-toolbar-actions">
					<button type="button" class="button mobishop-splash-replay" data-splash-replay><span class="dashicons dashicons-controls-repeat"></span><?php esc_html_e( 'Replay preview', 'mobishop' ); ?></button>
					<?php submit_button( __( 'Save Splash Screen', 'mobishop' ), 'primary', 'submit', false ); ?>
				</div>
			</div>
			<div class="mobishop-builder-cards-scroll">
			<section class="mobishop-page-card is-open"><div class="mobishop-page-card__header"><div><span class="dashicons dashicons-format-image"></span><strong><?php esc_html_e( 'Startup Screen', 'mobishop' ); ?></strong></div><label class="mobishop-page-master-toggle"><input type="hidden" name="splash[enabled]" value="0"><input type="checkbox" name="splash[enabled]" value="1" <?php checked( ! empty( $settings['enabled'] ) ); ?>><span><?php esc_html_e( 'Show', 'mobishop' ); ?></span></label><button type="button" class="button mobishop-page-expand" aria-expanded="true"><span class="dashicons dashicons-arrow-down-alt2"></span></button></div>
				<div class="mobishop-page-card__body"><div class="mobishop-page-fields">
					<div class="mobishop-settings-section-title mobishop-settings-section-title--splash-branding"><?php esc_html_e( 'Branding & Image', 'mobishop' ); ?></div>
					<div class="mobishop-page-field mobishop-page-field--image"><label><?php esc_html_e( 'Logo / image', 'mobishop' ); ?></label><div class="mobishop-page-media"><input class="mobishop-page-media-url" type="url" name="splash[image_url]" value="<?php echo esc_attr( $settings['image_url'] ); ?>"><button type="button" class="button mobishop-page-media-choose"><?php esc_html_e( 'Choose image', 'mobishop' ); ?></button></div></div>
					<?php foreach ( array( 'image_width' => 'Image width', 'image_height' => 'Image height' ) as $key => $label ) : ?><div class="mobishop-page-field"><label><?php echo esc_html( $label ); ?></label><input type="number" min="40" max="320" name="splash[<?php echo esc_attr( $key ); ?>]" value="<?php echo esc_attr( (string) $settings[ $key ] ); ?>"></div><?php endforeach; ?>
					<div class="mobishop-page-field"><label><?php esc_html_e( 'Image fit', 'mobishop' ); ?></label><select name="splash[image_fit]"><?php foreach ( array( 'contain' => 'Contain', 'cover' => 'Cover', 'fill' => 'Fill' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $settings['image_fit'], $value ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
					<div class="mobishop-page-field"><label><?php esc_html_e( 'Image shape', 'mobishop' ); ?></label><select name="splash[image_shape]"><?php foreach ( array( 'none' => 'Original', 'rounded' => 'Rounded', 'circle' => 'Circle' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $settings['image_shape'], $value ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
					<div class="mobishop-page-field"><label><?php esc_html_e( 'Store name', 'mobishop' ); ?></label><input type="text" name="splash[store_name]" value="<?php echo esc_attr( $settings['store_name'] ); ?>"></div>
					<div class="mobishop-page-field"><label><?php esc_html_e( 'Show store name', 'mobishop' ); ?></label><label class="mobishop-page-toggle"><input type="hidden" name="splash[show_store_name]" value="0"><input type="checkbox" name="splash[show_store_name]" value="1" <?php checked( ! empty( $settings['show_store_name'] ) ); ?>><b><?php esc_html_e( 'Show', 'mobishop' ); ?></b></label></div>
					<div class="mobishop-page-field"><label><?php esc_html_e( 'Text color', 'mobishop' ); ?></label><input type="color" name="splash[text_color]" value="<?php echo esc_attr( $settings['text_color'] ); ?>"></div>
					<div class="mobishop-settings-section-title mobishop-settings-section-title--splash-background"><?php esc_html_e( 'Background, Timing & Loader', 'mobishop' ); ?></div>
					<?php foreach ( array( 'background_color' => 'Background color', 'background_color_end' => 'Gradient color' ) as $key => $label ) : ?><div class="mobishop-page-field"><label><?php echo esc_html( $label ); ?></label><input type="color" name="splash[<?php echo esc_attr( $key ); ?>]" value="<?php echo esc_attr( $settings[ $key ] ); ?>"></div><?php endforeach; ?>
					<div class="mobishop-page-field"><label><?php esc_html_e( 'Duration (milliseconds)', 'mobishop' ); ?></label><input type="number" min="500" max="10000" step="100" name="splash[duration_ms]" value="<?php echo esc_attr( (string) $settings['duration_ms'] ); ?>"></div>
					<div class="mobishop-page-field"><label><?php esc_html_e( 'Show loader', 'mobishop' ); ?></label><label class="mobishop-page-toggle"><input type="hidden" name="splash[show_loader]" value="0"><input type="checkbox" name="splash[show_loader]" value="1" <?php checked( ! empty( $settings['show_loader'] ) ); ?>><b><?php esc_html_e( 'Show', 'mobishop' ); ?></b></label></div>
					<div class="mobishop-page-field"><label><?php esc_html_e( 'Loader color', 'mobishop' ); ?></label><input type="color" name="splash[loader_color]" value="<?php echo esc_attr( $settings['loader_color'] ); ?>"></div>
				</div></div>
			</section>
			</div>
		</form>
	</div>
</div>
