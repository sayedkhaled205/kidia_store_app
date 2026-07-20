import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:kidia_store_app/features/cart/presentation/adapters/product_purchase_selection.dart'
    as cart_selection;
import 'package:kidia_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:kidia_store_app/features/product/application/product_detail_controller.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';

class ProductQuickAddButton extends ConsumerWidget {
  const ProductQuickAddButton({required this.productId, super.key});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CmsPageLayout productLayout =
        ref.watch(cmsPageLayoutProvider('product')).value ??
        CmsPageLayout.fallback('product');
    if (productId <= 0 ||
        !productLayout
            .element('product_summary')
            .boolean('quick_add_enabled', true)) {
      return const SizedBox.shrink();
    }
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        key: Key('quick-add-product-$productId'),
        tooltip: 'إضافة سريعة للسلة',
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) => _ProductQuickAddSheet(
            productId: productId,
          ),
        ),
        icon: const Icon(Icons.shopping_bag_outlined),
      ),
    );
  }
}

class _ProductQuickAddSheet extends ConsumerStatefulWidget {
  const _ProductQuickAddSheet({required this.productId});

  final int productId;

  @override
  ConsumerState<_ProductQuickAddSheet> createState() =>
      _ProductQuickAddSheetState();
}

class _ProductQuickAddSheetState
    extends ConsumerState<_ProductQuickAddSheet> {
  late final ProductDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProductDetailController(
      repository: ref.read(catalogRepositoryProvider),
      productId: widget.productId,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('product-quick-add-sheet'),
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            if (_controller.status == ProductDetailStatus.loading ||
                _controller.status == ProductDetailStatus.initial) {
              return const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_controller.status != ProductDetailStatus.success ||
                _controller.product == null) {
              return SizedBox(
                height: 260,
                child: Center(
                  child: Text(
                    _controller.loadError ?? 'تعذر تحميل المنتج.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return _content(context, _controller.product!);
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, CatalogProduct product) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final displayedPrice = _controller.displayedPrice;
    final String price =
        displayedPrice?.displayAmount(displayedPrice.priceMinor) ?? '';
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IconButton(
              key: const Key('product-quick-add-close'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (product.images.isNotEmpty)
                    SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: product.images.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (BuildContext context, int index) =>
                            AppNetworkImage(
                              imageUrl: product.images[index].source.toString(),
                              width: 150,
                              height: 190,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(16),
                            ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          product.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        price,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  for (final ProductOptionGroup group
                      in _controller.optionGroups) ...<Widget>[
                    Text(
                      group.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: group.values.map((ProductOptionValue option) {
                        final bool selected =
                            _controller.selectedAttributes[group.key] ==
                            option.value;
                        final bool available = _controller.isOptionAvailable(
                          group.key,
                          option.value,
                        );
                        return ChoiceChip(
                          selected: selected,
                          label: Text(option.label),
                          onSelected: available
                              ? (_) => _controller.selectOption(
                                  group.key,
                                  option.value,
                                )
                              : null,
                        );
                      }).toList(growable: false),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (_controller.addError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _controller.addError!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                key: const Key('product-quick-add-submit'),
                onPressed: _controller.canAddToCart ? _addToCart : null,
                icon: _controller.isAdding
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shopping_bag_outlined),
                label: const Text('أضف إلى السلة'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart() async {
    final addSelection = ref.read(addProductPurchaseSelectionProvider);
    final bool added = await _controller.addToCart(
      (ProductPurchaseSelection selection) async {
        final result = await addSelection(
          cart_selection.ProductPurchaseSelection(
            productId: selection.variationId ?? selection.productId,
            quantity: selection.quantity,
            variation: selection.selectedAttributes.entries
                .map(
                  (MapEntry<String, String> entry) => CartItemVariation(
                    attribute: entry.key,
                    value: entry.value,
                  ),
                )
                .toList(growable: false),
          ),
        );
        if (!result.succeeded) {
          throw StateError(result.message ?? 'تعذر إضافة المنتج إلى السلة.');
        }
      },
    );
    if (added && mounted) Navigator.of(context).pop();
  }
}
