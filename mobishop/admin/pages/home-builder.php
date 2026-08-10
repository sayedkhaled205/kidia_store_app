<?php
/**
 * Home Builder admin page.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

if (
	! isset( $definitions )
	|| ! is_array( $definitions )
) {
	$definitions =
		MobiShop_Block_Registry::picker_definitions();
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
	'app_header'       => 'mobishop_app_headers',
	'hero_slider'      => 'mobishop_hero_sliders',
	'image_banner'     => 'mobishop_image_banners',
	'product_carousel' => 'mobishop_product_carousels',
	'brand_carousel'   => 'mobishop_brand_carousels',
	'category_grid'    => 'mobishop_category_grids',
	'product_grid'     => 'mobishop_product_grids',
	'section_header'   => 'mobishop_section_headers',
	'promo_strip'      => 'mobishop_promo_strips',
	'coupon_banner'    => 'mobishop_coupon_banners',
	'countdown'        => 'mobishop_countdowns',
	'video_banner'     => 'mobishop_video_banners',
	'text_block'       => 'mobishop_text_blocks',
	'divider'          => 'mobishop_dividers',
	'spacer'           => 'mobishop_spacers',
	'quick_links'      => 'mobishop_quick_links',
	'banner_grid'      => 'mobishop_banner_grids',
);

/**
 * Library records grouped by block type.
 *
 * @var array<string,array<int,array<string,mixed>>>
 */
$library_items = array();
$layout_counts = array();

/**
 * Friendly categories used to organise Home elements without changing their
 * saved page order.
 *
 * @var array<string,array{label:string,types:array<int,string>}>
 */
$element_categories = array(
	'visual' => array(
		'label' => __( 'Visual', 'mobishop' ),
		'types' => array( 'app_header', 'hero_slider', 'image_banner', 'banner_grid', 'video_banner' ),
	),
	'products' => array(
		'label' => __( 'Products', 'mobishop' ),
		'types' => array( 'category_grid', 'product_carousel', 'product_grid', 'brand_carousel', 'bundle_collection' ),
	),
	'content' => array(
		'label' => __( 'Content', 'mobishop' ),
		'types' => array( 'section_header', 'text_block', 'quick_links' ),
	),
	'marketing-layout' => array(
		'label' => __( 'Marketing & Layout', 'mobishop' ),
		'types' => array( 'promo_strip', 'coupon_banner', 'countdown', 'divider', 'spacer' ),
	),
);

$element_category_by_type = array();
foreach ( $element_categories as $category_key => $category ) {
	foreach ( $category['types'] as $category_type ) {
		$element_category_by_type[ $category_type ] = array(
			'key'   => $category_key,
			'label' => $category['label'],
		);
	}
}

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

