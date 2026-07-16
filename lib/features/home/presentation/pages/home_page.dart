import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/features/home/data/repositories/home_repository_impl.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_layout.dart';
import 'package:kidia_store_app/features/home/presentation/providers/home_providers.dart';
import 'package:kidia_store_app/features/home/presentation/widgets/home_block_renderer.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String locale = Localizations.localeOf(context).toLanguageTag();

    final AsyncValue<HomeLayout> homeLayoutAsync = ref.watch(
      homeLayoutProvider(locale),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () {
            return ref.refresh(homeLayoutProvider(locale).future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _HomeHeader()),
              homeLayoutAsync.when(
                data: (HomeLayout layout) {
                  return HomeBlockRenderer(
                    blocks: layout.enabledBlocks,
                    onAction: (HomeAction action) {
                      _handleHomeAction(context: context, action: action);
                    },
                  );
                },
                loading: () {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _HomeLoadingState(),
                  );
                },
                error: (Object error, StackTrace stackTrace) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _HomeErrorState(
                      message: _resolveErrorMessage(error),
                      onRetry: () {
                        ref.invalidate(homeLayoutProvider(locale));
                      },
                    ),
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
        context.go(value.isEmpty ? '/search' : '/search?q=$encodedValue');
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConfig.storeName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppConfig.storeTagline,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'البحث',
            onPressed: () {
              context.go('/search');
            },
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
    );
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
