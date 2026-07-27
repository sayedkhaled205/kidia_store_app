import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../cart/presentation/adapters/product_purchase_selection.dart';
import '../../cart/presentation/providers/cart_state_providers.dart';
import '../../catalog/domain/entities/catalog_product.dart';
import '../../catalog/presentation/providers/catalog_providers.dart';
import '../../home/presentation/providers/home_providers.dart';

final bundleDetailProvider =
    FutureProvider.autoDispose.family<_BundleDetail, String>((ref, id) async {
      final response = await ref
          .watch(homeDioProvider)
          .get<dynamic>('/wp-json/woo-mobile/v1/bundles/$id');
      if (response.data is! Map) {
        throw const FormatException('Invalid bundle response.');
      }
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        response.data as Map,
      );
      final List<int> productIds = (data['product_ids'] is List
              ? data['product_ids'] as List<dynamic>
              : const <dynamic>[])
          .map((dynamic value) => int.tryParse('$value') ?? 0)
          .where((int value) => value > 0)
          .toList(growable: false);
      final List<CatalogProduct> products = <CatalogProduct>[];
      for (final int productId in productIds) {
        try {
          products.add(
            await ref.watch(catalogRepositoryProvider).getProduct(productId),
          );
        } on Object {
          // A removed product should not prevent the rest of the bundle loading.
        }
      }
      return _BundleDetail(
        id: '$id',
        name: '${data['name'] ?? 'Bundle'}',
        description: '${data['description'] ?? ''}',
        type: '${data['type'] ?? 'fixed'}',
        productId: int.tryParse('${data['product_id'] ?? 0}') ?? 0,
        minimumItems: int.tryParse('${data['minimum_items'] ?? 1}') ?? 1,
        maximumItems: int.tryParse('${data['maximum_items'] ?? 2}') ?? 2,
        pricing: '${data['pricing'] ?? 'none'}',
        discountValue:
            double.tryParse('${data['discount_value'] ?? 0}') ?? 0,
        products: products,
      );
    });

class BundleBuilderScreen extends ConsumerStatefulWidget {
  const BundleBuilderScreen({required this.bundleId, super.key});

  final String bundleId;

  @override
  ConsumerState<BundleBuilderScreen> createState() =>
      _BundleBuilderScreenState();
}

class _BundleBuilderScreenState extends ConsumerState<BundleBuilderScreen> {
  final Set<int> _selected = <int>{};
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<_BundleDetail> state = ref.watch(
      bundleDetailProvider(widget.bundleId),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('اختيار العرض')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _BundleError(
          onRetry: () => ref.invalidate(bundleDetailProvider(widget.bundleId)),
        ),
        data: (_BundleDetail bundle) {
          if (_selected.isEmpty && bundle.type == 'fixed') {
            _selected.addAll(bundle.products.map((product) => product.id));
          }
          return Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Text(
                      bundle.name,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (bundle.description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        bundle.description,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _BundleTerms(bundle: bundle),
                    const SizedBox(height: 18),
                    ...bundle.products.map(
                      (CatalogProduct product) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BundleProductTile(
                          product: product,
                          selected: _selected.contains(product.id),
                          locked: bundle.type == 'fixed',
                          onChanged: (bool selected) {
                            setState(() {
                              if (selected) {
                                if (_selected.length < bundle.maximumItems) {
                                  _selected.add(product.id);
                                }
                              } else {
                                _selected.remove(product.id);
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: _submitting ||
                            (bundle.productId <= 0 &&
                                _selected.length < bundle.minimumItems)
                        ? null
                        : () => _addBundle(bundle),
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.shopping_bag_outlined),
                    label: Text(
                      bundle.productId <= 0 &&
                              _selected.length < bundle.minimumItems
                          ? 'اختر ${bundle.minimumItems} على الأقل'
                          : 'أضف العرض للسلة',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addBundle(_BundleDetail bundle) async {
    setState(() => _submitting = true);
    final addSelection = ref.read(addProductPurchaseSelectionProvider);
    final List<int> productIds = bundle.productId > 0
        ? <int>[bundle.productId]
        : _selected.toList(growable: false);
    for (final int productId in productIds) {
      final CartActionResult result = await addSelection(
        ProductPurchaseSelection(productId: productId),
      );
      if (!result.succeeded && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'تعذر إضافة العرض للسلة.')),
        );
        setState(() => _submitting = false);
        return;
      }
    }
    if (bundle.productId <= 0 && bundle.discountValue > 0) {
      try {
        final response = await ref.read(homeDioProvider).post<dynamic>(
          '/wp-json/woo-mobile/v1/bundles/${Uri.encodeComponent(bundle.id)}/claim',
          queryParameters: const <String, dynamic>{'channel': 'mobile'},
        );
        final Map<String, dynamic> data = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : const <String, dynamic>{};
        final String couponCode = '${data['coupon_code'] ?? ''}'.trim();
        if (couponCode.isNotEmpty) {
          final CartActionResult couponResult = await ref
              .read(cartControllerProvider.notifier)
              .applyCoupon(couponCode);
          if (!couponResult.succeeded && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  couponResult.message ?? 'أضيفت المنتجات وتعذر تطبيق الخصم.',
                ),
              ),
            );
            setState(() => _submitting = false);
            return;
          }
        }
      } on Object {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('أضيفت المنتجات وتعذر تجهيز خصم الباندل.'),
            ),
          );
          setState(() => _submitting = false);
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    context.push('/cart');
  }
}

class _BundleTerms extends StatelessWidget {
  const _BundleTerms({required this.bundle});

  final _BundleDetail bundle;

  @override
  Widget build(BuildContext context) {
    final String discount = bundle.discountValue <= 0
        ? 'سعر المنتجات'
        : bundle.pricing == 'percentage'
        ? 'خصم ${bundle.discountValue.toStringAsFixed(0)}%'
        : 'خصم ${bundle.discountValue.toStringAsFixed(0)}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$discount • اختر من ${bundle.minimumItems} إلى ${bundle.maximumItems}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BundleProductTile extends StatelessWidget {
  const _BundleProductTile({
    required this.product,
    required this.selected,
    required this.locked,
    required this.onChanged,
  });

  final CatalogProduct product;
  final bool selected;
  final bool locked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: CheckboxListTile(
        value: selected,
        onChanged: locked
            ? null
            : (bool? value) => onChanged(value ?? false),
        secondary: const Icon(Icons.inventory_2_outlined),
        title: Text(
          product.name,
          textAlign: TextAlign.right,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          product.prices.displayAmount(product.prices.priceMinor),
          textAlign: TextAlign.right,
        ),
      ),
    );
  }
}

class _BundleError extends StatelessWidget {
  const _BundleError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          const Text('تعذر تحميل العرض حاليًا.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

class _BundleDetail {
  const _BundleDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.productId,
    required this.minimumItems,
    required this.maximumItems,
    required this.pricing,
    required this.discountValue,
    required this.products,
  });

  final String id;
  final String name;
  final String description;
  final String type;
  final int productId;
  final int minimumItems;
  final int maximumItems;
  final String pricing;
  final double discountValue;
  final List<CatalogProduct> products;
}
