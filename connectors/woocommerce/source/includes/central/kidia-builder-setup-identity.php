<?php
/** Setup identity only: complete page presets are already saved by their original stores. */
final class MobiShop_Central_Setup_Identity
{
    public static function prepare(array $submitted): array
    {
        foreach($submitted as $value) if(is_array($value)) continue; elseif(!is_scalar($value)&&$value!==null) throw new InvalidArgumentException('Invalid Setup value.');
        if(isset($submitted['enabled_pages'])&&!is_array($submitted['enabled_pages'])) throw new InvalidArgumentException('Invalid enabled-page map.');
        $wizard=new MobiShop_Setup_Wizard;
        $themes=MobiShop_Setup_Wizard::themes();
        $normalize=new ReflectionMethod(MobiShop_Setup_Wizard::class,'normalize_theme_key');
        $enabled=new ReflectionMethod(MobiShop_Setup_Wizard::class,'sanitize_enabled_pages');
        foreach(['theme','primary_color','secondary_color','app_name','logo_id','logo_url','language','direction','app_icon_shape','font_family'] as $key) if(isset($submitted[$key])&&!is_scalar($submitted[$key])) throw new InvalidArgumentException('Invalid Setup field.');
        // Same original Setup sanitizer and defaults, without calling apply():
        // apply() would reapply presets and overwrite already-confirmed page layouts.
        $themeKey=$normalize->invoke($wizard,(string)($submitted['theme']??'fashion'),$themes);
        $theme=$themes[$themeKey];
        $name=sanitize_text_field((string)($submitted['app_name']??get_bloginfo('name')));
        $logoId=absint($submitted['logo_id']??0);
        $logoRaw=(string)($submitted['logo_url']??'');
        if(!$logoId&&str_starts_with($logoRaw,'data:')) throw new InvalidArgumentException('Upload the logo to the connected store before applying Setup.');
        $identity=[
            'app_name'=>$name!==''?$name:get_bloginfo('name'),
            'logo_id'=>$logoId,
            'logo_url'=>$logoId?(string)wp_get_attachment_image_url($logoId,'full'):esc_url_raw($logoRaw),
            'language'=>sanitize_key((string)($submitted['language']??(is_rtl()?'ar':'en'))),
            'direction'=>($submitted['direction']??'')==='rtl'?'rtl':'ltr',
            'app_icon_shape'=>in_array((string)($submitted['app_icon_shape']??''),['rounded_square','circle','square'],true)?(string)$submitted['app_icon_shape']:'rounded_square',
            'font_family'=>in_array((string)($submitted['font_family']??''),['system','poppins','roboto','noto_sans_arabic','serif','monospace'],true)?(string)$submitted['font_family']:'system',
            'primary_color'=>sanitize_hex_color((string)($submitted['primary_color']??''))?:$theme['primary'],
            'secondary_color'=>sanitize_hex_color((string)($submitted['secondary_color']??''))?:$theme['soft'],
            'theme'=>$themeKey,
            'page_themes'=>array_fill_keys(array_keys(MobiShop_Setup_Wizard::setup_pages()),$themeKey),
            'enabled_pages'=>$enabled->invoke($wizard,$submitted['enabled_pages']??null),
        ];
        // Theme application consumes the canonical identity, not the page layout.
        // Carry artwork bounds here so applying a preset cannot restore padded logos.
        if($themeKey==='kids_baby' && $identity['logo_url']!=='') {
            $url=$identity['logo_url'];
            if(explode('#',$url)[0]===explode('#',$logoRaw)[0]) $url=$logoRaw;
            $saved=get_option('mobishop_app_identity',[]);
            $savedUrl=is_array($saved)?(string)($saved['logo_url']??''):'';
            if(!str_contains($url,'#wm=') && str_contains($savedUrl,'#wm=') && explode('#',$url)[0]===explode('#',$savedUrl)[0]) $url=$savedUrl;
            $parts=[];
            if(preg_match('/#wm=([0-9.,]+)$/D',$url,$match)) $parts=array_map('floatval',explode(',',$match[1]));
            $valid=count($parts)===5 && $parts[0]>=0 && $parts[1]>=0 && $parts[2]>0 && $parts[3]>0 && $parts[0]+$parts[2]<=1.001 && $parts[1]+$parts[3]<=1.001 && $parts[4]>0 && $parts[4]<=20;
            $crop=$valid?$parts:MobiShop_Setup_Wizard::logo_crop($url);
            if($crop) $identity['logo_url']=explode('#',$url)[0].'#wm='.implode(',',$crop);
        }
        return $identity;
    }

    public static function save(array $identity): array
    {
        update_option('mobishop_app_identity',$identity,false);
        if(get_option('mobishop_app_identity',null)!==$identity) throw new RuntimeException('Application identity persistence could not be confirmed.');
        $time=time();
        $state=['completed'=>true,'theme'=>$identity['theme'],'page_themes'=>$identity['page_themes'],'enabled_pages'=>$identity['enabled_pages'],'completed_at'=>$time,'source'=>'built_in','build_required'=>true,'build_requested_at'=>$time];
        update_option('mobishop_setup_wizard_state',$state,false);
        if(get_option('mobishop_setup_wizard_state',null)!==$state) throw new RuntimeException('Setup completion could not be confirmed.');
        return $identity;
    }

    public static function form(array $identity): array
    {
        $form=$identity;
        unset($form['page_themes']);
        $form['enabled_pages']=[];
        foreach(MobiShop_Setup_Wizard::setup_pages() as $page=>$details)$form['enabled_pages'][$page]=in_array($page,$identity['enabled_pages'],true);
        return $form;
    }
}
