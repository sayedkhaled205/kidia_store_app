<?php
chdir('/home/woomobile/woomobile-api');
$root=getcwd(); $stage=$root.'/storage/app/private/combined-build-20261031';
$manifest=json_decode(file_get_contents('/home/woomobile/combined-build-package.json'),true,32,JSON_THROW_ON_ERROR);
$config=$root.'/config/native_signing.php';
$beforeConfig='55f8bf90eac01c84eb1ea68e8cce866d6db17a2d2c9a3c1542680713c2bc1f43';
$configuration=require $config;
$registration=json_decode(file_get_contents($stage.'/registration.json'),true,32,JSON_THROW_ON_ERROR);
if (hash_file('sha256',$config)!==$beforeConfig && ($configuration['stores']['6990b322-e396-46bb-a188-a1e472b6bf64']??null)!==$registration) throw new RuntimeException('Signing configuration changed; review before applying.');
foreach ($manifest as $relative=>$item) {
    if ((is_file($root.'/'.$relative)?hash_file('sha256',$root.'/'.$relative):null)!==$item['before']) throw new RuntimeException('Concurrent change: '.$relative);
    if (hash_file('sha256',$stage.'/backend/'.$relative)!==$item['after']) throw new RuntimeException('Staged patch changed.');
}
$configuration['stores']['6990b322-e396-46bb-a188-a1e472b6bf64']=$registration;
$manifest['config/native_signing.php']=['content'=>base64_encode("<?php\nreturn ".var_export($configuration,true).";\n")];
// Complete all backups before replacing any live file. Enable the registration last.
$backups=[];
foreach ($manifest as $relative=>$item) {
    $target=$root.'/'.$relative; $backup=$stage.'/backup/'.$relative;
    if (is_file($target)) { if (!is_dir(dirname($backup))) mkdir(dirname($backup),0700,true); if (is_file($backup)) $backup.='.'.gmdate('His'); if (!copy($target,$backup)) throw new RuntimeException('Backup failed.'); $backups[$relative]=$backup; }
}
$applied=[];
try {
    foreach ($manifest as $relative=>$item) {
        $target=$root.'/'.$relative; $tmp=tempnam(dirname($target),'combined-');
        if (file_put_contents($tmp,base64_decode($item['content'],true))===false) throw new RuntimeException('Write failed.');
        chmod($tmp,0644);
        if (!rename($tmp,$target)) throw new RuntimeException('Atomic replacement failed.');
        $applied[]=$relative;
    }
} catch (\Throwable $e) {
    foreach (array_reverse($applied) as $relative) {
        $backup=$backups[$relative]??null;
        if ($backup && is_file($backup)) copy($backup,$root.'/'.$relative);
        elseif ($relative==='app/Services/AndroidReleaseSigningIdentity.php') unlink($root.'/'.$relative);
    }
    throw $e;
}
echo 'Applied '.count($manifest).' files; original files backed up in private storage.'.PHP_EOL;
