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
    BuildContext actionContext,
    CustomerOrder order,
    CustomerOrdersController controller,
    _OrdersCopy copy,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: actionContext,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(copy.cancelTitle(order)),
            content: Text(copy.cancelConfirmation(order)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(copy.keepOrder),
              ),
              FilledButton(
                key: const Key('confirm-cancel-order'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(copy.confirmCancellation(order)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }

    final bool cancelled = await controller.cancelOrder(order);
    if (!mounted || !actionContext.mounted) {
      return;
    }
    final CustomerOrder? updated = controller.orderById(order.id);
    final String message = cancelled
        ? updated?.status == 'cancel-request'
              ? copy.cancelRequested
              : copy.cancelled
        : copy.cancelError(controller.state.mutationError, order);
    ScaffoldMessenger.of(actionContext)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openOrder(
    CustomerOrder order,
    CustomerOrdersController controller,
    _OrdersCopy copy,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => _CustomerOrderDetailsScreen(
          orderId: order.id,
          initialOrder: order,
          controller: controller,
          copy: copy,
          onCancel: (BuildContext actionContext, CustomerOrder current) =>
              _cancelOrder(actionContext, current, controller, copy),
        ),
      ),
    );
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
          onOpen: (CustomerOrder order) =>
              _openOrder(order, controller, copy),
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
    required this.onOpen,
  });

  final CustomerOrdersController controller;
  final ScrollController scrollController;
  final _OrdersCopy copy;
  final ValueChanged<CustomerOrder> onOpen;

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
                    onTap: () => onOpen(order),
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
    required this.onTap,
    super.key,
  });

  final CustomerOrder order;
  final _OrdersCopy copy;
  final VoidCallback onTap;

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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('open-customer-order-${order.id}'),
        onTap: onTap,
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
              const SizedBox(height: KidiaSpacing.xs),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  copy.viewDetails,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
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

typedef _CancelOrderCallback =
    Future<void> Function(BuildContext context, CustomerOrder order);

class _CustomerOrderDetailsScreen extends StatelessWidget {
  const _CustomerOrderDetailsScreen({
    required this.orderId,
    required this.initialOrder,
    required this.controller,
    required this.copy,
    required this.onCancel,
  });

