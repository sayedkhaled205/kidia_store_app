<?php
/** Fixed application header/footer card shared by the Home and Category builders. */
defined( 'ABSPATH' ) || exit;

$chrome_component = is_array( $chrome_layout[ $chrome_part ] ?? null ) ? $chrome_layout[ $chrome_part ] : array();
$chrome_settings  = is_array( $chrome_component['settings'] ?? null ) ? $chrome_component['settings'] : array();
$chrome_fields    = 'header' === $chrome_part ? $header_fields : $footer_fields;
$chrome_title     = 'header' === $chrome_part ? __( 'Fixed Header', 'kidia-mobile-cms' ) : __( 'Fixed Footer', 'kidia-mobile-cms' );
?>
<section class="kidia-fixed-chrome-card kidia-page-card kidia-page-card--locked" data-chrome-part="<?php echo esc_attr( $chrome_part ); ?>">
	<div class="kidia-page-card__header">
		<div><span class="dashicons dashicons-lock"></span><strong><?php echo esc_html( $chrome_title ); ?></strong><small><?php esc_html_e( 'Cannot be moved or removed', 'kidia-mobile-cms' ); ?></small></div>
		<label class="kidia-page-master-toggle"><input type="checkbox" name="layout[<?php echo esc_attr( $chrome_part ); ?>][enabled]" value="1" <?php checked( ! empty( $chrome_component['enabled'] ) ); ?>><span><?php esc_html_e( 'Show', 'kidia-mobile-cms' ); ?></span></label>
		<button type="button" class="button kidia-fixed-chrome-expand" aria-expanded="false"><span class="dashicons dashicons-arrow-down-alt2"></span></button>
	</div>
	<div class="kidia-page-card__body" hidden><div class="kidia-page-fields">
		<?php foreach ( $chrome_fields as $field ) :
			$key = $field['key']; $value = $chrome_settings[ $key ] ?? $field['default'];
			$name = 'layout[' . $chrome_part . '][settings][' . $key . ']'; ?>
			<div class="kidia-page-field"><label><?php echo esc_html( $field['label'] ); ?></label>
			<?php if ( 'checkbox' === $field['type'] ) : ?><label class="kidia-page-toggle"><input type="checkbox" name="<?php echo esc_attr( $name ); ?>" value="1" <?php checked( ! empty( $value ) ); ?>><span></span><b><?php echo esc_html( ! empty( $value ) ? __( 'Visible', 'kidia-mobile-cms' ) : __( 'Hidden', 'kidia-mobile-cms' ) ); ?></b></label>
			<?php elseif ( 'select' === $field['type'] ) : ?><select name="<?php echo esc_attr( $name ); ?>"><?php foreach ( $field['options'] as $option_value => $option_label ) : ?><option value="<?php echo esc_attr( $option_value ); ?>" <?php selected( (string) $value, (string) $option_value ); ?>><?php echo esc_html( $option_label ); ?></option><?php endforeach; ?></select>
			<?php elseif ( 'color' === $field['type'] ) : ?><input type="color" name="<?php echo esc_attr( $name ); ?>" value="<?php echo esc_attr( sanitize_hex_color( (string) $value ) ?: (string) $field['default'] ); ?>">
			<?php elseif ( 'number' === $field['type'] ) : ?><input type="number" name="<?php echo esc_attr( $name ); ?>" min="<?php echo esc_attr( (string) $field['min'] ); ?>" max="<?php echo esc_attr( (string) $field['max'] ); ?>" step="<?php echo esc_attr( (string) $field['step'] ); ?>" value="<?php echo esc_attr( (string) $value ); ?>">
			<?php else : ?><input type="text" name="<?php echo esc_attr( $name ); ?>" value="<?php echo esc_attr( (string) $value ); ?>"><?php endif; ?>
			</div>
		<?php endforeach; ?>
	</div></div>
</section>
