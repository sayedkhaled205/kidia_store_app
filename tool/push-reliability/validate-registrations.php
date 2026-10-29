<?php
/** FCM dry-run only: never sends a customer notification. */
if (PHP_SAPI !== 'cli' || empty($argv[1])) exit(2);
require rtrim($argv[1],'/').'/wp-load.php';
$retire=in_array('--retire-expired',$argv,true);
$devices=get_option('mobishop_push_devices_v1',[]);
$counts=['valid'=>0,'expired'=>0,'other'=>0,'skipped_disabled'=>0];
$errors=[];
foreach ($devices as $device) {
    if (empty($device['enabled'])) { $counts['skipped_disabled']++; continue; }
    $result=MobiShop_Store_Notifications::request('messages','POST',[
        'target_type'=>'token','target'=>(string)$device['token'],
        'data'=>['diagnostic'=>'validation_only'],'validate_only'=>true,
    ]);
    if (!is_wp_error($result)) { $counts['valid']++; continue; }
    if ($result->get_error_code()==='push_token_unregistered') {
        $counts['expired']++;
        if ($retire) MobiShop_Push_Service::retire_expired_token((string)$device['token']);
    } else {
        $counts['other']++;
        $code=(string)$result->get_error_code();
        $errors[$code]=($errors[$code]??0)+1;
    }
}
echo json_encode(['validation_only'=>true,'retired_confirmed_expired'=>$retire,'counts'=>$counts,'error_codes'=>$errors]),"\n";
