<?php
/**
 * Image Banners Library.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

?>

<div class="wrap kidia-hero-library">

	<h1 class="wp-heading-inline">

		<?php esc_html_e(
			'Image Banners',
			'kidia-mobile-cms'
		); ?>

	</h1>

	<button
		type="button"
		class="page-title-action"
		id="kidia-new-image-banner"
	>

		<?php esc_html_e(
			'New Banner',
			'kidia-mobile-cms'
		); ?>

	</button>

	<hr class="wp-header-end">

	<div class="kidia-hero-toolbar">

		<input
			type="search"
			id="kidia-search-image-banner"
			class="regular-text kidia-hero-search"
			placeholder="<?php esc_attr_e(
				'Search...',
				'kidia-mobile-cms'
			); ?>"
		>

	</div>

	<?php if ( empty( $items ) ) : ?>

		<div class="kidia-empty-library">

			<h2>

				<?php esc_html_e(
					'No Image Banners',
					'kidia-mobile-cms'
				); ?>

			</h2>

		</div>

	<?php else : ?>

		<?php foreach ( $items as $item ) : ?>

			<div class="kidia-hero-card">

				<div class="kidia-hero-card__left">

					<div class="kidia-hero-card__title">

						<?php
						echo esc_html(
							$item['name']
						);
						?>

					</div>

					<span
						class="kidia-hero-card__status kidia-hero-card__status--<?php echo esc_attr(
							$item['status']
						); ?>"
					>

						<?php
						echo esc_html(
							ucfirst(
								$item['status']
							)
						);
						?>

					</span>

				</div>

				<div class="kidia-hero-card__actions">

					<a
						class="button button-primary"
						href="#"
					>

						Edit

					</a>

					<a
						class="button"
						href="<?php echo esc_url(
							wp_nonce_url(
								admin_url(
									'admin-post.php?action=kidia_mobile_duplicate_image_banner&id=' .
									$item['id']
								),
								'kidia_mobile_duplicate_image_banner'
							)
						); ?>"
					>

						Duplicate

					</a>

					<a
						class="button button-link-delete"
						onclick="return confirm('Delete this Banner?');"
						href="<?php echo esc_url(
							wp_nonce_url(
								admin_url(
									'admin-post.php?action=kidia_mobile_delete_image_banner&id=' .
									$item['id']
								),
								'kidia_mobile_delete_image_banner'
							)
						); ?>"
					>

						Delete

					</a>

				</div>

			</div>

		<?php endforeach; ?>

	<?php endif; ?>

</div>