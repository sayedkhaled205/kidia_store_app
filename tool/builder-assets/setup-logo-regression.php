<?php
// Isolated regression for canonical Setup identity; no WordPress writes.
class MobiShop_Setup_Wizard {
    static function themes(){return ['kids_baby'=>['primary'=>'#000000','soft'=>'#ffffff']];}
    static function setup_pages(){return ['home'=>[]];}
    private function normalize_theme_key($key,$themes){return $key;}
    private function sanitize_enabled_pages($pages){return ['home'];}
    static function logo_crop($url){return [0.1,0.2,0.8,0.6,2];}
}
function sanitize_text_field($s){return $s;}
function sanitize_key($s){return $s;}
function sanitize_hex_color($s){return $s;}
function absint($v){return abs((int)$v);}
function get_bloginfo($s){return 'Test';}
function is_rtl(){return false;}
function esc_url_raw($s){return $s;}
function wp_get_attachment_image_url($id,$size){return 'https://example.test/logo.png';}
function get_option($key,$default){return $GLOBALS['saved'];}
require $argv[1];
$raw='https://example.test/logo.png';
$marked=$raw.'#wm=0.1,0.2,0.8,0.6,3';
$saved=['logo_url'=>$marked];
$base=['theme'=>'kids_baby','enabled_pages'=>['home'=>true],'logo_id'=>7,'logo_url'=>$raw];
$check=function($input,$expected,$label){
    $got=MobiShop_Central_Setup_Identity::prepare($input)['logo_url'];
    if($got!==$expected)throw new RuntimeException($label);
    echo "PASS $label\n";
};
$check($base,$marked,'reapply preserves saved artwork with attachment id');
$check(array_replace($base,['logo_url'=>$marked]),$marked,'explicit artwork survives canonicalization');
$saved=[];
$check($base,$raw.'#wm=0.1,0.2,0.8,0.6,2','first application detects artwork bounds');
$saved=['logo_url'=>$marked];
$check(array_replace($base,['logo_id'=>0,'logo_url'=>'https://example.test/new.png']),
    'https://example.test/new.png#wm=0.1,0.2,0.8,0.6,2','different logo does not inherit old geometry');
$check(array_replace($base,['logo_id'=>0,'logo_url'=>$raw.'#wm=0,0,9,9,999']),
    $raw.'#wm=0.1,0.2,0.8,0.6,2','invalid bounds are recalculated');
