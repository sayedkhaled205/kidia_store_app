import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/wishlist/application/wishlist_repository_provider.dart';
import 'package:mobishop_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_wishlist_appearance.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

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
  bool _busy = false;
  bool _loading = true;
  StreamSubscription<List<int>>? _changes;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(wishlistRepositoryProvider);
    _changes = _repository.productIdChanges.listen((ids) {
      if (!mounted) return;
      _revision++;
      setState(() { _selected = ids.contains(widget.productId); _loading = false; });
    });
    _load();
  }

  @override
  void didUpdateWidget(covariant ProductWishlistButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) _load();
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _loading = true;
    final revision = ++_revision;
    try {
      final List<int> ids = await _repository.loadProductIds();
      if (mounted && revision == _revision) setState(() { _selected = ids.contains(widget.productId); _loading = false; });
    } catch (_) {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    if (_busy || _loading) return;
    final nativeAuth = AppConfig.isCmsPreview || AppConfig.commercePlatform == CommercePlatform.wooCommerce;
    if (nativeAuth && ref.read(authControllerProvider).isLoading) return;
    final session = nativeAuth ? ref.read(authControllerProvider).asData?.value : null;
    final String accessMode = nativeAuth ? ref.read(cmsPageLayoutProvider('wishlist')).value?.string(
      'wishlist_access_mode',
      'sign_in_required',
    ) ?? 'sign_in_required' : 'guest';
    if (nativeAuth && session == null && accessMode == 'sign_in_required') {
      await context.push('/auth');
      return;
    }
    setState(() => _busy = true);
    try {
      final id = widget.productId;
      final ids = await _repository.updateProductIds((current) => current.contains(id)
          ? current.where((value) => value != id).toList()
          : [id, ...current]);
      if (mounted) setState(() => _selected = ids.contains(widget.productId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'تعذر حفظ المفضلة. حاول مرة أخرى.'
            : 'Unable to save your wishlist. Please try again.',
        )));
      }
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
    final authLoading = (AppConfig.isCmsPreview || AppConfig.commercePlatform == CommercePlatform.wooCommerce)
        && ref.watch(authControllerProvider.select((state) => state.isLoading));
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
          onPressed: _busy || _loading || authLoading ? null : _toggle,
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
