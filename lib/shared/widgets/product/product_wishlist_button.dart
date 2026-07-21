import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kidia_store_app/features/wishlist/data/shared_preferences_wishlist_repository.dart';
import 'package:kidia_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:kidia_store_app/shared/widgets/product/product_wishlist_appearance.dart';

class ProductWishlistButton extends ConsumerStatefulWidget {
  const ProductWishlistButton({
    required this.productId,
    required this.appearance,
    super.key,
  });

  final int productId;
  final ProductWishlistAppearance appearance;

  @override
  ConsumerState<ProductWishlistButton> createState() => _ProductWishlistButtonState();
}

class _ProductWishlistButtonState extends ConsumerState<ProductWishlistButton> {
  late final WishlistRepository _repository;
  bool _selected = false;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _repository = SharedPreferencesWishlistRepository.forConfiguredStore();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<int> ids = await _repository.loadProductIds();
      if (mounted) setState(() { _selected = ids.contains(widget.productId); _busy = false; });
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final session = ref.read(authControllerProvider).asData?.value;
    if (session == null) {
      await context.push('/auth');
      return;
    }
    setState(() => _busy = true);
    try {
      final List<int> ids = (await _repository.loadProductIds()).toList();
      if (ids.contains(widget.productId)) {
        ids.remove(widget.productId);
      } else {
        ids.add(widget.productId);
      }
      await _repository.saveProductIds(ids);
      if (mounted) setState(() => _selected = ids.contains(widget.productId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  IconData get _icon {
    final bool filled = _selected || widget.appearance.iconStyle == 'filled';
    if (widget.appearance.iconVariant == 'bookmark') {
      return filled ? Icons.bookmark : Icons.bookmark_border;
    }
    return filled ? Icons.favorite_rounded : Icons.favorite_border_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.appearance.enabled || widget.productId <= 0) return const SizedBox.shrink();
    final double shell = widget.appearance.backgroundSize.clamp(20, 64).toDouble();
    return SizedBox.square(
      dimension: shell,
      child: Material(
        color: widget.appearance.showBackground
            ? widget.appearance.backgroundColor ?? Theme.of(context).colorScheme.surface
            : Colors.transparent,
        borderRadius: BorderRadius.circular(widget.appearance.backgroundRadius.clamp(0, 40).toDouble()),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          key: Key('product-card-wishlist-${widget.productId}'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: _busy ? null : _toggle,
          icon: Icon(
            _icon,
            size: widget.appearance.iconSize.clamp(10, 36).toDouble(),
            color: _selected ? Theme.of(context).colorScheme.error : widget.appearance.iconColor,
          ),
        ),
      ),
    );
  }
}
