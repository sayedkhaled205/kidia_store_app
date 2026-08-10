<?php
/**
 * Image Banners Library.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

?>

<div class="wrap mobishop-hero-library">

	<h1 class="wp-heading-inline">

		<?php esc_html_e(
			'Image Banners',
			'mobishop'
		); ?>

	</h1>

	<button
		type="button"
		class="page-title-action"
		id="mobishop-new-image-banner"
	>

		<?php esc_html_e(
			'New Banner',
			'mobishop'
		); ?>

	</button>

	<hr class="wp-header-end">

	<div class="mobishop-hero-toolbar">

		<input
			type="search"
			id="mobishop-search-image-banner"
			class="regular-text mobishop-hero-search"
			placeholder="<?php esc_attr_e(
				'Search...',
				'mobishop'
			); ?>"
		>

	</div>

	<?php if ( empty( $items ) ) : ?>

		<div class="mobishop-empty-library">

			<h2>

				<?php esc_html_e(
					'No Image Banners',
					'mobishop'
				); ?>

			</h2>

		</div>

	<?php else : ?>

		<?php foreach ( $items as $item ) : ?>

			<div class="mobishop-hero-card">

				<div class="mobishop-hero-card__left">

					<div class="mobishop-hero-card__title">

						<?php
						echo esc_html(
							$item['name']
						);
						?>

					</div>

					<span
						class="mobishop-hero-card__status mobishop-hero-card__status--<?php echo esc_attr(
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

				<div class="mobishop-hero-card__actions">

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
									'admin-post.php?action=mobishop_duplicate_image_banner&id=' .
									$item['id']
								),
								'mobishop_duplicate_image_banner'
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
									'admin-post.php?action=mobishop_delete_image_banner&id=' .
									$item['id']
								),
								'mobishop_delete_image_banner'
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