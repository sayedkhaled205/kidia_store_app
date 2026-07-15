<?php
/**
 * Edit Hero Slider.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

?>

<div class="wrap">

	<h1>

		<?php esc_html_e(
			'Edit Hero Slider',
			'kidia-mobile-cms'
		); ?>

	</h1>

	<form
		method="post"
		action="<?php echo esc_url(
			admin_url( 'admin-post.php' )
		); ?>"
	>

		<input
			type="hidden"
			name="action"
			value="kidia_mobile_save_hero_slider"
		>

		<?php
		wp_nonce_field(
			'kidia_mobile_save_hero_slider'
		);
		?>

		<input
			type="hidden"
			name="id"
			value="<?php echo esc_attr(
				$item['id']
			); ?>"
		>

		<table class="form-table">

			<tr>

				<th>

					<?php esc_html_e(
						'Name',
						'kidia-mobile-cms'
					); ?>

				</th>

				<td>

					<input
						type="text"
						class="regular-text"
						name="name"
						value="<?php echo esc_attr(
							$item['name']
						); ?>"
					>

				</td>

			</tr>

			<tr>

				<th>

					<?php esc_html_e(
						'Status',
						'kidia-mobile-cms'
					); ?>

				</th>

				<td>

					<select
						name="status"
					>

						<option
							value="draft"
							<?php selected(
								'draft',
								$item['status']
							); ?>
						>

							Draft

						</option>

						<option
							value="published"
							<?php selected(
								'published',
								$item['status']
							); ?>
						>

							Published

						</option>

					</select>

				</td>

			</tr>
