<?php
/**
 * Home Builder admin page.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if (
	! isset( $definitions )
	|| ! is_array( $definitions )
) {
	$definitions =
		Kidia_Mobile_Block_Registry::picker_definitions();
}

if (
	! isset( $blocks )
	|| ! is_array( $blocks )
) {
	$blocks = array();
}

/**
 * Library option names by block type.
 *
 * @var array<string,string>
 */
$library_options = array(
	'app_header'       => 'kidia_mobile_app_headers',
	'hero_slider'      => 'kidia_mobile_hero_sliders',
	'image_banner'     => 'kidia_mobile_image_banners',
	'product_carousel' => 'kidia_mobile_product_carousels',
	'brand_carousel'   => 'kidia_mobile_brand_carousels',
	'category_grid'    => 'kidia_mobile_category_grids',
	'product_grid'     => 'kidia_mobile_product_grids',
	'section_header'   => 'kidia_mobile_section_headers',
	'promo_strip'      => 'kidia_mobile_promo_strips',
	'coupon_banner'    => 'kidia_mobile_coupon_banners',
	'countdown'        => 'kidia_mobile_countdowns',
	'video_banner'     => 'kidia_mobile_video_banners',
	'text_block'       => 'kidia_mobile_text_blocks',
	'divider'          => 'kidia_mobile_dividers',
	'spacer'           => 'kidia_mobile_spacers',
);

/**
 * Library records grouped by block type.
 *
 * @var array<string,array<int,array<string,mixed>>>
 */
$library_items = array();
$layout_counts = array();

foreach ( $blocks as $layout_block ) {
	if ( ! is_array( $layout_block ) ) {
		continue;
	}

	$layout_type = sanitize_key( (string) ( $layout_block['type'] ?? '' ) );

	if ( '' !== $layout_type ) {
		$layout_counts[ $layout_type ] = ( $layout_counts[ $layout_type ] ?? 0 ) + 1;
	}
}

foreach ( $library_options as $type => $option_name ) {
	$items = get_option(
		$option_name,
		array()
	);

	$library_items[ $type ] = is_array( $items )
		? array_values( $items )
		: array();
}
?>

