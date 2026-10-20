import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/theme/mobishop_colors.dart';
import 'providers/auth_providers.dart';

class WebsiteAuthScreen extends ConsumerStatefulWidget {
  const WebsiteAuthScreen({super.key});
  @override
  ConsumerState<WebsiteAuthScreen> createState() => _WebsiteAuthScreenState();
}

class _WebsiteAuthScreenState extends ConsumerState<WebsiteAuthScreen> {
  bool _busy = false;
  String? _message;
  bool get _arabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  Future<void> _start() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final router = GoRouter.of(context);
    final checkout = GoRouterState.of(context).uri.path == '/checkout';
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      // Finish restoration before publishing the newly verified session.
      await ref.read(authControllerProvider.future);
      if (!mounted) return;
      await ref.read(authControllerProvider.notifier).signInThroughWebsite();
      if (!checkout) router.go('/');
    } catch (error) {
      if (!mounted) return;
      final cancelled = error is PlatformException && error.code == 'CANCELED';
      setState(
        () => _message = cancelled
            ? (_arabic
                  ? 'تم إغلاق تسجيل الدخول. تقدر تحاول مرة أخرى.'
                  : 'Sign-in closed. You can try again.')
            : (_arabic
                  ? 'تعذر إكمال الدخول. حاول مرة أخرى.'
                  : 'Could not complete sign-in. Please try again.'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(AppConfig.storeName),
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        icon: const Icon(Icons.close_rounded),
        onPressed: _busy ? null : () => context.go('/'),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy)
                  const CircularProgressIndicator(color: MobiShopColors.primary)
                else
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 48,
                    color: MobiShopColors.primary,
                  ),
                const SizedBox(height: 24),
                Text(
                  _arabic
                      ? 'تسجيل الدخول أو إنشاء حساب'
                      : 'Sign in or create an account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  _message ??
                      (_arabic
                          ? 'كمّل تسجيل الدخول بالطريقة المتاحة على موقع المتجر. هترجع للتطبيق بعد تسجيل الدخول.'
                          : 'Continue with a sign-in method available on the store website. You will return to the app after sign-in.'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (!_busy)
                  FilledButton(
                    key: const Key('website-auth-retry'),
                    onPressed: _start,
                    child: Text(
                      _arabic ? 'متابعة تسجيل الدخول' : 'Continue sign-in',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
