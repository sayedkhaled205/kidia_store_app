<?php
/**
 * Edit Image Banner.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

?>

<div class="wrap kidia-image-banner-edit">

	<h1>

		<?php esc_html_e(
			'Edit Image Banner',
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
			value="kidia_mobile_save_image_banner"
		>

		<?php
		wp_nonce_field(
			'kidia_mobile_save_image_banner'
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

			<tr>

				<th>

					<?php esc_html_e(
						'Image',
						'kidia-mobile-cms'
					); ?>

				</th>

				<td>

					<input
						type="url"
						id="kidia-image-banner-url"
						class="regular-text"
						name="settings[image_url]"
						value="<?php echo esc_attr(
							$item['settings']['image_url'] ?? ''
						); ?>"
					>

					<p>

						<button
							type="button"
							class="button"
							id="kidia-select-image-banner"
						>

							<?php esc_html_e(
								'Select Image',
								'kidia-mobile-cms'
							); ?>

						</button>

					</p>

					<img
						id="kidia-image-banner-preview"
						src="<?php echo esc_url(
							$item['settings']['image_url'] ?? ''
						); ?>"
						style="
							max-width:600px;
							width:100%;
							border-radius:14px;
							display:<?php echo empty(
								$item['settings']['image_url']
							) ? 'none' : 'block'; ?>;
						"
					>

				</td>

			</tr>
						<tr>

            				<th>

            					<?php esc_html_e(
            						'Accessibility Label',
            						'kidia-mobile-cms'
            					); ?>

            				</th>

            				<td>

            					<input
            						type="text"
            						class="regular-text"
            						name="settings[semantic_label]"
            						value="<?php echo esc_attr(
            							$item['settings']['semantic_label'] ?? ''
            						); ?>"
            					>

            				</td>

            			</tr>

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
            						max="5"
            						name="settings[aspect_ratio]"
            						value="<?php echo esc_attr(
            							$item['settings']['aspect_ratio'] ?? 2.4
            						); ?>"
            					>

            				</td>

            			</tr>

            			<tr>

            				<th>

            					<?php esc_html_e(
            						'Border Radius',
            						'kidia-mobile-cms'
            					); ?>

            				</th>

            				<td>

            					<input
            						type="number"
            						min="0"
            						max="48"
            						name="settings[border_radius]"
            						value="<?php echo esc_attr(
            							$item['settings']['border_radius'] ?? 20
            						); ?>"
            					>

            				</td>

            			</tr>

            			<tr>

            				<th>

            					<?php esc_html_e(
            						'Action Type',
            						'kidia-mobile-cms'
            					); ?>

            				</th>

            				<td>

            					<select
            						name="settings[action_type]"
            					>

            						<option value="">None</option>

            						<option value="product" <?php selected(
            							'product',
            							$item['settings']['action_type'] ?? ''
            						); ?>>Product</option>

            						<option value="category" <?php selected(
            							'category',
            							$item['settings']['action_type'] ?? ''
            						); ?>>Category</option>

            						<option value="collection" <?php selected(
            							'collection',
            							$item['settings']['action_type'] ?? ''
            						); ?>>Collection</option>

            						<option value="search" <?php selected(
            							'search',
            							$item['settings']['action_type'] ?? ''
            						); ?>>Search</option>

            						<option value="external" <?php selected(
            							'external',
            							$item['settings']['action_type'] ?? ''
            						); ?>>External URL</option>

            					</select>

            				</td>

            			</tr>

            			<tr>

            				<th>

            					<?php esc_html_e(
            						'Action Value',
            						'kidia-mobile-cms'
            					); ?>

            				</th>

            				<td>

            					<input
            						type="text"
            						class="regular-text"
            						name="settings[action_value]"
            						value="<?php echo esc_attr(
            							$item['settings']['action_value'] ?? ''
            						); ?>"
            					>

            				</td>

            			</tr>

            			<tr>

            				<th>

            					<?php esc_html_e(
            						'Enabled',
            						'kidia-mobile-cms'
            					); ?>

            				</th>

            				<td>

            					<label>

            						<input
            							type="checkbox"
            							name="settings[enabled]"
            							value="1"
            							<?php checked(
            								true,
            								! empty(
            									$item['settings']['enabled']
            								)
            							); ?>
            						>

            						Enabled

            					</label>

            				</td>

            			</tr>

            		</table>

            		<?php
            		submit_button(
            			__(
            				'Save Banner',
            				'kidia-mobile-cms'
            			)
            		);
            		?>

            	</form>

            </div>
            <script>

            (function () {

            	'use strict';

            	const button =
            		document.getElementById(
            			'kidia-select-image-banner'
            		);

            	const input =
            		document.getElementById(
            			'kidia-image-banner-url'
            		);

            	const preview =
            		document.getElementById(
            			'kidia-image-banner-preview'
            		);

            	if (
            		! button ||
            		! input ||
            		! preview
            	) {
            		return;
            	}

            	button.addEventListener(
            		'click',
            		function () {

            			if (
            				typeof wp === 'undefined' ||
            				! wp.media
            			) {
            				return;
            			}

            			const frame = wp.media({

            				title: 'Select Banner Image',

            				button: {
            					text: 'Use this image'
            				},

            				multiple: false,

            				library: {
            					type: 'image'
            				}

            			});

            			frame.on(
            				'select',
            				function () {

            					const attachment =
            						frame
            						.state()
            						.get('selection')
            						.first()
            						.toJSON();

            					input.value =
            						attachment.url || '';

            					preview.src =
            						attachment.url || '';

            					preview.style.display =
            						attachment.url
            							? 'block'
            							: 'none';

            				}
            			);

            			frame.open();

            		}
            	);

            })();

            </script>

            <?php