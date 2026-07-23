import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/features/home/data/repositories/home_repository_impl.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_layout.dart';
import 'package:kidia_store_app/features/home/presentation/providers/home_providers.dart';
import 'package:kidia_store_app/features/home/presentation/widgets/home_block_renderer.dart';
import 'package:kidia_store_app/features/search/presentation/catalog_search_launcher.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:kidia_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final ScrollController _scrollController;
  final Map<String, GlobalKey> _blockKeys = <String, GlobalKey>{};
  List<HomeBlock> _visibleBlocks = const <HomeBlock>[];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String locale = Localizations.localeOf(context).toLanguageTag();

    final AsyncValue<HomeLayout> homeLayoutAsync = ref.watch(
      homeLayoutProvider(locale),
    );
    final AsyncValue<CmsPageLayout> chromeState = ref.watch(
      cmsPageLayoutProvider('home'),
    );
    final CmsPageLayout? loadedChrome = chromeState.value;
    if (loadedChrome == null && !chromeState.hasError) {
      return const Scaffold(
        body: SafeArea(child: _HomeLoadingState()),
      );
    }
    final CmsPageLayout chrome =
        loadedChrome ?? CmsPageLayout.fallback('home');
    ref.listen<AsyncValue<String>>(
      cmsPreviewHomeFocusTargetProvider,
      (_, AsyncValue<String> next) => next.whenData(_focusPreviewTarget),
    );

    return CmsPageScaffold(
      layout: chrome,
      defaultTitle: 'Kidia',
      scrollController: _scrollController,
      actions: <CmsPageHeaderAction>[
          CmsPageHeaderAction(type: 'search', icon: Icons.search_rounded, tooltip: 'بحث', onPressed: () => showCatalogSearch(context)),
          CmsPageHeaderAction(type: 'cart', icon: Icons.shopping_bag_outlined, tooltip: 'السلة', onPressed: () => context.go('/cart')),
          CmsPageHeaderAction(type: 'wishlist', icon: Icons.favorite_border_rounded, tooltip: 'المفضلة', onPressed: () => context.go('/wishlist')),
          CmsPageHeaderAction(type: 'account', icon: Icons.person_outline_rounded, tooltip: 'حسابي', onPressed: () => context.go('/account')),
      ],
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () {
            return ref.refresh(homeLayoutProvider(locale).future);
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              homeLayoutAsync.when(
                data: (HomeLayout layout) {
                  _visibleBlocks = layout.enabledBlocks
                      .where((HomeBlock block) => block is! AppHeaderBlock)
                      .toList(growable: false);
                  return SliverMainAxisGroup(
                    slivers: <Widget>[
                      HomeBlockRenderer(
                        blocks: _visibleBlocks,
                        keyForBlock: _keyForBlock,
                        onAction: (HomeAction action) {
                          _handleHomeAction(context: context, action: action);
                        },
                      ),
                    ],
                  );
                },
                loading: () {
                  return const SliverMainAxisGroup(
                    slivers: <Widget>[
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _HomeLoadingState(),
                      ),
                    ],
                  );
                },
                error: (Object error, StackTrace stackTrace) {
                  return SliverMainAxisGroup(
                    slivers: <Widget>[
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _HomeErrorState(
                          message: _resolveErrorMessage(error),
                          onRetry: () {
                            ref.invalidate(homeLayoutProvider(locale));
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Key _keyForBlock(String blockId) =>
      _blockKeys.putIfAbsent(blockId, GlobalKey.new);

  void _focusPreviewTarget(String target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (target == 'header') {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (target == 'footer') {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      final BuildContext? blockContext = _blockKeys[target]?.currentContext;
      if (blockContext != null) {
        Scrollable.ensureVisible(
          blockContext,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: .18,
        );
        return;
      }
      final int index = _visibleBlocks.indexWhere(
        (HomeBlock block) => block.id == target,
      );
      if (index < 0 || _visibleBlocks.isEmpty) return;
      final double fraction = index / _visibleBlocks.length;
      _scrollController
          .animateTo(
            _scrollController.position.maxScrollExtent * fraction,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          )
          .then((_) {
            if (!mounted) return;
            final BuildContext? context = _blockKeys[target]?.currentContext;
            if (context != null) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: .18,
              );
            }
          });
    });
  }

  static String _resolveErrorMessage(Object error) {
    if (error is HomeRepositoryException) {
      return error.message;
    }

    return 'تعذر تحميل الصفحة الرئيسية حاليًا.';
  }

  static void _handleHomeAction({
    required BuildContext context,
    required HomeAction action,
  }) {
    final String value = action.value.trim();
    final String encodedValue = Uri.encodeComponent(value);

    switch (action.type) {
      case 'product':
        if (value.isEmpty) {
          _showMissingActionValue(context);
          return;
        }
        context.push('/product/$encodedValue');
        return;

      case 'category':
        if (value.isEmpty) {
          _showMissingActionValue(context);
          return;
        }
        context.go('/categories/$encodedValue');
        return;

      case 'collection':
        if (value.isEmpty) {
          _showMissingActionValue(context);
          return;
        }
        context.push('/collection/$encodedValue');
        return;

      case 'brand':
        if (value.isEmpty) {
          _showMissingActionValue(context);
          return;
        }
        context.push('/brand/$encodedValue');
        return;

      case 'brands':
        context.push('/brands');
        return;

      case 'search':
        if (value.isEmpty) {
          unawaited(showCatalogSearch(context));
          return;
        }
        context.go('/search?q=$encodedValue');
        return;

      case 'cart':
        context.push('/cart');
        return;

      case 'account':
        context.go('/account');
        return;

	  case 'wishlist':
		context.go('/wishlist');
		return;

      case 'external':
        unawaited(_openExternalUrl(context, value));
        return;

      default:
        _showMessage(context, 'هذا الإجراء غير مدعوم حاليًا.');
        return;
    }
  }

  static void _showMissingActionValue(BuildContext context) {
    _showMessage(context, 'بيانات الوجهة غير مكتملة.');
  }

  static Future<void> _openExternalUrl(
    BuildContext context,
    String value,
  ) async {
    final Uri? uri = Uri.tryParse(value);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      _showMessage(context, 'الرابط الخارجي غير صالح.');
      return;
    }

    bool launched = false;

    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      launched = false;
    }

    if (!launched && context.mounted) {
      _showMessage(context, 'تعذر فتح الرابط الخارجي.');
    }
  }

  static void _showMessage(BuildContext context, String message) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'تحقق من الاتصال ثم حاول مرة أخرى.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
