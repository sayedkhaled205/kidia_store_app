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
    foreach ([
        ['cart_layout' => 'other'], ['cart_layout' => null], ['cart_layout' => ['compact']],
        ['cart_summary_display' => 'javascript:alert(1)'], ['cart_item_image_width' => -1],
        ['cart_item_image_width' => '100'], ['cart_item_image_width' => INF],
        ['cart_checkout_button_height' => 65], ['unknown' => null], ['auth_button_height' => null],
    ] as $invalid) {
        try { LiveAppUiControls::normalize($invalid); }
        catch (\Illuminate\Validation\ValidationException) { continue; }
        throw new \RuntimeException('Invalid input accepted');
    }
    echo "PASS optional sizes, zero radius, inherited defaults and allowlisted layout choices\n";
}
