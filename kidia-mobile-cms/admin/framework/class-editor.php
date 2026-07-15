<?php
/**
 * Generic Editor Controller.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Editor', false ) ) {
	return;
}

final class Kidia_Mobile_Editor {

	/**
	 * Schema.
	 *
	 * @var array<string,mixed>
	 */
	private array $schema;

	/**
	 * Item.
	 *
	 * @var array<string,mixed>
	 */
	private array $item;

	/**
	 * Save action.
	 *
	 * @var string
	 */
	private string $save_action;

	/**
	 * Constructor.
	 *
	 * @param array<string,mixed> $schema      Schema.
	 * @param array<string,mixed> $item        Item.
	 * @param string              $save_action Save action.
	 */
	public function __construct(
		array $schema,
		array $item,
		string $save_action
	) {

		$this->schema = $schema;
		$this->item = $item;
		$this->save_action = $save_action;
	}

	/**
	 * Renders editor.
	 *
	 * @return void
	 */
	public function render(): void {

		$schema = $this->schema;

		$item = $this->item;

		$save_action = $this->save_action;

		require
			KIDIA_MOBILE_CMS_PATH .
			'admin/framework/editor.php';
	}

	/**
	 * Enqueues assets.
	 *
	 * @return void
	 */
	public function enqueue_assets(): void {

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

		wp_localize_script(
			'kidia-editor',
			'kidiaEditor',
			array(
				'nonce' => wp_create_nonce(
					'kidia_editor'
				),
			)
		);
	}
		/**
    	 * Returns schema.
    	 *
    	 * @return array<string,mixed>
    	 */
    	public function get_schema(): array {
    		return $this->schema;
    	}

    	/**
    	 * Returns current item.
    	 *
    	 * @return array<string,mixed>
    	 */
    	public function get_item(): array {
    		return $this->item;
    	}

    	/**
    	 * Returns save action.
    	 *
    	 * @return string
    	 */
    	public function get_save_action(): string {
    		return $this->save_action;
    	}

    	/**
    	 * Returns editor title.
    	 *
    	 * @return string
    	 */
    	public function get_title(): string {

    		if ( ! empty( $this->schema['title'] ) ) {
    			return (string) $this->schema['title'];
    		}

    		return __( 'Editor', 'kidia-mobile-cms' );
    	}

    	/**
    	 * Returns editor fields.
    	 *
    	 * @return array<int,array<string,mixed>>
    	 */
    	public function get_fields(): array {

    		if (
    			empty( $this->schema['fields'] )
    			|| ! is_array( $this->schema['fields'] )
    		) {
    			return array();
    		}

    		return $this->schema['fields'];
    	}

    	/**
    	 * Returns item setting.
    	 *
    	 * @param string $key Setting key.
    	 * @param mixed  $default Default value.
    	 *
    	 * @return mixed
    	 */
    	public function get_setting(
    		string $key,
    		$default = ''
    	) {

    		if (
    			! isset(
    				$this->item['settings']
    			)
    			|| ! is_array(
    				$this->item['settings']
    			)
    		) {
    			return $default;
    		}

    		return $this->item['settings'][ $key ]
    			?? $default;
    	}

    	/**
    	 * Checks whether setting is enabled.
    	 *
    	 * @param string $key Setting key.
    	 *
    	 * @return bool
    	 */
    	public function is_checked(
    		string $key
    	): bool {

    		return ! empty(
    			$this->item['settings'][ $key ]
    		);
    	}

    	/**
    	 * Returns item id.
    	 *
    	 * @return string
    	 */
    	public function get_id(): string {

    		return isset( $this->item['id'] )
    			? (string) $this->item['id']
    			: '';
    	}

    	/**
    	 * Returns item name.
    	 *
    	 * @return string
    	 */
    	public function get_name(): string {

    		return isset( $this->item['name'] )
    			? (string) $this->item['name']
    			: '';
    	}

    	/**
    	 * Returns item status.
    	 *
    	 * @return string
    	 */
    	public function get_status(): string {

    		return isset( $this->item['status'] )
    			? (string) $this->item['status']
    			: 'draft';
    	}
    		/**
        	 * Returns all editor tabs.
        	 *
        	 * @return array<int,array<string,mixed>>
        	 */
        	public function get_tabs(): array {

        		if (
        			empty( $this->schema['tabs'] )
        			|| ! is_array(
        				$this->schema['tabs']
        			)
        		) {
        			return array(
        				array(
        					'id' => 'general',
        					'label' => __(
        						'General',
        						'kidia-mobile-cms'
        					),
        				),
        			);
        		}

        		return $this->schema['tabs'];
        	}

        	/**
        	 * Returns fields for one tab.
        	 *
        	 * @param string $tab_id Tab ID.
        	 *
        	 * @return array<int,array<string,mixed>>
        	 */
        	public function get_tab_fields(
        		string $tab_id
        	): array {

        		$fields = $this->get_fields();

        		$result = array();

        		foreach ( $fields as $field ) {

        			$field_tab = isset(
        				$field['tab']
        			)
        				? (string) $field['tab']
        				: 'general';

        			if ( $field_tab !== $tab_id ) {
        				continue;
        			}

        			$result[] = $field;
        		}

        		return $result;
        	}

        	/**
        	 * Checks whether a tab contains fields.
        	 *
        	 * @param string $tab_id Tab ID.
        	 *
        	 * @return bool
        	 */
        	public function has_tab(
        		string $tab_id
        	): bool {

        		return ! empty(
        			$this->get_tab_fields(
        				$tab_id
        			)
        		);
        	}

        	/**
        	 * Returns editor description.
        	 *
        	 * @return string
        	 */
        	public function get_description(): string {

        		return isset(
        			$this->schema['description']
        		)
        			? (string) $this->schema['description']
        			: '';
        	}

        	/**
        	 * Returns editor icon.
        	 *
        	 * @return string
        	 */
        	public function get_icon(): string {

        		return isset(
        			$this->schema['icon']
        		)
        			? (string) $this->schema['icon']
        			: 'dashicons-admin-generic';
        	}
        		/**
            	 * Returns field value.
            	 *
            	 * @param array<string,mixed> $field Field definition.
            	 *
            	 * @return mixed
            	 */
            	public function get_field_value(
            		array $field
            	) {

            		$key = isset( $field['key'] )
            			? (string) $field['key']
            			: '';

            		if ( '' === $key ) {
            			return '';
            		}

            		$default = $field['default'] ?? '';

            		return $this->get_setting(
            			$key,
            			$default
            		);
            	}

            	/**
            	 * Returns field label.
            	 *
            	 * @param array<string,mixed> $field Field.
            	 *
            	 * @return string
            	 */
            	public function get_field_label(
            		array $field
            	): string {

            		return isset( $field['label'] )
            			? (string) $field['label']
            			: '';
            	}

            	/**
            	 * Returns field description.
            	 *
            	 * @param array<string,mixed> $field Field.
            	 *
            	 * @return string
            	 */
            	public function get_field_description(
            		array $field
            	): string {

            		return isset( $field['description'] )
            			? (string) $field['description']
            			: '';
            	}

            	/**
            	 * Returns field type.
            	 *
            	 * @param array<string,mixed> $field Field.
            	 *
            	 * @return string
            	 */
            	public function get_field_type(
            		array $field
            	): string {

            		return isset( $field['type'] )
            			? (string) $field['type']
            			: 'text';
            	}

            	/**
            	 * Returns select options.
            	 *
            	 * @param array<string,mixed> $field Field.
            	 *
            	 * @return array<string,string>
            	 */
            	public function get_field_options(
            		array $field
            	): array {

            		if (
            			empty( $field['options'] )
            			|| ! is_array(
            				$field['options']
            			)
            		) {
            			return array();
            		}

            		return $field['options'];
            	}

            	/**
            	 * Checks whether field is required.
            	 *
            	 * @param array<string,mixed> $field Field.
            	 *
            	 * @return bool
            	 */
            	public function is_required(
            		array $field
            	): bool {

            		return ! empty(
            			$field['required']
            		);
            	}

            	/**
            	 * Checks whether field is repeatable.
            	 *
            	 * @param array<string,mixed> $field Field.
            	 *
            	 * @return bool
            	 */
            	public function is_repeatable(
            		array $field
            	): bool {

            		return ! empty(
            			$field['repeatable']
            		);
            	}
            }