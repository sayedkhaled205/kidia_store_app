<?php
/** Execute the provider hook registrations with synthetic WordPress filters only. */
$source=$argv[1]??__DIR__.'/website/kidia-login-page.php';
$php=file_get_contents($source);
$hooks=array();
function add_filter($name,$callback,$priority=10,$accepted=1) { $GLOBALS['hooks'][$name][$priority][]=$callback; }
function __return_true() { return true; }
function __return_false() { return false; }
function policy_filter($name,$allowed) {
    $priorities=$GLOBALS['hooks'][$name]??array(); ksort($priorities);
    foreach($priorities as $callbacks) foreach($callbacks as $callback) $allowed=$callback($allowed,null,123);
    return $allowed;
}
// Load the real statements without booting shipping, WordPress, a browser or customer accounts.
preg_match_all("/add_filter\(\s*'nsl_(?:facebook|google)_auto_link_allowed'[^;]*;/s",$php,$matches);
if(count($matches[0])!==2) throw new RuntimeException('Expected explicit provider policy hooks');
foreach($matches[0] as $statement) eval($statement);
if(policy_filter('nsl_facebook_auto_link_allowed',true)!==false) throw new RuntimeException('Facebook matching email must require independent account proof');
if(policy_filter('nsl_facebook_auto_link_allowed',false)!==false) throw new RuntimeException('Facebook must preserve an earlier denied auto-link');
if(policy_filter('nsl_google_auto_link_allowed',true)!==true) throw new RuntimeException('Separate Google policy must remain unchanged');
echo 'Facebook website auto-link policy: 3 checks passed.'.PHP_EOL;
