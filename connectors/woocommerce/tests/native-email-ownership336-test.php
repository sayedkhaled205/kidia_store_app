<?php
/** An authoritative provider email must not adopt a preclaimed store account. */
require __DIR__ . '/native-auth-contract-test.php';
$email = 'ownership-collision-fixture@gmail.com';
$verifier = str_repeat( 'e', 64 );
$phone = '+201299990001';
native_clear_rate();
$start = native_data( $endpoint->password( native_request( array( 'identifier'=>$email, 'password'=>'claimant-fixture-password', 'verifier'=>$verifier ) ) ), 'Claim unused email' );
$prepared = native_data( $endpoint->phone_enroll( native_request( array( 'phone'=>$phone, 'ticket'=>$start['ticket'], 'verifier'=>$verifier ) ) ), 'Prepare fixture contact' );
$confirmed = native_data( $endpoint->phone_confirm( native_request( array( 'phone'=>$phone, 'ticket'=>$prepared['ticket'], 'verifier'=>$verifier ) ) ), 'Confirm fixture contact' );
$claimed = native_data( $endpoint->register_customer( native_request( array( 'ticket'=>$confirmed['ticket'], 'verifier'=>$verifier, 'name'=>'Claimant fixture', 'password'=>'claimant-fixture-password' ) ) ), 'Create unverified email fixture' );
$claims = array_merge( native_google_claims( 'rightful-google-fixture-subject' ), array( 'email'=>$email ) );
native_clear_rate();
$issued_before = count( $GLOBALS['native_issued'] );
$result = $endpoint->google( native_request( array( 'id_token'=>native_jwt( $claims ), 'verifier'=>str_repeat( 'd', 64 ) ) ) );
$signed_in=native_data($result,'Verified Google subject signs in independently');
native_assert($signed_in['user_id']!==$claimed['user_id'] && get_user_by('id',$signed_in['user_id'])->user_email==='', 'New subject cannot adopt the preclaimed account or its email');
native_assert(NextendSocialLogin::$providers['google']->links['rightful-google-fixture-subject']===$signed_in['user_id'], 'Provider binds only its new customer');
native_assert(count($GLOBALS['native_issued'])===$issued_before+1 && $GLOBALS['native_users'][$claimed['user_id']]['password']==='claimant-fixture-password', 'Existing credentials preserved while independent customer signs in');
echo "Email ownership regression passed.\n";
