<?php
/** Drag-and-drop application header/footer editor shared by every page builder. */
defined( 'ABSPATH' ) || exit;

$chrome_component = is_array( $chrome_layout[ $chrome_part ] ?? null ) ? $chrome_layout[ $chrome_part ] : array();
$chrome_settings  = is_array( $chrome_component['settings'] ?? null ) ? $chrome_component['settings'] : array();
$chrome_fields    = 'header' === $chrome_part ? $header_fields : $footer_fields;
$chrome_title     = 'header' === $chrome_part ? __( 'Fixed Header', 'mobishop' ) : __( 'Fixed Footer', 'mobishop' );
$chrome_prefix    = isset( $chrome_name_prefix ) ? (string) $chrome_name_prefix : 'layout[' . $chrome_part . ']';
$chrome_page_name = isset( $chrome_page ) ? (string) $chrome_page : ( isset( $page ) ? (string) $page : '' );
$chrome_items     = array( 'logo' => 'Logo', 'title' => 'Title', 'search' => 'Search icon', 'search_bar' => 'Search bar', 'back' => 'Back', 'cart' => 'Cart', 'wishlist' => 'Wishlist', 'account' => 'Account', 'orders' => 'Orders', 'support' => 'Customer support', 'menu' => 'Menu' );
if ( 'footer' === $chrome_part ) {
	$chrome_items = array( 'home' => 'Home', 'categories' => 'Categories', 'search' => 'Search', 'cart' => 'Cart', 'wishlist' => 'Wishlist', 'account' => 'Account', 'orders' => 'Orders', 'share' => 'Share', 'like' => 'Like', 'add_to_cart' => 'Add to bag' );
}
$collapsed_header_keys = array( 'collapse_on_scroll', 'collapse_transition', 'compact_search_width_percent', 'collapse_speed', 'compact_height', 'compact_style', 'compact_background_color', 'compact_horizontal_padding', 'compact_side_margin', 'compact_radius', 'compact_border_width', 'compact_border_color', 'compact_shadow' );
$section_layout_groups = array(
	array( 'margin_top', 'margin_bottom' ),
	array( 'space_up', 'space_down' ),
	array( 'background_color' ),
);
$section_layout_keys = array_merge( ...$section_layout_groups );
$item_field = static function ( string $part, string $key ): string {
	if ( 'header' === $part ) {
		if ( 'show_cart_badge' === $key ) { return 'cart'; }
		if ( 0 === strpos( $key, 'logo_' ) || 'logo_url' === $key ) { return 'logo'; }
		if ( 'title' === $key || 0 === strpos( $key, 'title_' ) ) { return 'title'; }
		if ( 'subtitle' === $key ) { return 'logo'; }
		if ( 0 === strpos( $key, 'search_' ) || 'show_voice_search' === $key ) { return false !== strpos( $key, 'search_icon' ) ? 'search' : 'search_bar'; }
		foreach ( array( 'back', 'cart', 'wishlist', 'account', 'orders', 'support', 'menu' ) as $item ) { if ( 0 === strpos( $key, $item . '_' ) ) { return $item; } }
	} else {
		foreach ( array( 'home', 'categories', 'search', 'cart', 'wishlist', 'account', 'orders', 'share', 'like' ) as $item ) { if ( 0 === strpos( $key, $item . '_' ) ) { return $item; } }
		if ( 0 === strpos( $key, 'button_' ) || 0 === strpos( $key, 'add_to_cart_' ) || in_array( $key, array( 'show_price', 'show_quantity' ), true ) ) { return 'add_to_cart'; }
	}
	return 'general';
};
$is_placement_toggle = static function ( string $part, string $key ) use ( $chrome_items ): bool {
	if ( 'show_account_label' === $key ) {
		return true;
	}
	if ( 0 !== strpos( $key, 'show_' ) ) {
		return false;
	}
	return isset( $chrome_items[ substr( $key, 5 ) ] );
};
$is_redundant_ui_field = static function ( string $part, string $key ): bool {
	return ( 'header' === $part && 'search_style' === $key )
		|| ( 'header' === $part && in_array( $key, array( 'icon_size', 'icon_color' ), true ) )
		|| ( 'footer' === $part && in_array( $key, array( 'share_icon_size', 'like_icon_size' ), true ) );
};
$render_chrome_field = static function ( array $field, $value, string $name ): void {
	?><div class="mobishop-page-field<?php echo 'image' === $field['type'] ? ' mobishop-page-field--image' : ''; ?>" data-setting="<?php echo esc_attr( $field['key'] ); ?>"><label><?php echo esc_html( $field['label'] ); ?></label><?php
	if ( 'checkbox' === $field['type'] ) { ?><label class="mobishop-page-toggle"><input type="hidden" name="<?php echo esc_attr( $name ); ?>" value="0"><input type="checkbox" name="<?php echo esc_attr( $name ); ?>" value="1" <?php checked( ! empty( $value ) ); ?>><b><?php esc_html_e( 'Show', 'mobishop' ); ?></b></label><?php }
	elseif ( 'select' === $field['type'] ) { ?><select name="<?php echo esc_attr( $name ); ?>"><?php foreach ( $field['options'] as $option => $label ) { ?><option value="<?php echo esc_attr( $option ); ?>" <?php selected( (string) $value, (string) $option ); ?>><?php echo esc_html( $label ); ?></option><?php } ?></select><?php }
	elseif ( 'color' === $field['type'] ) { ?><input type="color" name="<?php echo esc_attr( $name ); ?>" value="<?php echo esc_attr( sanitize_hex_color( (string) $value ) ?: (string) $field['default'] ); ?>"><?php }
	elseif ( 'number' === $field['type'] ) { ?><input type="number" name="<?php echo esc_attr( $name ); ?>" min="<?php echo esc_attr( (string) $field['min'] ); ?>" max="<?php echo esc_attr( (string) $field['max'] ); ?>" step="<?php echo esc_attr( (string) $field['step'] ); ?>" value="<?php echo esc_attr( (string) $value ); ?>"><?php }
	elseif ( 'image' === $field['type'] ) { ?><div class="mobishop-page-media"><div class="mobishop-page-media-actions"><button type="button" class="button mobishop-page-media-choose"><?php esc_html_e( 'Choose image', 'mobishop' ); ?></button></div><input class="mobishop-page-media-url" type="url" name="<?php echo esc_attr( $name ); ?>" value="<?php echo esc_attr( (string) $value ); ?>"></div><img class="mobishop-page-media-preview" src="<?php echo esc_url( (string) $value ); ?>" alt="" <?php echo empty( $value ) ? 'hidden' : ''; ?>><?php }
	else { ?><div class="mobishop-page-text-control"><input type="text" name="<?php echo esc_attr( $name ); ?>" value="<?php echo esc_attr( (string) $value ); ?>"></div><?php }
	?></div><?php
};
$footer_icon_symbols = array(
	'back'       => array( 'arrow' => 'f572', 'chevron' => 'f63a', 'rounded' => 'f82f' ),
	'home'       => array( 'home' => 'f107', 'rounded' => 'f244', 'filled' => 'f7f5' ),
	'categories' => array( 'grid' => 'f0d7', 'category' => 'ef37', 'list' => 'f498' ),
	'search'     => array( 'rounded' => 'f013d', 'classic' => 'e567', 'minimal' => 'f1ad' ),
	'cart'       => array( 'bag' => 'f37d', 'cart' => 'f37f', 'basket' => 'f37e' ),
	'wishlist'   => array( 'heart' => 'f737', 'rounded' => 'f738', 'bookmark' => 'e0f4' ),
	'account'    => array( 'person' => 'f006c', 'circle' => 'ee35', 'profile' => 'f1ac' ),
	'orders'     => array( 'receipt' => 'f2ef', 'box' => 'f134', 'list' => 'f792' ),
	'share'      => array( 'upload' => 'f138', 'share' => 'f378', 'send' => 'f355' ),
	'like'       => array( 'heart' => 'f737', 'rounded' => 'f738', 'bookmark' => 'e0f4' ),
	'support'    => array( 'headset' => 'f0ee', 'support' => 'f01f5', 'chat' => 'f62f' ),
	'menu'       => array( 'menu' => 'f8b6', 'dots' => 'f8d9', 'grid' => 'f7c4' ),
);
?>
<section class="mobishop-fixed-chrome-card mobishop-page-card mobishop-page-card--locked" data-element="<?php echo esc_attr( $chrome_part ); ?>" data-chrome-part="<?php echo esc_attr( $chrome_part ); ?>" data-page="<?php echo esc_attr( $chrome_page_name ); ?>">
	<div class="mobishop-page-card__header">
		<div class="mobishop-fixed-chrome-identity"><span class="dashicons dashicons-lock"></span><strong><?php echo esc_html( $chrome_title ); ?></strong></div>
		<div class="mobishop-card-actions">
			<?php /* translators: Placeholder values are supplied at runtime. */ ?>
			<div class="mobishop-chrome-transfer-actions" aria-label="<?php echo esc_attr( sprintf( __( '%s settings transfer', 'mobishop' ), $chrome_title ) ); ?>">
				<button type="button" class="button mobishop-chrome-copy mobishop-card-action mobishop-card-action--primary" data-chrome-copy><span class="dashicons dashicons-admin-page" aria-hidden="true"></span><?php esc_html_e( 'Copy', 'mobishop' ); ?></button>
				<button type="button" class="button mobishop-chrome-paste mobishop-card-action mobishop-card-action--secondary" data-chrome-paste><span class="dashicons dashicons-clipboard" aria-hidden="true"></span><?php esc_html_e( 'Paste', 'mobishop' ); ?></button>
				<span class="mobishop-chrome-transfer-status" role="status" aria-live="polite"></span>
			</div>
			<button type="button" class="button mobishop-fixed-chrome-expand mobishop-page-expand mobishop-card-action mobishop-card-action--expand" aria-expanded="false"><span class="dashicons dashicons-arrow-down-alt2"></span></button>
			<label class="mobishop-builder-switch mobishop-builder-switch--card mobishop-card-action mobishop-card-action--toggle"><input type="hidden" name="<?php echo esc_attr( $chrome_prefix ); ?>[enabled]" value="0"><input type="checkbox" name="<?php echo esc_attr( $chrome_prefix ); ?>[enabled]" value="1" <?php checked( ! empty( $chrome_component['enabled'] ) ); ?>><span class="mobishop-builder-switch__track"></span><span class="mobishop-builder-switch__state"></span></label>
		</div>
	</div>
	<div class="mobishop-page-card__body" hidden>
		<div class="mobishop-chrome-composer" data-part="<?php echo esc_attr( $chrome_part ); ?>" data-page="<?php echo esc_attr( $chrome_page_name ); ?>">
			<?php if ( 'header' === $chrome_part ) : ?><div class="mobishop-chrome-composer__heading"><h3><?php esc_html_e( 'Regular header', 'mobishop' ); ?></h3></div><?php endif; ?>
			<?php if ( 'header' === $chrome_part ) : ?>
			<section class="mobishop-header-presets" aria-labelledby="mobishop-header-presets-title">
				<div class="mobishop-header-presets__heading">
					<strong id="mobishop-header-presets-title"><?php esc_html_e( 'Quick header presets', 'mobishop' ); ?></strong>
					<span><?php esc_html_e( 'Choose a popular layout, then customize it below.', 'mobishop' ); ?></span>
				</div>
				<div class="mobishop-header-presets__grid">
					<?php
					$header_presets = array(
						'standard' => array( 'Standard store', 'Logo, search and cart', array( array( array( 'logo' ), array( 'search' ), array( 'wishlist', 'cart' ) ) ) ),
						'search'   => array( 'Search first', 'Full-width product search', array( array( array( 'logo' ), array( 'cart' ) ), array( array( 'search_bar' ) ) ) ),
						'centered' => array( 'Centered brand', 'Menu, centered logo and cart', array( array( array( 'menu' ), array( 'logo' ), array( 'cart' ) ) ) ),
						'page'     => array( 'Page title', 'Back, centered title and cart', array( array( array( 'back' ), array( 'title' ), array( 'cart' ) ) ) ),
						'actions'  => array( 'Action rich', 'Menu, search, account and cart', array( array( array( 'menu', 'search' ), array( 'logo' ), array( 'account', 'cart' ) ) ) ),
					);
					foreach ( $header_presets as $preset_key => $preset_copy ) :
						?>
						<button type="button" class="mobishop-header-preset" data-header-preset="<?php echo esc_attr( $preset_key ); ?>" aria-pressed="false">
							<span class="mobishop-header-preset__preview mobishop-header-preset__preview--<?php echo esc_attr( $preset_key ); ?>" aria-hidden="true">
								<?php foreach ( $preset_copy[2] as $preview_row ) : ?>
									<span class="mobishop-header-preset__row">
										<?php foreach ( $preview_row as $preview_column ) : ?>
											<span class="mobishop-header-preset__column">
												<?php foreach ( $preview_column as $preview_item ) : ?><i class="mobishop-header-preset__item mobishop-header-preset__item--<?php echo esc_attr( $preview_item ); ?>"></i><?php endforeach; ?>
											</span>
										<?php endforeach; ?>
									</span>
								<?php endforeach; ?>
							</span>
							<strong><?php echo esc_html( $preset_copy[0] ); ?></strong>
							<small><?php echo esc_html( $preset_copy[1] ); ?></small>
						</button>
					<?php endforeach; ?>
				</div>
			</section>
			<?php endif; ?>
			<input type="hidden" class="mobishop-chrome-layout-json" name="<?php echo esc_attr( $chrome_prefix ); ?>[settings][layout_json]" value="<?php echo esc_attr( (string) ( $chrome_settings['layout_json'] ?? '' ) ); ?>">
			<div class="mobishop-chrome-layout" aria-label="<?php echo esc_attr( $chrome_title ); ?>"></div>
			<div class="mobishop-chrome-palette"><strong><?php esc_html_e( 'Available items — drop here to remove', 'mobishop' ); ?></strong><div class="mobishop-chrome-palette__items"><?php foreach ( $chrome_items as $item => $label ) : ?><button type="button" draggable="true" class="mobishop-chrome-item" data-item="<?php echo esc_attr( $item ); ?>"><span class="dashicons dashicons-move"></span><?php echo esc_html( $label ); ?></button><?php endforeach; ?></div></div>
			<button type="button" class="button mobishop-chrome-reset"><?php esc_html_e( 'Restore page default', 'mobishop' ); ?></button>
		</div>
		<?php if ( 'header' === $chrome_part ) : ?>
		<div class="mobishop-chrome-composer mobishop-chrome-composer--collapsed" data-part="header" data-page="<?php echo esc_attr( $chrome_page_name ); ?>" data-variant="collapsed">
			<div class="mobishop-chrome-composer__heading">
				<div><h3><?php esc_html_e( 'Collapsed header shown on scroll', 'mobishop' ); ?></h3><p><?php esc_html_e( 'Add, remove and arrange rows and items independently from the fixed header.', 'mobishop' ); ?></p></div>
				<label class="mobishop-page-master-toggle mobishop-collapsed-header-toggle" aria-label="<?php esc_attr_e( 'Turn collapsed header on or off', 'mobishop' ); ?>"><input type="hidden" name="<?php echo esc_attr( $chrome_prefix ); ?>[settings][collapse_on_scroll]" value="0"><input type="checkbox" class="mobishop-collapsed-header-enabled" name="<?php echo esc_attr( $chrome_prefix ); ?>[settings][collapse_on_scroll]" value="1" <?php checked( ! empty( $chrome_settings['collapse_on_scroll'] ) ); ?>><span class="mobishop-toggle-state"></span></label>
			</div>
			<input type="hidden" class="mobishop-chrome-layout-json" name="<?php echo esc_attr( $chrome_prefix ); ?>[settings][compact_layout_json]" value="<?php echo esc_attr( (string) ( $chrome_settings['compact_layout_json'] ?? '' ) ); ?>">
			<div class="mobishop-chrome-layout" aria-label="<?php esc_attr_e( 'Collapsed header layout', 'mobishop' ); ?>"></div>
			<div class="mobishop-chrome-palette"><strong><?php esc_html_e( 'Available items — drop here to remove', 'mobishop' ); ?></strong><div class="mobishop-chrome-palette__items"><?php foreach ( $chrome_items as $item => $label ) : ?><button type="button" draggable="true" class="mobishop-chrome-item" data-item="<?php echo esc_attr( $item ); ?>"><span class="dashicons dashicons-move"></span><?php echo esc_html( $label ); ?></button><?php endforeach; ?></div></div>
			<button type="button" class="button mobishop-chrome-reset"><?php esc_html_e( 'Restore collapsed default', 'mobishop' ); ?></button>
		</div>
		<section class="mobishop-chrome-setting mobishop-collapsed-header-settings">
			<div class="mobishop-page-fields"><?php foreach ( $chrome_fields as $field ) { if ( ! in_array( $field['key'], array( 'collapse_on_scroll', 'compact_search_width_percent' ), true ) && in_array( $field['key'], $collapsed_header_keys, true ) ) { $render_chrome_field( $field, $chrome_settings[ $field['key'] ] ?? $field['default'], $chrome_prefix . '[settings][' . $field['key'] . ']' ); } } ?></div>
		</section>
		<?php endif; ?>
		<div class="mobishop-chrome-settings">
		<?php $footer_icon_group_open = 'footer' === $chrome_part; ?>
		<?php if ( $footer_icon_group_open ) : ?><section class="mobishop-chrome-setting mobishop-footer-icons-setting"><h3><?php esc_html_e( 'Footer Icons', 'mobishop' ); ?></h3><div class="mobishop-footer-icons-setting__items"><?php endif; ?>
		<?php foreach ( $chrome_items as $item => $label ) :
			if ( $footer_icon_group_open && 'add_to_cart' === $item ) {
				echo '</div></section>';
				$footer_icon_group_open = false;
			}
			$variant_key   = $item . '_icon_variant';
			$variant_field = null;
			foreach ( $chrome_fields as $candidate ) { if ( $candidate['key'] === $variant_key ) { $variant_field = $candidate; break; } }
			$item_fields = array_values( array_filter( $chrome_fields, static function ( array $field ) use ( $item_field, $is_placement_toggle, $is_redundant_ui_field, $chrome_part, $item, $variant_key ): bool {
				return $field['key'] !== $variant_key && ! $is_placement_toggle( $chrome_part, $field['key'] ) && ! $is_redundant_ui_field( $chrome_part, $field['key'] ) && $item_field( $chrome_part, $field['key'] ) === $item;
			} ) );
			if ( 'header' === $chrome_part && 'logo' === $item ) {
				$logo_order = array( 'logo_url' => 0, 'subtitle' => 2, 'logo_text' => 3, 'logo_width' => 4, 'logo_height' => 5, 'logo_text_color' => 6 );
				usort( $item_fields, static function ( array $left, array $right ) use ( $logo_order ): int { return ( $logo_order[ $left['key'] ] ?? 99 ) <=> ( $logo_order[ $right['key'] ] ?? 99 ); } );
			}
			if ( ! $variant_field && ! $item_fields ) { continue; }
			?>
			<<?php echo 'footer' === $chrome_part && 'add_to_cart' !== $item ? 'div' : 'section'; ?> class="mobishop-chrome-item-setting mobishop-chrome-item-setting--<?php echo esc_attr( $item ); ?> <?php echo 'header' === $chrome_part && 'cart' === $item ? 'mobishop-chrome-item-setting--header-cart' : ''; ?>" data-item-section="<?php echo esc_attr( $item ); ?>" hidden>
				<?php /* translators: Placeholder values are supplied at runtime. */ ?>
				<<?php echo 'footer' === $chrome_part && 'add_to_cart' !== $item ? 'h4' : 'h3'; ?>><?php echo esc_html( sprintf( __( '%s Settings', 'mobishop' ), $label ) ); ?></<?php echo 'footer' === $chrome_part && 'add_to_cart' !== $item ? 'h4' : 'h3'; ?>>
				<?php if ( $variant_field ) : $selected_variant = (string) ( $chrome_settings[ $variant_key ] ?? $variant_field['default'] ); $symbols = $footer_icon_symbols[ $item ] ?? array(); ?>
					<div class="mobishop-chrome-icon-choice"><strong><?php esc_html_e( 'Icon shape', 'mobishop' ); ?></strong><div class="mobishop-chrome-icon-options" role="radiogroup" aria-label="<?php echo esc_attr( $label ); ?>"><?php foreach ( $variant_field['options'] as $option => $option_label ) : $codepoint = preg_match( '/^[0-9a-f]+$/i', (string) ( $symbols[ $option ] ?? '' ) ) ? (string) $symbols[ $option ] : 'ef53'; ?><button type="button" class="mobishop-chrome-icon-option <?php echo $selected_variant === (string) $option ? 'is-selected' : ''; ?>" data-icon-value="<?php echo esc_attr( $option ); ?>" title="<?php echo esc_attr( $option_label ); ?>" aria-pressed="<?php echo $selected_variant === (string) $option ? 'true' : 'false'; ?>"><span class="mobishop-material-icon-choice" aria-hidden="true"><?php echo '&#x' . esc_html( $codepoint ) . ';'; ?></span></button><?php endforeach; ?></div><select class="mobishop-chrome-icon-select screen-reader-text" name="<?php echo esc_attr( $chrome_prefix . '[settings][' . $variant_key . ']' ); ?>"><?php foreach ( $variant_field['options'] as $option => $option_label ) : ?><option value="<?php echo esc_attr( $option ); ?>" <?php selected( $selected_variant, (string) $option ); ?>><?php echo esc_html( $option_label ); ?></option><?php endforeach; ?></select></div>
				<?php endif; ?>
				<div class="mobishop-page-fields"><?php foreach ( $item_fields as $field ) { $render_chrome_field( $field, $chrome_settings[ $field['key'] ] ?? $field['default'], $chrome_prefix . '[settings][' . $field['key'] . ']' ); if ( 'header' === $chrome_part && 'logo' === $item && 'logo_url' === $field['key'] ) : ?><div class="mobishop-page-field mobishop-page-field--logo-source" data-setting="logo_source"><label><?php esc_html_e( 'Logo source', 'mobishop' ); ?></label><div class="mobishop-page-text-control"><button type="button" class="button mobishop-page-media-clear"><?php esc_html_e( 'Use logo text', 'mobishop' ); ?></button></div></div><?php endif; } ?></div>
			</<?php echo 'footer' === $chrome_part && 'add_to_cart' !== $item ? 'div' : 'section'; ?>>
		<?php endforeach; ?>
		<?php if ( $footer_icon_group_open ) : ?></div></section><?php endif; ?>
		<section class="mobishop-chrome-setting mobishop-chrome-setting--general <?php echo 'footer' === $chrome_part ? 'mobishop-chrome-footer-general' : ''; ?>"><h3><?php esc_html_e( 'General Settings', 'mobishop' ); ?></h3><div class="mobishop-page-fields"><?php foreach ( $chrome_fields as $field ) { $key = $field['key']; if ( ! in_array( $key, array_merge( array( 'layout_json', 'compact_layout_json' ), $collapsed_header_keys, $section_layout_keys ), true ) && ! $is_placement_toggle( $chrome_part, $key ) && ! $is_redundant_ui_field( $chrome_part, $key ) && 'general' === $item_field( $chrome_part, $key ) ) { $render_chrome_field( $field, $chrome_settings[ $key ] ?? $field['default'], $chrome_prefix . '[settings][' . $key . ']' ); } } ?></div></section>
		<section class="mobishop-chrome-setting mobishop-chrome-setting--section-layout mobishop-section-layout-panel"><div class="mobishop-settings-section-title mobishop-settings-section-title--section_layout"><?php esc_html_e( 'Section Layout Settings', 'mobishop' ); ?></div><div class="mobishop-section-layout-grid">
			<?php foreach ( $section_layout_groups as $group_index => $group_keys ) : ?><div class="mobishop-section-layout-column mobishop-section-layout-column--<?php echo esc_attr( array( 'merge', 'space', 'background' )[ $group_index ] ); ?>">
				<?php foreach ( $group_keys as $layout_key ) { foreach ( $chrome_fields as $field ) { if ( $field['key'] === $layout_key ) { $render_chrome_field( $field, $chrome_settings[ $layout_key ] ?? $field['default'], $chrome_prefix . '[settings][' . $layout_key . ']' ); break; } } } ?>
			</div><?php endforeach; ?>
		</div></section>
		</div>
	</div>
</section>
