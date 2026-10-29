<?php
// Dependency-free normalization contract. Transaction/owner checks are covered
// separately by backend-test.php inside the application.
namespace Illuminate\Validation {
    class ValidationException extends \RuntimeException {
        public static function withMessages(array $messages): self { return new self('Rejected'); }
    }
}
namespace {
    require __DIR__.'/backend/app/Services/LiveAppUiControls.php';
    use App\Services\LiveAppUiControls;
    function expectSame($actual, $expected): void {
        if ($actual !== $expected) throw new \RuntimeException('Normalization contract failed');
    }
    expectSame(LiveAppUiControls::normalize([
        'cart_layout' => 'compact', 'cart_coupon_display' => 'expanded',
        'cart_summary_display' => 'theme', 'cart_item_image_radius' => 0,
        'cart_item_image_width' => null, 'cart_checkout_button_height' => 60,
    ]), ['cart_checkout_button_height' => 60, 'cart_coupon_display' => 'expanded',
        'cart_item_image_radius' => 0, 'cart_layout' => 'compact']);
    expectSame(LiveAppUiControls::normalize([
        'cart_layout' => 'theme', 'cart_item_image_radius' => null,
        'cart_pulse_enabled' => true, 'logout_height' => 38,
    ]), []);
    expectSame(LiveAppUiControls::normalize(['filters_width_fraction'=>.85,'quickadd_button_height'=>60,'receipt_card_style'=>'soft','receipt_show_logo'=>false,'receipt_section_radius'=>0]),
        ['filters_width_fraction'=>.85,'quickadd_button_height'=>60,'receipt_card_style'=>'soft','receipt_section_radius'=>0,'receipt_show_logo'=>false]);
    foreach ([
        ['cart_layout' => 'other'], ['cart_layout' => null], ['cart_layout' => ['compact']],
        ['cart_summary_display' => 'javascript:alert(1)'], ['cart_item_image_width' => -1],
        ['cart_item_image_width' => '100'], ['cart_item_image_width' => INF],
        ['cart_checkout_button_height' => 65], ['unknown' => null], ['auth_button_height' => null],
        ['filters_width_fraction'=>1.1],['quickadd_button_height'=>30],['receipt_card_style'=>'paid'],['receipt_thanks_en'=>'<script>'],['receipt_show_logo'=>'false'],
    ] as $invalid) {
        try { LiveAppUiControls::normalize($invalid); }
        catch (\Illuminate\Validation\ValidationException) { continue; }
        throw new \RuntimeException('Invalid input accepted');
    }
    echo "PASS optional sizes, zero radius, inherited defaults and allowlisted layout choices\n";
}
