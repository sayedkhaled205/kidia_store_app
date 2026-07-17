import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/features/cart/presentation/providers/cart_state_providers.dart';

/// A cart action that stays in sync with the authoritative WooCommerce cart.
class CartIconButton extends StatelessWidget {
  const CartIconButton({
    required this.onPressed,
    super.key,
    this.tooltip = 'السلة',
  });

  final VoidCallback? onPressed;
  final String tooltip;

  static const double iconSize = 26.4;
  static const double edgeInset = 6;

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

    return Padding(
      // In Arabic this is the physical left edge. Keeping a small end inset
      // prevents the bag and its badge from touching the screen edge while
      // preserving one identical size in every header.
      padding: const EdgeInsetsDirectional.only(end: edgeInset),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Badge.count(
          count: itemCount > 99 ? 99 : itemCount,
          isLabelVisible: itemCount > 0,
          backgroundColor: colors.error,
          textColor: colors.onError,
          child: const Icon(
            Icons.shopping_bag_outlined,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}
