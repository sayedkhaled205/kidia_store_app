<?php
namespace App\Services\Firebase;

/** Only explicit expired registration errors may retire a device token. */
final class FcmDeliveryFailure
{
    public static function isUnregistered(array $error): bool
    {
        foreach (($error['details'] ?? []) as $detail) {
            if (($detail['@type'] ?? '') === 'type.googleapis.com/google.firebase.fcm.v1.FcmError'
                && ($detail['errorCode'] ?? '') === 'UNREGISTERED') {
                return true;
            }
        }
        return in_array($error['message'] ?? '', ['NotRegistered', 'UNREGISTERED'], true);
    }
}
