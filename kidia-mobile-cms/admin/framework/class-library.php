<?php
/**
 * Generic Library Controller.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Library', false ) ) {
	return;
}

final class Kidia_Mobile_Library {

	/**
	 * Option name.
	 *
	 * @var string
	 */
	private string $option_name;

	/**
	 * Page title.
	 *
	 * @var string
	 */
	private string $title;

	/**
	 * Menu slug.
	 *
	 * @var string
	 */
	private string $page_slug;

	/**
	 * Capability.
	 *
	 * @var string
	 */
	private string $capability;

	/**
	 * Schema file.
	 *
	 * @var string
	 */
	private string $schema;

	/**
	 * Create action.
	 *
	 * @var string
	 */
	private string $create_action;

	/**
	 * Save action.
	 *
	 * @var string
	 */
	private string $save_action;

	/**
	 * Duplicate action.
	 *
	 * @var string
	 */
	private string $duplicate_action;

	/**
	 * Delete action.
	 *
	 * @var string
	 */
	private string $delete_action;

	/**
	 * Constructor.
	 *
	 * @param string $option_name      Option name.
	 * @param string $title            Page title.
	 * @param string $page_slug        Menu slug.
	 * @param string $schema           Schema file.
	 * @param string $create_action    Create action.
	 * @param string $save_action      Save action.
	 * @param string $duplicate_action Duplicate action.
	 * @param string $delete_action    Delete action.
	 * @param string $capability       Capability.
	 */
	public function __construct(
		string $option_name,
		string $title,
		string $page_slug,
		string $schema,
		string $create_action,
		string $save_action,
		string $duplicate_action,
		string $delete_action,
		string $capability = 'manage_options'
	) {

		$this->option_name      = $option_name;
		$this->title            = $title;
		$this->page_slug        = $page_slug;
		$this->schema           = $schema;
		$this->create_action    = $create_action;
		$this->save_action      = $save_action;
		$this->duplicate_action = $duplicate_action;
		$this->delete_action    = $delete_action;
		$this->capability       = $capability;
	}

	/**
	 * Registers hooks.
	 *
	 * @return void
	 */
	public function register(): void {

		add_action(
			'admin_menu',
			array(
				$this,
				'register_menu',
			)
		);

		add_action(
			'admin_enqueue_scripts',
			array(
				$this,
				'enqueue_assets',
			)
		);

		add_action(
			'admin_post_' . $this->create_action,
			array(
				$this,
				'create',
			)
		);

		add_action(
			'admin_post_' . $this->save_action,
			array(
				$this,
				'save',
			)
		);

		add_action(
			'admin_post_' . $this->duplicate_action,
			array(
				$this,
				'duplicate',
			)
		);

		add_action(
			'admin_post_' . $this->delete_action,
			array(
				$this,
				'delete',
			)
		);

		add_action(
			'admin_post_' . $this->save_action . '_toggle_status',
			array(
				$this,
				'toggle_status',
			)
		);
	}
		/**
    	 * Registers submenu page.
    	 *
    	 * @return void
    	 */
    	public function register_menu(): void {

    		add_submenu_page(
    			'kidia-mobile-cms',
    			$this->title,
    			$this->title,
    			$this->capability,
    			$this->page_slug,
    			array(
    				$this,
    				'render',
    			)
    		);
    	}

    	/**
    	 * Renders library or editor page.
    	 *
    	 * @return void
    	 */
    	public function render(): void {

    		$this->assert_permission();

    		$items = $this->get_items();

    		$item_id = isset( $_GET['id'] )
    			? sanitize_text_field(
    				wp_unslash(
    					$_GET['id']
    				)
    			)
    			: '';

    		if ( '' !== $item_id ) {

    			$item = $this->find_item(
    				$item_id,
    				$items
    			);

    			if ( null === $item ) {
    				wp_die(
    					esc_html__(
    						'Item not found.',
    						'kidia-mobile-cms'
    					)
    				);
    			}

    			$schema = $this->load_schema();

    			$save_action = $this->save_action;

    			require
    				KIDIA_MOBILE_CMS_PATH .
    				'admin/framework/editor.php';

    			return;
    		}

    		$title            = $this->title;
    		$page_slug        = $this->page_slug;
    		$create_action    = $this->create_action;
    		$duplicate_action = $this->duplicate_action;
    		$delete_action    = $this->delete_action;
    		$status_action    = $this->save_action . '_toggle_status';

    		require
    			KIDIA_MOBILE_CMS_PATH .
    			'admin/framework/library.php';
    	}

    	/**
    	 * Loads framework assets only on this module page.
    	 *
    	 * @param string $hook_suffix Current admin hook.
    	 *
    	 * @return void
    	 */
    	public function enqueue_assets(
    		string $hook_suffix
    	): void {

    		$expected_hook =
    			'kidia-mobile-cms_page_' .
    			$this->page_slug;

    		if ( $expected_hook !== $hook_suffix ) {
    			return;
    		}

    		wp_enqueue_style(
    			'kidia-library',
    			KIDIA_MOBILE_CMS_URL .
    			'admin/framework/library.css',
    			array(),
    			KIDIA_MOBILE_CMS_VERSION
    		);

    		wp_enqueue_script(
    			'kidia-library',
    			KIDIA_MOBILE_CMS_URL .
    			'admin/framework/library.js',
    			array(),
    			KIDIA_MOBILE_CMS_VERSION,
    			true
    		);

    		wp_localize_script(
    			'kidia-library',
    			'kidiaLibrary',
    			array(
    				'adminPostUrl' => admin_url(
    					'admin-post.php'
    				),
    				'nonce' => wp_create_nonce(
    					'kidia_library_action'
    				),
    				'pageSlug' => $this->page_slug,
    				'labels' => array(
    					'create' => __(
    						'Enter item name',
    						'kidia-mobile-cms'
    					),
    					'delete' => __(
    						'Delete this item?',
    						'kidia-mobile-cms'
    					),
    				),
    			)
    		);

    		wp_enqueue_media();

    		wp_enqueue_style(
    			'kidia-editor',
    			KIDIA_MOBILE_CMS_URL .
    			'admin/framework/editor.css',
    			array(),
    			KIDIA_MOBILE_CMS_VERSION
    		);

    		wp_enqueue_script(
    			'kidia-editor',
    			KIDIA_MOBILE_CMS_URL .
    			'admin/framework/editor.js',
    			array(),
    			KIDIA_MOBILE_CMS_VERSION,
    			true
    		);
    	}
    		/**
        	 * Creates a new library item.
        	 *
        	 * @return void
        	 */
        	public function create(): void {

        		$this->assert_permission();

        		check_admin_referer(
        			'kidia_library_action'
        		);

        		$name = isset( $_POST['name'] )
        			? sanitize_text_field(
        				wp_unslash(
        					$_POST['name']
        				)
        			)
        			: '';

        		if ( '' === $name ) {
        			$name = __(
        				'Untitled Item',
        				'kidia-mobile-cms'
        			);
        		}

        		$schema = $this->load_schema();
        		$items  = $this->get_items();
        		$id     = $this->generate_id();

        		$items[] = array(
        			'id'         => $id,
        			'name'       => $name,
        			'status'     => 'draft',
        			'enabled'    => true,
        			'created_at' => current_time(
        				'mysql',
        				true
        			),
        			'updated_at' => current_time(
        				'mysql',
        				true
        			),
        			'settings'   => isset( $schema['defaults'] )
        				&& is_array( $schema['defaults'] )
        					? $schema['defaults']
        					: array(),
        		);

        		$this->update_items(
        			$items
        		);

        		$this->redirect_to_editor(
        			$id
        		);
        	}

        	/**
        	 * Saves an existing library item.
        	 *
        	 * @return void
        	 */
        	public function save(): void {

        		$this->assert_permission();

        		check_admin_referer(
        			'kidia_library_action'
        		);

        		$id = isset( $_POST['id'] )
        			? sanitize_text_field(
        				wp_unslash(
        					$_POST['id']
        				)
        			)
        			: '';

        		if ( '' === $id ) {
        			wp_die(
        				esc_html__(
        					'Invalid item ID.',
        					'kidia-mobile-cms'
        				)
        			);
        		}

        		$name = isset( $_POST['name'] )
        			? sanitize_text_field(
        				wp_unslash(
        					$_POST['name']
        				)
        			)
        			: '';

        		if ( '' === $name ) {
        			$name = __(
        				'Untitled Item',
        				'kidia-mobile-cms'
        			);
        		}

        		$status = isset( $_POST['status'] )
        			? sanitize_key(
        				wp_unslash(
        					$_POST['status']
        				)
        			)
        			: 'draft';

        		if (
        			! in_array(
        				$status,
        				array(
        					'draft',
        					'published',
        				),
        				true
        			)
        		) {
        			$status = 'draft';
        		}

        		$submitted_settings = isset( $_POST['settings'] )
        			&& is_array( $_POST['settings'] )
        				? wp_unslash(
        					$_POST['settings']
        				)
        				: array();

        		$schema   = $this->load_schema();
        		$settings = $this->sanitize_settings(
        			$submitted_settings,
        			$schema
        		);

        		$items = $this->get_items();
        		$found = false;

        		foreach ( $items as &$item ) {

        			if (
        				! isset( $item['id'] )
        				|| $item['id'] !== $id
        			) {
        				continue;
        			}

        			$item['name']       = $name;
        			$item['status']     = $status;
        			$item['enabled']    = isset(
        				$_POST['enabled']
        			);
        			$item['settings']   = $settings;
        			$item['updated_at'] = current_time(
        				'mysql',
        				true
        			);

        			$found = true;

        			break;
        		}

        		unset( $item );

        		if ( ! $found ) {
        			wp_die(
        				esc_html__(
        					'Item not found.',
        					'kidia-mobile-cms'
        				)
        			);
        		}

        		$this->update_items(
        			$items
        		);

        		$this->redirect_to_editor(
        			$id,
        			array(
        				'updated' => '1',
        			)
        		);
        	}

        	/**
        	 * Duplicates an existing library item.
        	 *
        	 * @return void
        	 */
        	public function duplicate(): void {

        		$this->assert_permission();

        		check_admin_referer(
        			'kidia_library_action'
        		);

        		$id = isset( $_REQUEST['id'] )
        			? sanitize_text_field(
        				wp_unslash(
        					$_REQUEST['id']
        				)
        			)
        			: '';

        		$items  = $this->get_items();
        		$source = $this->find_item(
        			$id,
        			$items
        		);

        		if ( null === $source ) {
        			wp_die(
        				esc_html__(
        					'Item not found.',
        					'kidia-mobile-cms'
        				)
        			);
        		}

        		$copy               = $source;
        		$copy['id']         = $this->generate_id();
        		$copy['name']       = sprintf(
        			/* translators: %s: original item name. */
        			__(
        				'%s Copy',
        				'kidia-mobile-cms'
        			),
        			(string) $source['name']
        		);
        		$copy['status']     = 'draft';
        		$copy['created_at'] = current_time(
        			'mysql',
        			true
        		);
        		$copy['updated_at'] = current_time(
        			'mysql',
        			true
        		);

        		$items[] = $copy;

        		$this->update_items(
        			$items
        		);

        		$this->redirect_to_library(
        			array(
        				'duplicated' => '1',
        			)
        		);
        	}
        		/**
        	 * Toggles an item's publishing status.
        	 *
        	 * @return void
        	 */
        	public function toggle_status(): void {

        		$this->assert_permission();

        		check_admin_referer(
        			'kidia_library_action'
        		);

        		$id = isset( $_POST['id'] )
        			? sanitize_text_field(
        				wp_unslash( $_POST['id'] )
        			)
        			: '';

        		$items = $this->get_items();
        		$found = false;

        		foreach ( $items as &$item ) {

        			if (
        				! isset( $item['id'] )
        				|| $item['id'] !== $id
        			) {
        				continue;
        			}

        			$current_status = isset( $item['status'] )
        				? sanitize_key( (string) $item['status'] )
        				: 'draft';

        			$item['status'] = 'published' === $current_status
        				? 'draft'
        				: 'published';

        			$item['updated_at'] = current_time(
        				'mysql',
        				true
        			);

        			$found = true;
        			break;
        		}

        		unset( $item );

        		if ( ! $found ) {
        			wp_die(
        				esc_html__(
        					'Item not found.',
        					'kidia-mobile-cms'
        				)
        			);
        		}

        		$this->update_items( $items );

        		$this->redirect_to_library(
        			array(
        				'status_updated' => '1',
        			)
        		);
        	}

        		/**
            	 * Deletes a library item.
            	 *
            	 * @return void
            	 */
            	public function delete(): void {

            		$this->assert_permission();

            		check_admin_referer(
            			'kidia_library_action'
            		);

            		$id = isset( $_REQUEST['id'] )
            			? sanitize_text_field(
            				wp_unslash(
            					$_REQUEST['id']
            				)
            			)
            			: '';

            		$items = array_filter(
            			$this->get_items(),
            			static function ( array $item ) use ( $id ): bool {
            				return isset( $item['id'] )
            					&& $item['id'] !== $id;
            			}
            		);

            		$this->update_items(
            			array_values( $items )
            		);

            		$this->redirect_to_library();
            	}

            	/**
            	 * Returns all stored items.
            	 *
            	 * @return array<int,array<string,mixed>>
            	 */
            	public function get_items(): array {

            		$items = get_option(
            			$this->option_name,
            			array()
            		);

            		if ( ! is_array( $items ) ) {
            			return array();
            		}

            		return array_values(
            			$items
            		);
            	}

            	/**
            	 * Updates items.
            	 *
            	 * @param array<int,array<string,mixed>> $items Items.
            	 *
            	 * @return void
            	 */
            	private function update_items(
            		array $items
            	): void {

            		update_option(
            			$this->option_name,
            			$items,
            			false
            		);
            	}

            	/**
            	 * Finds item by id.
            	 *
            	 * @param string                           $id    Item id.
            	 * @param array<int,array<string,mixed>>   $items Items.
            	 *
            	 * @return array<string,mixed>|null
            	 */
            	private function find_item(
            		string $id,
            		array $items
            	): ?array {

            		foreach ( $items as $item ) {

            			if (
            				isset( $item['id'] )
            				&& $item['id'] === $id
            			) {
            				return $item;
            			}
            		}

            		return null;
            	}

            	/**
            	 * Loads schema.
            	 *
            	 * @return array<string,mixed>
            	 */
            	private function load_schema(): array {

            		$file =
            			KIDIA_MOBILE_CMS_PATH .
            			'includes/schema/' .
            			$this->schema .
            			'.php';

            		if ( ! file_exists( $file ) ) {
            			return array(
            				'defaults' => array(),
            				'fields'   => array(),
            			);
            		}

            		$schema = require $file;

            		return is_array( $schema )
            			? $schema
            			: array(
            				'defaults' => array(),
            				'fields'   => array(),
            			);
            	}

            	/**
            	 * Sanitizes settings.
            	 *
            	 * @param array<string,mixed> $settings Submitted settings.
            	 * @param array<string,mixed> $schema   Schema.
            	 *
            	 * @return array<string,mixed>
            	 */
            	private function sanitize_settings(
            		array $settings,
            		array $schema
            	): array {

            		if (
            			empty( $schema['fields'] )
            			|| ! is_array( $schema['fields'] )
            		) {
            			return $settings;
            		}

            		$clean = array();

            		foreach ( $schema['fields'] as $field ) {

            			if (
            				empty( $field['key'] )
            			) {
            				continue;
            			}

            			$key = (string) $field['key'];

							$field_type = (string) ( $field['type'] ?? 'text' );
							$value      = array_key_exists( $key, $settings )
								? $settings[ $key ]
								: ( $field['default'] ?? '' );

							if ( 'gallery' === $field_type ) {
            				$clean[ $key ] = array();

            				if ( is_array( $value ) ) {
            					foreach ( $value as $index => $gallery_item ) {
            						$image_url = is_array( $gallery_item )
            							? esc_url_raw( (string) ( $gallery_item['image_url'] ?? '' ) )
            							: esc_url_raw( (string) $gallery_item );

            						if ( '' === $image_url ) {
            							continue;
            						}

											$clean[ $key ][] = array(
												'id'           => sanitize_key( (string) ( is_array( $gallery_item ) ? ( $gallery_item['id'] ?? '' ) : '' ) ) ?: 'hero_slide_' . substr( md5( $image_url ), 0, 12 ),
												'enabled'      => ! is_array( $gallery_item ) || ! array_key_exists( 'enabled', $gallery_item ) || ! empty( $gallery_item['enabled'] ),
												'image_url'    => $image_url,
												'attachment_id'=> absint( is_array( $gallery_item ) ? ( $gallery_item['attachment_id'] ?? 0 ) : 0 ),
												'title'        => sanitize_text_field( (string) ( is_array( $gallery_item ) ? ( $gallery_item['title'] ?? '' ) : '' ) ),
												'subtitle'     => sanitize_textarea_field( (string) ( is_array( $gallery_item ) ? ( $gallery_item['subtitle'] ?? '' ) : '' ) ),
												'action_type'  => sanitize_key( (string) ( is_array( $gallery_item ) ? ( $gallery_item['action_type'] ?? '' ) : '' ) ),
												'action_value' => sanitize_text_field( (string) ( is_array( $gallery_item ) ? ( $gallery_item['action_value'] ?? '' ) : '' ) ),
											);
            					}
            				}

            				continue;
            			}

							if ( 'entity_select' === $field_type ) {
								$ids = is_array( $value )
									? $value
									: preg_split( '/[\s,]+/', (string) $value );
								$ids = array_values( array_unique( array_filter( array_map( 'absint', (array) $ids ) ) ) );
								$clean[ $key ] = ! empty( $field['multiple'] )
									? implode( ',', $ids )
									: ( ! empty( $ids ) ? (int) reset( $ids ) : 0 );
								continue;
							}

							switch ( $field_type ) {

								case 'number':
									$number = (float) $value;
									if ( isset( $field['min'] ) ) {
										$number = max( (float) $field['min'], $number );
									}
									if ( isset( $field['max'] ) ) {
										$number = min( (float) $field['max'], $number );
									}
									$clean[ $key ] = $number;
            					break;

            				case 'checkbox':
            					$clean[ $key ] = ! empty( $value );
            					break;

								case 'url':
								case 'image':
								case 'video':
            					$clean[ $key ] =
            						esc_url_raw(
            							(string) $value
            						);
            					break;

								case 'textarea':
            					$clean[ $key ] =
            						sanitize_textarea_field(
            							(string) $value
            						);
									break;

								case 'richtext':
									$clean[ $key ] = wp_kses_post( (string) $value );
									break;

								case 'color':
									$clean[ $key ] = sanitize_hex_color( (string) $value ) ?: '';
									break;

								case 'select':
									$select_value = sanitize_key( (string) $value );
									$options = isset( $field['options'] ) && is_array( $field['options'] )
										? $field['options']
										: array();
									$clean[ $key ] = array_key_exists( $select_value, $options )
										? $select_value
										: sanitize_key( (string) ( $field['default'] ?? '' ) );
									break;

            				default:
            					$clean[ $key ] =
            						sanitize_text_field(
            							(string) $value
            						);
            					break;
            			}
            		}

							if ( class_exists( 'Kidia_Mobile_Block_Registry' ) ) {
								$block = Kidia_Mobile_Block_Registry::get_block( $this->schema );

								if ( $block instanceof Kidia_Mobile_Block ) {
									return $block->sanitize_settings( $clean );
								}
							}

							return $clean;
            	}
            		/**
                	 * Verifies current user capability.
                	 *
                	 * @return void
                	 */
                	private function assert_permission(): void {

                		if (
                			! current_user_can(
                				$this->capability
                			)
                		) {
                			wp_die(
                				esc_html__(
                					'You do not have permission to perform this action.',
                					'kidia-mobile-cms'
                				)
                			);
                		}
                	}

                	/**
                	 * Generates a unique item ID.
                	 *
                	 * @return string
                	 */
                	private function generate_id(): string {

                		$id = function_exists(
                			'wp_generate_uuid4'
                		)
                			? wp_generate_uuid4()
                			: uniqid(
                				'kidia_',
                				true
                			);

                		return sanitize_key(
                			str_replace(
                				array(
                					'-',
                					'.',
                				),
                				'',
                				$id
                			)
                		);
                	}

                	/**
                	 * Redirects to the library page.
                	 *
                	 * @param array<string,string> $arguments Additional query arguments.
                	 *
                	 * @return void
                	 */
                	private function redirect_to_library(
                		array $arguments = array()
                	): void {

                		$query = array_merge(
                			array(
                				'page' => $this->page_slug,
                			),
                			$arguments
                		);

                		wp_safe_redirect(
                			add_query_arg(
                				$query,
                				admin_url(
                					'admin.php'
                				)
                			)
                		);

                		exit;
                	}

                	/**
                	 * Redirects to the item editor.
                	 *
                	 * @param string               $id        Item ID.
                	 * @param array<string,string> $arguments Additional query arguments.
                	 *
                	 * @return void
                	 */
                	private function redirect_to_editor(
                		string $id,
                		array $arguments = array()
                	): void {

                		$query = array_merge(
                			array(
                				'page' => $this->page_slug,
                				'id'   => $id,
                			),
                			$arguments
                		);

                		wp_safe_redirect(
                			add_query_arg(
                				$query,
                				admin_url(
                					'admin.php'
                				)
                			)
                		);

                		exit;
                	}
                }