  final int orderId;
  final CustomerOrder initialOrder;
  final CustomerOrdersController controller;
  final _OrdersCopy copy;
  final _CancelOrderCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final CustomerOrder order =
            controller.orderById(orderId) ?? initialOrder;
        final bool isCancelling = controller.isCancelling(order.id);
        final ThemeData theme = Theme.of(context);
        final ColorScheme colors = theme.colorScheme;
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Text(copy.detailsTitle),
          ),
          body: ListView(
            key: Key('customer-order-details-${order.id}'),
            padding: const EdgeInsets.all(KidiaSpacing.md),
            children: <Widget>[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(KidiaSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              copy.orderNumber(order.number),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _OrderStatusChip(
                            status: order.status,
                            label: copy.status(order),
                          ),
                        ],
                      ),
                      if (order.dateCreated != null) ...<Widget>[
                        const SizedBox(height: KidiaSpacing.sm),
                        _OrderDetailsRow(
                          label: copy.orderDate,
                          value: copy.date(order.dateCreated!),
                        ),
                      ],
                      const SizedBox(height: KidiaSpacing.xs),
                      _OrderDetailsRow(
                        label: copy.orderStatus,
                        value: copy.status(order),
                      ),
                    ],
                  ),
                ),
              ),
              if (order.status == 'cancel-request') ...<Widget>[
                const SizedBox(height: KidiaSpacing.md),
                Container(
                  key: const Key('order-cancellation-requested-notice'),
                  padding: const EdgeInsets.all(KidiaSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(KidiaRadius.md),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.schedule_send_outlined,
                        color: colors.onPrimaryContainer,
                      ),
                      const SizedBox(width: KidiaSpacing.sm),
                      Expanded(
                        child: Text(
                          copy.cancelRequestPending,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: KidiaSpacing.md),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(KidiaSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        copy.orderProducts,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: KidiaSpacing.sm),
                      if (order.items.isEmpty)
                        Text(copy.items(order.itemCount))
                      else
                        for (int index = 0; index < order.items.length; index++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index == order.items.length - 1
                                  ? 0
                                  : KidiaSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  Icons.checkroom_outlined,
                                  size: 20,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: KidiaSpacing.sm),
                                Expanded(
                                  child: Text(
                                    order.items[index].name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: KidiaSpacing.sm),
                                Text(
                                  '× ${order.items[index].quantity}',
                                  textDirection: TextDirection.ltr,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: KidiaSpacing.md),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(KidiaSpacing.md),
                  child: Row(
                    children: <Widget>[
                      Text(
                        copy.total,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          order.totalDisplay,
                          key: Key('customer-order-details-total-${order.id}'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (order.canCancel) ...<Widget>[
                const SizedBox(height: KidiaSpacing.md),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    key: Key('details-cancel-customer-order-${order.id}'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      visualDensity: VisualDensity.compact,
                      textStyle: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: isCancelling
                        ? null
                        : () => onCancel(context, order),
                    icon: isCancelling
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close_rounded, size: 17),
                    label: Text(
                      isCancelling
                          ? copy.cancellationInProgress(order)
                          : copy.cancellationAction(order),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: KidiaSpacing.lg),
            ],
          ),
        );
      },
    );
  }
}

class _OrderDetailsRow extends StatelessWidget {
  const _OrderDetailsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
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
      'cancel-request' => const Color(0xFF9A6700),
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
  String get detailsTitle => arabic ? 'تفاصيل الطلب' : 'Order details';
  String get viewDetails => arabic ? 'عرض التفاصيل' : 'View details';
  String get orderDate => arabic ? 'تاريخ الطلب' : 'Order date';
  String get orderStatus => arabic ? 'حالة الطلب' : 'Order status';
  String get orderProducts => arabic ? 'منتجات الطلب' : 'Order products';
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
  String get requestCancellation => arabic
      ? 'طلب إلغاء'
      : 'Request cancellation';
  String get keepOrder => arabic ? 'الاحتفاظ بالطلب' : 'Keep order';
  String get cancelled => arabic
      ? 'تم إلغاء الطلب بنجاح.'
      : 'The order was cancelled successfully.';
  String get cancelRequested => arabic
      ? 'تم إرسال طلب الإلغاء للمراجعة.'
      : 'The cancellation request was sent for review.';
  String get cancelRequestPending => arabic
      ? 'تم إرسال طلب الإلغاء، وهو الآن قيد مراجعة المتجر.'
      : 'Your cancellation request is being reviewed by the store.';

  String cancellationAction(CustomerOrder order) =>
      order.isCancellationRequest ? requestCancellation : cancelOrder;

  String cancellationInProgress(CustomerOrder order) {
    if (order.isCancellationRequest) {
      return arabic ? 'جارٍ إرسال الطلب…' : 'Sending request…';
    }
    return arabic ? 'جارٍ إلغاء الطلب…' : 'Cancelling…';
  }

  String cancelTitle(CustomerOrder order) => order.isCancellationRequest
      ? requestCancellation
      : cancelOrder;

  String confirmCancellation(CustomerOrder order) =>
      order.isCancellationRequest
      ? arabic
            ? 'إرسال الطلب'
            : 'Send request'
      : arabic
      ? 'تأكيد الإلغاء'
      : 'Confirm cancellation';

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

  String cancelConfirmation(CustomerOrder order) {
    if (order.isCancellationRequest) {
      return arabic
          ? 'هل تريد إرسال طلب إلغاء للطلب #${order.number}؟ سيقوم المتجر بمراجعته.'
          : 'Request cancellation for order #${order.number}? The store will review it.';
    }
    return arabic
        ? 'هل تريد إلغاء الطلب #${order.number}؟ لا يمكن التراجع بعد التأكيد.'
        : 'Cancel order #${order.number}? This cannot be undone after confirmation.';
  }

  String cancelError(Object? error, CustomerOrder order) {
    if (error is CustomerOrdersRepositoryException &&
        error.statusCode == 409) {
      return arabic
          ? 'لم يعد هذا الطلب متاحًا للإلغاء.'
          : 'This order can no longer be cancelled.';
    }
    if (order.isCancellationRequest) {
      return arabic
          ? 'تعذر إرسال طلب الإلغاء الآن. حاول مرة أخرى.'
          : 'Could not send the cancellation request. Please try again.';
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
      'cancel-request' => 'طلب إلغاء',
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
