document.addEventListener('DOMContentLoaded', function () {
  if (!window.jQuery) return;
  var $ = window.jQuery;
  $(document).ajaxError(function (_event, xhr, settings) {
    if (xhr.status !== 403 || !/[?&]wc-ajax=update_order_review(?:&|$)/.test(settings.url || '')) return;
    $('.woocommerce-checkout-payment,.woocommerce-checkout-review-order-table,form.checkout').unblock();
    if (document.getElementById('mobishop-checkout88-expired')) return;
    var notice = document.createElement('div');
    notice.id = 'mobishop-checkout88-expired';
    notice.className = 'woocommerce-error';
    notice.setAttribute('role', 'alert');
    notice.textContent = document.documentElement.lang.indexOf('ar') === 0
      ? 'انتهت جلسة الدفع. ارجع للسلة وافتح إتمام الطلب مرة تانية.'
      : 'Your checkout session expired. Return to the cart and open checkout again.';
    var form = document.querySelector('form.checkout');
    if (form) form.prepend(notice);
    $('#place_order').prop('disabled', true);
    notice.scrollIntoView({block:'center'});
  });
});
