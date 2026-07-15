<?php
/**
 * Admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-api-monitor.php';

final class Kidia_Mobile_CMS_Admin {

	/**
	 * Required capability.
	 *
	 * @var string
	 */
	private const CAPABILITY = 'manage_options';

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
			'admin_post_kidia_mobile_save_home_builder',
			array(
				$this,
				'save_home_builder',
			)
		);

	}
		/**
    	 * Registers admin pages.
    	 *
    	 * @return void
    	 */
    	public function register_menu(): void {

    		add_menu_page(
    			__( 'Kidia Mobile CMS', 'kidia-mobile-cms' ),
    			__( 'Kidia Mobile CMS', 'kidia-mobile-cms' ),
    			self::CAPABILITY,
    			'kidia-mobile-cms',
    			array(
    				$this,
    				'dashboard_page',
    			),
    			'dashicons-smartphone',
    			56
    		);

    		add_submenu_page(
    			'kidia-mobile-cms',
    			__( 'Dashboard', 'kidia-mobile-cms' ),
    			__( 'Dashboard', 'kidia-mobile-cms' ),
    			self::CAPABILITY,
    			'kidia-mobile-cms',
    			array(
    				$this,
    				'dashboard_page',
    			)
    		);

    		add_submenu_page(
    			'kidia-mobile-cms',
    			__( 'Home Builder', 'kidia-mobile-cms' ),
    			__( 'Home Builder', 'kidia-mobile-cms' ),
    			self::CAPABILITY,
    			'kidia-mobile-home-builder',
    			array(
    				$this,
    				'home_builder_page',
    			)
    		);

    	}

    	/**
    	 * Dashboard.
    	 *
    	 * @return void
    	 */
    	public function dashboard_page(): void {

    		if (
    			! current_user_can(
    				self::CAPABILITY
    			)
    		) {
    			wp_die(
    				esc_html__(
    					'You do not have permission to access this page.',
    					'kidia-mobile-cms'
    				)
    			);
    		}

    		$monitor = new Kidia_Mobile_CMS_API_Monitor();

    		$api = $monitor->get_status();

    		require
    			KIDIA_MOBILE_CMS_PATH .
    			'admin/pages/dashboard.php';
    	}
    		/**
        	 * Home Builder.
        	 *
        	 * @return void
        	 */
        	public function home_builder_page(): void {

        		if (
        			! current_user_can(
        				self::CAPABILITY
        			)
        		) {
        			wp_die(
        				esc_html__(
        					'You do not have permission to access this page.',
        					'kidia-mobile-cms'
        				)
        			);
        		}

        		$store = new Kidia_Mobile_Layout_Store();

        		$blocks = $store->get_layout();

        		$definitions =
        			Kidia_Mobile_Block_Registry::picker_definitions();

        		require
        			KIDIA_MOBILE_CMS_PATH .
        			'admin/pages/home-builder.php';
        	}

        	/**
        	 * Saves Home Builder.
        	 *
        	 * @return void
        	 */
        	public function save_home_builder(): void {

        		if (
        			! current_user_can(
        				self::CAPABILITY
        			)
        		) {
        			wp_die(
        				esc_html__(
        					'You do not have permission to perform this action.',
        					'kidia-mobile-cms'
        				)
        			);
        		}

        		check_admin_referer(
        			'kidia_mobile_save_home_builder',
        			'kidia_mobile_home_builder_nonce'
        		);

        		$submitted_blocks =
        			isset( $_POST['blocks'] )
        				? wp_unslash(
        					$_POST['blocks']
        				)
        				: array();

        		if (
        			! is_array(
        				$submitted_blocks
        			)
        		) {
        			$submitted_blocks = array();
        		}

        		$store = new Kidia_Mobile_Layout_Store();

        		$store->save_layout(
        			$submitted_blocks
        		);

        		wp_safe_redirect(
        			add_query_arg(
        				array(
        					'page'    =>
        						'kidia-mobile-home-builder',
        					'updated' => '1',
        				),
        				admin_url(
        					'admin.php'
        				)
        			)
        		);

        		exit;
        	}
        		/**
            	 * Loads Home Builder assets.
            	 *
            	 * @param string $hook_suffix Current admin page hook.
            	 *
            	 * @return void
            	 */
            	public function enqueue_assets(
            		string $hook_suffix
            	): void {

            		if (
            			'kidia-mobile-cms_page_kidia-mobile-home-builder'
            			!== $hook_suffix
            		) {
            			return;
            		}

            		wp_enqueue_media();

            		wp_enqueue_style(
            			'kidia-mobile-home-builder',
            			KIDIA_MOBILE_CMS_URL .
            			'admin/assets/home-builder.css',
            			array(),
            			KIDIA_MOBILE_CMS_VERSION
            		);

            		wp_enqueue_script(
            			'kidia-mobile-home-builder',
            			KIDIA_MOBILE_CMS_URL .
            			'admin/assets/home-builder.js',
            			array(),
            			KIDIA_MOBILE_CMS_VERSION,
            			true
            		);

            		wp_localize_script(
            			'kidia-mobile-home-builder',
            			'kidiaHomeBuilder',
            			array(
            				'labels' => array(
            					'deleteConfirm' => __(
            						'Delete this element?',
            						'kidia-mobile-cms'
            					),
            					'untitled'      => __(
            						'Untitled Element',
            						'kidia-mobile-cms'
            					),
            				),
            			)
            		);
            	}
            }