import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:kidia_store_app/features/cart/presentation/adapters/product_purchase_selection.dart'
    as cart_selection;
import 'package:kidia_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:kidia_store_app/features/product/application/product_detail_controller.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';
import 'package:kidia_store_app/shared/widgets/product/product_quick_add_appearance.dart';

class ProductQuickAddButton extends StatelessWidget {
  const ProductQuickAddButton({
    required this.productId,
    this.enabled = true,
    this.iconVariant = 'bag',
    this.iconStyle = 'outline',
    this.iconSize = 22,
    this.iconColor,
    this.showBackground = true,
    this.backgroundColor,
    this.backgroundRadius = 24,
	this.backgroundSize = 40,
    this.appearance,
    super.key,
  });

  final int productId;
  final bool enabled;
  final String iconVariant;
  final String iconStyle;
  final double iconSize;
  final Color? iconColor;
  final bool showBackground;
  final Color? backgroundColor;
  final double backgroundRadius;
  final double backgroundSize;
  final ProductQuickAddAppearance? appearance;

  IconData get _icon {
    final String resolvedStyle = appearance?.iconStyle ?? iconStyle;
    final bool filled = resolvedStyle == 'filled';
    switch (appearance?.iconVariant ?? iconVariant) {
      case 'cart':
        return filled ? Icons.shopping_cart : Icons.shopping_cart_outlined;
      case 'basket':
        return filled ? Icons.shopping_basket : Icons.shopping_basket_outlined;
      default:
        return filled || resolvedStyle == 'rounded'
            ? Icons.shopping_bag_rounded
            : Icons.shopping_bag_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (productId <= 0 || !enabled) {
      return const SizedBox.shrink();
    }
	final double resolvedSize = (appearance?.backgroundSize ?? backgroundSize)
		.clamp(28, 64)
		.toDouble();
    return SizedBox.square(
	  key: Key('quick-add-shell-$productId'),
	  dimension: resolvedSize,
	  child: Material(
      color: (appearance?.showBackground ?? showBackground)
          ? appearance?.backgroundColor ?? backgroundColor ??
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.94)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          (appearance?.backgroundRadius ?? backgroundRadius)
              .clamp(0, 40)
              .toDouble(),
        ),
      ),
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
        iconSize: (appearance?.iconSize ?? iconSize)
            .clamp(16, 36)
            .toDouble(),
        color:
            appearance?.iconColor ??
            iconColor ??
            Theme.of(context).colorScheme.onSurface,
		padding: EdgeInsets.zero,
		constraints: const BoxConstraints(),
		icon: _buildIcon(),
      ),
	  ),
    );
  }

	Widget _buildIcon() {
	  final double size = (appearance?.iconSize ?? iconSize).clamp(16, 36).toDouble();
	  final String variant = appearance?.iconVariant ?? iconVariant;
	  if (variant != 'bag') {
		return Icon(_icon);
	  }
	  return SizedBox.square(
		dimension: size,
		child: Stack(
		  clipBehavior: Clip.none,
		  children: <Widget>[
			Positioned.fill(child: Icon(_icon, size: size)),
			PositionedDirectional(
			  end: -1,
			  bottom: -1,
			  child: Icon(Icons.add_rounded, size: size * 0.46),
			),
		  ],
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
