<?php
/** Decodes central-builder form pairs without PHP max_input_vars truncation. */
final class MobiShop_Central_Form_State
{
    public static function decode(array $entries): array
    {
        if (count($entries) > 10000) throw new InvalidArgumentException('Too many builder fields.');
        $result = []; $bytes = 0;
        foreach ($entries as $pair) {
            if (!is_array($pair) || array_keys($pair) !== [0,1] || !is_string($pair[0]) || !is_string($pair[1])) throw new InvalidArgumentException('Invalid form pair.');
            [$name,$value] = $pair;
            $bytes += strlen($name)+strlen($value);
            if ($bytes > 2097152 || strlen($name) > 240 || strlen($value) > 1048576) throw new InvalidArgumentException('Builder draft too large.');
            if (!preg_match('/^[A-Za-z_][A-Za-z0-9_-]*(?:\[[A-Za-z0-9_-]*\])*$/D',$name)) throw new InvalidArgumentException('Invalid field name.');
            preg_match_all('/^([A-Za-z_][A-Za-z0-9_-]*)|\[([A-Za-z0-9_-]*)\]/',$name,$matches,PREG_SET_ORDER);
            $keys = array_map(static fn($m) => $m[1] !== '' ? $m[1] : ($m[2] ?? ''),$matches);
            if (count($keys)>12) throw new InvalidArgumentException('Builder field nesting too deep.');
            $cursor =& $result;
            foreach ($keys as $index=>$key) {
                if ($key === '') {
                    if ($index !== count($keys)-1) throw new InvalidArgumentException('Ambiguous array field.');
                    $cursor[] = $value;
                    continue;
                }
                if ($index === count($keys)-1) {
                    if (isset($cursor[$key]) && is_array($cursor[$key])) throw new InvalidArgumentException('Conflicting group and scalar.');
                    $cursor[$key] = $value; continue;
                }
                if (isset($cursor[$key]) && !is_array($cursor[$key])) throw new InvalidArgumentException('Conflicting scalar and group.');
                if (!isset($cursor[$key])) $cursor[$key] = [];
                $cursor =& $cursor[$key];
            }
            unset($cursor);
        }
        return $result;
    }

