<?php
// One-time operator setup, not a customer API. Uses the existing Laravel encryption key.
chdir('/home/woomobile/woomobile-api'); require 'vendor/autoload.php';
$app = require 'bootstrap/app.php'; $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use Illuminate\Support\Facades\Crypt;
$store = App\Models\Store::where('public_id','6990b322-e396-46bb-a188-a1e472b6bf64')->firstOrFail();
if ((string)$store->user_id !== '1' || $store->site_url !== 'https://kidiastore.com') throw new RuntimeException('Store binding changed.');
$project=app(App\Services\ConnectedStorePush::class)->project($store);
if ($project->ios_bundle_id !== 'app.mobishop.d983d98ad8afd98ad8a7d8b3d8aad988d8b1'
    || $project->android_package !== 'app.woomobile.store.s6990b322e39646bba188a1e472b6bf64') throw new RuntimeException('Application identity changed.');
$directory=storage_path('app/private/android-release-signing');
if (!is_dir($directory) && !mkdir($directory,0700,true)) throw new RuntimeException('Storage unavailable.');
chmod($directory,0700);
$path=$directory.'/'.hash('sha256',$store->public_id).'.enc';
$lock=fopen($path.'.lock','c'); chmod($path.'.lock',0600);
if (!$lock || !flock($lock,LOCK_EX)) throw new RuntimeException('Lock unavailable.');
try {
    if (is_file($path)) {
        $identity=json_decode(Crypt::decryptString(file_get_contents($path)),true,32,JSON_THROW_ON_ERROR);
        if ($identity['store']!==$store->public_id || $identity['package']!==$project->android_package) throw new RuntimeException('Existing key binding differs.');
    } else {
        if (config('native_signing.stores.'.$store->public_id)) throw new RuntimeException('Existing registration requires review; no key generated.');
        $key=openssl_pkey_new(['private_key_bits'=>3072,'private_key_type'=>OPENSSL_KEYTYPE_RSA]);
        $csr=openssl_csr_new(['countryName'=>'EG','organizationName'=>'Kidia Store','commonName'=>'Kidia Android Upload'], $key, ['digest_alg'=>'sha256']);
        $cert=openssl_csr_sign($csr,null,$key,10000,['digest_alg'=>'sha256'],random_int(1,PHP_INT_MAX));
        $password=bin2hex(random_bytes(32));
        if (!$cert || !openssl_pkcs12_export($cert,$bytes,$key,$password,['friendly_name'=>'kidiaupload'])) throw new RuntimeException('Upload key generation failed.');
        $identity=['store'=>$store->public_id,'owner_id'=>$store->user_id,'package'=>$project->android_package,
            'keystore'=>base64_encode($bytes),'password'=>$password,'alias'=>'kidiaupload','created_at'=>now()->toIso8601String()];
        $tmp=tempnam($directory,'new-'); chmod($tmp,0600);
        if (file_put_contents($tmp,Crypt::encryptString(json_encode($identity,JSON_THROW_ON_ERROR)))===false || !rename($tmp,$path)) throw new RuntimeException('Cannot persist upload key.');
        chmod($path,0600);
    }
    if (!openssl_pkcs12_read(base64_decode($identity['keystore'],true),$parts,$identity['password'])) throw new RuntimeException('Saved key cannot be read.');
    $cert=openssl_x509_parse($parts['cert']);
    if (!openssl_x509_check_private_key($parts['cert'],$parts['pkey'])) throw new RuntimeException('Saved key pair differs.');
    $row=['enabled'=>true,'owner_id'=>$store->user_id,'site_host'=>'kidiastore.com',
        'bundle_id'=>$project->ios_bundle_id,'team_id'=>'AC7BML9GL6','profile_uuid'=>'9a94234d-1cf0-4084-849e-695f3e56550c',
        'certificate_sha256'=>'d03d24813406cefc2d3c445a044c5a9808d55b24ba34b36604232ea098c2b324',
        'signing_provider'=>'managed','workflow_id'=>'kidia-managed-dual-release',
        'verified_at'=>'2026-10-31T11:09:05Z','expires_at'=>'2027-09-13T00:00:00Z',
        'firebase_project_id'=>$project->google_project_id,'apns_verified'=>false,
        'android_signing_provider'=>'server','android_release_verified'=>true,'android_package_name'=>$project->android_package,
        'android_certificate_sha256'=>openssl_x509_fingerprint($parts['cert'],'sha256'),
        'android_verified_at'=>$identity['created_at'],'android_expires_at'=>gmdate(DATE_ATOM,$cert['validTo_time_t']),
        'minimum_build_number'=>302];
    $stage=storage_path('app/private/combined-build-20261031');
    if (!is_dir($stage)) mkdir($stage,0700,true);
    file_put_contents($stage.'/registration.json',json_encode($row,JSON_PRETTY_PRINT|JSON_THROW_ON_ERROR));
    chmod($stage.'/registration.json',0600);
    file_put_contents($stage.'/android-upload-certificate.pem',$parts['cert']);
    chmod($stage.'/android-upload-certificate.pem',0600);
    echo json_encode(['store'=>$store->public_id,'android_package'=>$project->android_package,
        'upload_certificate_sha256'=>$row['android_certificate_sha256'],'minimum_build'=>302,'apns_ready'=>false,'key_saved_encrypted'=>true],JSON_PRETTY_PRINT).PHP_EOL;
} finally { flock($lock,LOCK_UN); fclose($lock); }
