<?php
/**
 * Generic Library Page.
 *
 * Available variables:
 *
 * @var string                           $title
 * @var string                           $page_slug
 * @var string                           $create_action
 * @var string                           $duplicate_action
 * @var string                           $delete_action
 * @var array<int,array<string,mixed>>   $items
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;
?>

<div
	class="wrap kidia-library"
	data-page-slug="<?php echo esc_attr( $page_slug ); ?>"
>
	<div class="kidia-library__header">

		<div>
			<h1 class="wp-heading-inline">
				<?php echo esc_html( $title ); ?>
			</h1>

			<p class="description">
				<?php
				esc_html_e(
					'Create, search and manage reusable elements.',
					'mobishop'
				);
				?>
			</p>
		</div>

		<button
			type="button"
			class="page-title-action kidia-library__new"
			id="kidia-library-new"
			data-action="<?php echo esc_attr( $create_action ); ?>"
		>
			<span class="dashicons dashicons-plus-alt2"></span>

			<?php
				esc_html_e(
					'Add New',
					'mobishop'
				);
				?>
		</button>

	</div>

	<hr class="wp-header-end">

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
						'Item saved successfully.',
						'mobishop'
					);
					?>
			</p>
		</div>

	<?php endif; ?>

	<?php if (
		isset( $_GET['deleted'] )
		&& '1' === sanitize_key(
			wp_unslash( $_GET['deleted'] )
		)
	) : ?>

		<div class="notice notice-success is-dismissible">
			<p>
				<?php
					esc_html_e(
						'Item deleted successfully.',
						'mobishop'
					);
					?>
			</p>
		</div>

	<?php endif; ?>

	<div class="kidia-library-toolbar">

		<div class="kidia-library-toolbar__search">

			<label
				class="screen-reader-text"
				for="kidia-library-search"
			>
				<?php
					esc_html_e(
						'Search items',
						'mobishop'
					);
					?>
			</label>

			<input
				type="search"
				id="kidia-library-search"
				class="regular-text"
				placeholder="<?php
					echo esc_attr__(
						'Search by name...',
						'mobishop'
					);
				?>"
			>

		</div>

		<div class="kidia-library-toolbar__count">

			<strong id="kidia-library-count">
				<?php echo esc_html( (string) count( $items ) ); ?>
			</strong>

			<?php
				esc_html_e(
					'items',
					'mobishop'
				);
				?>

		</div>

	</div>

	<div
		id="kidia-library-list"
		class="kidia-library-list"
	>

		<?php if ( empty( $items ) ) : ?>

			<div class="kidia-library-empty">

				<span class="dashicons dashicons-screenoptions"></span>

				<h2>
					<?php
						esc_html_e(
							'No items yet',
							'mobishop'
						);
						?>
				</h2>

				<p>
					<?php
						esc_html_e(
							'Create your first item to start building the application home page.',
							'mobishop'
						);
						?>
				</p>

				<button
					type="button"
					class="button button-primary kidia-library__new"
					data-action="<?php echo esc_attr( $create_action ); ?>"
				>
					<?php
						esc_html_e(
							'Create First Item',
							'mobishop'
						);
						?>
				</button>

			</div>

		<?php else : ?>

			<?php foreach ( $items as $item ) : ?>

				<?php
				$item_id = isset( $item['id'] )
					? (string) $item['id']
					: '';

				$item_name = isset( $item['name'] )
					? (string) $item['name']
					: __( 'Untitled Item', 'mobishop' );

				$item_status = isset( $item['status'] )
					? sanitize_key( (string) $item['status'] )
					: 'draft';

				if (
					! in_array(
						$item_status,
						array(
							'draft',
							'published',
						),
						true
					)
				) {
					$item_status = 'draft';
				}

				$is_enabled = ! isset( $item['enabled'] )
					|| ! empty( $item['enabled'] );

				$updated_at = isset( $item['updated_at'] )
					? (string) $item['updated_at']
					: '';
				?>

				<article
					class="kidia-library-card"
					data-name="<?php echo esc_attr( strtolower( $item_name ) ); ?>"
					data-id="<?php echo esc_attr( $item_id ); ?>"
				>

					<div class="kidia-library-card__main">

						<div class="kidia-library-card__icon">
							<span class="dashicons dashicons-screenoptions"></span>
						</div>

						<div class="kidia-library-card__content">

							<h2 class="kidia-library-card__title">

								<a
									href="<?php
										echo esc_url(
											add_query_arg(
												array(
													'page' => $page_slug,
													'id'   => $item_id,
												),
												admin_url( 'admin.php' )
											)
										);
									?>"
								>
									<?php echo esc_html( $item_name ); ?>
								</a>

							</h2>

							<div class="kidia-library-card__meta">

								<span
									class="kidia-library-status kidia-library-status--<?php
										echo esc_attr( $item_status );
									?>"
								>
									<?php
										echo esc_html(
											'published' === $item_status
												? __( 'Published', 'mobishop' )
												: __( 'Draft', 'mobishop' )
										);
									?>
								</span>

								<span
									class="kidia-library-enabled <?php
										echo $is_enabled
											? 'is-enabled'
											: 'is-disabled';
									?>"
								>
									<?php
										echo esc_html(
											$is_enabled
												? __( 'Enabled', 'mobishop' )
												: __( 'Disabled', 'mobishop' )
										);
									?>
								</span>

								<?php if ( '' !== $updated_at ) : ?>

									<span class="kidia-library-updated">
										<?php
											echo esc_html(
												sprintf(
													/* translators: %s: item update date. */
													__(
														'Updated: %s',
														'mobishop'
													),
													$updated_at
												)
											);
										?>
									</span>

								<?php endif; ?>

							</div>

						</div>

					</div>

					<div class="kidia-library-card__actions">

						<button
							type="button"
							class="button kidia-library-status-toggle <?php
								echo 'published' === $item_status
									? 'is-draft-action'
									: 'button-primary';
							?>"
							data-action="<?php echo esc_attr( $status_action ); ?>"
							data-id="<?php echo esc_attr( $item_id ); ?>"
						>
							<?php
							echo esc_html(
								'published' === $item_status
									? __( 'Draft', 'mobishop' )
									: __( 'Publish', 'mobishop' )
							);
							?>
						</button>

						<a
							class="button button-primary"
							href="<?php
								echo esc_url(
									add_query_arg(
										array(
											'page' => $page_slug,
											'id'   => $item_id,
										),
										admin_url( 'admin.php' )
									)
								);
							?>"
						>
							<?php
								esc_html_e(
									'Edit',
									'mobishop'
								);
								?>
						</a>

						<button
							type="button"
							class="button kidia-library-duplicate"
							data-action="<?php echo esc_attr( $duplicate_action ); ?>"
							data-id="<?php echo esc_attr( $item_id ); ?>"
						>
							<?php
								esc_html_e(
									'Duplicate',
									'mobishop'
								);
								?>
						</button>

						<button
							type="button"
							class="button button-link-delete kidia-library-delete"
							data-action="<?php echo esc_attr( $delete_action ); ?>"
							data-id="<?php echo esc_attr( $item_id ); ?>"
							data-name="<?php echo esc_attr( $item_name ); ?>"
						>
							<?php
								esc_html_e(
									'Delete',
									'mobishop'
								);
								?>
						</button>

					</div>

				</article>

			<?php endforeach; ?>

			<div
				id="kidia-library-no-results"
				class="kidia-library-empty"
				hidden
			>
				<h2>
					<?php
						esc_html_e(
							'No matching items',
							'mobishop'
						);
						?>
				</h2>
			</div>

		<?php endif; ?>

	</div>

