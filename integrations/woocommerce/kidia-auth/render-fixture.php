<?php
define('ABSPATH',__DIR__);
function esc_attr($s){return htmlspecialchars($s,ENT_QUOTES,'UTF-8');}function esc_html($s){return esc_attr($s);}function esc_url($s){return esc_attr($s);}function home_url($s=''){return 'https://example.test'.$s;}function get_permalink(){return 'https://example.test/login-register/';}function wp_nonce_field($a,$b){echo '<input type="hidden" name="'.esc_attr($b).'" value="fixture">';}
$logo_url='';$redirect_to='/';$phone_ready=false;$phone_html='';$social_html='<a class="kidia-google-provider">Google</a><a class="kidia-facebook-provider">Facebook</a>';$privacy_url='';$initial_email='';$initial_stage='';$initial_mode='';$initial_error='';$initial_phone='';$phone_error='';$setup_error='';$reset_sent=false;
$phone_setup_type=$argv[1]??'';$profile_details_collected=($argv[2]??'')==='collected';
ob_start();include __DIR__.'/website/content-login.php';$html=ob_get_clean();file_put_contents(__DIR__.'/fixture-'.($phone_setup_type?:'anonymous').($profile_details_collected?'-collected':'').'.html',$html);
