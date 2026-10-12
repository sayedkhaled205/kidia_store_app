import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'odoo_account_screen56.dart';
import 'odoo_customer_chrome56.dart';
import 'odoo_customer_data56.dart';

String _status(BuildContext context, String state) => switch (state) {
  'sale' => odooCopy56(context, 'مؤكد', 'Confirmed'),
  'done' => odooCopy56(context, 'مكتمل', 'Completed'),
  'cancel' => odooCopy56(context, 'ملغي', 'Cancelled'),
  _ => state,
};

class OdooOrdersScreen56 extends ConsumerStatefulWidget {
  const OdooOrdersScreen56({super.key});
  @override
  ConsumerState<OdooOrdersScreen56> createState() => _OdooOrdersScreen56State();
}

class _OdooOrdersScreen56State extends ConsumerState<OdooOrdersScreen56> {
  int _page = 1;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(odooCustomerOrders56Provider(_page));
    return Scaffold(
      appBar: AppBar(title: Text(odooCopy56(context, 'طلباتي', 'My orders'))),
      body: state.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => OdooCustomerFailure56(
          error: error,
          onRetry: () => ref.invalidate(odooCustomerOrders56Provider(_page)),
        ),
        data: (page) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(odooCustomerOrders56Provider(_page));
            await ref.read(odooCustomerOrders56Provider(_page).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (page.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    odooCopy56(
                      context,
                      'لا توجد طلبات في هذه الصفحة.',
                      'There are no orders on this page.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final order in page.items)
                Card(
                  key: Key('odoo-order-${order.id}'),
                  child: ListTile(
                    title: Text(order.name),
                    subtitle: Text(
                      '${_status(context, order.state)}\n${odooCustomerMoney56(order.totalMinor, order.minorUnit, order.currency)}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (context) => OdooCustomerGate56(
                          child: OdooOrderDetailsScreen56(orderId: order.id),
                        ),
                      ),
                    ),
                  ),
                ),
              if (page.totalPages > 1 || _page > 1) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    IconButton(
                      key: const Key('odoo-orders-first'),
                      tooltip: odooCopy56(context, 'أول صفحة', 'First page'),
                      onPressed: _page == 1
                          ? null
                          : () => setState(() => _page = 1),
                      icon: const Icon(Icons.first_page),
                    ),
                    IconButton(
                      key: const Key('odoo-orders-previous'),
                      tooltip: odooCopy56(
                        context,
                        'الصفحة السابقة',
                        'Previous page',
                      ),
                      onPressed: _page <= 1
                          ? null
                          : () => setState(() => _page--),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        '$_page / ${page.totalPages == 0 ? 1 : page.totalPages}',
                      ),
                    ),
                    IconButton(
                      key: const Key('odoo-orders-next'),
                      tooltip: odooCopy56(
                        context,
                        'الصفحة التالية',
                        'Next page',
                      ),
                      onPressed: _page >= page.totalPages
                          ? null
                          : () => setState(() => _page++),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    IconButton(
                      key: const Key('odoo-orders-last'),
                      tooltip: odooCopy56(context, 'آخر صفحة', 'Last page'),
                      onPressed: _page >= page.totalPages
                          ? null
                          : () => setState(() => _page = page.totalPages),
                      icon: const Icon(Icons.last_page),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OdooOrderDetailsScreen56 extends ConsumerWidget {
  const OdooOrderDetailsScreen56({required this.orderId, super.key});
  final int orderId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(odooCustomerOrder56Provider(orderId));
    return Scaffold(
      appBar: AppBar(
        title: Text(odooCopy56(context, 'تفاصيل الطلب', 'Order details')),
      ),
      body: state.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => OdooCustomerFailure56(
          error: error,
          onRetry: () => ref.invalidate(odooCustomerOrder56Provider(orderId)),
        ),
        data: (order) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(odooCustomerOrder56Provider(orderId));
            await ref.read(odooCustomerOrder56Provider(orderId).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        order.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(_status(context, order.state)),
                      if (order.date != null)
                        Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(order.date!.toLocal()),
                        ),
                    ],
                  ),
                ),
              ),
              for (final item in order.items)
                Card(
                  key: Key('odoo-order-item-${item.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        // Odoo's decimal quantity is preserved, never coerced into
                        // Woo's integer quantity model or rounded to whole units.
                        Text(
                          '${odooCopy56(context, 'الكمية', 'Quantity')}: ${item.quantity}',
                        ),
                        Text(
                          odooCustomerMoney56(
                            item.totalMinor,
                            order.minorUnit,
                            order.currency,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${odooCopy56(context, 'قبل الضريبة', 'Subtotal')}: ${odooCustomerMoney56(order.untaxedMinor, order.minorUnit, order.currency)}',
                      ),
                      Text(
                        '${odooCopy56(context, 'الضريبة', 'Tax')}: ${odooCustomerMoney56(order.taxMinor, order.minorUnit, order.currency)}',
                      ),
                      const Divider(),
                      Text(
                        '${odooCopy56(context, 'الإجمالي', 'Total')}: ${odooCustomerMoney56(order.totalMinor, order.minorUnit, order.currency)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
