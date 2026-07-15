<?php
/**
 * Generic Element Editor.
 *
 * Available variables:
 *
 * @var array<string,mixed> $schema
 * @var array<string,mixed> $item
 * @var string              $save_action
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

$item_id = isset( $item['id'] )
	? (string) $item['id']
	: '';

$item_name = isset( $item['name'] )
	? (string) $item['name']
	: '';

$item_status = isset( $item['status'] )
	? sanitize_key( (string) $item['status'] )
	: 'draft';

$item_enabled = ! isset( $item['enabled'] )
	|| ! empty( $item['enabled'] );

$settings = isset( $item['settings'] )
	&& is_array( $item['settings'] )
		? $item['settings']
		: array();

$fields = isset( $schema['fields'] )
	&& is_array( $schema['fields'] )
		? $schema['fields']
		: array();

$tabs = isset( $schema['tabs'] )
	&& is_array( $schema['tabs'] )
		? $schema['tabs']
		: array(
			array(
				'id'    => 'general',
				'label' => __( 'General', 'kidia-mobile-cms' ),
			),
		);

$editor_title = isset( $schema['title'] )
	? (string) $schema['title']
	: __( 'Element Editor', 'kidia-mobile-cms' );

$editor_description = isset( $schema['description'] )
	? (string) $schema['description']
	: '';

$page_slug = isset( $_GET['page'] )
	? sanitize_key(
		wp_unslash( $_GET['page'] )
	)
	: '';
?>

<div class="wrap kidia-editor">

	<div class="kidia-editor__header">

		<div>

			<a
				class="kidia-editor__back"
				href="<?php echo esc_url(
					add_query_arg(
						array(
							'page' => $page_slug,
						),
						admin_url( 'admin.php' )
					)
				); ?>"
			>
				←
				<?php esc_html_e(
					'Back to Library',
					'kidia-mobile-cms'
				); ?>
			</a>

			<h1>
				<?php echo esc_html( $editor_title ); ?>
			</h1>

			<?php if ( '' !== $editor_description ) : ?>

				<p class="description">
					<?php echo esc_html( $editor_description ); ?>
				</p>

			<?php endif; ?>

		</div>

	</div>

	<?php if (
		isset( $_GET['updated'] )
		&& '1' === sanitize_key(
			wp_unslash( $_GET['updated'] )
		)
	) : ?>

		<div class="notice notice-success is-dismissible">
			<p>
				<?php esc_html_e(
					'Item saved successfully.',
					'kidia-mobile-cms'
				); ?>
			</p>
		</div>

	<?php endif; ?>

	<form
		method="post"
		action="<?php echo esc_url(
			admin_url( 'admin-post.php' )
		); ?>"
		class="kidia-editor-form"
		id="kidia-editor-form"
	>

		<input
			type="hidden"
			name="action"
			value="<?php echo esc_attr( $save_action ); ?>"
		>

		<input
			type="hidden"
			name="id"
			value="<?php echo esc_attr( $item_id ); ?>"
		>

		<?php wp_nonce_field( 'kidia_library_action' ); ?>

		<div class="kidia-editor-layout">

			<main class="kidia-editor-main">

				<section class="kidia-editor-card">

					<div class="kidia-editor-card__header">

						<h2>
							<?php esc_html_e(
								'Element Details',
								'kidia-mobile-cms'
							); ?>
						</h2>

					</div>

					<div class="kidia-editor-card__body">

						<div class="kidia-editor-field">

							<label for="kidia-editor-name">
								<?php esc_html_e(
									'Name',
									'kidia-mobile-cms'
								); ?>
							</label>

							<input
								type="text"
								id="kidia-editor-name"
								name="name"
								value="<?php echo esc_attr( $item_name ); ?>"
								required
							>

						</div>

					</div>

				</section>

				<div class="kidia-editor-tabs">

					<div
						class="kidia-editor-tabs__nav"
						role="tablist"
					>

						<?php foreach ( $tabs as $tab_index => $tab ) : ?>

							<?php
							$tab_id = isset( $tab['id'] )
								? sanitize_key( (string) $tab['id'] )
								: 'general';

							$tab_label = isset( $tab['label'] )
								? (string) $tab['label']
								: $tab_id;
							?>

							<button
								type="button"
								class="kidia-editor-tab-button <?php echo 0 === $tab_index ? 'is-active' : ''; ?>"
								data-tab="<?php echo esc_attr( $tab_id ); ?>"
								role="tab"
								aria-selected="<?php echo 0 === $tab_index ? 'true' : 'false'; ?>"
							>
								<?php echo esc_html( $tab_label ); ?>
							</button>

						<?php endforeach; ?>

					</div>
										<div class="kidia-editor-tabs__content">

                    						<?php foreach ( $tabs as $tab_index => $tab ) : ?>

                    							<?php
                    							$tab_id = isset( $tab['id'] )
                    								? sanitize_key( (string) $tab['id'] )
                    								: 'general';
                    							?>

                    							<section
                    								class="kidia-editor-tab-panel <?php echo 0 === $tab_index ? 'is-active' : ''; ?>"
                    								data-tab-panel="<?php echo esc_attr( $tab_id ); ?>"
                    								role="tabpanel"
                    								<?php echo 0 === $tab_index ? '' : 'hidden'; ?>
                    							>

                    								<div class="kidia-editor-card">

                    									<div class="kidia-editor-card__body">

                    										<?php
                    										$tab_fields = array_filter(
                    											$fields,
                    											static function ( array $field ) use ( $tab_id ): bool {
                    												$field_tab = isset( $field['tab'] )
                    													? sanitize_key( (string) $field['tab'] )
                    													: 'general';

                    												return $field_tab === $tab_id;
                    											}
                    										);
                    										?>

                    										<?php if ( empty( $tab_fields ) ) : ?>

                    											<p class="description">
                    												<?php esc_html_e(
                    													'No settings available in this section.',
                    													'kidia-mobile-cms'
                    												); ?>
                    											</p>

                    										<?php else : ?>

                    											<div class="kidia-editor-fields">

                    												<?php foreach ( $tab_fields as $field ) : ?>

                    													<?php
                    													$field_key = isset( $field['key'] )
                    														? sanitize_key( (string) $field['key'] )
                    														: '';

                    													if ( '' === $field_key ) {
                    														continue;
                    													}

                    													$field_type = isset( $field['type'] )
                    														? sanitize_key( (string) $field['type'] )
                    														: 'text';

                    													$field_label = isset( $field['label'] )
                    														? (string) $field['label']
                    														: $field_key;

                    													$field_description = isset( $field['description'] )
                    														? (string) $field['description']
                    														: '';

                    													$field_value = array_key_exists(
                    														$field_key,
                    														$settings
                    													)
                    														? $settings[ $field_key ]
                    														: ( $field['default'] ?? '' );

                    													$field_id = 'kidia-editor-field-' . $field_key;

                    													$field_class = 'kidia-editor-field kidia-editor-field--' . $field_type;

                    													if ( ! empty( $field['full_width'] ) ) {
                    														$field_class .= ' kidia-editor-field--full';
                    													}
                    													?>

                    													<div class="<?php echo esc_attr( $field_class ); ?>">

                    														<label for="<?php echo esc_attr( $field_id ); ?>">

                    															<?php echo esc_html( $field_label ); ?>

                    															<?php if ( ! empty( $field['required'] ) ) : ?>
                    																<span class="kidia-editor-required">*</span>
                    															<?php endif; ?>

                    														</label>

                    														<?php if ( 'textarea' === $field_type ) : ?>

                    															<textarea
                    																id="<?php echo esc_attr( $field_id ); ?>"
                    																name="settings[<?php echo esc_attr( $field_key ); ?>]"
                    																rows="<?php echo esc_attr( (string) ( $field['rows'] ?? 5 ) ); ?>"
                    																<?php echo ! empty( $field['required'] ) ? 'required' : ''; ?>
                    															><?php echo esc_textarea( (string) $field_value ); ?></textarea>

                    														<?php elseif ( 'number' === $field_type ) : ?>

                    															<input
                    																type="number"
                    																id="<?php echo esc_attr( $field_id ); ?>"
                    																name="settings[<?php echo esc_attr( $field_key ); ?>]"
                    																value="<?php echo esc_attr( (string) $field_value ); ?>"
                    																<?php echo isset( $field['min'] ) ? 'min="' . esc_attr( (string) $field['min'] ) . '"' : ''; ?>
                    																<?php echo isset( $field['max'] ) ? 'max="' . esc_attr( (string) $field['max'] ) . '"' : ''; ?>
                    																<?php echo isset( $field['step'] ) ? 'step="' . esc_attr( (string) $field['step'] ) . '"' : ''; ?>
                    																<?php echo ! empty( $field['required'] ) ? 'required' : ''; ?>
                    															>

                    														<?php elseif ( 'checkbox' === $field_type ) : ?>

                    															<label class="kidia-editor-switch">

                    																<input
                    																	type="checkbox"
                    																	id="<?php echo esc_attr( $field_id ); ?>"
                    																	name="settings[<?php echo esc_attr( $field_key ); ?>]"
                    																	value="1"
                    																	<?php checked( true, ! empty( $field_value ) ); ?>
                    																>

                    																<span class="kidia-editor-switch__track"></span>

                    															</label>

                    														<?php elseif ( 'select' === $field_type ) : ?>

                    															<select
                    																id="<?php echo esc_attr( $field_id ); ?>"
                    																name="settings[<?php echo esc_attr( $field_key ); ?>]"
                    																<?php echo ! empty( $field['required'] ) ? 'required' : ''; ?>
                    															>

                    																<?php
                    																$options = isset( $field['options'] )
                    																	&& is_array( $field['options'] )
                    																		? $field['options']
                    																		: array();
                    																?>

                    																<?php foreach ( $options as $option_value => $option_label ) : ?>

                    																	<option
                    																		value="<?php echo esc_attr( (string) $option_value ); ?>"
                    																		<?php selected(
                    																			(string) $option_value,
                    																			(string) $field_value
                    																		); ?>
                    																	>
                    																		<?php echo esc_html( (string) $option_label ); ?>
                    																	</option>

                    																<?php endforeach; ?>

                    															</select>

                    														<?php elseif (
                    															'image' === $field_type
                    															|| 'media' === $field_type
                    														) : ?>

                    															<div class="kidia-editor-media">

                    																<input
                    																	type="url"
                    																	id="<?php echo esc_attr( $field_id ); ?>"
                    																	class="kidia-editor-media__input"
                    																	name="settings[<?php echo esc_attr( $field_key ); ?>]"
                    																	value="<?php echo esc_attr( (string) $field_value ); ?>"
                    																>

                    																<div class="kidia-editor-media__actions">

                    																	<button
                    																		type="button"
                    																		class="button kidia-editor-select-media"
                    																		data-target="<?php echo esc_attr( $field_id ); ?>"
                    																	>
                    																		<?php esc_html_e(
                    																			'Select Media',
                    																			'kidia-mobile-cms'
                    																		); ?>
                    																	</button>

                    																	<button
                    																		type="button"
                    																		class="button-link-delete kidia-editor-remove-media"
                    																		data-target="<?php echo esc_attr( $field_id ); ?>"
                    																	>
                    																		<?php esc_html_e(
                    																			'Remove',
                    																			'kidia-mobile-cms'
                    																		); ?>
                    																	</button>

                    																</div>

                    																<img
                    																	class="kidia-editor-media__preview"
                    																	data-preview-for="<?php echo esc_attr( $field_id ); ?>"
                    																	src="<?php echo esc_url( (string) $field_value ); ?>"
                    																	alt=""
                    																	<?php echo empty( $field_value ) ? 'hidden' : ''; ?>
                    																>

                    															</div>

                    														<?php elseif ( 'color' === $field_type ) : ?>

                    															<input
                    																type="color"
                    																id="<?php echo esc_attr( $field_id ); ?>"
                    																name="settings[<?php echo esc_attr( $field_key ); ?>]"
                    																value="<?php echo esc_attr(
                    																	(string) (
                    																		sanitize_hex_color(
                    																			(string) $field_value
                    																		) ?: '#ffffff'
                    																	)
                    																); ?>"
                    															>

                    														<?php elseif ( 'url' === $field_type ) : ?>

                    															<input
                    																type="url"
                    																id="<?php echo esc_attr( $field_id ); ?>"
                    																name="settings[<?php echo esc_attr( $field_key ); ?>]"
                    																value="<?php echo esc_attr( (string) $field_value ); ?>"
                    																<?php echo ! empty( $field['required'] ) ? 'required' : ''; ?>
                    															>

                    														<?php else : ?>

                    															<input
                    																type="text"
                    																id="<?php echo esc_attr( $field_id ); ?>"
                    																name="settings[<?php echo esc_attr( $field_key ); ?>]"
                    																value="<?php echo esc_attr( (string) $field_value ); ?>"
                    																<?php echo ! empty( $field['required'] ) ? 'required' : ''; ?>
                    															>

                    														<?php endif; ?>

                    														<?php if ( '' !== $field_description ) : ?>

                    															<p class="description">
                    																<?php echo esc_html( $field_description ); ?>
                    															</p>

                    														<?php endif; ?>

                    													</div>

                    												<?php endforeach; ?>

                    											</div>

                    										<?php endif; ?>

                    									</div>

                    								</div>

                    							</section>

                    						<?php endforeach; ?>

                    					</div>

                    				</div>

                    			</main>
                    						<aside class="kidia-editor-sidebar">

                                				<section class="kidia-editor-card">

                                					<div class="kidia-editor-card__header">

                                						<h2>
                                							<?php
                                							esc_html_e(
                                								'Publishing',
                                								'kidia-mobile-cms'
                                							);
                                							?>
                                						</h2>

                                					</div>

                                					<div class="kidia-editor-card__body">

                                						<div class="kidia-editor-field">

                                							<label for="kidia-editor-status">
                                								<?php
                                								esc_html_e(
                                									'Status',
                                									'kidia-mobile-cms'
                                								);
                                								?>
                                							</label>

                                							<select
                                								id="kidia-editor-status"
                                								name="status"
                                							>

                                								<option
                                									value="draft"
                                									<?php
                                									selected(
                                										'draft',
                                										$item_status
                                									);
                                									?>
                                								>
                                									<?php
                                									esc_html_e(
                                										'Draft',
                                										'kidia-mobile-cms'
                                									);
                                									?>
                                								</option>

                                								<option
                                									value="published"
                                									<?php
                                									selected(
                                										'published',
                                										$item_status
                                									);
                                									?>
                                								>
                                									<?php
                                									esc_html_e(
                                										'Published',
                                										'kidia-mobile-cms'
                                									);
                                									?>
                                								</option>

                                							</select>

                                						</div>

                                						<div class="kidia-editor-field">

                                							<label class="kidia-editor-switch">

                                								<input
                                									type="checkbox"
                                									name="enabled"
                                									value="1"
                                									<?php
                                									checked(
                                										true,
                                										$item_enabled
                                									);
                                									?>
                                								>

                                								<span class="kidia-editor-switch__track"></span>

                                							</label>

                                							<span>
                                								<?php
                                								esc_html_e(
                                									'Enabled',
                                									'kidia-mobile-cms'
                                								);
                                								?>
                                							</span>

                                						</div>

                                						<div class="kidia-editor-actions">

                                							<?php
                                							submit_button(
                                								__(
                                									'Save',
                                									'kidia-mobile-cms'
                                								),
                                								'primary',
                                								'submit',
                                								false
                                							);
                                							?>

                                							<a
                                								class="button"
                                								href="<?php
                                								echo esc_url(
                                									add_query_arg(
                                										array(
                                											'page' => $page_slug,
                                										),
                                										admin_url(
                                											'admin.php'
                                										)
                                									)
                                								);
                                								?>"
                                							>
                                								<?php
                                								esc_html_e(
                                									'Back',
                                									'kidia-mobile-cms'
                                								);
                                								?>
                                							</a>

                                						</div>

                                					</div>

                                				</section>

                                			</aside>

                                		</div>

                                	</form>

                                </div>