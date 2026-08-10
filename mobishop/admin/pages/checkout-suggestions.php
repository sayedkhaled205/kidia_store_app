<?php
/** Checkout design and fields builder. */
defined( 'ABSPATH' ) || exit;

$checkout_field_types = array(
	'text'     => __( 'Text', 'mobishop' ),
	'email'    => __( 'Email', 'mobishop' ),
	'tel'      => __( 'Phone', 'mobishop' ),
	'select'   => __( 'Select', 'mobishop' ),
	'textarea' => __( 'Textarea', 'mobishop' ),
	'checkbox' => __( 'Checkbox', 'mobishop' ),
	'hidden'   => __( 'Hidden', 'mobishop' ),
	'country'  => __( 'Country', 'mobishop' ),
	'state'    => __( 'State', 'mobishop' ),
);
$render_checkout_field = static function ( array $field, string $index ) use ( $checkout_field_types ): void {
	$options_text = '';
	foreach ( (array) ( $field['options'] ?? array() ) as $option_key => $option_label ) {
		$options_text .= ( '' === $options_text ? '' : "\n" ) . $option_key . '|' . $option_label;
	}
	?>
	<section class="mobishop-page-card mobishop-checkout-field-card" draggable="true" data-checkout-field>
		<div class="mobishop-page-card__header">
			<div class="mobishop-page-card__identity">
				<span class="dashicons dashicons-move mobishop-checkout-field-drag" aria-hidden="true"></span>
				<span class="dashicons dashicons-editor-textcolor" aria-hidden="true"></span>
				<strong data-checkout-field-title><?php echo esc_html( (string) ( $field['label'] ?? __( 'Checkout field', 'mobishop' ) ) ); ?></strong>
				<small><?php echo esc_html( (string) ( $field['key'] ?? '' ) ); ?></small>
			</div>
			<div class="mobishop-card-actions mobishop-checkout-field-actions">
				<button type="button" class="button mobishop-checkout-field-remove mobishop-card-action mobishop-card-action--secondary"><span class="dashicons dashicons-trash"></span><?php esc_html_e( 'Remove', 'mobishop' ); ?></button>
				<button type="button" class="button mobishop-page-expand mobishop-card-action mobishop-card-action--expand" aria-expanded="false"><span class="dashicons dashicons-arrow-down-alt2"></span></button>
				<label class="mobishop-builder-switch mobishop-builder-switch--card mobishop-card-action mobishop-card-action--toggle">
					<input type="hidden" name="checkout[fields][<?php echo esc_attr( $index ); ?>][enabled]" value="0">
					<input type="checkbox" name="checkout[fields][<?php echo esc_attr( $index ); ?>][enabled]" value="1" <?php checked( ! isset( $field['enabled'] ) || ! empty( $field['enabled'] ) ); ?>>
					<span class="mobishop-builder-switch__track"></span>
					<span class="mobishop-builder-switch__state"></span>
				</label>
			</div>
		</div>
		<div class="mobishop-page-card__body" hidden>
			<div class="mobishop-page-fields">
				<div class="mobishop-page-field"><label><?php esc_html_e( 'Field label', 'mobishop' ); ?></label><input data-checkout-label type="text" name="checkout[fields][<?php echo esc_attr( $index ); ?>][label]" value="<?php echo esc_attr( (string) ( $field['label'] ?? '' ) ); ?>" required></div>
				<div class="mobishop-page-field"><label><?php esc_html_e( 'Field key', 'mobishop' ); ?></label><input type="text" name="checkout[fields][<?php echo esc_attr( $index ); ?>][key]" value="<?php echo esc_attr( (string) ( $field['key'] ?? '' ) ); ?>" required></div>
				<div class="mobishop-page-field"><label><?php esc_html_e( 'Group', 'mobishop' ); ?></label><select name="checkout[fields][<?php echo esc_attr( $index ); ?>][group]"><?php foreach ( array( 'billing' => __( 'Billing', 'mobishop' ), 'shipping' => __( 'Shipping', 'mobishop' ), 'order' => __( 'Order', 'mobishop' ) ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $field['group'] ?? 'billing', $value ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
				<div class="mobishop-page-field"><label><?php esc_html_e( 'Field type', 'mobishop' ); ?></label><select data-checkout-type name="checkout[fields][<?php echo esc_attr( $index ); ?>][type]"><?php foreach ( $checkout_field_types as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $field['type'] ?? 'text', $value ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
				<div class="mobishop-page-field"><label><?php esc_html_e( 'Placeholder', 'mobishop' ); ?></label><input type="text" name="checkout[fields][<?php echo esc_attr( $index ); ?>][placeholder]" value="<?php echo esc_attr( (string) ( $field['placeholder'] ?? '' ) ); ?>"></div>
				<div class="mobishop-page-field"><label><?php esc_html_e( 'Autocomplete', 'mobishop' ); ?></label><input type="text" name="checkout[fields][<?php echo esc_attr( $index ); ?>][autocomplete]" value="<?php echo esc_attr( (string) ( $field['autocomplete'] ?? '' ) ); ?>"></div>
				<div class="mobishop-page-field"><label><?php esc_html_e( 'Default value', 'mobishop' ); ?></label><input type="text" name="checkout[fields][<?php echo esc_attr( $index ); ?>][default]" value="<?php echo esc_attr( (string) ( $field['default'] ?? '' ) ); ?>"></div>
				<div class="mobishop-page-field"><label><?php esc_html_e( 'Required', 'mobishop' ); ?></label><label class="mobishop-page-toggle"><input type="hidden" name="checkout[fields][<?php echo esc_attr( $index ); ?>][required]" value="0"><input type="checkbox" name="checkout[fields][<?php echo esc_attr( $index ); ?>][required]" value="1" <?php checked( ! empty( $field['required'] ) ); ?>><b><?php esc_html_e( 'Required', 'mobishop' ); ?></b></label></div>
				<div class="mobishop-page-field mobishop-checkout-options-field"><label><?php esc_html_e( 'Options', 'mobishop' ); ?></label><textarea name="checkout[fields][<?php echo esc_attr( $index ); ?>][options_text]" rows="4" placeholder="value|Label"><?php echo esc_textarea( $options_text ); ?></textarea><small><?php esc_html_e( 'One option per line: value|Label', 'mobishop' ); ?></small></div>
			</div>
		</div>
	</section>
	<?php
};
?>
<div class="wrap mobishop-page-builder mobishop-checkout-builder">
	<?php if ( isset( $_GET['updated'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Checkout saved successfully.', 'mobishop' ); ?></p></div><?php endif; ?>
	<?php if ( isset( $_GET['fields_restored'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'The current WooCommerce checkout fields were copied into the builder.', 'mobishop' ); ?></p></div><?php endif; ?>
	<div class="mobishop-page-workspace mobishop-commerce-preview-workspace">
		<aside class="mobishop-page-preview">
			<div class="mobishop-page-phone"><div id="mobishop-commerce-preview" class="mobishop-page-phone__screen mobishop-app-preview" data-preview-kind="checkout"></div></div>
			<p><?php esc_html_e( 'Live mobile preview', 'mobishop' ); ?></p>
		</aside>
		<form class="mobishop-page-editor mobishop-commerce-preview-form mobishop-checkout-fields-form" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
			<input type="hidden" name="action" value="mobishop_save_checkout_suggestions">
			<?php wp_nonce_field( 'mobishop_save_checkout_suggestions', 'mobishop_checkout_suggestions_nonce' ); ?>
			<div class="mobishop-page-toolbar mobishop-checkout-toolbar">
				<div>
					<button type="button" class="button button-primary" data-checkout-add-field><span class="dashicons dashicons-plus-alt2"></span><?php esc_html_e( 'Add Field', 'mobishop' ); ?></button>
					<button type="submit" class="button" name="restore_checkout_fields" value="1" formnovalidate onclick="return window.confirm('<?php echo esc_js( __( 'Replace the builder fields with the checkout fields currently registered by WooCommerce and installed plugins?', 'mobishop' ) ); ?>');"><span class="dashicons dashicons-update"></span><?php esc_html_e( 'Restore Defaults', 'mobishop' ); ?></button>
				</div>
				<?php submit_button( __( 'Save Checkout', 'mobishop' ), 'primary', 'submit', false ); ?>
			</div>
			<section class="mobishop-checkout-design-panel">
				<div class="mobishop-checkout-design-heading">
					<div>
						<h2><?php esc_html_e( 'Checkout Design', 'mobishop' ); ?></h2>
						<p><?php esc_html_e( 'Choose the real mobile checkout layout first, then select and arrange its fields below.', 'mobishop' ); ?></p>
					</div>
				</div>
				<div class="mobishop-checkout-designs">
					<?php foreach ( MobiShop_Checkout_Fields_Store::designs() as $design_key => $design_label ) : ?>
						<label class="mobishop-checkout-design-option">
							<input type="radio" name="checkout_design" value="<?php echo esc_attr( $design_key ); ?>" <?php checked( $checkout_design, $design_key ); ?>>
							<span class="mobishop-checkout-design-option__preview is-<?php echo esc_attr( $design_key ); ?>" aria-hidden="true">
								<i class="mobishop-checkout-design-option__summary"></i>
								<i></i><i></i><i></i>
								<b></b>
							</span>
							<strong><?php echo esc_html( $design_label ); ?></strong>
							<small>
								<?php
								echo esc_html(
									'classic' === $design_key
										? __( 'Fields first, then the order summary.', 'mobishop' )
										: ( 'summary_first' === $design_key
											? __( 'Order summary first, then the fields.', 'mobishop' )
											: __( 'Smaller cards and tighter spacing.', 'mobishop' ) )
								);
								?>
							</small>
						</label>
					<?php endforeach; ?>
				</div>
			</section>
			<section class="mobishop-checkout-fields-panel">
				<div class="mobishop-checkout-fields-heading">
					<div><h2><?php esc_html_e( 'Checkout Fields', 'mobishop' ); ?></h2><p><?php esc_html_e( 'Drag to reorder. Restore Defaults reads the live WooCommerce schema after every installed plugin has modified it.', 'mobishop' ); ?></p></div>
					<label class="mobishop-page-status-control">
						<input type="hidden" name="checkout[enabled]" value="0">
						<input type="checkbox" name="checkout[enabled]" value="1" <?php checked( ! empty( $checkout_fields['enabled'] ) ); ?>>
						<span><b><?php esc_html_e( 'Checkout fields status', 'mobishop' ); ?></b><small data-page-status-copy></small></span>
					</label>
				</div>
				<div class="mobishop-checkout-fields-list" data-checkout-fields-list>
					<?php foreach ( $checkout_fields['fields'] as $field_index => $field ) { $render_checkout_field( $field, (string) $field_index ); } ?>
				</div>
			</section>
			<template data-checkout-field-template><?php $render_checkout_field( array( 'enabled' => true, 'label' => __( 'New field', 'mobishop' ), 'key' => '', 'group' => 'billing', 'type' => 'text', 'placeholder' => '', 'required' => false, 'priority' => 100, 'options' => array(), 'default' => '', 'autocomplete' => '' ), '__INDEX__' ); ?></template>
		</form>
	</div>
</div>
