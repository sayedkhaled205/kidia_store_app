<?php
/** Completion checks inside the existing identity lease; no real accounts/network. */
require __DIR__ . '/native-auth-contract-test.php';
$before_checks = $GLOBALS['native_checks'];
$verifier = str_repeat('f',64);
foreach (array('password_reset','completed_profile','elevated_account') as $index=>$scenario) {
    native_clear_rate();
    $id = 9001 + $index;
    $email = 'completion-fixture-'.$id.'@example.test';
    $phone = '+20109999999'.$index;
    $GLOBALS['native_users'][$id] = array('login'=>'fixture-'.$id,'email'=>$email,'password'=>'original-fixture-password','name'=>'Pending fixture','roles'=>array('customer'));
    $GLOBALS['native_meta'][$id] = array('kidia_login_phone'=>$phone,'kidia_phone_setup_required'=>'account');
    $start = native_data($endpoint->password(native_request(array('identifier'=>$email,'password'=>'original-fixture-password','verifier'=>$verifier))), 'Pending '.$scenario);
    $verified = native_data(native_phone($endpoint,$verifier,$phone,array('ticket'=>$start['ticket'])), 'Phone '.$scenario);
    native_clear_rate();
    $after_concurrent = null;
    $issued_before = count($GLOBALS['native_issued']);
    $GLOBALS['on_native_lock'] = static function() use($id,$scenario,&$after_concurrent) {
        unset($GLOBALS['on_native_lock']);
        if ($scenario === 'password_reset') $GLOBALS['native_users'][$id]['password'] = 'concurrent-reset-password';
        if ($scenario === 'completed_profile') delete_user_meta($id,'kidia_phone_setup_required');
        if ($scenario === 'elevated_account') $GLOBALS['native_users'][$id]['roles'] = array('administrator');
        $after_concurrent = $GLOBALS['native_users'][$id];
    };
    $result = $endpoint->register_customer(native_request(array('ticket'=>$verified['ticket'],'verifier'=>$verifier,'name'=>'Old pending flow','password'=>'stale-flow-password')));
    native_rejected($result, 'Reject stale '.$scenario.' completion');
    native_assert($GLOBALS['native_users'][$id] === $after_concurrent, 'Preserve concurrent '.$scenario.' data');
    native_assert(count($GLOBALS['native_issued']) === $issued_before, 'Do not issue stale '.$scenario.' session');
}
echo 'Native completion races: '.($GLOBALS['native_checks']-$before_checks).' checks passed.'.PHP_EOL;