<div class="wrap kidia-builder-wrap">

	<div class="kidia-builder-page-header">

		<div>

			<h1>
				<?php
				esc_html_e(
					'Woo Mobile Home Builder',
					'kidia-mobile-cms'
				);
				?>
			</h1>

			<p class="description">
				<?php
				esc_html_e(
					'Arrange the application home page using your saved elements.',
					'kidia-mobile-cms'
				);
				?>
			</p>

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
				<?php
					esc_html_e(
						'Home Layout saved successfully.',
						'kidia-mobile-cms'
					);
					?>
			</p>

		</div>

	<?php endif; ?>

	<form
		method="post"
		action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>"
		id="kidia-home-builder-form"
	>

		<input
			type="hidden"
			name="action"
			value="kidia_mobile_save_home_builder"
		>

		<input
			type="hidden"
			name="blocks_payload"
			id="kidia-home-builder-payload"
			value=""
		>

		<input
			type="hidden"
			name="edit_after_save_type"
			id="kidia-edit-after-save-type"
			value=""
		>

		<input
			type="hidden"
			name="edit_after_save_id"
			id="kidia-edit-after-save-id"
			value=""
		>

		<?php
		wp_nonce_field(
			'kidia_mobile_save_home_builder',
			'kidia_mobile_home_builder_nonce'
		);
		?>

		<div class="kidia-builder-toolbar">

			<div class="kidia-builder-toolbar__actions">

				<button
					type="button"
					class="button button-primary"
					id="kidia-add-element"
				>
					<span class="dashicons dashicons-plus-alt2"></span>

					<?php
						esc_html_e(
							'Add Element',
							'kidia-mobile-cms'
						);
						?>
				</button>

				<button
					type="button"
					class="button"
					id="kidia-collapse-all"
				>
					<?php
						esc_html_e(
							'Collapse All',
							'kidia-mobile-cms'
						);
						?>
				</button>

				<button
					type="button"
					class="button"
					id="kidia-expand-all"
				>
					<?php
						esc_html_e(
							'Expand All',
							'kidia-mobile-cms'
						);
						?>
				</button>

			</div>

			<?php
			submit_button(
				__(
					'Save Home Layout',
					'kidia-mobile-cms'
				),
				'primary',
				'submit',
				false
			);
			?>

		</div>

		<div
			id="kidia-home-builder"
			class="kidia-builder-list"
		>

			<?php if ( empty( $blocks ) ) : ?>

				<div
					id="kidia-builder-empty"
					class="kidia-builder-empty"
				>
					<span class="dashicons dashicons-screenoptions"></span>

					<h2>
						<?php
							esc_html_e(
								'No elements on the Home Page',
								'kidia-mobile-cms'
							);
							?>
					</h2>

					<p>
						<?php
							esc_html_e(
								'Add an element to start building the application Home Page.',
								'kidia-mobile-cms'
							);
							?>
					</p>

					<button
						type="button"
						class="button button-primary"
						data-kidia-open-picker
					>
						<?php
							esc_html_e(
								'Add First Element',
								'kidia-mobile-cms'
							);
							?>
					</button>
				</div>

			<?php endif; ?>

			<?php foreach ( $blocks as $index => $block_data ) : ?>

				<?php
				if ( ! is_array( $block_data ) ) {
					continue;
				}

				$type = isset( $block_data['type'] )
					? sanitize_key(
						(string) $block_data['type']
					)
					: '';

				if ( '' === $type ) {
					continue;
				}

				$block =
					Kidia_Mobile_Block_Registry::get_block(
						$type
					);

				if (
					! $block instanceof Kidia_Mobile_Block
				) {
					continue;
				}

				$block_data['name'] = ! empty(
					$block_data['name']
				)
					? sanitize_text_field(
						(string) $block_data['name']
					)
					: $block->get_label();

				$block_data['library_id'] = ! empty(
					$block_data['library_id']
				)
					? sanitize_key(
						(string) $block_data['library_id']
					)
					: sanitize_key(
						(string) (
							$block_data['id']
							?? ''
						)
					);

				include
					KIDIA_MOBILE_CMS_PATH .
					'admin/templates/block-template.php';
				?>

			<?php endforeach; ?>

		</div>

	</form>

</div>

<div
	id="kidia-element-picker"
	class="kidia-element-picker"
	hidden
	aria-hidden="true"
