<?php
/** Checkout design and fields builder. */
defined( 'ABSPATH' ) || exit;

$checkout_field_types = array(
	'text'     => __( 'Text', 'kidia-mobile-cms' ),
	'email'    => __( 'Email', 'kidia-mobile-cms' ),
	'tel'      => __( 'Phone', 'kidia-mobile-cms' ),
	'select'   => __( 'Select', 'kidia-mobile-cms' ),
	'textarea' => __( 'Textarea', 'kidia-mobile-cms' ),
	'checkbox' => __( 'Checkbox', 'kidia-mobile-cms' ),
	'hidden'   => __( 'Hidden', 'kidia-mobile-cms' ),
	'country'  => __( 'Country', 'kidia-mobile-cms' ),
	'state'    => __( 'State', 'kidia-mobile-cms' ),
);
$render_checkout_field = static function ( array $field, string $index ) use ( $checkout_field_types ): void {
	$options_text = '';
	foreach ( (array) ( $field['options'] ?? array() ) as $option_key => $option_label ) {
		$options_text .= ( '' === $options_text ? '' : "\n" ) . $option_key . '|' . $option_label;
	}
	?>
	<section class="kidia-page-card kidia-checkout-field-card" draggable="true" data-checkout-field>
		<div class="kidia-page-card__header">
			<div class="kidia-page-card__identity">
				<span class="dashicons dashicons-move kidia-checkout-field-drag" aria-hidden="true"></span>
				<span class="dashicons dashicons-editor-textcolor" aria-hidden="true"></span>
				<strong data-checkout-field-title><?php echo esc_html( (string) ( $field['label'] ?? __( 'Checkout field', 'kidia-mobile-cms' ) ) ); ?></strong>
				<small><?php echo esc_html( (string) ( $field['key'] ?? '' ) ); ?></small>
			</div>
			<div class="kidia-card-actions kidia-checkout-field-actions">
				<span class="kidia-card-action-placeholder kidia-card-action--primary" aria-hidden="true"></span>
				<button type="button" class="button kidia-checkout-field-remove kidia-card-action kidia-card-action--secondary"><span class="dashicons dashicons-trash"></span><?php esc_html_e( 'Remove', 'kidia-mobile-cms' ); ?></button>
				<button type="button" class="button kidia-page-expand kidia-card-action kidia-card-action--expand" aria-expanded="false"><span class="dashicons dashicons-arrow-down-alt2"></span></button>
				<label class="kidia-builder-switch kidia-builder-switch--card kidia-card-action kidia-card-action--toggle">
					<input type="hidden" name="checkout[fields][<?php echo esc_attr( $index ); ?>][enabled]" value="0">
					<input type="checkbox" name="checkout[fields][<?php echo esc_attr( $index ); ?>][enabled]" value="1" <?php checked( ! isset( $field['enabled'] ) || ! empty( $field['enabled'] ) ); ?>>
					<span class="kidia-builder-switch__track"></span>
					<span class="kidia-builder-switch__state"></span>
				</label>
			</div>
		</div>
		<div class="kidia-page-card__body" hidden>
			<div class="kidia-page-fields">
				<div class="kidia-page-field"><label><?php esc_html_e( 'Field label', 'kidia-mobile-cms' ); ?></label><input data-checkout-label type="text" name="checkout[fields][<?php echo esc_attr( $index ); ?>][label]" value="<?php echo esc_attr( (string) ( $field['label'] ?? '' ) ); ?>" required></div>
				<div class="kidia-page-field"><label><?php esc_html_e( 'Field key', 'kidia-mobile-cms' ); ?></label><input type="text" name="checkout[fields][<?php echo esc_attr( $index ); ?>][key]" value="<?php echo esc_attr( (string) ( $field['key'] ?? '' ) ); ?>" required></div>
				<div class="kidia-page-field"><label><?php esc_html_e( 'Group', 'kidia-mobile-cms' ); ?></label><select name="checkout[fields][<?php echo esc_attr( $index ); ?>][group]"><?php foreach ( array( 'billing' => __( 'Billing', 'kidia-mobile-cms' ), 'shipping' => __( 'Shipping', 'kidia-mobile-cms' ), 'order' => __( 'Order', 'kidia-mobile-cms' ) ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $field['group'] ?? 'billing', $value ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
				<div class="kidia-page-field"><label><?php esc_html_e( 'Field type', 'kidia-mobile-cms' ); ?></label><select data-checkout-type name="checkout[fields][<?php echo esc_attr( $index ); ?>][type]"><?php foreach ( $checkout_field_types as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $field['type'] ?? 'text', $value ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
				<div class="kidia-page-field"><label><?php esc_html_e( 'Placeholder', 'kidia-mobile-cms' ); ?></label><input type="text" name="checkout[fields][<?php echo esc_attr( $index ); ?>][placeholder]" value="<?php echo esc_attr( (string) ( $field['placeholder'] ?? '' ) ); ?>"></div>
				<div class="kidia-page-field"><label><?php esc_html_e( 'Autocomplete', 'kidia-mobile-cms' ); ?></label><input type="text" name="checkout[fields][<?php echo esc_attr( $index ); ?>][autocomplete]" value="<?php echo esc_attr( (string) ( $field['autocomplete'] ?? '' ) ); ?>"></div>
				<div class="kidia-page-field"><label><?php esc_html_e( 'Default value', 'kidia-mobile-cms' ); ?></label><input type="text" name="checkout[fields][<?php echo esc_attr( $index ); ?>][default]" value="<?php echo esc_attr( (string) ( $field['default'] ?? '' ) ); ?>"></div>
				<div class="kidia-page-field"><label><?php esc_html_e( 'Required', 'kidia-mobile-cms' ); ?></label><label class="kidia-page-toggle"><input type="hidden" name="checkout[fields][<?php echo esc_attr( $index ); ?>][required]" value="0"><input type="checkbox" name="checkout[fields][<?php echo esc_attr( $index ); ?>][required]" value="1" <?php checked( ! empty( $field['required'] ) ); ?>><b><?php esc_html_e( 'Required', 'kidia-mobile-cms' ); ?></b></label></div>
				<div class="kidia-page-field kidia-checkout-options-field"><label><?php esc_html_e( 'Options', 'kidia-mobile-cms' ); ?></label><textarea name="checkout[fields][<?php echo esc_attr( $index ); ?>][options_text]" rows="4" placeholder="value|Label"><?php echo esc_textarea( $options_text ); ?></textarea><small><?php esc_html_e( 'One option per line: value|Label', 'kidia-mobile-cms' ); ?></small></div>
			</div>
		</div>
	</section>
	<?php
};
?>
<div class="wrap kidia-page-builder kidia-checkout-builder">
	<?php if ( isset( $_GET['updated'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Checkout saved successfully.', 'kidia-mobile-cms' ); ?></p></div><?php endif; ?>
	<?php if ( isset( $_GET['fields_restored'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'The current WooCommerce checkout fields were copied into the builder.', 'kidia-mobile-cms' ); ?></p></div><?php endif; ?>
	<div class="kidia-page-workspace kidia-commerce-preview-workspace">
		<aside class="kidia-page-preview">
			<div class="kidia-page-phone"><div id="kidia-commerce-preview" class="kidia-page-phone__screen kidia-app-preview" data-preview-kind="checkout"></div></div>
			<p><?php esc_html_e( 'Live mobile preview', 'kidia-mobile-cms' ); ?></p>
		</aside>
		<form class="kidia-page-editor kidia-commerce-preview-form kidia-checkout-fields-form" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
			<input type="hidden" name="action" value="kidia_mobile_save_checkout_suggestions">
			<?php wp_nonce_field( 'kidia_mobile_save_checkout_suggestions', 'kidia_mobile_checkout_suggestions_nonce' ); ?>
			<div class="kidia-page-toolbar kidia-checkout-toolbar">
				<div>
					<button type="button" class="button button-primary" data-checkout-add-field><span class="dashicons dashicons-plus-alt2"></span><?php esc_html_e( 'Add Field', 'kidia-mobile-cms' ); ?></button>
					<button type="submit" class="button" name="restore_checkout_fields" value="1" formnovalidate onclick="return window.confirm('<?php echo esc_js( __( 'Replace the builder fields with the checkout fields currently registered by WooCommerce and installed plugins?', 'kidia-mobile-cms' ) ); ?>');"><span class="dashicons dashicons-update"></span><?php esc_html_e( 'Default Fields', 'kidia-mobile-cms' ); ?></button>
				</div>
				<?php submit_button( __( 'Save Checkout', 'kidia-mobile-cms' ), 'primary', 'submit', false ); ?>
			</div>
			<section class="kidia-checkout-design-panel">
				<div class="kidia-checkout-design-heading">
					<div>
						<h2><?php esc_html_e( 'Checkout Design', 'kidia-mobile-cms' ); ?></h2>
						<p><?php esc_html_e( 'Choose the real mobile checkout layout first, then select and arrange its fields below.', 'kidia-mobile-cms' ); ?></p>
					</div>
				</div>
				<div class="kidia-checkout-designs">
					<?php foreach ( Kidia_Mobile_Checkout_Fields_Store::designs() as $design_key => $design_label ) : ?>
						<label class="kidia-checkout-design-option">
							<input type="radio" name="checkout_design" value="<?php echo esc_attr( $design_key ); ?>" <?php checked( $checkout_design, $design_key ); ?>>
							<span class="kidia-checkout-design-option__preview is-<?php echo esc_attr( $design_key ); ?>" aria-hidden="true">
								<i class="kidia-checkout-design-option__summary"></i>
								<i></i><i></i><i></i>
								<b></b>
							</span>
							<strong><?php echo esc_html( $design_label ); ?></strong>
							<small>
								<?php
								echo esc_html(
									'classic' === $design_key
										? __( 'Fields first, then the order summary.', 'kidia-mobile-cms' )
										: ( 'summary_first' === $design_key
											? __( 'Order summary first, then the fields.', 'kidia-mobile-cms' )
											: __( 'Smaller cards and tighter spacing.', 'kidia-mobile-cms' ) )
								);
								?>
							</small>
						</label>
					<?php endforeach; ?>
				</div>
			</section>
			<section class="kidia-checkout-fields-panel">
				<div class="kidia-checkout-fields-heading">
					<div><h2><?php esc_html_e( 'Checkout Fields', 'kidia-mobile-cms' ); ?></h2><p><?php esc_html_e( 'Drag to reorder. Default Fields reads the live WooCommerce schema after every installed plugin has modified it.', 'kidia-mobile-cms' ); ?></p></div>
					<label class="kidia-page-status-control">
						<input type="hidden" name="checkout[enabled]" value="0">
						<input type="checkbox" name="checkout[enabled]" value="1" <?php checked( ! empty( $checkout_fields['enabled'] ) ); ?>>
						<span class="kidia-page-status-control__icon"><span class="dashicons dashicons-yes-alt"></span></span>
						<span><b><?php esc_html_e( 'Checkout fields', 'kidia-mobile-cms' ); ?></b><small data-page-status-copy></small></span>
					</label>
				</div>
				<div class="kidia-checkout-fields-list" data-checkout-fields-list>
					<?php foreach ( $checkout_fields['fields'] as $field_index => $field ) { $render_checkout_field( $field, (string) $field_index ); } ?>
				</div>
			</section>
			<template data-checkout-field-template><?php $render_checkout_field( array( 'enabled' => true, 'label' => __( 'New field', 'kidia-mobile-cms' ), 'key' => '', 'group' => 'billing', 'type' => 'text', 'placeholder' => '', 'required' => false, 'priority' => 100, 'options' => array(), 'default' => '', 'autocomplete' => '' ), '__INDEX__' ); ?></template>
		</form>
	</div>
</div>
