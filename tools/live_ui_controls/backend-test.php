<?php
require '/home/woomobile/woomobile-api/vendor/autoload.php';
$app = require '/home/woomobile/woomobile-api/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use App\Models\Store;
use App\Services\LiveAppDesign as Design;
use App\Services\LiveAppUiControls as Controls;
use Illuminate\Support\Facades\DB;
function check($value, $message) { if (!$value) throw new RuntimeException($message); }
check(count(Controls::schema()) === 32, '32 controls exposed');
foreach ([['unknown'=>true],['auth_title_size'=>999],['cart_pulse_enabled'=>'false'],['auth_title_en'=>'<script>'],['auth_title_en'=>str_repeat('x',121)]] as $bad) {
    try { Controls::normalize($bad); throw new RuntimeException('Unsafe value accepted'); }
    catch (Illuminate\Validation\ValidationException) {}
}
check(Controls::normalize(['auth_title_size'=>23,'auth_background'=>'#ffffff']) === [], 'Default values remain implicit');
DB::beginTransaction();
try {
    $store = Store::whereKey(29)->lockForUpdate()->firstOrFail();
    $settings = $store->settings;
    $old = Design::status($store);
    $one = Design::publish($store, (int)$store->user_id, $old['revision'], $old['draft_digest']);
    $original = Design::query($store)->orderByDesc('id')->first()->bundle;
    $status = Controls::status($store);
    $new = Controls::save($store, (int)$store->user_id,
        ['auth_title_en'=>'Welcome back','logout_height'=>42,'cart_pulse_enabled'=>false], $status['controls_digest']);
    $store->refresh(); $after = $store->settings; unset($after['builder']['ui_controls_v1']); unset($settings['builder']['ui_controls_v1']);
    check($after === $settings, 'Other store and Builder settings preserved');
    check(Design::query($store)->orderByDesc('id')->first()->bundle === $original, 'Saving controls does not publish');
    try { Controls::save($store, (int)$store->user_id, [], $status['controls_digest']); throw new RuntimeException('Stale save accepted'); }
    catch (Symfony\Component\HttpKernel\Exception\HttpException $e) { check($e->getStatusCode() === 409, 'Conflict status'); }
    try { Controls::save($store, 99999999, [], $new['controls_digest']); throw new RuntimeException('Foreign owner accepted'); }
    catch (Symfony\Component\HttpKernel\Exception\HttpException $e) { check($e->getStatusCode() === 403, 'Owner scope'); }
    $draft = Design::status($store); check($draft['has_changes'], 'New controls detected');
    $two = Design::publish($store,(int)$store->user_id,$one['revision'],$draft['draft_digest']);
    $release = Design::query($store)->orderByDesc('id')->first();
    $bundle = json_decode(base64_decode($release->bundle),true);
    check($bundle['pages']['home']['settings']['ui_controls_v1']['cart_pulse_enabled'] === false, 'Controls included in public release');
    Design::publish($store,(int)$store->user_id,$two['revision'],null,true);
    check(Design::query($store)->orderByDesc('id')->first()->bundle === $original, 'Rollback restores prior settings');
    echo "PASS: 32 controls, bounds, default compatibility, draft isolation, owner scope, conflicts, publish, rollback\n";
} finally { DB::rollBack(); echo "All test data rolled back.\n"; }
