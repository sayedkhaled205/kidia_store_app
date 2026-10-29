<?php
require __DIR__.'/FcmDeliveryFailure.php';
use App\Services\Firebase\FcmDeliveryFailure;
$cases = [
    [['message'=>'NotRegistered'], true],
    [['message'=>'UNREGISTERED'], true],
    [['details'=>[['@type'=>'type.googleapis.com/google.firebase.fcm.v1.FcmError','errorCode'=>'UNREGISTERED']]], true],
    [['message'=>'Invalid argument','status'=>'INVALID_ARGUMENT'], false],
    [['message'=>'NotRegistered in an unrelated diagnostic'], false],
    [['details'=>[['@type'=>'other','errorCode'=>'UNREGISTERED']]], false],
    [['status'=>'UNAVAILABLE'], false],
    [[], false],
];
foreach ($cases as [$error,$expected]) {
    if (FcmDeliveryFailure::isUnregistered($error) !== $expected) throw new RuntimeException('Unsafe token retirement');
}
echo "8 provider error classification cases passed.\n";
