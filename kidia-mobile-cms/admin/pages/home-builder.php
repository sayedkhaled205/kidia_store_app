<?php
/**
 * Home Builder admin page.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

$definitions = Kidia_Mobile_Block_Registry::picker_definitions();
?>

<div class="wrap kidia-builder-wrap">

	<h1>
		<?php esc_html_e(
			'Kidia Home Builder',
			'kidia-mobile-cms'
		); ?>
	</h1>

	<?php if (
		isset( $_GET['updated'] ) &&
		'1' === sanitize_key(
			wp_unslash( $_GET['updated'] )
		)
	) : ?>

	<div class="notice notice-success is-dismissible">
		<p>
			<?php esc_html_e(
				'Home Layout saved successfully.',
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
	>

		<input
			type="hidden"
			name="action"
			value="kidia_mobile_save_home_builder"
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

					<?php esc_html_e(
						'Add Element',
						'kidia-mobile-cms'
					); ?>

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
					<?php foreach ( $blocks as $index => $block_data ) : ?>

        				<?php

        				$type = isset( $block_data['type'] )
        					? (string) $block_data['type']
        					: '';

        				$block =
        					Kidia_Mobile_Block_Registry::get_block(
        						$type
        					);

        				if ( ! $block ) {
        					continue;
        				}

        				include
        					KIDIA_MOBILE_CMS_PATH .
        					'admin/templates/block-template.php';

        				?>

        			<?php endforeach; ?>

        		</div>

        		<div
        			id="kidia-element-picker"
        			class="kidia-element-picker"
        			hidden
        		>

        			<div class="kidia-element-picker__panel">

        				<h2>

        					<?php
        					esc_html_e(
        						'Add Element',
        						'kidia-mobile-cms'
        					);
        					?>

        				</h2>

        				<div
        					class="kidia-element-picker__grid"
        				>

        					<?php foreach (
        						$definitions as $definition
        					) : ?>

        						<?php
        						if (
        							empty(
        								$definition['available']
        							)
        						) {
        							continue;
        						}
        						?>

        						<button
        							type="button"
        							class="kidia-element-card"
        							data-block-type="<?php echo esc_attr(
        								$definition['type']
        							); ?>"
        						>

        							<span
        								class="dashicons <?php echo esc_attr(
        									$definition['icon']
        								); ?>"
        							></span>

        							<div>

        								<strong>
        									<?php
        									echo esc_html(
        										$definition['label']
        									);
        									?>
        								</strong>

        								<p>

        									<?php
        									echo esc_html(
        										$definition['description']
        									);
        									?>

        								</p>

        							</div>

        						</button>

        					<?php endforeach; ?>

        				</div>

        			</div>

        		</div>
        				<?php foreach ( $definitions as $definition ) : ?>

                			<?php

                			if ( empty( $definition['available'] ) ) {
                				continue;
                			}

                			$block =
                				Kidia_Mobile_Block_Registry::get_block(
                					$definition['type']
                				);

                			if ( ! $block ) {
                				continue;
                			}

                			$block_data =
                				$block->create_instance();

                			$block_data['id'] =
                				'__BLOCK_ID__';

                			$index =
                				'__INDEX__';

                			?>

                			<script
                				type="text/html"
                				id="tmpl-kidia-block-<?php echo esc_attr(
                					$definition['type']
                				); ?>"
                			>

                				<?php

                				include
                					KIDIA_MOBILE_CMS_PATH .
                					'admin/templates/block-template.php';

                				?>

                			</script>

                		<?php endforeach; ?>

                	</form>

                </div>
