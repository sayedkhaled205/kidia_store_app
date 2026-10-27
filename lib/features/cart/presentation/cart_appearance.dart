import 'package:flutter/widgets.dart';
import 'package:mobishop_store_app/core/app_design/app_ui_controls.dart';

/// Which of the existing CartScreen layouts a remote publication selects.
///
/// [theme] keeps the current compactFamilyProvider decision; [classic] and
/// [compact] pin the screen to one of the two layouts that already exist.
enum CartLayout { theme, classic, compact }

/// Display mode for an optional, collapsible cart section.
enum CartSectionDisplay { theme, expanded, collapsed }

/// Validated optional sizes inherit the selected layout/theme when absent.
class CartAppearance {
  const CartAppearance._(this._values);

  final Map<String, dynamic> _values;

  factory CartAppearance.of(BuildContext context) =>
      CartAppearance._(AppUiControlsScope.of(context).values);

  double? _number(String key) {
    final Object? value = _values[key];
    return value is num ? value.toDouble() : null;
  }

  String _choice(String key) {
    final Object? value = _values[key];
    return value is String ? value : 'theme';
  }

  CartLayout get layout => switch (_choice('cart_layout')) {
    'classic' => CartLayout.classic,
    'compact' => CartLayout.compact,
    _ => CartLayout.theme,
  };

  CartSectionDisplay _display(String key) => switch (_choice(key)) {
    'expanded' => CartSectionDisplay.expanded,
    'collapsed' => CartSectionDisplay.collapsed,
    _ => CartSectionDisplay.theme,
  };

  CartSectionDisplay get couponDisplay => _display('cart_coupon_display');
  CartSectionDisplay get summaryDisplay => _display('cart_summary_display');

  double sidePadding({required double fallback}) =>
      _number('cart_side_padding') ?? fallback;
  double itemGap({required double fallback}) =>
      _number('cart_item_gap') ?? fallback;
  double itemImageWidth({required double fallback}) =>
      _number('cart_item_image_width') ?? fallback;
  double itemImageHeight({required double fallback}) =>
      _number('cart_item_image_height') ?? fallback;
  double itemImageRadius({required double fallback}) =>
      _number('cart_item_image_radius') ?? fallback;
  double? get itemNameSize => _number('cart_item_name_size');
  int itemNameLines({required int fallback}) {
    final double? value = _number('cart_item_name_lines');
    return value == null ? fallback : value.round();
  }

  double? get checkoutButtonHeight => _number('cart_checkout_button_height');
  double? get checkoutButtonRadius => _number('cart_checkout_button_radius');
  double? get checkoutButtonFontSize =>
      _number('cart_checkout_button_font_size');

  double emptyIconSize({required double fallback}) =>
      _number('cart_empty_icon_size') ?? fallback;
  double emptyTopSpacing({required double fallback}) =>
      _number('cart_empty_top_spacing') ?? fallback;
}
