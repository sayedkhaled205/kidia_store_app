<?php
/** Provider names are cosmetic, sanitized, and never an identity/linking proof. */
require __DIR__ . '/native-social-direct-test.php';
$before_names = $GLOBALS['native_checks'];
function named_social($kind, $sub, $name, $platform = 'ios', $request_name = null, $invalid = false) {
    global $endpoint;
    native_clear_rate();
    if ($kind === 'facebook') {
        facebook_http_fixture($sub);
        $GLOBALS['facebook_me']['name'] = $name;
        $challenge = facebook_challenge($platform);
        $claims = facebook_claims($challenge, $sub);
        $claims['name'] = $name;
        if ($invalid) $claims['nonce'] = 'wrong';
        return facebook_exchange($challenge, $platform === 'ios' ? ['id_token' => native_jwt($claims)] : ['access_token' => 'fixture-access-token'], $platform);
    }
    $claims = $kind === 'google' ? array_replace(native_google_claims($sub), ['azp' => 'web.apps.googleusercontent.com']) : [
        'aud'=>'test-project','iss'=>'https://securetoken.google.com/test-project','sub'=>'firebase-'.$sub,'iat'=>time(),'exp'=>time()+3600,'auth_time'=>time(),
        'firebase'=>['sign_in_provider'=>'apple.com','identities'=>['apple.com'=>[$sub]]],
    ];
    if ($name !== null) $claims['name'] = $name;
    if ($invalid) $claims['aud'] = 'wrong';
    return $endpoint->$kind(native_request(['platform'=>$platform,'verifier'=>str_repeat('a',64),'id_token'=>native_jwt($claims),'name'=>$request_name]));
}
foreach ([['google','names-google','ios'],['apple','names-apple','ios'],['facebook','998001','ios'],['facebook','998002','android']] as [$kind,$sub,$platform]) {
    $result = native_data(named_social($kind,$sub,'Provider Person',$platform), 'Named social login');
    $id = $result['user_id'];
    native_assert(get_user_by('id',$id)->display_name === 'Provider Person', 'New '.$kind.' '.$platform.' saves provider name');
    $GLOBALS['native_users'][$id]['name'] = 'Customer';
    native_data(named_social($kind,$sub,'Recovered Person',$platform), 'Returning placeholder name');
    native_assert(get_user_by('id',$id)->display_name === 'Recovered Person', 'Returning placeholder repaired');
    $GLOBALS['native_users'][$id]['name'] = 'My chosen name';
    native_data(named_social($kind,$sub,'Different Provider Name',$platform), 'Preserve chosen name');
    native_assert(get_user_by('id',$id)->display_name === 'My chosen name', 'Meaningful customer name is never overwritten');
    $GLOBALS['native_users'][$id]['name'] = 'Customer';
    if ($platform === 'ios') {
        native_rejected(named_social($kind,$sub,'Untrusted',$platform,null,true), 'Invalid provider proof');
        native_assert(get_user_by('id',$id)->display_name === 'Customer', 'Invalid proof cannot change profile');
    }
}
$id = native_data(named_social('apple','apple-sdk-name',null,'ios','SDK Person'), 'Apple SDK profile')['user_id'];
native_assert(get_user_by('id',$id)->display_name === 'SDK Person', 'Existing native Apple name payload works without signed name');
$id = native_data(named_social('apple','apple-signed-name','Signed Person','ios','Different Payload'), 'Apple signed name')['user_id'];
native_assert(get_user_by('id',$id)->display_name === 'Signed Person', 'Signed name takes precedence');
foreach ([null, [], str_repeat('x',121), ''] as $i=>$bad) {
    $id = native_data(named_social('apple','apple-bad-name-'.$i,$bad,'ios'), 'Optional invalid name')['user_id'];
    native_assert(get_user_by('id',$id)->display_name === 'Customer', 'Invalid optional name does not block login or fabricate identity');
}
$id = native_data(named_social('facebook','998003','<b>Clean Person</b>','android'), 'Sanitized provider name')['user_id'];
native_assert(get_user_by('id',$id)->display_name === 'Clean Person', 'Provider markup is stripped');
echo 'Social profile names: '.($GLOBALS['native_checks']-$before_names).' additional checks passed.'.PHP_EOL;
