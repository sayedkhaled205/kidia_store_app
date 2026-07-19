<?php
/** Drag-and-drop application header/footer editor shared by every page builder. */
defined( 'ABSPATH' ) || exit;

$chrome_component = is_array( $chrome_layout[ $chrome_part ] ?? null ) ? $chrome_layout[ $chrome_part ] : array();
$chrome_settings  = is_array( $chrome_component['settings'] ?? null ) ? $chrome_component['settings'] : array();
$chrome_fields    = 'header' === $chrome_part ? $header_fields : $footer_fields;
$chrome_title     = 'header' === $chrome_part ? __( 'Fixed Header', 'kidia-mobile-cms' ) : __( 'Fixed Footer', 'kidia-mobile-cms' );
$chrome_prefix    = isset( $chrome_name_prefix ) ? (string) $chrome_name_prefix : 'layout[' . $chrome_part . ']';
$chrome_page_name = isset( $chrome_page ) ? (string) $chrome_page : ( isset( $page ) ? (string) $page : '' );
$chrome_items     = 'header' === $chrome_part
	? array( 'logo' => 'Logo', 'title' => 'Title', 'subtitle' => 'Subtitle', 'search' => 'Search icon', 'search_bar' => 'Search bar', 'back' => 'Back', 'cart' => 'Cart', 'wishlist' => 'Wishlist', 'account' => 'Account', 'orders' => 'Orders', 'support' => 'Customer support', 'menu' => 'Menu' )
	: array( 'home' => 'Home', 'categories' => 'Categories', 'search' => 'Search', 'cart' => 'Cart', 'wishlist' => 'Wishlist', 'account' => 'Account', 'orders' => 'Orders', 'share' => 'Share', 'like' => 'Like', 'add_to_cart' => 'Add to bag' );
