<?php
require '/home/woomobile/woomobile-api/vendor/autoload.php';
// CLI-only candidate classes allow transaction tests before deployment.
if (isset($argv[1])) {
    require $argv[1].'/app/Services/LiveAppUiControls.php';
    require $argv[1].'/app/Http/Controllers/Portal/LiveAppDesignController.php';
}
$app = require '/home/woomobile/woomobile-api/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use App\Models\Store;
use App\Services\LiveAppDesign as Design;
use App\Services\LiveAppUiControls as Controls;
use Illuminate\Support\Facades\DB;
function check($value, $message) { if (!$value) throw new RuntimeException($message); }
check(count(Controls::schema()) === 73, '73 controls exposed');
foreach ([['unknown'=>true],['auth_title_size'=>999],['cart_pulse_enabled'=>'false'],['auth_title_en'=>'<script>'],['auth_title_en'=>str_repeat('x',121)],['support_contact_email'=>'https://buyer@example.com'],['support_whatsapp'=>'javascript:alert(1)']] as $bad) {
    try { Controls::normalize($bad); throw new RuntimeException('Unsafe value accepted'); }
    catch (Illuminate\Validation\ValidationException) {}
}
check(Controls::normalize(['auth_title_size'=>23,'auth_background'=>'#ffffff']) === [], 'Default values remain implicit');
check(Controls::normalize(['auth_title_en'=>null]) === [], 'HTTP empty text normalization restores default');
check(Controls::normalize(['support_contact_email'=>'help@example.com']) === ['support_contact_email'=>'help@example.com'], 'Public email accepted');
DB::beginTransaction();
try {
    $store = Store::whereKey(29)->lockForUpdate()->firstOrFail();
    $settings = $store->settings;
    $old = Design::status($store);
    $one = Design::publish($store, (int)$store->user_id, $old['revision'], $old['draft_digest']);
    $original = Design::query($store)->orderByDesc('id')->first()->bundle;
    $status = Controls::status($store);
    $new = Controls::save($store, (int)$store->user_id,
        ['auth_title_en'=>'Welcome back','logout_height'=>42,'cart_pulse_enabled'=>false,
         'support_contact_email'=>'help@example.com','support_whatsapp_enabled'=>false,
         'cart_layout'=>'compact','cart_item_image_radius'=>0,
         'cart_item_image_width'=>null,'cart_summary_display'=>'expanded',
         'message_style'=>'soft','checkout_button_height'=>60,'checkout_address_radius'=>0,
         'orders_detail_image_size'=>72,'auth_identifier_hint_en'=>'01XXXXXXXXX'], $status['controls_digest']);
    $store->refresh(); $after = $store->settings; unset($after['builder']['ui_controls_v1']); unset($settings['builder']['ui_controls_v1']);
    check($after === $settings, 'Other store and Builder settings preserved');
    check(Design::query($store)->orderByDesc('id')->first()->bundle === $original, 'Saving controls does not publish');
    try { Controls::save($store, (int)$store->user_id, [], $status['controls_digest']); throw new RuntimeException('Stale save accepted'); }
    catch (Symfony\Component\HttpKernel\Exception\HttpException $e) { check($e->getStatusCode() === 409, 'Conflict status'); }
    try { Controls::save($store, 99999999, [], $new['controls_digest']); throw new RuntimeException('Foreign owner accepted'); }
    catch (Symfony\Component\HttpKernel\Exception\HttpException $e) { check($e->getStatusCode() === 403, 'Owner scope'); }
    $withCheckout = $store->settings;
    $entries = data_get($withCheckout, 'builder.screens.checkout-builder.entries', []);
    $entries = array_values(array_filter($entries, fn($entry) => ($entry[0] ?? null) !== 'checkout_design'));
    $entries[] = ['checkout_design', 'compact'];
    data_set($withCheckout, 'builder.screens.checkout-builder.entries', $entries);
    $store->settings = $withCheckout; $store->timestamps = false; $store->save();
    // Match the actual request boundary. Disabling Eloquent timestamps also
    // disables its implicit date casts on this temporary test instance.
    $store = $store->fresh();
    $draft = Design::status($store); check($draft['has_changes'], 'New controls detected');
    $two = Design::publish($store,(int)$store->user_id,$one['revision'],$draft['draft_digest']);
    $release = Design::query($store)->orderByDesc('id')->first();
    $bundle = json_decode(base64_decode($release->bundle),true);
    check($bundle['pages']['home']['settings']['ui_controls_v1']['cart_pulse_enabled'] === false, 'Controls included in public release');
    check($bundle['pages']['home']['settings']['ui_controls_v1']['support_contact_email'] === 'help@example.com', 'Public support published');
    $ui = $bundle['pages']['home']['settings']['ui_controls_v1'];
    check($ui['cart_layout'] === 'compact' && $ui['cart_summary_display'] === 'expanded', 'Cart choices published');
    check($ui['cart_item_image_radius'] === 0, 'Zero cart radius published');
    check($ui['checkout_address_radius'] === 0 && $ui['checkout_button_height'] === 60, 'Checkout appearance published');
    check($ui['message_style'] === 'soft' && $ui['orders_detail_image_size'] === 72 && $ui['auth_identifier_hint_en'] === '01XXXXXXXXX', 'Messages, order images and auth hints published');
    check(!array_key_exists('cart_item_image_width', $ui), 'Blank cart size inherits theme');
    check($bundle['pages']['home']['settings']['checkout_presentation_v1'] === ['design'=>'compact'], 'Saved checkout design published');
    $controller = new App\Http\Controllers\Portal\LiveAppDesignController();
    $etag = '"'.$release->id.'-'.$release->digest.'"';
    $request = Illuminate\Http\Request::create('/');
    $request->headers->set('If-None-Match', $etag);
    DB::enableQueryLog(); DB::flushQueryLog();
    $unchanged = $controller->show($request, $store->public_id);
    $queries = DB::getQueryLog(); DB::disableQueryLog();
    check($unchanged->getStatusCode() === 304 && $unchanged->getContent() === '', 'Unchanged release returns no body');
    check(count($queries) === 2, 'Unchanged read uses two metadata queries');
    foreach ($queries as $query) check(!str_contains($query['query'], '*') && !str_contains($query['query'], 'bundle') && !str_contains($query['query'], 'settings'), '304 must not load merchant settings or bundle');
    $changed = $controller->show(Illuminate\Http\Request::create('/'), $store->public_id);
    check($changed->getStatusCode() === 200 && $changed->getData(true) === Design::envelope($release), 'Changed read returns the exact pinned release');
    check($changed->headers->get('ETag') === $etag, 'Body and ETag agree');
    Design::publish($store,(int)$store->user_id,$two['revision'],null,true);
    check(Design::query($store)->orderByDesc('id')->first()->bundle === $original, 'Rollback restores prior settings');
    echo "PASS: 73 controls, bounds, default compatibility, draft isolation, owner scope, conflicts, publish, rollback\n";
} finally { DB::rollBack(); echo "All test data rolled back.\n"; }