>

	<div
		class="kidia-element-picker__overlay"
		data-kidia-close-picker
	></div>

	<div
		class="kidia-element-picker__panel"
		role="dialog"
		aria-modal="true"
		aria-labelledby="kidia-element-picker-title"
	>

		<div class="kidia-element-picker__header">

			<div>

				<h2 id="kidia-element-picker-title">
					<?php
						esc_html_e(
							'Add Element',
							'kidia-mobile-cms'
						);
						?>
				</h2>

				<p>
					<?php
						esc_html_e(
							'Choose an element type. Expand it only when you need a saved item.',
							'kidia-mobile-cms'
						);
						?>
				</p>

			</div>

			<button
				type="button"
				class="button-link kidia-element-picker__close"
				data-kidia-close-picker
				aria-label="<?php
					echo esc_attr__(
						'Close',
						'kidia-mobile-cms'
					);
				?>"
			>
				<span class="dashicons dashicons-no-alt"></span>
			</button>

		</div>

		<div class="kidia-element-picker__toolbar">

			<input
				type="search"
				id="kidia-element-picker-search"
				class="regular-text"
				placeholder="<?php
					echo esc_attr__(
						'Search elements...',
						'kidia-mobile-cms'
					);
				?>"
			>

		</div>

		<div class="kidia-element-picker__content">

			<?php foreach ( $definitions as $type => $definition ) : ?>

				<?php
				$type = sanitize_key(
					(string) (
						$definition['type']
						?? $type
					)
				);

				if (
					'' === $type
					|| empty( $definition['available'] )
				) {
					continue;
				}

				$label = isset( $definition['label'] )
					? (string) $definition['label']
					: $type;

				$description = isset(
					$definition['description']
				)
					? (string) $definition['description']
					: '';

				$icon = isset( $definition['icon'] )
					? (string) $definition['icon']
					: 'dashicons-screenoptions';

				$type_items = $library_items[ $type ]
					?? array();
				?>

				<details
					class="kidia-element-group"
					data-element-group="<?php echo esc_attr( $type ); ?>"
				>
					<summary class="kidia-element-group__summary">
						<span class="kidia-element-group__identity">
								<span
									class="dashicons <?php echo esc_attr( $icon ); ?>"
								></span>
							<strong><?php echo esc_html( $label ); ?></strong>
						</span>
						<span class="kidia-element-group__count">
							<?php
							echo esc_html(
								(string) ( $layout_counts[ $type ] ?? 0 )
							);
							?>
						</span>
					</summary>

					<div class="kidia-element-group__body">
						<div class="kidia-element-group__actions">
						<button
							type="button"
							class="button kidia-create-element"
							data-block-type="<?php echo esc_attr( $type ); ?>"
							data-block-label="<?php echo esc_attr( $label ); ?>"
						>
							<?php
								esc_html_e(
									'Create New',
									'kidia-mobile-cms'
								);
								?>
						</button>

						</div>

					<?php if ( ! empty( $type_items ) ) : ?>

						<div class="kidia-element-picker__grid">

							<?php foreach ( $type_items as $library_item ) : ?>

								<?php
								if (
									! is_array( $library_item )
									|| empty( $library_item['id'] )
								) {
									continue;
								}

								$library_id = sanitize_key(
									(string) $library_item['id']
								);

								$item_name = ! empty(
									$library_item['name']
								)
									? sanitize_text_field(
										(string) $library_item['name']
									)
									: $label;

								$item_status = isset(
									$library_item['status']
								)
									? sanitize_key(
										(string) $library_item['status']
									)
									: 'draft';
								?>

								<button
									type="button"
									class="kidia-element-card kidia-add-library-element"
									data-block-type="<?php echo esc_attr( $type ); ?>"
									data-library-id="<?php echo esc_attr( $library_id ); ?>"
									data-block-name="<?php echo esc_attr( $item_name ); ?>"
									data-template-id="<?php
										echo esc_attr(
											'tmpl-kidia-library-' .
											$type .
											'-' .
											$library_id
										);
									?>"
								>

									<span
										class="dashicons <?php echo esc_attr( $icon ); ?>"
									></span>

									<div>

										<strong>
											<?php echo esc_html( $item_name ); ?>
										</strong>

										<p>
											<?php
												echo esc_html(
													'published' === $item_status
														? __(
															'Published',
															'kidia-mobile-cms'
														)
														: __(
															'Draft',
															'kidia-mobile-cms'
														)
												);
												?>
										</p>

									</div>

								</button>

							<?php endforeach; ?>

						</div>

					<?php else : ?>

						<p class="kidia-element-group__empty">
							<?php
								esc_html_e(
									'No saved elements of this type yet.',
									'kidia-mobile-cms'
								);
								?>
						</p>

					<?php endif; ?>
					</div>

				</details>

			<?php endforeach; ?>

			<div
				id="kidia-element-picker-no-results"
				class="kidia-element-picker__empty"
				hidden
			>
				<?php
					esc_html_e(
						'No matching elements found.',
						'kidia-mobile-cms'
					);
					?>
			</div>

		</div>

		<div class="kidia-element-picker__footer">

			<button
				type="button"
				class="button"
				data-kidia-close-picker
			>
				<?php
					esc_html_e(
						'Cancel',
						'kidia-mobile-cms'
					);
					?>
			</button>

		</div>

	</div>

</div>

<div
	id="kidia-create-element-modal"
	class="kidia-create-element-modal"
	hidden
	aria-hidden="true"
