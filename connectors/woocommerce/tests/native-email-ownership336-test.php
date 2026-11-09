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
native_rejected( $result, 'Unlinked Google subject cannot adopt an unverified preclaimed account' );
native_assert( $result->get_error_code() === 'mobishop_native_additional_proof_required', 'Existing account offers independent account proof' );
native_assert( ! isset( NextendSocialLogin::$providers['google']->links['rightful-google-fixture-subject'] ), 'Rejected collision leaves no provider link' );
native_assert( count( $GLOBALS['native_issued'] ) === $issued_before, 'Rejected collision issues no session' );
echo "Email ownership regression passed.\n";
