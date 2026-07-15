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

/**
 * Resolves selectable WooCommerce entities for schema entity fields.
 *
 * The editor deliberately uses a one-at-a-time picker. It is easier to use
 * than comma-separated IDs while keeping the saved value backward compatible.
 *
 * @param array<string,mixed> $field       Field definition.
 * @param mixed               $field_value Saved field value.
 *
 * @return array<int,string>
 */
$resolve_entity_options = static function ( array $field, $field_value ): array {
	$options = array();
	$entity  = sanitize_key( (string) ( $field['entity'] ?? '' ) );

	if ( 'product' === $entity && post_type_exists( 'product' ) ) {
		$product_ids = get_posts(
			array(
				'post_type'              => 'product',
				'post_status'            => array( 'publish', 'draft', 'pending', 'private' ),
				'fields'                 => 'ids',
				'posts_per_page'         => 250,
				'orderby'                => 'title',
				'order'                  => 'ASC',
				'no_found_rows'          => true,
				'update_post_meta_cache' => false,
				'update_post_term_cache' => false,
			)
		);

		foreach ( (array) $product_ids as $product_id ) {
			$product_id = absint( $product_id );

			if ( 0 === $product_id ) {
				continue;
			}

			$options[ $product_id ] = sprintf(
				'#%1$d — %2$s',
				$product_id,
				get_the_title( $product_id ) ?: __( 'Untitled Product', 'kidia-mobile-cms' )
			);
		}
	}

	if ( in_array( $entity, array( 'term', 'brand' ), true ) ) {
		$taxonomy = sanitize_key( (string) ( $field['taxonomy'] ?? '' ) );

		if ( 'brand' === $entity ) {
			$brand_candidates = array(
				'product_brand',
				'pwb-brand',
				'yith_product_brand',
				'pa_brand',
			);
			$fallback_taxonomy = '';

			foreach ( $brand_candidates as $candidate ) {
				if ( ! taxonomy_exists( $candidate ) ) {
					continue;
				}

				if ( '' === $fallback_taxonomy ) {
					$fallback_taxonomy = $candidate;
				}

				$count = wp_count_terms( array( 'taxonomy' => $candidate, 'hide_empty' => false ) );
				if ( ! is_wp_error( $count ) && 0 < (int) $count ) {
					$taxonomy = $candidate;
					break;
				}
			}

			if ( '' === $taxonomy ) {
				$taxonomy = $fallback_taxonomy;
			}
		}

		if ( '' !== $taxonomy && taxonomy_exists( $taxonomy ) ) {
			$terms = get_terms(
				array(
					'taxonomy'   => $taxonomy,
					'hide_empty' => false,
					'number'     => 250,
					'orderby'    => 'name',
					'order'      => 'ASC',
				)
			);

			if ( ! is_wp_error( $terms ) ) {
				foreach ( $terms as $term ) {
					$options[ (int) $term->term_id ] = sprintf(
						'#%1$d — %2$s',
						(int) $term->term_id,
						(string) $term->name
					);
				}
			}
		}
	}

	$saved_ids = is_array( $field_value )
		? $field_value
		: preg_split( '/[\s,]+/', (string) $field_value );

	foreach ( array_filter( array_map( 'absint', (array) $saved_ids ) ) as $saved_id ) {
		if ( isset( $options[ $saved_id ] ) ) {
			continue;
		}

		$label = get_the_title( $saved_id );
		$options[ $saved_id ] = sprintf(
			'#%1$d — %2$s',
			$saved_id,
			$label ?: __( 'Saved item', 'kidia-mobile-cms' )
		);
	}

	return $options;
};
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

															$show_if_key = '';
															$show_if_value = '';
															if ( ! empty( $field['show_if'] ) && is_array( $field['show_if'] ) ) {
																$show_if_key = sanitize_key( (string) array_key_first( $field['show_if'] ) );
																$show_if_value = (string) reset( $field['show_if'] );
															}
															?>

															<div
																class="<?php echo esc_attr( $field_class ); ?>"
																<?php echo '' !== $show_if_key ? 'data-show-if-key="' . esc_attr( $show_if_key ) . '" data-show-if-value="' . esc_attr( $show_if_value ) . '"' : ''; ?>
															>

                    														<label for="<?php echo esc_attr( $field_id ); ?>">

                    															<?php echo esc_html( $field_label ); ?>

                    															<?php if ( ! empty( $field['required'] ) ) : ?>
                    																<span class="kidia-editor-required">*</span>
                    															<?php endif; ?>

                    														</label>

														<?php if ( 'entity_select' === $field_type ) : ?>

															<?php
															$entity_options = $resolve_entity_options( $field, $field_value );
															$is_multiple    = ! empty( $field['multiple'] );
															$selected_ids   = is_array( $field_value )
																? $field_value
																: preg_split( '/[\s,]+/', (string) $field_value );
															$selected_ids   = array_values(
																array_unique(
																	array_filter( array_map( 'absint', (array) $selected_ids ) )
																)
															);
															if ( ! $is_multiple && ! empty( $selected_ids ) ) {
																$selected_ids = array( reset( $selected_ids ) );
															}
															?>

															<div class="kidia-entity-picker" data-multiple="<?php echo $is_multiple ? '1' : '0'; ?>">
																<input
																	type="hidden"
																	id="<?php echo esc_attr( $field_id ); ?>"
																	class="kidia-entity-picker__value"
																	name="settings[<?php echo esc_attr( $field_key ); ?>]"
																	value="<?php echo esc_attr( implode( ',', $selected_ids ) ); ?>"
																>

																<div class="kidia-entity-picker__controls">
																	<select class="kidia-entity-picker__select" aria-label="<?php echo esc_attr( $field_label ); ?>">
																		<option value=""><?php esc_html_e( 'Choose an item…', 'kidia-mobile-cms' ); ?></option>
																		<?php foreach ( $entity_options as $entity_id => $entity_label ) : ?>
																			<option value="<?php echo esc_attr( (string) $entity_id ); ?>"><?php echo esc_html( $entity_label ); ?></option>
																		<?php endforeach; ?>
																	</select>
																	<button type="button" class="button kidia-entity-picker__add"><?php esc_html_e( 'Add', 'kidia-mobile-cms' ); ?></button>
																</div>

																<ul class="kidia-entity-picker__selected">
																	<?php foreach ( $selected_ids as $selected_id ) : ?>
																		<li data-id="<?php echo esc_attr( (string) $selected_id ); ?>">
																			<span><?php echo esc_html( $entity_options[ $selected_id ] ?? ( '#' . $selected_id ) ); ?></span>
																			<button type="button" class="button-link-delete kidia-entity-picker__remove" aria-label="<?php esc_attr_e( 'Remove', 'kidia-mobile-cms' ); ?>">×</button>
																		</li>
																	<?php endforeach; ?>
																</ul>
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
																						<div class="kidia-editor-gallery__item" draggable="true">
																							<span class="dashicons dashicons-move kidia-editor-gallery__drag" aria-hidden="true"></span>
                    																			<img src="<?php echo esc_url( $image_url ); ?>" alt="">
                    																			<input type="hidden" name="settings[<?php echo esc_attr( $field_key ); ?>][<?php echo esc_attr( (string) $gallery_index ); ?>][image_url]" value="<?php echo esc_attr( $image_url ); ?>">
                    																			<button type="button" class="button-link-delete kidia-editor-gallery__remove"><?php esc_html_e( 'Remove', 'kidia-mobile-cms' ); ?></button>
                    																		</div>
                    																	<?php endforeach; ?>
                    																</div>
                    																<button type="button" class="button button-primary kidia-editor-gallery__select"><?php esc_html_e( 'Select Images', 'kidia-mobile-cms' ); ?></button>
                    															</div>

														<?php elseif ( 'richtext' === $field_type ) : ?>

															<?php
															wp_editor(
																(string) $field_value,
																$field_id,
																array(
																	'textarea_name' => 'settings[' . $field_key . ']',
																	'textarea_rows' => absint( $field['rows'] ?? 10 ),
																	'media_buttons' => false,
																	'quicktags'     => true,
																)
															);
															?>

														<?php elseif ( 'textarea' === $field_type ) : ?>

                    															<textarea
                    																id="<?php echo esc_attr( $field_id ); ?>"
                    																name="settings[<?php echo esc_attr( $field_key ); ?>]"
                    																rows="<?php echo esc_attr( (string) ( $field['rows'] ?? 5 ) ); ?>"
                    																<?php echo ! empty( $field['required'] ) ? 'required' : ''; ?>
                    															><?php echo esc_textarea( (string) $field_value ); ?></textarea>

														<?php elseif ( 'datetime' === $field_type ) : ?>

															<input
																type="datetime-local"
																id="<?php echo esc_attr( $field_id ); ?>"
																name="settings[<?php echo esc_attr( $field_key ); ?>]"
																value="<?php echo esc_attr( (string) $field_value ); ?>"
																<?php echo ! empty( $field['required'] ) ? 'required' : ''; ?>
															>

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
															|| 'video' === $field_type
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
																				data-media-type="<?php echo esc_attr( 'video' === $field_type ? 'video' : ( 'image' === $field_type ? 'image' : '' ) ); ?>"
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

																<?php if ( 'video' !== $field_type ) : ?>
																<img
																	class="kidia-editor-media__preview"
                    																	data-preview-for="<?php echo esc_attr( $field_id ); ?>"
                    																	src="<?php echo esc_url( (string) $field_value ); ?>"
                    																	alt=""
																	<?php echo empty( $field_value ) ? 'hidden' : ''; ?>
																>
																<?php endif; ?>

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