    /** Reuses the native application's existing sanitizer; performs no writes. */
    public static function previewPage(string $screen,array $state): array
    {
        $pages = ['home-builder'=>'home','category-builder'=>'category','catalog-builder'=>'catalog','product-builder'=>'product','size-chart-builder'=>'size_chart','wishlist-builder'=>'wishlist','account-builder'=>'account','checkout-builder'=>'checkout','splash'=>'splash','website-promotion'=>'website-promotion','setup'=>'setup'];
        if (!isset($pages[$screen])) throw new InvalidArgumentException('Unknown shared application page.');
        if (!isset($state['entries']) || !is_array($state['entries'])) throw new InvalidArgumentException('Form entries required.');
        $form = self::decode($state['entries']);
        if($screen==='setup') {
            if(!isset($form['setup'])||!is_array($form['setup'])) throw new InvalidArgumentException('Setup identity fields required.');
            return ['page'=>'setup','identity'=>MobiShop_Central_Setup_Identity::prepare($form['setup'])];
        }
        if(array_key_exists('layout_visibility_only',$form)) {
            if(count($form)!==1 || $form['layout_visibility_only']!=='0' || !in_array($screen,['category-builder','catalog-builder','wishlist-builder','account-builder'],true))throw new InvalidArgumentException('Invalid visibility-only request.');
            $layout=(new MobiShop_Page_Layout_Store)->get_layout($pages[$screen]);
            $layout['enabled']=false;
            $plan=['page'=>$pages[$screen],'layout'=>$layout];
            if($screen==='category-builder') {
                $category=(new MobiShop_Category_Page_Store)->get_settings();
                $category['enabled']=false;
                $plan['category']=$category;
            }
            return $plan;
        }
        if ($screen === 'website-promotion') {
            if (!isset($form['promotion']) || !is_array($form['promotion'])) throw new InvalidArgumentException('Promotion settings required.');
            return ['page'=>'website-promotion','promotion'=>MobiShop_Website_App_Promotion::sanitize($form['promotion'])];
        }
        if ($screen === 'splash') {
            if (!isset($form['splash']) || !is_array($form['splash'])) throw new InvalidArgumentException('Splash settings required.');
            $row = $form['splash'];
            // Matches the existing save_splash_screen() contract, including bounds.
            $clean = [
                'enabled'=>!empty($row['enabled']), 'image_url'=>esc_url_raw((string)($row['image_url']??'')),
                'background_color'=>sanitize_hex_color($row['background_color']??'')?:'#2F806E',
                'background_color_end'=>sanitize_hex_color($row['background_color_end']??'')?:'#236B59',
                'duration_ms'=>min(10000,max(500,absint($row['duration_ms']??2000))),
                'image_width'=>min(320,max(40,absint($row['image_width']??140))),
                'image_height'=>min(320,max(40,absint($row['image_height']??140))),
                'image_fit'=>in_array($row['image_fit']??'',['contain','cover','fill'],true)?sanitize_key($row['image_fit']):'contain',
                'image_shape'=>in_array($row['image_shape']??'',['none','rounded','circle'],true)?sanitize_key($row['image_shape']):'none',
                'show_store_name'=>!empty($row['show_store_name']),'store_name'=>sanitize_text_field((string)($row['store_name']??'')),
                'text_color'=>sanitize_hex_color($row['text_color']??'')?:'#FFFFFF',
                'show_loader'=>!empty($row['show_loader']),'loader_color'=>sanitize_hex_color($row['loader_color']??'')?:'#FFFFFF',
            ];
            return ['page'=>'splash','splash'=>$clean];
        }
        if ($screen === 'checkout-builder') {
            if (array_key_exists('checkout_design_only',$form)) {
                if ($form['checkout_design_only'] !== '1' || isset($form['checkout']) || count($form)!==2 || !isset($form['checkout_design'])) throw new InvalidArgumentException('Invalid design-only checkout request.');
                $design=(string)$form['checkout_design'];
                if (!isset(MobiShop_Checkout_Fields_Store::designs()[$design])) throw new InvalidArgumentException('Unknown checkout design.');
                // A Setup theme changes presentation only. The application's current
                // checkout schema is read directly; a stale portal draft is not used.
                return ['page'=>'checkout','checkout_design_only'=>true,'checkout'=>(new MobiShop_Checkout_Fields_Store)->get(),'design'=>$design];
            }
            if (!isset($form['checkout']) || !is_array($form['checkout'])) throw new InvalidArgumentException('Checkout fields required.');
            $fields = $form['checkout']['fields'] ?? [];
            if (!is_array($fields)) throw new InvalidArgumentException('Invalid checkout field list.');
            foreach ($fields as &$field) if (is_array($field) && !array_key_exists('default',$field)) $field['default']='';
            unset($field);
            // The existing save() uses this exact sanitizer. Fixed internal method;
            // neither the method name nor target class comes from a submitted field.
            $store = new MobiShop_Checkout_Fields_Store;
            $sanitize = new ReflectionMethod(MobiShop_Checkout_Fields_Store::class,'sanitize_fields');
            $design = sanitize_key((string)($form['checkout_design'] ?? 'classic'));
            return ['page'=>'checkout','checkout'=>['enabled'=>!empty($form['checkout']['enabled']),'fields'=>$sanitize->invoke($store,$fields)],'design'=>isset(MobiShop_Checkout_Fields_Store::designs()[$design]) ? $design : 'classic'];
        }
        if (!isset($form['layout']) || !is_array($form['layout'])) throw new InvalidArgumentException('Page layout required.');
        if (isset($form['builder_page']) && $form['builder_page'] !== $pages[$screen]) throw new InvalidArgumentException('Page mismatch.');
        $layout = (new MobiShop_Page_Layout_Store)->preview_layout($pages[$screen],$form['layout']);
        if (!$layout) throw new InvalidArgumentException('Application layout unavailable.');
        $plan = ['page'=>$pages[$screen],'layout'=>$layout];
        if ($screen === 'category-builder') {
            if (!isset($form['category_general']) || !is_array($form['category_general'])) throw new InvalidArgumentException('Category settings required.');
            if (isset($form['categories']) && !is_array($form['categories'])) throw new InvalidArgumentException('Invalid category overrides.');
            $rows = [];
            foreach (($form['categories'] ?? []) as $id=>$row) {
                if (!is_array($row) || !term_exists(absint($id),'product_cat')) continue;
                $rows[absint($id)] = $row;
            }
            $plan['category'] = (new MobiShop_Category_Page_Store)->preview_settings(['enabled'=>!empty($form['category_element_enabled']),'general'=>$form['category_general'],'categories'=>$rows]);
        }
        if ($screen === 'home-builder') {
            if (isset($form['blocks_payload'])) {
                $encoding = $form['blocks_payload_encoding'] ?? '';
                if (!in_array($encoding,['','base64'],true)) throw new InvalidArgumentException('Unknown Home payload encoding.');
                $json = $encoding === 'base64' ? base64_decode($form['blocks_payload'],true) : $form['blocks_payload'];
                if ($json === false) throw new InvalidArgumentException('Invalid Home payload.');
                $blocks = json_decode($json,true,512,JSON_THROW_ON_ERROR);
            } else $blocks = $form['blocks'] ?? null;
            if (!is_array($blocks) || !array_is_list($blocks)) throw new InvalidArgumentException('Home block list required.');
            $homeStore = new MobiShop_Layout_Store;
            $normalize = new ReflectionMethod(MobiShop_Layout_Store::class,'normalize_layout');
            $reorder = new ReflectionMethod(MobiShop_Layout_Store::class,'reorder_layout');
            $plan['home'] = $reorder->invoke($homeStore,$normalize->invoke($homeStore,$blocks));
        }
        return $plan;
    }
}
