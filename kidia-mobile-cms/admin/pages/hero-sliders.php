<?php
/**
 * Hero Sliders Library.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;
?>

<div class="wrap kidia-legacy-library">

	<h1 class="wp-heading-inline">

		<?php esc_html_e(
			'Hero Sliders',
			'kidia-mobile-cms'
		); ?>

	</h1>

	<button
		type="button"
		class="page-title-action"
		id="kidia-new-hero"
	>
		<?php esc_html_e(
			'New Hero',
			'kidia-mobile-cms'
		); ?>
	</button>

	<hr class="wp-header-end">

	<div style="max-width:420px;margin:20px 0;">

		<input
			type="search"
			id="kidia-search-hero"
			class="regular-text"
			placeholder="<?php esc_attr_e(
				'Search...',
				'kidia-mobile-cms'
			); ?>"
			style="width:100%;"
		>

	</div>

	<table class="widefat striped">

		<thead>

			<tr>

				<th width="80">
					#
				</th>

				<th>
					<?php esc_html_e(
						'Name',
						'kidia-mobile-cms'
					); ?>
				</th>

				<th width="120">
					<?php esc_html_e(
						'Status',
						'kidia-mobile-cms'
					); ?>
				</th>

				<th width="280">
					<?php esc_html_e(
						'Actions',
						'kidia-mobile-cms'
					); ?>
				</th>

			</tr>

		</thead>

		<tbody>

		<?php if ( empty( $items ) ) : ?>

			<tr>

				<td colspan="4">

					<?php esc_html_e(
						'No Hero Sliders yet.',
						'kidia-mobile-cms'
					); ?>

				</td>

			</tr>

		<?php else : ?>

			<?php foreach ( $items as $index => $item ) : ?>

				<tr>

					<td>

						<?php echo esc_html(
							(string) ( $index + 1 )
						); ?>

					</td>

					<td>

						<strong>

							<?php echo esc_html(
								$item['name']
							); ?>

						</strong>

					</td>

					<td>

						<?php echo esc_html(
							$item['status']
						); ?>

					</td>

					<td>

						<a
							class="button button-primary"
							href="#"
						>

							<?php esc_html_e(
								'Edit',
								'kidia-mobile-cms'
							); ?>

						</a>

						<a
							class="button"
							href="<?php echo esc_url(
								wp_nonce_url(
									admin_url(
										'admin-post.php?action=kidia_mobile_duplicate_hero_slider&id=' .
										$item['id']
									),
									'kidia_mobile_duplicate_hero_slider'
								)
							); ?>"
						>

							<?php esc_html_e(
								'Duplicate',
								'kidia-mobile-cms'
							); ?>

						</a>

						<a
							class="button button-link-delete"
							href="<?php echo esc_url(
								wp_nonce_url(
									admin_url(
										'admin-post.php?action=kidia_mobile_delete_hero_slider&id=' .
										$item['id']
									),
									'kidia_mobile_delete_hero_slider'
								)
							); ?>"
							onclick="return confirm('Delete this Hero Slider?');"
						>

							<?php esc_html_e(
								'Delete',
								'kidia-mobile-cms'
							); ?>

						</a>

					</td>

				</tr>

			<?php endforeach; ?>

		<?php endif; ?>

		</tbody>

	</table>

</div>
			<tr>

				<th>

					<?php esc_html_e(
						'Aspect Ratio',
						'kidia-mobile-cms'
					); ?>

				</th>

				<td>

					<input
						type="number"
						step="0.1"
						min="1"
						max="4"
						name="settings[aspect_ratio]"
						value="<?php echo esc_attr(
							$item['settings']['aspect_ratio'] ?? 1.8
						); ?>"
					>

				</td>

			</tr>

			<tr>

				<th>

					<?php esc_html_e(
						'Autoplay',
						'kidia-mobile-cms'
					); ?>

				</th>

				<td>

					<label>

						<input
							type="checkbox"
							name="settings[auto_play]"
							value="1"
							<?php checked(
								true,
								! empty(
									$item['settings']['auto_play']
								)
							); ?>
						>

						<?php esc_html_e(
							'Enable autoplay',
							'kidia-mobile-cms'
						); ?>

					</label>

				</td>

			</tr>

			<tr>

				<th>

					<?php esc_html_e(
						'Interval',
						'kidia-mobile-cms'
					); ?>

				</th>

				<td>

					<input
						type="number"
						min="2000"
						max="15000"
						step="500"
						name="settings[interval_ms]"
						value="<?php echo esc_attr(
							$item['settings']['interval_ms'] ?? 4500
						); ?>"
					>

				</td>

			</tr>

		</table>

		<?php
		submit_button(
			__(
				'Save Hero Slider',
				'kidia-mobile-cms'
			)
		);
		?>

	</form>

</div>
