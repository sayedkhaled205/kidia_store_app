<?php
chdir('/home/woomobile/woomobile-api');
$root=getcwd(); $stage=$root.'/storage/app/private/combined-build-20261031';
$manifest=json_decode(file_get_contents('/home/woomobile/combined-build-package.json'),true,32,JSON_THROW_ON_ERROR);
foreach ($manifest as $relative=>$item) {
    if (!preg_match('#^(app/(Services|Http/Controllers/Portal)/[A-Za-z]+\.php)$#D',$relative)) throw new RuntimeException('Invalid patch path.');
    $current=$root.'/'.$relative;
    $actual=is_file($current)?hash_file('sha256',$current):null;
    if ($actual!==$item['before'] && $actual!==$item['after']) throw new RuntimeException('Concurrent change detected: '.$relative);
    $bytes=base64_decode($item['content'],true);
    if (hash('sha256',$bytes)!==$item['after']) throw new RuntimeException('Patch checksum failed.');
    $target=$stage.'/backend/'.$relative;
    if (!is_dir(dirname($target))) mkdir(dirname($target),0700,true);
    file_put_contents($target,$bytes); chmod($target,0600);
    exec('/opt/cpanel/ea-php83/root/usr/bin/php -l '.escapeshellarg($target),$output,$exit);
    if ($exit!==0) throw new RuntimeException('PHP syntax failed: '.$relative);
}
echo 'Staged '.count($manifest).' PHP files; checksums and PHP 8.3 syntax passed.'.PHP_EOL;
