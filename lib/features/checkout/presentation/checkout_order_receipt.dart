import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/shared/widgets/common/app_network_image.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/orders/domain/entities/customer_order.dart';
import 'package:mobishop_store_app/features/orders/domain/repositories/customer_orders_repository.dart';
import 'package:mobishop_store_app/features/orders/presentation/customer_orders_screen.dart';
import 'package:mobishop_store_app/features/orders/presentation/providers/customer_orders_providers.dart';

// A receipt lookup never creates an order or launches/retries a payment. Scope
// its cached result to the current session, including logout and account switch.
final checkoutReceiptProvider = FutureProvider.autoDispose
    .family<CustomerOrder, int>((ref, id) async {
      final auth = ref.watch(authControllerProvider);
      final session = auth.value;
      if (auth.hasError || session == null || session.isExpired) {
        throw StateError('Sign in to view this order.');
      }
      final repository = ref.watch(customerOrdersRepositoryProvider);
      if (repository is! CustomerOrderLookupRepository) {
        throw StateError('Order details are unavailable.');
      }
      final order = await (repository as CustomerOrderLookupRepository)
          .getOrder(id);
      if (order.id != id) throw StateError('The order did not match.');
      return order;
    });

class CheckoutReceiptLoader extends ConsumerWidget {
  const CheckoutReceiptLoader({
    required this.orderId,
    this.onContinueShopping,
    this.onViewDetails,
    super.key,
  });
  final int orderId;
  final VoidCallback? onContinueShopping;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(checkoutReceiptProvider(orderId));
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: CheckoutOrderReceipt(
        orderId: orderId,
        order: result.asData?.value,
        title: ar ? 'تم استلام طلبك' : 'Order received',
        titleKey: const Key('checkout-success'),
        logoUrl:
            ref
                .watch(cmsPageLayoutProvider('account'))
                .value
                ?.header
                .string('logo_url', '') ??
            '',
        onContinueShopping: onContinueShopping,
        onViewDetails: onViewDetails,
        loading: result.isLoading,
        onRetry: result.hasError
            ? () => ref.invalidate(checkoutReceiptProvider(orderId))
            : null,
      ),
    );
  }
}

/// Shared by immediate card success and verified COD/redirect continuations.
/// Display only facts from the owned order; never infer delivery dates or paid
/// status from an order number, gateway redirect, or the now-cleared cart.
class CheckoutOrderReceipt extends StatelessWidget {
  const CheckoutOrderReceipt({
    required this.orderId,
    required this.title,
    this.order,
    this.titleKey,
    this.onContinueShopping,
    this.onViewDetails,
    this.loading = false,
    this.onRetry,
    this.logoUrl = '',
    super.key,
  });
  final int orderId;
  final CustomerOrder? order;
  final String title;
  final Key? titleKey;
  final VoidCallback? onContinueShopping;
  final VoidCallback? onViewDetails;
  final bool loading;
  final VoidCallback? onRetry;
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);
    final value = order;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (logoUrl.isNotEmpty) ...[
          Center(
            child: AppNetworkImage(
              imageUrl: logoUrl,
              width: 150,
              height: 56,
              fit: BoxFit.contain,
              trimTransparentPadding: true,
              placeholder: const SizedBox.shrink(),
              errorWidget: const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Icon(
          Icons.check_circle_outline_rounded,
          size: 66,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          key: titleKey,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ar ? 'شكرًا لطلبك!' : 'Thank you for your order!',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        if (onContinueShopping != null) ...[
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onContinueShopping,
            key: const Key('receipt-continue-shopping'),
            child: Text(ar ? 'متابعة التسوق' : 'Continue shopping'),
          ),
        ],
        const SizedBox(height: 24),
        _ReceiptSection(
          title: ar ? 'ملخص الطلب' : 'Order summary',
          children: [
            _ReceiptRow(
              label: ar ? 'رقم الطلب' : 'Order number',
              value: value?.number ?? '$orderId',
            ),
            if (value != null) ...[
              if (value.totalDisplay.isNotEmpty)
                _ReceiptRow(
                  label: ar ? 'الإجمالي' : 'Total',
                  value: value.totalDisplay,
                ),
              if (value.paymentMethodTitle.isNotEmpty)
                _ReceiptRow(
                  label: ar ? 'طريقة الدفع' : 'Payment method',
                  value: value.paymentMethodTitle,
                ),
              if (value.shippingMethod.isNotEmpty)
                _ReceiptRow(
                  label: ar ? 'التوصيل' : 'Delivery',
                  value: value.shippingMethod,
                ),
            ],
            if (onViewDetails != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('receipt-view-details'),
                onPressed: onViewDetails,
                child: Text(ar ? 'عرض تفاصيل الطلب' : 'View order details'),
              ),
            ],
          ],
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          Text(
            ar
                ? 'طلبك محفوظ. تعذر تحميل التفاصيل الآن.'
                : 'Your order is saved. Details could not be loaded.',
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: onRetry,
            key: const Key('receipt-retry'),
            child: Text(ar ? 'إعادة تحميل التفاصيل' : 'Retry details'),
          ),
        ],
        if (value != null && value.items.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ReceiptSection(
            title: ar ? 'منتجات الطلب' : 'Order items',
            children: [
              for (var i = 0; i < value.items.length; i++) ...[
                if (i > 0) const Divider(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CustomerOrderItemImage(item: value.items[i]),
                    const SizedBox(width: 12),
                    Expanded(child: Text(value.items[i].name)),
                    const SizedBox(width: 8),
                    Text(
                      '× ${value.items[i].quantity}',
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _ReceiptSection extends StatelessWidget {
  const _ReceiptSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