>

	<div
		class="kidia-create-element-modal__overlay"
		data-kidia-close-create-modal
	></div>

	<div
		class="kidia-create-element-modal__panel"
		role="dialog"
		aria-modal="true"
		aria-labelledby="kidia-create-element-title"
	>

		<div class="kidia-create-element-modal__header">

			<h2 id="kidia-create-element-title">
				<?php
					esc_html_e(
						'Create Element',
						'kidia-mobile-cms'
					);
					?>
			</h2>

			<button
				type="button"
				class="button-link"
				data-kidia-close-create-modal
				aria-label="<?php
					echo esc_attr__(
						'Close',
						'kidia-mobile-cms'
					);
				?>"
			>
				<span class="dashicons dashicons-no-alt"></span>
			</button>

		</div>

		<div class="kidia-create-element-modal__body">

			<label for="kidia-create-element-name">

				<strong>
					<?php
						esc_html_e(
							'Element Name',
							'kidia-mobile-cms'
						);
						?>
				</strong>

			</label>

			<input
				type="text"
				id="kidia-create-element-name"
				class="regular-text"
				autocomplete="off"
			>

			<p
				id="kidia-create-element-error"
				class="kidia-create-element-modal__error"
				hidden
			>
				<?php
					esc_html_e(
						'Please enter an element name.',
						'kidia-mobile-cms'
					);
					?>
			</p>

		</div>

		<div class="kidia-create-element-modal__footer">

			<button
				type="button"
				class="button"
				data-kidia-close-create-modal
			>
				<?php
					esc_html_e(
						'Cancel',
						'kidia-mobile-cms'
					);
					?>
			</button>

			<button
				type="button"
				class="button button-primary"
				id="kidia-create-element-submit"
			>
				<?php
					esc_html_e(
						'Create and Add',
						'kidia-mobile-cms'
					);
					?>
			</button>

		</div>

	</div>

</div>

<?php foreach ( $definitions as $type => $definition ) : ?>

	<?php
	$type = sanitize_key(
		(string) (
			$definition['type']
			?? $type
		)
	);

	if (
		'' === $type
		|| empty( $definition['available'] )
	) {
		continue;
	}

	$block =
		Kidia_Mobile_Block_Registry::get_block(
			$type
		);

	if (
		! $block instanceof Kidia_Mobile_Block
	) {
		continue;
	}

	$default_block_data =
		$block->create_instance();

	if ( ! is_array( $default_block_data ) ) {
		continue;
	}

	$default_block_data['id'] =
		'__BLOCK_ID__';

	$default_block_data['library_id'] =
		'__LIBRARY_ID__';

	$default_block_data['name'] =
		'__BLOCK_NAME__';

	$default_block_data['order'] =
		'__ORDER__';

	$default_block_data['status'] =
		'draft';

	$index = '__INDEX__';

	$block_data = $default_block_data;
	?>

	<script
		type="text/html"
		id="tmpl-kidia-block-<?php echo esc_attr( $type ); ?>"
	>
		<?php
		include
			KIDIA_MOBILE_CMS_PATH .
			'admin/templates/block-template.php';
		?>
	</script>

	<?php foreach ( $library_items[ $type ] ?? array() as $library_item ) : ?>

		<?php
		if (
			! is_array( $library_item )
			|| empty( $library_item['id'] )
		) {
			continue;
		}

		$library_id = sanitize_key(
			(string) $library_item['id']
		);

		$block_data = array(
			'id'         => '__BLOCK_ID__',
			'library_id' => $library_id,
			'type'       => $type,
			'name'       => ! empty( $library_item['name'] )
				? sanitize_text_field(
					(string) $library_item['name']
				)
				: $block->get_label(),
			'enabled'    => ! isset( $library_item['enabled'] )
				|| ! empty( $library_item['enabled'] ),
			'status'     => 'published' === ( $library_item['status'] ?? 'published' )
				? 'published'
				: 'draft',
			'order'      => '__ORDER__',
			'settings'   => isset( $library_item['settings'] )
				&& is_array( $library_item['settings'] )
					? $library_item['settings']
					: $block->get_default_settings(),
		);

		$index = '__INDEX__';
		?>

		<script
			type="text/html"
			id="<?php
				echo esc_attr(
					'tmpl-kidia-library-' .
					$type .
					'-' .
					$library_id
				);
			?>"
		>
			<?php
			include
				KIDIA_MOBILE_CMS_PATH .
				'admin/templates/block-template.php';
			?>
		</script>

	<?php endforeach; ?>

<?php endforeach; ?>
