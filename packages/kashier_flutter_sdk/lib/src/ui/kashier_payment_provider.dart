import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

/// Wraps the merchant's app to enable the Kashier SDK to show payment UI.
///
/// Place this above your `MaterialApp` (or any router) so the SDK can
/// display payment sheets on its own overlay — independent of the
/// merchant's navigation stack.
///
/// ```dart
/// void main() {
///   runApp(
///     KashierPaymentProvider(
///       child: MaterialApp.router(
///         routerConfig: goRouter,
///       ),
///     ),
///   );
/// }
/// ```
///
/// Works with any navigation solution: Navigator 2.0, GoRouter, AutoRoute,
/// CupertinoApp, nested navigators, etc.
class KashierPaymentProvider extends StatefulWidget {
  /// The merchant's app widget tree.
  final Widget child;

  const KashierPaymentProvider({
    super.key,
    required this.child,
  });

  /// Returns the provider state from anywhere in the tree below it.
  ///
  /// Used internally by the SDK — merchants should not call this directly.
  static KashierPaymentProviderState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<KashierPaymentProviderState>();
  }

  @override
  State<KashierPaymentProvider> createState() => KashierPaymentProviderState();
}

/// The state that manages the payment overlay.
///
/// The SDK uses this to show and dismiss payment sheets without
/// depending on the merchant's navigator.
class KashierPaymentProviderState extends State<KashierPaymentProvider> {
  /// The global instance, set when the provider mounts.
  ///
  /// This allows the SDK to access the overlay from static methods
  /// without requiring a BuildContext.
  static KashierPaymentProviderState? _instance;

  /// Returns the current mounted provider instance, or null if not mounted.
  @internal
  static KashierPaymentProviderState? get instance => _instance;

  Widget? _overlayChild;

  @override
  void initState() {
    super.initState();
    _instance = this;
  }

  @override
  void dispose() {
    if (_instance == this) {
      _instance = null;
    }
    super.dispose();
  }

  /// Shows a widget on the payment overlay.
  ///
  /// Only one payment sheet can be shown at a time. The language the
  /// overlay renders in comes from [KashierSDK.language], which the
  /// merchant sets at [KashierSDK.initialize].
  @internal
  void showPaymentSheet(Widget sheet) {
    setState(() {
      _overlayChild = sheet;
    });
  }

  /// Dismisses the current payment sheet.
  void dismissPaymentSheet() {
    setState(() => _overlayChild = null);
  }

  /// Whether a payment sheet is currently visible.
  bool get isShowing => _overlayChild != null;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (_overlayChild != null) _overlayChild!,
        ],
      ),
    );
  }
}
