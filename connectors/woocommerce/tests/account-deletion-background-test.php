<?php
/** Simulated FPM response flush, never a real background or account operation. */
function fastcgi_finish_request(): bool {
    $GLOBALS['fixture_response_flushes'] = ($GLOBALS['fixture_response_flushes'] ?? 0) + 1;
    return $GLOBALS['fixture_flush_succeeds'] ?? true;
}
require __DIR__ . '/account-deletion-test.php';
deletion_reset();$GLOBALS['mobishop_actions']['shutdown']=[];
$result=$deletion->request_deletion(deletion_request(deletion_login()));
mobishop_auth_assert($result->status===202&&isset($GLOBALS['mobishop_users'][7]),'Accepted HTTP response precedes background cleanup.');
mobishop_auth_assert(count($GLOBALS['mobishop_actions']['shutdown'])===1,'Only the accepted self-deletion schedules response-side work.');
($GLOBALS['mobishop_actions']['shutdown'][0])();
mobishop_auth_assert($GLOBALS['fixture_response_flushes']===1&&!isset($GLOBALS['mobishop_users'][7]),'Flushing the response starts the bounded worker.');
mobishop_auth_assert(deletion_status()->data['status']==='completed','Immediate work retains the same durable completion receipt.');
deletion_reset();$GLOBALS['mobishop_actions']['shutdown']=[];$GLOBALS['fixture_flush_succeeds']=false;
$deletion->request_deletion(deletion_request(deletion_login()));
($GLOBALS['mobishop_actions']['shutdown'][0])();
mobishop_auth_assert(isset($GLOBALS['mobishop_users'][7])&&MobiShop_Customer_Account_Deletion::is_pending(7),'Failed flush leaves accepted job for the existing cron fallback.');
deletion_tick();mobishop_auth_assert(!isset($GLOBALS['mobishop_users'][7]),'Cron still completes if immediate kickoff is unavailable.');
deletion_reset();$GLOBALS['mobishop_actions']['shutdown']=[];
$rejected=$deletion->request_deletion(deletion_request(deletion_login(),['confirmation'=>'invalid']));
mobishop_auth_assert(is_wp_error($rejected)&&!$GLOBALS['mobishop_actions']['shutdown'],'Rejected requests schedule no background work.');
echo "Account deletion background kickoff checks passed.\n";
