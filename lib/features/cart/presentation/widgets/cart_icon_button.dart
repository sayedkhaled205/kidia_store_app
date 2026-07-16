import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/features/cart/presentation/providers/cart_state_providers.dart';

/// A cart action that stays in sync with the authoritative WooCommerce cart.
class CartIconButton extends StatelessWidget {
  const CartIconButton({
    required this.onPressed,
    super.key,
    this.tooltip = 'السلة',
    this.iconSize,
  });

  final VoidCallback? onPressed;
  final String tooltip;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    try {
      ProviderScope.containerOf(context, listen: false);
    } on StateError {
      // Keeps isolated previews and screen-level tests usable. Production is
      // always hosted by the application's ProviderScope.
      return _button(context, 0);
    }
    return Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? child) {
        return _button(context, ref.watch(cartBadgeCountProvider));
      },
    );
  }

  Widget _button(BuildContext context, int itemCount) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Badge.count(
        count: itemCount > 99 ? 99 : itemCount,
        isLabelVisible: itemCount > 0,
        backgroundColor: colors.error,
        textColor: colors.onError,
        child: Icon(Icons.shopping_bag_outlined, size: iconSize),
      ),
    );
  }
}