<div class="wrap mobishop-builder-wrap">

	<?php if ( isset( $_GET['restored'] ) ) : ?>
		<div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Home page restored to defaults.', 'mobishop' ); ?></p></div>
	<?php elseif (
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
						'mobishop'
					);
					?>
			</p>

		</div>

	<?php endif; ?>

	<div class="mobishop-builder-workspace">
		<aside class="mobishop-preview" aria-label="<?php echo esc_attr__( 'Live mobile preview', 'mobishop' ); ?>">
			<div class="mobishop-preview__device">
			<div class="mobishop-preview__screen">
				<?php if ( file_exists( MOBISHOP_PATH . 'admin/flutter-preview/index.html' ) ) : ?>
					<iframe id="mobishop-flutter-preview" class="mobishop-flutter-preview" title="<?php echo esc_attr__( 'Flutter mobile preview', 'mobishop' ); ?>" src="<?php echo esc_url( add_query_arg( array( 'page' => 'home', 'v' => MOBISHOP_VERSION ), MOBISHOP_URL . 'admin/flutter-preview/index.html' ) ); ?>"></iframe>
					<div id="mobishop-preview-content" class="mobishop-preview__content mobishop-legacy-preview-fallback" hidden></div>
				<?php else : ?>
					<div id="mobishop-preview-content" class="mobishop-preview__content"></div>
				<?php endif; ?>
				</div>
			</div>
		</aside>
		<div class="mobishop-builder-editor">
	<form
		method="post"
		action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>"
		id="mobishop-home-builder-form"
		novalidate
	>

		<input
			type="hidden"
			name="action"
			value="mobishop_save_home_builder"
		>

		<input
			type="hidden"
			name="blocks_payload"
			id="mobishop-home-builder-payload"
			value=""
		>

		<input
			type="hidden"
			name="blocks_payload_encoding"
			id="mobishop-home-builder-payload-encoding"
			value="base64"
		>

		<input
			type="hidden"
			name="edit_after_save_type"
			id="mobishop-edit-after-save-type"
			value=""
		>

		<input
			type="hidden"
			name="edit_after_save_id"
			id="mobishop-edit-after-save-id"
			value=""
		>

		<?php
		wp_nonce_field(
			'mobishop_save_home_builder',
			'mobishop_home_builder_nonce'
		);
		?>

		<?php
		$mobishop_toolbar_title = __( 'Home Page', 'mobishop' );
		$mobishop_toolbar_save_label = __( 'Save Home Layout', 'mobishop' );
		$mobishop_toolbar_show_add = true;
		$mobishop_toolbar_show_restore = true;
		$mobishop_toolbar_page_toggle = false;
		include MOBISHOP_PATH . 'admin/pages/builder-toolbar.php';
		?>
		<div class="mobishop-builder-cards-scroll" data-mobishop-builder-cards-scroll>
		<?php $chrome_layout = $home_chrome; $chrome_part = 'header'; $chrome_page = 'home'; include MOBISHOP_PATH . 'admin/pages/fixed-chrome-card.php'; ?>

		<div
			id="mobishop-home-builder"
			class="mobishop-builder-list"
		>

			<?php if ( empty( $blocks ) ) : ?>

				<div
					id="mobishop-builder-empty"
					class="mobishop-builder-empty"
				>
					<span class="dashicons dashicons-screenoptions"></span>

					<h2>
						<?php
							esc_html_e(
								'No elements on the Home Page',
								'mobishop'
							);
							?>
					</h2>

					<p>
						<?php
							esc_html_e(
								'Add an element to start building the application Home Page.',
								'mobishop'
							);
							?>
					</p>

					<button
						type="button"
						class="button button-primary"
						data-mobishop-open-picker
					>
						<?php
							esc_html_e(
								'Add First Element',
								'mobishop'
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
					MobiShop_Block_Registry::get_block(
						$type
					);

				if (
					! $block instanceof MobiShop_Block
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

				$definition = $block->get_definition();
				$category = $element_category_by_type[ $type ] ?? array(
					'key'   => 'content',
					'label' => __( 'Content', 'mobishop' ),
				);
				$block_data['element_icon'] = sanitize_html_class(
					(string) ( $definition['icon'] ?? 'dashicons-screenoptions' )
				);
				$block_data['element_category_key'] = sanitize_key( $category['key'] );
				$block_data['element_category_label'] = sanitize_text_field( $category['label'] );

				include
					MOBISHOP_PATH .
					'admin/templates/block-template.php';
				?>

			<?php endforeach; ?>

		</div>
		<?php $chrome_layout = $home_chrome; $chrome_part = 'footer'; $chrome_page = 'home'; include MOBISHOP_PATH . 'admin/pages/fixed-chrome-card.php'; ?>
		</div>

	</form>
		</div>
	</div>

</div>

<div
	id="mobishop-element-picker"
	class="mobishop-element-picker"
	hidden
	aria-hidden="true"
>

	<div
		class="mobishop-element-picker__overlay"
		data-mobishop-close-picker
	></div>

	<div
		class="mobishop-element-picker__panel"
		role="dialog"
		aria-modal="true"
		aria-labelledby="mobishop-element-picker-title"
	>
		<nav class="mobishop-element-category-filter" aria-label="<?php echo esc_attr__( 'Filter elements by category', 'mobishop' ); ?>">
			<button type="button" class="button is-active" data-mobishop-element-category="all" aria-pressed="true">
				<?php esc_html_e( 'All', 'mobishop' ); ?>
			</button>
			<?php foreach ( $element_categories as $category_key => $category ) : ?>
				<button type="button" class="button" data-mobishop-element-category="<?php echo esc_attr( $category_key ); ?>" aria-pressed="false">
					<?php echo esc_html( $category['label'] ); ?>
				</button>
			<?php endforeach; ?>
		</nav>

		<div class="mobishop-element-picker__header">

			<div>

				<h2 id="mobishop-element-picker-title">
					<?php
						esc_html_e(
							'Add Element',
							'mobishop'
						);
						?>
				</h2>

				<p>
					<?php
						esc_html_e(
							'Choose an element type. Expand it only when you need a saved item.',
							'mobishop'
						);
						?>
				</p>

			</div>

			<button
				type="button"
				class="button-link mobishop-element-picker__close"
				data-mobishop-close-picker
				aria-label="<?php
					echo esc_attr__(
						'Close',
						'mobishop'
					);
				?>"
			>
				<span class="dashicons dashicons-no-alt"></span>
			</button>

		</div>

		<div class="mobishop-element-picker__toolbar">

			<input
				type="search"
				id="mobishop-element-picker-search"
				class="regular-text"
				placeholder="<?php
					echo esc_attr__(
						'Search elements...',
						'mobishop'
					);
				?>"
			>

		</div>

		<div class="mobishop-element-picker__content">

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

				// Home Builder is the only authoring surface. Legacy Library records
				// remain in the database for migration, but are not offered here.
				$type_items = array();
				$picker_category = $element_category_by_type[ $type ] ?? array(
					'key'   => 'content',
					'label' => __( 'Content', 'mobishop' ),
				);
				?>

				<button
					type="button"
					class="mobishop-element-group"
					data-element-group="<?php echo esc_attr( $type ); ?>"
					data-element-category="<?php echo esc_attr( $picker_category['key'] ); ?>"
					data-block-type="<?php echo esc_attr( $type ); ?>"
					data-block-label="<?php echo esc_attr( $label ); ?>"
				>
					<span class="mobishop-element-group__summary">
						<span class="mobishop-element-group__identity">
								<span
									class="dashicons <?php echo esc_attr( $icon ); ?>"
							></span>
							<strong><?php echo esc_html( $label ); ?></strong>
							<small><?php echo esc_html( $picker_category['label'] ); ?></small>
						</span>
					</span>
				</button>

			<?php endforeach; ?>

			<div
				id="mobishop-element-picker-no-results"
				class="mobishop-element-picker__empty"
				hidden
			>
				<?php
					esc_html_e(
						'No matching elements found.',
						'mobishop'
					);
					?>
			</div>

		</div>

		<div class="mobishop-element-picker__footer">

			<button
				type="button"
				class="button"
				data-mobishop-close-picker
			>
				<?php
					esc_html_e(
						'Cancel',
						'mobishop'
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
		MobiShop_Block_Registry::get_block(
			$type
		);

	if (
		! $block instanceof MobiShop_Block
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
		'published';

	$index = 987654321;

	$block_data = $default_block_data;
	?>

	<script
		type="text/html"
		id="tmpl-mobishop-block-<?php echo esc_attr( $type ); ?>"
	>
		<?php
		include
			MOBISHOP_PATH .
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

		$index = 987654321;
		?>

		<script
			type="text/html"
			id="<?php
				echo esc_attr(
					'tmpl-mobishop-library-' .
					$type .
					'-' .
					$library_id
				);
			?>"
		>
			<?php
			include
				MOBISHOP_PATH .
				'admin/templates/block-template.php';
			?>
		</script>

	<?php endforeach; ?>

<?php endforeach; ?>
