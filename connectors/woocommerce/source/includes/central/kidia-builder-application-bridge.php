<?php
defined('ABSPATH') || exit;
require_once __DIR__.'/kidia-builder-form-state.php';
require_once __DIR__.'/kidia-builder-application-commit.php';
require_once __DIR__.'/kidia-builder-setup-identity.php';
add_action('rest_api_init',static function(): void {
    register_rest_route('mobishop/v1','/builder/application-state',[
        'methods'=>WP_REST_Server::CREATABLE,
        'permission_callback'=>static fn(): bool => current_user_can('manage_options'),
        'callback'=>static function(WP_REST_Request $request) {
            $body=$request->get_json_params();
            if(!is_array($body)||!is_string($body['screen']??null)||!is_array($body['state']??null)||!is_bool($body['validate_only']??null)) return new WP_Error('invalid_builder_state','A valid application draft is required.',['status'=>400]);
            try {
                if($body['validate_only']) {
                    $plan=MobiShop_Central_Form_State::previewPage($body['screen'],$body['state']);
                    $result=['ok'=>true,'validated'=>true,'screen'=>$body['screen']];
                    if($body['screen']==='setup')$result['state']=MobiShop_Central_Application_Commit::canonicalState($body['state'],$plan);
                } else $result=MobiShop_Central_Application_Commit::apply($body['screen'],$body['state']);
                $response=rest_ensure_response($result);
                $response->header('Cache-Control','no-store, private');
                return $response;
            } catch(InvalidArgumentException|JsonException $error) {
                return new WP_Error('invalid_builder_state','Check the application fields before saving.',['status'=>400]);
            } catch(Throwable $error) {
                // No connector credentials, upstream bodies, customer data or SQL output.
                return new WP_Error('application_save_unconfirmed','Application persistence could not be confirmed.',['status'=>503]);
            }
        },
    ]);
});
