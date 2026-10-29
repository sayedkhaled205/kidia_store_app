"""Narrow, assertion-guarded changes to the currently deployed shared services."""
def replace_once(source, before, after):
    assert source.count(before) == 1, 'Source changed; review before patching: ' + before[:90]
    return source.replace(before, after)

def backend(path, source):
    if path.endswith('BuilderPushMetrics.php'):
        return replace_once(source, "            return $metrics;", "            $metrics['analytics'] = BuilderPushAnalytics::normalize($data['analytics'] ?? null);\n            return $metrics;")
    if path.endswith('ConnectedStorePush.php'):
        source=replace_once(source,"'history'=>StorePushCampaign::where", "'analytics'=>app(ConnectedPushAnalytics::class)->forStore($store),\n   'history'=>StorePushCampaign::where")
        source=replace_once(source,"   foreach($devices->cursor() as $device) {", """   foreach($devices->cursor() as $device) {
    // Audience evidence precedes provider submission; client receipts are unique.
    DB::table('store_push_events')->insertOrIgnore(['store_id'=>$store->id,'campaign_id'=>$row->id,'event'=>'target_v2',
     'client_hash'=>hash('sha256',$device->client_id),'created_at'=>now(),'updated_at'=>now()]);""")
        return source
    if path.endswith('StorePushController.php'):
        source=replace_once(source,"'locale'=>'nullable|string|max:20'", "'locale'=>'nullable|string|max:20','test'=>'sometimes|boolean'")
        source=replace_once(source,"'locale'=>$input['locale']??'','enabled'=>true", "'locale'=>$input['locale']??'','test'=>$input['test']??false,'enabled'=>true")
        start=source.index(' public function event(')
        assert source[start:].count('function ') == 1
        return source[:start]+""" public function event(Request $r,Store $store) {
  $i=$r->validate(['notification_id'=>'required|uuid','event'=>'required|in:delivered,opened','client_id'=>'required|string|min:8|max:160|regex:/^[a-zA-Z0-9_-]+$/']);
  $client=hash('sha256',$i['client_id']);
  abort_unless(DB::table('store_push_events')->where('store_id',$store->id)->where('campaign_id',$i['notification_id'])
   ->where('event','target_v2')->where('client_hash',$client)->exists(),404);
  $row=['store_id'=>$store->id,'campaign_id'=>$i['notification_id'],'client_hash'=>$client,'created_at'=>now(),'updated_at'=>now()];
  $rows=[array_merge($row,['event'=>$i['event'].'_v2'])];
  if($i['event']==='opened')$rows[]=array_merge($row,['event'=>'delivered_v2']);
  $count=DB::table('store_push_events')->insertOrIgnore($rows);
  return response()->json(['recorded'=>$count>0,'deduplicated'=>$count===0]);
 }
}
"""
    raise ValueError(path)

def frame(source):
    start=source.index('  function pushNotice(message, failed) {')
    end=source.index('  function submitPush(form) {',start)
    source=source[:start]+"""  function pushNotice(message, failed) {
    let status = root.querySelector('.kidia-push-action-status, .wm-push-notice');
    if (!status) {
      status = document.createElement('p');
      root.querySelector('.mobishop-push-submit').append(status);
    }
    window.MobiShopPushReport.notice(status, message, failed, Boolean(pushRequest && pushRequest.busy));
  }
"""+source[end:]
    return replace_once(source,'    const metrics = payload.push_metrics;',"    const metrics = payload.push_metrics;\n    window.MobiShopPushReport.mount(root, metrics && metrics.analytics);")
