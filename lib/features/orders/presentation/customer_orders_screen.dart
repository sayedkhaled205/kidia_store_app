import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/core/theme/kidia_colors.dart';
import 'package:kidia_store_app/core/theme/kidia_radius.dart';
import 'package:kidia_store_app/core/theme/kidia_spacing.dart';
import 'package:kidia_store_app/features/cart/presentation/widgets/cart_icon_button.dart';
import 'package:kidia_store_app/features/orders/domain/entities/customer_order.dart';
import 'package:kidia_store_app/features/orders/domain/repositories/customer_orders_repository.dart';
import 'package:kidia_store_app/features/orders/presentation/controllers/customer_orders_controller.dart';
import 'package:kidia_store_app/features/orders/presentation/providers/customer_orders_providers.dart';

class CustomerOrdersScreen extends ConsumerStatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  ConsumerState<CustomerOrdersScreen> createState() =>
      _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends ConsumerState<CustomerOrdersScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 420) {
      ref.read(customerOrdersControllerProvider).loadMore();
    }
  }

  Future<void> _cancelOrder(
    CustomerOrder order,
    CustomerOrdersController controller,
    _OrdersCopy copy,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(copy.cancelTitle),
            content: Text(copy.cancelConfirmation(order.number)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(copy.keepOrder),
              ),
              FilledButton(
                key: const Key('confirm-cancel-order'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(copy.confirmCancel),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }

    final bool cancelled = await controller.cancelOrder(order);
    if (!mounted) {
      return;
    }
    final String message = cancelled
        ? copy.cancelled
        : copy.cancelError(controller.state.mutationError);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final CustomerOrdersController controller = ref.watch(
      customerOrdersControllerProvider,
    );
    final _OrdersCopy copy = _OrdersCopy.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(copy.title),
        actions: <Widget>[
          CartIconButton(onPressed: () => context.push('/cart')),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (BuildContext context, Widget? child) => _OrdersContent(
          controller: controller,
          scrollController: _scrollController,
          copy: copy,
          onCancel: (CustomerOrder order) =>
              _cancelOrder(order, controller, copy),
        ),
      ),
    );
  }
}

class _OrdersContent extends StatelessWidget {
  const _OrdersContent({
    required this.controller,
    required this.scrollController,
    required this.copy,
    required this.onCancel,
  });

  final CustomerOrdersController controller;
  final ScrollController scrollController;
  final _OrdersCopy copy;
  final ValueChanged<CustomerOrder> onCancel;

