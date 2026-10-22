import 'package:flutter/material.dart';

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
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.35,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.35,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 55,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(CartCountPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count &&
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

