<?php
require __DIR__.'/BuilderPushAnalytics.php';
use App\Services\BuilderPushAnalytics;
function verify($condition,$message){if(!$condition)throw new RuntimeException($message);}
$input=['status'=>'ready','version'=>2,'conversion_supported'=>true,'campaigns'=>[
 ['id'=>'campaign-123','title'=>'<script>unsafe</script> Offer','message'=>'Hello','status'=>'sent','created_at'=>1,'sent'=>3,'received'=>2,'opened'=>1,'orders'=>1,'buyers'=>1,'paid_orders'=>0,'revenue'=>['EGP'=>'12.340000','USD'=>'1.05','bad'=>'NaN'],'email'=>'private@example.invalid','client_hash'=>'private','platforms'=>['android'=>['received'=>2,'opened'=>1],'malicious'=>['opened'=>999]]],
 ['id'=>'bad id','sent'=>900]
]];
$result=BuilderPushAnalytics::normalize($input);
verify(count($result['campaigns'])===1,'Reject malformed campaign identity');
verify($result['campaigns'][0]['revenue']===['EGP'=>'12.340000','USD'=>'1.05'],'Preserve exact currencies and reject invalid money');
verify(!str_contains(json_encode($result),'private'),'Never expose personal or device fields');
verify(!isset($result['campaigns'][0]['platforms']['malicious']),'Restrict platform keys');
verify(!str_contains($result['campaigns'][0]['title'],'<'),'Strip imported markup');
verify(BuilderPushAnalytics::normalize(['status'=>'ready','version'=>1])===['status'=>'unavailable'],'Legacy counters must not become verified zeros');
verify(BuilderPushAnalytics::normalize(null)===['status'=>'unavailable'],'Upstream failure stays unavailable');
$input['conversion_supported']=false;
verify(BuilderPushAnalytics::normalize($input)['conversion_supported']===false,'Unsupported purchase tracking stays unsupported');
echo "Push aggregate boundary contracts passed.\n";
