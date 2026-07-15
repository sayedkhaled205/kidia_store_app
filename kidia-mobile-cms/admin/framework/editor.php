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
	: 'published';

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

	<?php if (
		isset( $_GET['validation_error'] )
		&& '1' === sanitize_key(
			wp_unslash( $_GET['validation_error'] )
		)
	) : ?>

		<div class="notice notice-error">
			<p>
				<?php
				esc_html_e(
					'Saved as draft. Complete the required fields and use valid HTTP/HTTPS media URLs before publishing.',
					'kidia-mobile-cms'
				);
				?>
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

																	<?php if ( 'slides' === $field_type ) : ?>

																		<?php
																		$slide_items = is_array( $field_value )
																			? array_values( $field_value )
																			: array();
																		$action_options = array(
																			''           => __( 'No action', 'kidia-mobile-cms' ),
																			'product'    => __( 'Product', 'kidia-mobile-cms' ),
																			'category'   => __( 'Category', 'kidia-mobile-cms' ),
																			'collection' => __( 'Collection', 'kidia-mobile-cms' ),
																			'brand'      => __( 'Brand', 'kidia-mobile-cms' ),
																			'brands'     => __( 'All brands', 'kidia-mobile-cms' ),
																			'search'     => __( 'Search', 'kidia-mobile-cms' ),
																			'external'   => __( 'External URL', 'kidia-mobile-cms' ),
																		);
																		?>

																		<div
																			class="kidia-editor-slides"
																			data-field-key="<?php echo esc_attr( $field_key ); ?>"
																		>
																			<div class="kidia-editor-slides__items">
																				<?php foreach ( $slide_items as $slide_index => $slide_item ) : ?>
																					<?php
																					if ( ! is_array( $slide_item ) ) {
																						continue;
																					}

																					$slide_image = (string) ( $slide_item['image_url'] ?? '' );
																					$slide_id = (string) ( $slide_item['id'] ?? 'hero_slide_' . ( $slide_index + 1 ) );
																					$image_field_id = $field_id . '-image-' . $slide_index;
																					?>
																					<article class="kidia-editor-slide" draggable="true">
																						<header class="kidia-editor-slide__header">
																							<span class="dashicons dashicons-move kidia-editor-slide__handle" aria-hidden="true"></span>
																							<strong class="kidia-editor-slide__number">
																								<?php
																								printf(
																									/* translators: %d: slide position. */
																									esc_html__( 'Slide %d', 'kidia-mobile-cms' ),
																									(int) $slide_index + 1
																								);
																								?>
																							</strong>
																							<div class="kidia-editor-slide__header-actions">
																								<button type="button" class="button-link kidia-editor-slide__move-up" aria-label="<?php esc_attr_e( 'Move slide up', 'kidia-mobile-cms' ); ?>">↑</button>
																								<button type="button" class="button-link kidia-editor-slide__move-down" aria-label="<?php esc_attr_e( 'Move slide down', 'kidia-mobile-cms' ); ?>">↓</button>
																								<button type="button" class="button-link-delete kidia-editor-slide__remove"><?php esc_html_e( 'Remove', 'kidia-mobile-cms' ); ?></button>
																							</div>
																						</header>

																						<div class="kidia-editor-slide__grid">
																							<div class="kidia-editor-slide__media">
																								<img data-slide-preview src="<?php echo esc_url( $slide_image ); ?>" alt="" <?php echo '' === $slide_image ? 'hidden' : ''; ?>>
																								<div class="kidia-editor-slide__placeholder" <?php echo '' !== $slide_image ? 'hidden' : ''; ?>>
																									<span class="dashicons dashicons-format-image" aria-hidden="true"></span>
																								</div>
																								<input type="hidden" id="<?php echo esc_attr( $image_field_id ); ?>" data-slide-field="image_url" value="<?php echo esc_attr( $slide_image ); ?>">
																								<input type="hidden" data-slide-field="id" value="<?php echo esc_attr( $slide_id ); ?>">
																								<div class="kidia-editor-slide__media-actions">
																									<button type="button" class="button kidia-editor-slide__select-media"><?php esc_html_e( 'Choose image', 'kidia-mobile-cms' ); ?></button>
																									<button type="button" class="button-link-delete kidia-editor-slide__remove-media"><?php esc_html_e( 'Clear image', 'kidia-mobile-cms' ); ?></button>
																								</div>
																							</div>

																							<div class="kidia-editor-slide__fields">
																								<label>
																									<span><?php esc_html_e( 'Title', 'kidia-mobile-cms' ); ?></span>
																									<input type="text" data-slide-field="title" value="<?php echo esc_attr( (string) ( $slide_item['title'] ?? '' ) ); ?>">
																								</label>
																								<label>
																									<span><?php esc_html_e( 'Subtitle', 'kidia-mobile-cms' ); ?></span>
																									<textarea rows="2" data-slide-field="subtitle"><?php echo esc_textarea( (string) ( $slide_item['subtitle'] ?? '' ) ); ?></textarea>
																								</label>
																								<div class="kidia-editor-slide__action-row">
																									<label>
																										<span><?php esc_html_e( 'Tap action', 'kidia-mobile-cms' ); ?></span>
																										<select data-slide-field="action_type">
																											<?php foreach ( $action_options as $action_value => $action_label ) : ?>
																												<option value="<?php echo esc_attr( $action_value ); ?>" <?php selected( $action_value, (string) ( $slide_item['action_type'] ?? '' ) ); ?>><?php echo esc_html( $action_label ); ?></option>
																											<?php endforeach; ?>
																										</select>
																									</label>
																									<label>
																										<span><?php esc_html_e( 'Action value', 'kidia-mobile-cms' ); ?></span>
																										<input type="text" data-slide-field="action_value" value="<?php echo esc_attr( (string) ( $slide_item['action_value'] ?? '' ) ); ?>" placeholder="<?php esc_attr_e( 'ID, search term or URL', 'kidia-mobile-cms' ); ?>">
																									</label>
																								</div>
																								<label class="kidia-editor-slide__enabled">
																									<input type="hidden" data-slide-field="enabled" value="0">
																									<input type="checkbox" data-slide-field="enabled" value="1" <?php checked( true, ! isset( $slide_item['enabled'] ) || ! empty( $slide_item['enabled'] ) ); ?>>
																									<span><?php esc_html_e( 'Show this slide', 'kidia-mobile-cms' ); ?></span>
																								</label>
																							</div>
																						</div>
																					</article>
																				<?php endforeach; ?>
																			</div>

																			<button type="button" class="button button-primary kidia-editor-slides__add">
																				<span class="dashicons dashicons-plus-alt2" aria-hidden="true"></span>
																				<?php esc_html_e( 'Add slides', 'kidia-mobile-cms' ); ?>
																			</button>
																		</div>

																	<?php elseif ( 'gallery' === $field_type ) : ?>

                    															<?php
                    															$gallery_items = is_array( $field_value )
                    																? array_values( $field_value )
                    																: array();
                    															?>

                    															<div
                    																class="kidia-editor-gallery"
                    																data-field-key="<?php echo esc_attr( $field_key ); ?>"
                    															>
                    																<div class="kidia-editor-gallery__items">
                    																	<?php foreach ( $gallery_items as $gallery_index => $gallery_item ) : ?>
                    																		<?php
                    																		$image_url = is_array( $gallery_item )
                    																			? (string) ( $gallery_item['image_url'] ?? '' )
                    																			: (string) $gallery_item;
                    																		if ( '' === $image_url ) {
                    																			continue;
                    																		}
                    																		?>
                    																		<div class="kidia-editor-gallery__item">
                    																			<img src="<?php echo esc_url( $image_url ); ?>" alt="">
                    																			<input type="hidden" name="settings[<?php echo esc_attr( $field_key ); ?>][<?php echo esc_attr( (string) $gallery_index ); ?>][image_url]" value="<?php echo esc_attr( $image_url ); ?>">
                    																			<button type="button" class="button-link-delete kidia-editor-gallery__remove"><?php esc_html_e( 'Remove', 'kidia-mobile-cms' ); ?></button>
                    																		</div>
                    																	<?php endforeach; ?>
                    																</div>
                    																<button type="button" class="button button-primary kidia-editor-gallery__select"><?php esc_html_e( 'Select Images', 'kidia-mobile-cms' ); ?></button>
                    															</div>

                    														<?php elseif ( 'textarea' === $field_type ) : ?>

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
