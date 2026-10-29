<?php
namespace App\Services;

/** Strict aggregate-only boundary between store connectors and the builder. */
final class BuilderPushAnalytics
{
    public static function normalize($input): array
    {
        if (!is_array($input) || ($input['status'] ?? '') !== 'ready' || ($input['version'] ?? null) !== 2) return ['status'=>'unavailable'];
        $rows=[];
        foreach (array_slice(is_array($input['campaigns'] ?? null)?$input['campaigns']:[],0,1000) as $row) {
            if (!is_array($row) || !is_string($row['id']??null) || !preg_match('/^[a-zA-Z0-9_-]{8,80}$/D',$row['id'])) continue;
            $out=['id'=>$row['id']];
            foreach (['title'=>200,'message'=>2000,'status'=>30,'audience'=>30] as $key=>$limit) $out[$key]=mb_substr(is_string($row[$key]??null)?strip_tags($row[$key]):'',0,$limit);
            foreach (['created_at','sent','failed','targeted','received','opened','orders','buyers','paid_orders'] as $key) $out[$key]=is_int($row[$key]??null)&&$row[$key]>=0?$row[$key]:0;
            $out['revenue']=[];
            foreach (is_array($row['revenue']??null)?$row['revenue']:[] as $currency=>$value) if (preg_match('/^[A-Z]{3}$/D',(string)$currency)&&is_string($value)&&preg_match('/^\d{1,14}(?:\.\d{1,6})?$/D',$value)) $out['revenue'][$currency]=$value;
            $out['platforms']=[];
            foreach (['android','ios','web'] as $platform) {
                if (!isset($row['platforms'][$platform])) continue;
                foreach (['targeted','received','opened'] as $key) $out['platforms'][$platform][$key]=max(0,(int)($row['platforms'][$platform][$key]??0));
            }
            $rows[]=$out;
        }
        return ['status'=>'ready','version'=>2,'started_at'=>max(0,(int)($input['started_at']??0)),
            'conversion_supported'=>($input['conversion_supported']??false)===true,'attribution_days'=>7,
            'receipt_coverage'=>'foreground_and_open','truncated'=>($input['truncated']??false)===true || count(is_array($input['campaigns']??null)?$input['campaigns']:[])>1000,'campaigns'=>$rows];
    }
}