</div>
<div
	id="kidia-library-create-modal"
	class="kidia-library-modal"
	hidden
>
	<div
		class="kidia-library-modal__overlay"
		data-kidia-close-modal
	></div>

	<div
		class="kidia-library-modal__panel"
		role="dialog"
		aria-modal="true"
		aria-labelledby="kidia-library-create-title"
	>
		<div class="kidia-library-modal__header">

			<h2 id="kidia-library-create-title">
				<?php
				esc_html_e(
					'Create New Item',
					'mobishop'
				);
				?>
			</h2>

			<button
				type="button"
				class="button-link kidia-library-modal__close"
				data-kidia-close-modal
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

		<div class="kidia-library-modal__body">

			<label for="kidia-library-new-name">
				<strong>
					<?php
						esc_html_e(
							'Name',
							'mobishop'
						);
						?>
				</strong>
			</label>

			<input
				type="text"
				id="kidia-library-new-name"
				class="regular-text"
				autocomplete="off"
				placeholder="<?php
					echo esc_attr__(
						'Enter item name',
						'mobishop'
					);
				?>"
			>

			<p
				id="kidia-library-create-error"
				class="kidia-library-modal__error"
				hidden
			>
				<?php
					esc_html_e(
						'Please enter a name.',
						'mobishop'
					);
					?>
			</p>

		</div>

		<div class="kidia-library-modal__footer">

			<button
				type="button"
				class="button"
				data-kidia-close-modal
			>
				<?php
					esc_html_e(
						'Cancel',
						'mobishop'
					);
					?>
			</button>

			<button
				type="button"
				class="button button-primary"
				id="kidia-library-create-submit"
				data-action="<?php echo esc_attr( $create_action ); ?>"
			>
				<?php
					esc_html_e(
						'Create',
						'mobishop'
					);
					?>
			</button>

		</div>

	</div>
</div>

<div
	id="kidia-library-delete-modal"
	class="kidia-library-modal"
	hidden
>
	<div
		class="kidia-library-modal__overlay"
		data-kidia-close-delete-modal
	></div>

	<div
		class="kidia-library-modal__panel"
		role="dialog"
		aria-modal="true"
		aria-labelledby="kidia-library-delete-title"
	>
		<div class="kidia-library-modal__header">

			<h2 id="kidia-library-delete-title">
				<?php
					esc_html_e(
						'Delete Item',
						'mobishop'
					);
					?>
			</h2>

			<button
				type="button"
				class="button-link kidia-library-modal__close"
				data-kidia-close-delete-modal
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

		<div class="kidia-library-modal__body">

			<p>
				<?php
					esc_html_e(
						'Are you sure you want to delete this item?',
						'mobishop'
					);
					?>
			</p>

			<p>
				<strong id="kidia-library-delete-name"></strong>
			</p>

		</div>

		<div class="kidia-library-modal__footer">

			<button
				type="button"
				class="button"
				data-kidia-close-delete-modal
			>
				<?php
					esc_html_e(
						'Cancel',
						'mobishop'
					);
					?>
			</button>

			<button
				type="button"
				class="button button-link-delete"
				id="kidia-library-delete-submit"
			>
				<?php
					esc_html_e(
						'Delete',
						'mobishop'
					);
					?>
			</button>

		</div>

	</div>
</div>

<form
	id="kidia-library-action-form"
	method="post"
	action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>"
	hidden
>
	<input
		type="hidden"
		name="action"
		id="kidia-library-form-action"
		value=""
	>

	<input
		type="hidden"
		name="id"
		id="kidia-library-form-id"
		value=""
	>

	<input
		type="hidden"
		name="name"
		id="kidia-library-form-name"
		value=""
	>

	<input
		type="hidden"
		name="_wpnonce"
		value="<?php
			echo esc_attr(
				wp_create_nonce(
					'kidia_library_action'
				)
			);
		?>"
	>
</form>