<?php
require __DIR__.'/backend/app/Services/LiveAppDesign.php';
use App\Services\LiveAppDesign;
function check($condition) { if (!$condition) throw new RuntimeException('Presentation contract failed'); }
check(LiveAppDesign::checkoutPresentation([]) === null);
foreach (['classic', 'summary_first', 'compact'] as $design) {
    $screens = ['checkout-builder' => ['entries' => [
        ['checkout_design', $design],
        ['checkout[billing][address]', 'must not be published'],
        ['payment_method', 'must not be published'],
    ]]];
    check(LiveAppDesign::checkoutPresentation($screens) === ['design' => $design]);
}
foreach ([
    [['checkout_design', 'arbitrary']],
    [['checkout_design', ['compact']]],
    [['checkout_design', 'classic'], ['checkout_design', 'compact']],
] as $entries) {
    $rejected = false;
    try { LiveAppDesign::checkoutPresentation(['checkout-builder' => ['entries' => $entries]]); }
    catch (RuntimeException) { $rejected = true; }
    check($rejected);
}
echo "PASS: three checkout designs, legacy absence, malformed/duplicate rejection, private fields excluded\n";