  @override
  Widget build(BuildContext context) {
    final CustomerOrdersState state = controller.state;
    return RefreshIndicator(
      onRefresh: () => controller.loadInitial(refresh: true),
      child: CustomScrollView(
        key: const Key('customer-orders-scroll'),
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          if (state.isInitialLoading && state.items.isNotEmpty)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          if (state.isInitialLoading && state.items.isEmpty)
            const _OrdersLoadingList()
          else if (state.error != null && state.items.isEmpty)
            _OrdersStatus(
              icon: Icons.cloud_off_outlined,
              title: copy.errorTitle,
              description: copy.errorMessage(state.error!),
              actionLabel: copy.retry,
              onAction: controller.loadInitial,
            )
          else if (state.items.isEmpty)
            _OrdersStatus(
              icon: Icons.receipt_long_outlined,
              title: copy.emptyTitle,
              description: copy.emptyBody,
            )
          else ...<Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  KidiaSpacing.md,
                  KidiaSpacing.md,
                  KidiaSpacing.md,
                  KidiaSpacing.sm,
                ),
                child: Text(
                  copy.orderCount(state.totalItems),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                KidiaSpacing.md,
                0,
                KidiaSpacing.md,
                KidiaSpacing.sm,
              ),
              sliver: SliverList.separated(
                itemCount: state.items.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: KidiaSpacing.sm),
                itemBuilder: (BuildContext context, int index) {
                  final CustomerOrder order = state.items[index];
                  return _OrderCard(
                    key: ValueKey<int>(order.id),
                    order: order,
                    copy: copy,
                    isCancelling: controller.isCancelling(order.id),
                    onCancel: () => onCancel(order),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: _OrdersFooter(
                state: state,
                copy: copy,
                onRetry: controller.loadMore,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.copy,
    required this.isCancelling,
    required this.onCancel,
    super.key,
  });

  final CustomerOrder order;
  final _OrdersCopy copy;
  final bool isCancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<CustomerOrderItem> visibleItems = order.items
        .take(3)
        .toList(growable: false);
    final int hiddenItems = order.items.length - visibleItems.length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(KidiaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        copy.orderNumber(order.number),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (order.dateCreated != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          copy.date(order.dateCreated!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: KidiaSpacing.sm),
                _OrderStatusChip(
                  status: order.status,
                  label: copy.status(order),
                ),
              ],
            ),
            const SizedBox(height: KidiaSpacing.sm),
            Divider(color: colors.outlineVariant),
            const SizedBox(height: KidiaSpacing.xs),
            if (visibleItems.isEmpty)
              Text(
                copy.items(order.itemCount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              )
            else
              for (final CustomerOrderItem item in visibleItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.checkroom_outlined,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: KidiaSpacing.xs),
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: KidiaSpacing.sm),
                      Text(
                        '× ${item.quantity}',
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            if (hiddenItems > 0)
              Text(
                copy.moreItems(hiddenItems),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: KidiaSpacing.sm),
            Row(
              children: <Widget>[
                Text(
                  copy.total,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    order.totalDisplay,
                    key: Key('customer-order-total-${order.id}'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if (order.canCancel) ...<Widget>[
              const SizedBox(height: KidiaSpacing.sm),
              OutlinedButton.icon(
                key: Key('cancel-customer-order-${order.id}'),
                onPressed: isCancelling ? null : onCancel,
                icon: isCancelling
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close_rounded),
                label: Text(
                  isCancelling ? copy.cancelling : copy.cancelOrder,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderStatusChip extends StatelessWidget {
  const _OrderStatusChip({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color foreground = switch (status) {
      'completed' => KidiaColors.success,
      'processing' => KidiaColors.primaryDark,
      'pending' || 'on-hold' => const Color(0xFF9A6700),
      'cancelled' || 'failed' || 'refunded' => KidiaColors.error,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(KidiaRadius.full),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OrdersLoadingList extends StatelessWidget {
  const _OrdersLoadingList();

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.surfaceContainer;
    return SliverPadding(
      padding: const EdgeInsets.all(KidiaSpacing.md),
      sliver: SliverList.separated(
        itemCount: 4,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: KidiaSpacing.sm),
        itemBuilder: (BuildContext context, int index) => Container(
          height: 190,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(KidiaRadius.lg),
          ),
        ),
      ),
    );
  }
}

class _OrdersStatus extends StatelessWidget {
  const _OrdersStatus({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(KidiaSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: KidiaSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: KidiaSpacing.xs),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: KidiaSpacing.md),
                FilledButton.tonalIcon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersFooter extends StatelessWidget {
  const _OrdersFooter({
    required this.state,
    required this.copy,
    required this.onRetry,
  });

  final CustomerOrdersState state;
  final _OrdersCopy copy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(KidiaSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(KidiaSpacing.md),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(copy.loadMoreRetry),
          ),
        ),
      );
    }
    return const SizedBox(height: KidiaSpacing.lg);
  }
}

class _OrdersCopy {
  const _OrdersCopy(this.arabic);

  factory _OrdersCopy.of(BuildContext context) => _OrdersCopy(
    Localizations.localeOf(context).languageCode.toLowerCase() == 'ar',
  );

  final bool arabic;

  String get title => arabic ? 'طلباتي' : 'My orders';
  String get total => arabic ? 'الإجمالي' : 'Total';
  String get retry => arabic ? 'إعادة المحاولة' : 'Retry';
  String get loadMoreRetry => arabic
      ? 'تعذر تحميل المزيد، حاول مرة أخرى'
      : 'Could not load more, try again';
  String get emptyTitle => arabic ? 'لا توجد طلبات حتى الآن' : 'No orders yet';
  String get emptyBody => arabic
      ? 'أي طلب تنفذه بهذا الحساب سيظهر هنا تلقائيًا.'
      : 'Orders placed with this account will appear here automatically.';
  String get errorTitle =>
      arabic ? 'تعذر تحميل طلباتك' : 'Could not load your orders';
  String get cancelOrder => arabic ? 'إلغاء الطلب' : 'Cancel order';
  String get cancelling => arabic ? 'جارٍ إلغاء الطلب…' : 'Cancelling…';
  String get cancelTitle => arabic ? 'إلغاء الطلب' : 'Cancel order';
  String get keepOrder => arabic ? 'الاحتفاظ بالطلب' : 'Keep order';
  String get confirmCancel => arabic ? 'تأكيد الإلغاء' : 'Confirm cancellation';
  String get cancelled => arabic
      ? 'تم إلغاء الطلب بنجاح.'
      : 'The order was cancelled successfully.';

  String errorMessage(Object error) {
    if (error is CustomerOrdersRepositoryException) {
      if (error.kind == CustomerOrdersFailureKind.unauthorized) {
        return arabic
            ? 'انتهت جلسة الحساب. سجّل الدخول من جديد ثم حاول مرة أخرى.'
            : 'Your account session expired. Sign in again and retry.';
      }
      if (error.kind == CustomerOrdersFailureKind.connection ||
          error.kind == CustomerOrdersFailureKind.timeout) {
        return arabic
            ? 'تحقق من اتصال الإنترنت ثم حاول مرة أخرى.'
            : 'Check your internet connection and try again.';
      }
    }
    return arabic
        ? 'حدثت مشكلة أثناء قراءة الطلبات من المتجر.'
        : 'There was a problem reading orders from the store.';
  }

  String orderNumber(String number) =>
      arabic ? 'طلب #$number' : 'Order #$number';
  String orderCount(int count) =>
      arabic ? '$count طلب' : '$count ${count == 1 ? 'order' : 'orders'}';
  String items(int count) =>
      arabic ? '$count منتج' : '$count ${count == 1 ? 'item' : 'items'}';
  String moreItems(int count) =>
      arabic ? '+ $count منتجات أخرى' : '+ $count more items';

  String cancelConfirmation(String number) => arabic
      ? 'هل تريد إلغاء الطلب #$number؟ لا يمكن التراجع بعد التأكيد.'
      : 'Cancel order #$number? This cannot be undone after confirmation.';

  String cancelError(Object? error) {
    if (error is CustomerOrdersRepositoryException &&
        error.statusCode == 409) {
      return arabic
          ? 'لم يعد هذا الطلب متاحًا للإلغاء.'
          : 'This order can no longer be cancelled.';
    }
    return arabic
        ? 'تعذر إلغاء الطلب الآن. حاول مرة أخرى.'
        : 'Could not cancel the order. Please try again.';
  }

  String status(CustomerOrder order) {
    if (!arabic) {
      return order.statusName;
    }
    return switch (order.status) {
      'pending' => 'بانتظار الدفع',
      'processing' => 'قيد التنفيذ',
      'on-hold' => 'قيد الانتظار',
      'completed' => 'مكتمل',
      'cancelled' => 'ملغي',
      'refunded' => 'مسترد',
      'failed' => 'فشل',
      _ => order.statusName,
    };
  }

  String date(DateTime value) {
    final DateTime local = value.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}