$item_field = static function ( string $part, string $key ): string {
	if ( 'header' === $part ) {
		if ( 'show_cart_badge' === $key ) { return 'cart'; }
		if ( 0 === strpos( $key, 'logo_' ) || 'logo_url' === $key ) { return 'logo'; }
		if ( 'title' === $key || 'title_color' === $key ) { return 'title'; }
		if ( 'subtitle' === $key ) { return 'subtitle'; }
		if ( 0 === strpos( $key, 'search_' ) || 'show_voice_search' === $key ) { return false !== strpos( $key, 'search_icon' ) ? 'search' : 'search_bar'; }
		foreach ( array( 'back', 'cart', 'wishlist', 'account', 'orders', 'support', 'menu' ) as $item ) { if ( 0 === strpos( $key, $item . '_' ) ) { return $item; } }
	} else {
		foreach ( array( 'home', 'categories', 'search', 'cart', 'wishlist', 'account', 'orders', 'share', 'like' ) as $item ) { if ( 0 === strpos( $key, $item . '_' ) ) { return $item; } }
		if ( 0 === strpos( $key, 'button_' ) || 0 === strpos( $key, 'add_to_cart_' ) || in_array( $key, array( 'show_price', 'show_quantity' ), true ) ) { return 'add_to_cart'; }
	}
	return 'general';
};
$render_chrome_field = static function ( array $field, $value, string $name ): void {
	?><div class="kidia-page-field" data-setting="<?php echo esc_attr( $field['key'] ); ?>"><label><?php echo esc_html( $field['label'] ); ?></label><?php
	if ( 'checkbox' === $field['type'] ) { ?><label class="kidia-page-toggle"><input type="hidden" name="<?php echo esc_attr( $name ); ?>" value="0"><input type="checkbox" name="<?php echo esc_attr( $name ); ?>" value="1" <?php checked( ! empty( $value ) ); ?>><b><?php esc_html_e( 'Show', 'kidia-mobile-cms' ); ?></b></label><?php }
	elseif ( 'select' === $field['type'] ) { ?><select name="<?php echo esc_attr( $name ); ?>"><?php foreach ( $field['options'] as $option => $label ) { ?><option value="<?php echo esc_attr( $option ); ?>" <?php selected( (string) $value, (string) $option ); ?>><?php echo esc_html( $label ); ?></option><?php } ?></select><?php }
	elseif ( 'color' === $field['type'] ) { ?><input type="color" name="<?php echo esc_attr( $name ); ?>" value="<?php echo esc_attr( sanitize_hex_color( (string) $value ) ?: (string) $field['default'] ); ?>"><?php }
	elseif ( 'number' === $field['type'] ) { ?><input type="number" name="<?php echo esc_attr( $name ); ?>" min="<?php echo esc_attr( (string) $field['min'] ); ?>" max="<?php echo esc_attr( (string) $field['max'] ); ?>" step="<?php echo esc_attr( (string) $field['step'] ); ?>" value="<?php echo esc_attr( (string) $value ); ?>"><?php }
	elseif ( 'image' === $field['type'] ) { ?><div class="kidia-page-media"><input class="kidia-page-media-url" type="url" name="<?php echo esc_attr( $name ); ?>" value="<?php echo esc_attr( (string) $value ); ?>"><button type="button" class="button kidia-page-media-choose"><?php esc_html_e( 'Choose image', 'kidia-mobile-cms' ); ?></button></div><?php }
	else { ?><input type="text" name="<?php echo esc_attr( $name ); ?>" value="<?php echo esc_attr( (string) $value ); ?>"><?php }
	?></div><?php
};
$footer_icon_symbols = array(
	'back'       => array( 'arrow' => 'dashicons-arrow-left-alt', 'chevron' => 'dashicons-arrow-left-alt2', 'rounded' => 'dashicons-undo' ),
	'home'       => array( 'home' => 'dashicons-admin-home', 'rounded' => 'dashicons-building', 'filled' => 'dashicons-store' ),
	'categories' => array( 'grid' => 'dashicons-grid-view', 'category' => 'dashicons-screenoptions', 'list' => 'dashicons-list-view' ),
	'search'     => array( 'rounded' => 'dashicons-search', 'classic' => 'dashicons-search', 'minimal' => 'dashicons-visibility' ),
	'cart'       => array( 'bag' => 'dashicons-products', 'cart' => 'dashicons-cart', 'basket' => 'dashicons-buddicons-groups' ),
	'wishlist'   => array( 'heart' => 'dashicons-heart', 'rounded' => 'dashicons-heart', 'bookmark' => 'dashicons-bookmark' ),
	'account'    => array( 'person' => 'dashicons-admin-users', 'circle' => 'dashicons-admin-users', 'profile' => 'dashicons-id' ),
	'orders'     => array( 'receipt' => 'dashicons-media-text', 'box' => 'dashicons-archive', 'list' => 'dashicons-list-view' ),
	'share'      => array( 'upload' => 'dashicons-upload', 'share' => 'dashicons-share', 'send' => 'dashicons-email-alt' ),
	'like'       => array( 'heart' => 'dashicons-heart', 'rounded' => 'dashicons-heart', 'bookmark' => 'dashicons-bookmark' ),
	'support'    => array( 'headset' => 'dashicons-phone', 'support' => 'dashicons-businessperson', 'chat' => 'dashicons-format-chat' ),
	'menu'       => array( 'menu' => 'dashicons-menu', 'dots' => 'dashicons-ellipsis', 'grid' => 'dashicons-grid-view' ),
);
?>
<section class="kidia-fixed-chrome-card kidia-page-card kidia-page-card--locked" data-element="<?php echo esc_attr( $chrome_part ); ?>" data-chrome-part="<?php echo esc_attr( $chrome_part ); ?>">
	<div class="kidia-page-card__header">
		<div><span class="dashicons dashicons-lock"></span><strong><?php echo esc_html( $chrome_title ); ?></strong><small><?php esc_html_e( 'Fixed position · arrange the visible items below', 'kidia-mobile-cms' ); ?></small></div>
		<label class="kidia-page-master-toggle"><input type="hidden" name="<?php echo esc_attr( $chrome_prefix ); ?>[enabled]" value="0"><input type="checkbox" name="<?php echo esc_attr( $chrome_prefix ); ?>[enabled]" value="1" <?php checked( ! empty( $chrome_component['enabled'] ) ); ?>><span><?php esc_html_e( 'Show', 'kidia-mobile-cms' ); ?></span></label>
		<button type="button" class="button kidia-fixed-chrome-expand kidia-page-expand" aria-expanded="false"><span class="dashicons dashicons-arrow-down-alt2"></span></button>
	</div>
	<div class="kidia-page-card__body" hidden>
		<div class="kidia-chrome-composer" data-part="<?php echo esc_attr( $chrome_part ); ?>" data-page="<?php echo esc_attr( $chrome_page_name ); ?>">
			<input type="hidden" class="kidia-chrome-layout-json" name="<?php echo esc_attr( $chrome_prefix ); ?>[settings][layout_json]" value="<?php echo esc_attr( (string) ( $chrome_settings['layout_json'] ?? '' ) ); ?>">
			<div class="kidia-chrome-layout" aria-label="<?php echo esc_attr( $chrome_title ); ?>"></div>
			<div class="kidia-chrome-palette"><strong><?php esc_html_e( 'Available items', 'kidia-mobile-cms' ); ?></strong><div class="kidia-chrome-palette__items"><?php foreach ( $chrome_items as $item => $label ) : ?><button type="button" draggable="true" class="kidia-chrome-item" data-item="<?php echo esc_attr( $item ); ?>"><span class="dashicons dashicons-move"></span><?php echo esc_html( $label ); ?></button><?php endforeach; ?></div></div>
			<button type="button" class="button kidia-chrome-reset"><?php esc_html_e( 'Restore page default', 'kidia-mobile-cms' ); ?></button>
		</div>
		<div class="kidia-chrome-settings">
		<?php foreach ( $chrome_items as $item => $label ) :
			$variant_key   = $item . '_icon_variant';
			$variant_field = null;
			foreach ( $chrome_fields as $candidate ) { if ( $candidate['key'] === $variant_key ) { $variant_field = $candidate; break; } }
			$item_fields = array_values( array_filter( $chrome_fields, static function ( array $field ) use ( $item_field, $chrome_part, $item, $variant_key ): bool {
				return $field['key'] !== $variant_key && $item_field( $chrome_part, $field['key'] ) === $item;
			} ) );
			if ( ! $variant_field && ! $item_fields ) { continue; }
			?>
			<section class="kidia-chrome-item-setting" data-item-section="<?php echo esc_attr( $item ); ?>" hidden>
				<h3><?php echo esc_html( sprintf( __( '%s Settings', 'kidia-mobile-cms' ), $label ) ); ?></h3>
				<?php if ( $variant_field ) : $selected_variant = (string) ( $chrome_settings[ $variant_key ] ?? $variant_field['default'] ); $symbols = $footer_icon_symbols[ $item ] ?? array(); ?>
					<div class="kidia-chrome-icon-choice"><strong><?php esc_html_e( 'Icon shape', 'kidia-mobile-cms' ); ?></strong><div class="kidia-chrome-icon-options" role="radiogroup" aria-label="<?php echo esc_attr( $label ); ?>"><?php foreach ( $variant_field['options'] as $option => $option_label ) : ?><button type="button" class="kidia-chrome-icon-option <?php echo $selected_variant === (string) $option ? 'is-selected' : ''; ?>" data-icon-value="<?php echo esc_attr( $option ); ?>" title="<?php echo esc_attr( $option_label ); ?>" aria-pressed="<?php echo $selected_variant === (string) $option ? 'true' : 'false'; ?>"><span class="dashicons <?php echo esc_attr( $symbols[ $option ] ?? 'dashicons-marker' ); ?>"></span></button><?php endforeach; ?></div><select class="kidia-chrome-icon-select screen-reader-text" name="<?php echo esc_attr( $chrome_prefix . '[settings][' . $variant_key . ']' ); ?>"><?php foreach ( $variant_field['options'] as $option => $option_label ) : ?><option value="<?php echo esc_attr( $option ); ?>" <?php selected( $selected_variant, (string) $option ); ?>><?php echo esc_html( $option_label ); ?></option><?php endforeach; ?></select></div>
				<?php endif; ?>
				<div class="kidia-page-fields"><?php foreach ( $item_fields as $field ) { $render_chrome_field( $field, $chrome_settings[ $field['key'] ] ?? $field['default'], $chrome_prefix . '[settings][' . $field['key'] . ']' ); } ?></div>
			</section>
		<?php endforeach; ?>
		<section class="kidia-chrome-setting kidia-chrome-setting--general <?php echo 'footer' === $chrome_part ? 'kidia-chrome-footer-general' : ''; ?>"><h3><?php esc_html_e( 'General Settings', 'kidia-mobile-cms' ); ?></h3><div class="kidia-page-fields"><?php foreach ( $chrome_fields as $field ) { $key = $field['key']; if ( 'layout_json' !== $key && 'general' === $item_field( $chrome_part, $key ) ) { $render_chrome_field( $field, $chrome_settings[ $key ] ?? $field['default'], $chrome_prefix . '[settings][' . $key . ']' ); } ?></div></section>
		</div>
	</div>
</section>
