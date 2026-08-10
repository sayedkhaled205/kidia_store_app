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
			'mobishop'
		); ?>

	</h1>

	<button
		type="button"
		class="page-title-action"
		id="kidia-new-hero"
	>
		<?php esc_html_e(
			'New Hero',
			'mobishop'
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
				'mobishop'
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
						'mobishop'
					); ?>
				</th>

				<th width="120">
					<?php esc_html_e(
						'Status',
						'mobishop'
					); ?>
				</th>

				<th width="280">
					<?php esc_html_e(
						'Actions',
						'mobishop'
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
						'mobishop'
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
								'mobishop'
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
								'mobishop'
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
								'mobishop'
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
						'mobishop'
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
						'mobishop'
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
							'mobishop'
						); ?>

					</label>

				</td>

			</tr>

			<tr>

				<th>

					<?php esc_html_e(
						'Interval',
						'mobishop'
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
				'mobishop'
			)
		);
		?>

	</form>

</div>
