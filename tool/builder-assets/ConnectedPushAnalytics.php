<?php
namespace App\Services;

use App\Models\{Store,StorePushCampaign};
use Illuminate\Support\Facades\DB;

final class ConnectedPushAnalytics
{
    public function forStore(Store $store): array
    {
        $rows=StorePushCampaign::where('store_id',$store->id)->latest()->orderByDesc('id')->limit(1001)->get();
        $truncated=$rows->count()>1000;
        $rows=$rows->take(1000);
        $ids=$rows->pluck('id')->all();
        $events=DB::table('store_push_events')->where('store_id',$store->id)->whereIn('campaign_id',$ids)
            ->whereIn('event',['target_v2','delivered_v2','opened_v2'])->selectRaw('campaign_id,event,COUNT(DISTINCT client_hash) AS total')->groupBy('campaign_id','event')->get();
        $counts=[];
        foreach($events as $event)$counts[$event->campaign_id][$event->event]=(int)$event->total;
        $campaigns=[];
        foreach($rows as $row) {
            // Legacy campaigns have no deduplicated audience baseline.
            if(!isset($counts[$row->id]['target_v2']))continue;
            $campaigns[]=['id'=>$row->id,'title'=>$row->payload['title']??'','message'=>$row->payload['message']??'',
                'status'=>$row->status,'audience'=>$row->payload['audience']??'all','created_at'=>$row->created_at->timestamp,
                'sent'=>(int)$row->sent,'failed'=>(int)$row->failed,'targeted'=>$counts[$row->id]['target_v2'],
                'received'=>$counts[$row->id]['delivered_v2']??0,'opened'=>$counts[$row->id]['opened_v2']??0,
                'orders'=>0,'buyers'=>0,'paid_orders'=>0,'revenue'=>[],'platforms'=>[]];
        }
        return BuilderPushAnalytics::normalize(['status'=>'ready','version'=>2,'conversion_supported'=>false,'truncated'=>$truncated,'campaigns'=>$campaigns]);
    }
}
