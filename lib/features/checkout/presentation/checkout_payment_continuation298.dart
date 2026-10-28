import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/features/checkout/application/checkout_payment_controller298.dart';
import 'package:mobishop_store_app/features/checkout/presentation/providers/checkout_payment_provider298.dart';
import 'checkout_order_receipt.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

class CheckoutPaymentContinuation298 extends ConsumerStatefulWidget {
  const CheckoutPaymentContinuation298({
    required this.orderId,
    this.onReviewOrders,
    this.onContinueShopping,
    this.onViewDetails,
    super.key,
  });
  final int orderId;
  final VoidCallback? onReviewOrders;
  final VoidCallback? onContinueShopping;
  final VoidCallback? onViewDetails;

  @override
  ConsumerState<CheckoutPaymentContinuation298> createState() =>
      _CheckoutPaymentContinuation298State();
}

class _CheckoutPaymentContinuation298State
    extends ConsumerState<CheckoutPaymentContinuation298>
    with WidgetsBindingObserver {
  CheckoutPaymentController298? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller?.returnedToApp();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(
      checkoutPaymentController298Provider(widget.orderId),
    );
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_changed);
      _controller = controller..addListener(_changed);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(controller, _controller)) controller.refresh();
      });
    }
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final state = controller.state;
    final title = switch (state) {
      CheckoutPaymentState298.checking =>
        ar ? 'جارٍ مراجعة الطلب' : 'Checking your order',
      CheckoutPaymentState298.pending =>
        ar ? 'طلبك محفوظ، في انتظار الدفع' : 'Order saved, payment pending',
      CheckoutPaymentState298.paid =>
        ar ? 'تم تأكيد الدفع' : 'Payment confirmed',
      CheckoutPaymentState298.received =>
        ar ? 'تم استلام طلبك' : 'Order received',
      CheckoutPaymentState298.closed =>
        ar ? 'راجع حالة الطلب' : 'Review order status',
      CheckoutPaymentState298.unavailable =>
        ar ? 'تعذر التحقق من حالة الدفع' : 'Unable to verify payment status',
    };
    final resolved =
        state == CheckoutPaymentState298.paid ||
        state == CheckoutPaymentState298.received;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (resolved && controller.order != null)
              CheckoutOrderReceipt(
                orderId: widget.orderId,
                order: controller.order,
                title: title,
                titleKey: Key('checkout-payment-${state.name}'),
                logoUrl:
                    ref
                        .watch(cmsPageLayoutProvider('account'))
                        .value
                        ?.header
                        .string('logo_url', '') ??
                    '',
                onContinueShopping: widget.onContinueShopping,
                onViewDetails: widget.onViewDetails,
              ),
            if (!resolved) ...[
              Icon(
                resolved
                    ? Icons.check_circle_rounded
                    : Icons.receipt_long_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                title,
                key: Key('checkout-payment-${state.name}'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                ar
                    ? 'رقم الطلب: ${widget.orderId}'
                    : 'Order number: ${widget.orderId}',
              ),
            ],
            if (!resolved) ...[
              const SizedBox(height: 12),
              Text(
                state == CheckoutPaymentState298.unavailable
                    ? (ar
                          ? 'طلبك محفوظ. تحقق من الاتصال وتسجيل الدخول، ثم حاول مرة أخرى أو راجع طلباتك.'
                          : 'Your order is saved. Check your connection and sign-in, then retry or review your orders.')
                    : state == CheckoutPaymentState298.closed
                    ? (ar
                          ? 'راجع حالة هذا الطلب في طلباتك قبل إجراء أي عملية جديدة.'
                          : 'Review this order in your order history before taking another action.')
                    : ar
                    ? 'كمّل الدفع بأمان داخل التطبيق. طلبك محفوظ ولا تحتاج لإنشاء طلب جديد.'
                    : 'Complete payment securely in the app. Your order is saved; you do not need to create another order.',
                key: const Key('checkout-redirect-required'),
                textAlign: TextAlign.center,
              ),
            ],
            if (controller.busy) ...[
              const SizedBox(height: 16),
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
            if (state == CheckoutPaymentState298.pending) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('checkout-continue-payment'),
                onPressed: controller.canPay ? controller.openPayment : null,
                icon: const Icon(Icons.lock_outline),
                label: Text(ar ? 'متابعة الدفع' : 'Continue payment'),
              ),
              if (!controller.busy && !controller.canPay)
                Text(
                  ar
                      ? 'رابط الدفع غير متاح الآن. راجع الطلب أو تواصل مع المتجر.'
                      : 'A verified payment link is unavailable. Review the order or contact the store.',
                  key: const Key('checkout-payment-link-unavailable'),
                  textAlign: TextAlign.center,
                ),
            ],
            if (controller.openFailed) ...[
              const SizedBox(height: 12),
              Text(
                ar
                    ? 'تعذر فتح الدفع. حاول مرة أخرى.'
                    : 'Unable to open payment. Please retry.',
                key: const Key('checkout-payment-open-failed'),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('checkout-check-payment'),
              onPressed: controller.busy ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
              label: Text(ar ? 'التحقق من حالة الطلب' : 'Check order status'),
            ),
            if (widget.onReviewOrders != null)
              TextButton(
                key: const Key('checkout-payment-review-orders'),
                onPressed: controller.busy ? null : widget.onReviewOrders,
                child: Text(ar ? 'عرض طلباتي' : 'View my orders'),
              ),
          ],
        ),
      ),
    );
  }
}
