import 'package:flutter/material.dart';
import 'package:mobishop_store_app/core/app_design/app_ui_controls.dart';

/// Draw attention once when the authoritative quantity increases, never on load.
class CartCountPulse extends StatefulWidget {
  const CartCountPulse({required this.count, required this.child, super.key});
  final int count;
  final Widget child;

  @override
  State<CartCountPulse> createState() => _CartCountPulseState();
}

class _CartCountPulseState extends State<CartCountPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 440),
  );
  bool _enabled = true;
  double _peak = 1.35;
  late Animation<double> _scale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configure();
  }

  void _configure() {
    final ui = AppUiControlsScope.of(context);
    _enabled =
        ui.boolean('cart_pulse_enabled') &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    _peak = ui.number('cart_pulse_scale');
    _controller.duration = Duration(
      milliseconds: ui.number('cart_pulse_duration').round(),
    );
    if (!_enabled) _controller.reset();
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: _peak,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: _peak,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(CartCountPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configure();
    if (_enabled &&
        widget.count > oldWidget.count &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    key: const Key('cart-count-pulse'),
    scale: _scale,
    child: widget.child,
  );
}
