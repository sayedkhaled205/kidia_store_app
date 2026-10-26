import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobishop_store_app/features/product/application/product_detail_controller.dart';

/// Refresh the visible purchase surface for every commerce platform, including
/// stores without revision events. These are fresh reads, not stock guarantees;
/// the store still validates quantities atomically when the cart is mutated.
class ProductAvailabilityRefresh extends StatefulWidget {
  const ProductAvailabilityRefresh({
    required this.controller,
    required this.child,
    this.interval = const Duration(seconds: 3),
    super.key,
  });

  final ProductDetailController controller;
  final Widget child;
  final Duration interval;

  @override
  State<ProductAvailabilityRefresh> createState() =>
      _ProductAvailabilityRefreshState();
}

class _ProductAvailabilityRefreshState extends State<ProductAvailabilityRefresh>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _reading = false;
  bool get _foreground => WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (mounted && _foreground) _timer = Timer(widget.interval, _refresh);
  }

  Future<void> _refresh() async {
    if (!mounted || !_foreground) return;
    final controller = widget.controller;
    if (!_reading && (ModalRoute.of(context)?.isCurrent ?? true) &&
        controller.status == ProductDetailStatus.success &&
        !controller.isAdding) {
      _reading = true;
      try {
        await controller.load(preserveSelection: true, preserveAddError: true);
      } finally {
        _reading = false;
      }
    }
    if (mounted) _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _timer?.cancel();
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
