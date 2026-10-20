<?php
/** Apply prepared settings through original stores and verify their saved options. */
final class MobiShop_Central_Application_Commit
{
    private static function verify(string $option,array $expected): void
    {
        if(get_option($option,null)!==$expected) throw new RuntimeException('Application persistence could not be confirmed.');
    }

    public static function apply(string $screen,array $state): array
    {
        $plan=MobiShop_Central_Form_State::previewPage($screen,$state);
        if(isset($plan['identity'])) $plan['identity']=MobiShop_Central_Setup_Identity::save($plan['identity']);
        if(isset($plan['layout'])) {
            $saved=(new MobiShop_Page_Layout_Store)->save_layout($plan['page'],$plan['layout']);
            self::verify('mobishop_page_layout_'.$plan['page'],$saved);
            $plan['layout']=$saved;
        }
        if(isset($plan['category'])) {
            $saved=(new MobiShop_Category_Page_Store)->save_settings($plan['category']);
            self::verify('mobishop_category_page',$saved);
            $plan['category']=$saved;
        }
        if(isset($plan['home'])) {
            $store=new MobiShop_Layout_Store;
            $store->save_layout($plan['home']);
            $references=[];
            foreach($plan['home'] as $block) $references[]=array_intersect_key($block,array_flip(['id','library_id','type','name','enabled','status','order','settings']));
            self::verify('mobishop_home_layout_v5',$references);
            // Removes transient creation intent from the next saved draft.
            $plan['home']=$store->get_runtime_layout();
        }
        if(isset($plan['checkout'])) {
            $store=new MobiShop_Checkout_Fields_Store;
            if (!empty($plan['checkout_design_only'])) {
                $original=get_option(MobiShop_Checkout_Fields_Store::OPTION,null);
                $store->save_design($plan['design']);
                if(get_option(MobiShop_Checkout_Fields_Store::OPTION,null)!==$original) throw new RuntimeException('Checkout fields changed during design-only save.');
            } else {
                $store->save($plan['checkout']); $store->save_design($plan['design']);
                self::verify(MobiShop_Checkout_Fields_Store::OPTION,$plan['checkout']);
            }
            if(get_option(MobiShop_Checkout_Fields_Store::DESIGN_OPTION)!==$plan['design']) throw new RuntimeException('Checkout design persistence failed.');
        }
        if(isset($plan['splash'])) { update_option('mobishop_splash_screen',$plan['splash'],false); self::verify('mobishop_splash_screen',$plan['splash']); }
        if(isset($plan['promotion'])) { update_option(MobiShop_Website_App_Promotion::OPTION,$plan['promotion'],false); self::verify(MobiShop_Website_App_Promotion::OPTION,$plan['promotion']); }
        $canonical=self::canonicalState($state,$plan);
        return ['ok'=>true,'applied'=>true,'screen'=>$screen,'receipt'=>hash('sha256',serialize($plan)),'state'=>$canonical];
    }

    public static function canonicalState(array $state,array $plan): array
    {
        $replace=['layout_visibility_only'=>null];
        if(isset($plan['identity'])) $replace['setup']=MobiShop_Central_Setup_Identity::form($plan['identity']);
        if(isset($plan['layout'])) $replace['layout']=$plan['layout'];
        if(isset($plan['category'])) {
            $replace['category_general']=$plan['category']['general'];
            $replace['category_element_enabled']=$plan['category']['enabled'];
            $replace['categories']=$plan['category']['categories'];
        }
        if(isset($plan['home'])) { $replace['blocks']=null; $replace['blocks_payload_encoding']='base64'; $replace['blocks_payload']=base64_encode(json_encode($plan['home'],JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR)); }
        if(isset($plan['checkout'])) { $replace['checkout_design_only']=null; $replace['checkout']=$plan['checkout']; $replace['checkout_design']=$plan['design']; }
        if(isset($plan['splash'])) $replace['splash']=$plan['splash'];
        if(isset($plan['promotion'])) $replace['promotion']=$plan['promotion'];
        $entries=[];
        foreach($state['entries'] as $entry) {
            $root=strtok($entry[0],'[');
            if(!array_key_exists($root,$replace)) $entries[]=$entry;
        }
        foreach($replace as $root=>$value) if($value!==null) self::flatten($value,$root,$entries);
        return ['entries'=>$entries];
    }

    private static function flatten($value,string $name,array &$entries): void
    {
        if(is_array($value)) { foreach($value as $key=>$item) self::flatten($item,$name.'['.$key.']',$entries); return; }
        $entries[]=[$name,is_bool($value)?($value?'1':'0'):(string)$value];
    }
}
