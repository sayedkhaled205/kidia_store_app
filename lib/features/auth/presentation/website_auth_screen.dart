import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/theme/mobishop_colors.dart';
import 'package:mobishop_store_app/features/auth/data/website_auth_service.dart';
import 'embedded_store_auth_view.dart';
import 'providers/auth_providers.dart';
import 'providers/website_auth_providers.dart';

class WebsiteAuthScreen extends ConsumerStatefulWidget {
  const WebsiteAuthScreen({super.key, this.popOnSuccess = true});
  final bool popOnSuccess;
  @override
  ConsumerState<WebsiteAuthScreen> createState() => _WebsiteAuthScreenState();
}

class _ExternalAuthenticationRequested implements Exception {
  const _ExternalAuthenticationRequested({this.confirmed = false});
  final bool confirmed;
}

class _WebsiteAuthScreenState extends ConsumerState<WebsiteAuthScreen> {
  bool _busy = false;
  String? _message;
  EmbeddedStoreAuthRequest? _embedded;
  Completer<String>? _presentation;
  WebsiteAuthAttempt? _attempt;
  bool get _arabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  Future<String> _presentInsideApp(Uri uri) {
    if (!mounted) throw PlatformException(code: 'CANCELED');
    final completion = Completer<String>();
    final service = ref.read(websiteAuthServiceProvider);
    setState(() {
      _presentation = completion;
      _embedded = EmbeddedStoreAuthRequest(
        uri: uri,
        store: service.store,
        callbackScheme: WebsiteAuthService.schemeFor(service.store),
        onComplete: (callback) {
          if (!completion.isCompleted) completion.complete(callback);
        },
        onExternalAuthentication: () {
          if (!completion.isCompleted) {
            completion.completeError(const _ExternalAuthenticationRequested());
          }
        },
        onFailure: () {
          if (!completion.isCompleted) {
            completion.completeError(
              const FormatException('Sign-in page unavailable.'),
            );
          }
        },
      );
    });
    return completion.future;
  }

  Future<void> _start({bool external = false}) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final router = GoRouter.of(context);
    final attempt = WebsiteAuthAttempt();
    _attempt = attempt;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(authControllerProvider.future);
      if (!mounted) return;
      attempt.checkActive();
      try {
        await ref
            .read(authControllerProvider.notifier)
            .signInThroughWebsite(
              presenter: external ? null : _presentInsideApp,
              attempt: attempt,
            );
      } on _ExternalAuthenticationRequested catch (request) {
        if (!mounted) return;
        setState(() {
          _embedded = null;
          _presentation = null;
        });
        if (!request.confirmed) {
          setState(
            () => _message = _arabic
                ? 'طريقة الدخول دي بتكمل عبر Google أو المتصفح. اضغط الزر بالأسفل للمتابعة.'
                : 'This sign-in method continues with Google or your browser. Use the button below to continue.',
          );
          return;
        }
        // Abort first, then create fresh state/verifier and a new authorize URL.
        // Never transfer embedded cookies or a mid-flow OAuth URL to a browser.
        await ref
            .read(authControllerProvider.notifier)
            .signInThroughWebsite(attempt: attempt);
      }
      if (mounted && widget.popOnSuccess) {
        if (router.canPop()) {
          router.pop(true);
        } else {
          router.go('/account');
        }
      }
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
      if (mounted) {
        setState(() {
          _busy = false;
          _embedded = null;
          _presentation = null;
          _attempt = null;
        });
      }
    }
  }

  void _cancel() {
    _attempt?.cancel();
    final presentation = _presentation;
    if (presentation != null && !presentation.isCompleted) {
      presentation.completeError(PlatformException(code: 'CANCELED'));
    }
  }

  void _close() {
    _cancel();
    if (context.canPop()) {
      context.pop(false);
    } else {
      context.go('/account');
    }
  }

  void _openBrowser() {
    final presentation = _presentation;
    if (presentation != null && !presentation.isCompleted) {
      presentation.completeError(
        const _ExternalAuthenticationRequested(confirmed: true),
      );
    } else if (!_busy) {
      _start(external: true);
    }
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _embedded == null,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _cancel();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(AppConfig.storeName),
        leading: IconButton(
          key: const Key('website-auth-close'),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(Icons.close_rounded),
          onPressed: _close,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _embedded != null
                  ? ref.watch(embeddedStoreAuthBuilderProvider)(_embedded!)
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_busy)
                                const CircularProgressIndicator(
                                  color: MobiShopColors.primary,
                                )
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
                                        ? 'جارٍ تحميل تسجيل الدخول…'
                                        : 'Loading sign-in…'),
                                textAlign: TextAlign.center,
                              ),
                              if (!_busy) ...[
                                const SizedBox(height: 24),
                                FilledButton(
                                  key: const Key('website-auth-retry'),
                                  onPressed: _start,
                                  child: Text(
                                    _arabic ? 'إعادة المحاولة' : 'Try again',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            TextButton.icon(
              key: const Key('website-auth-browser'),
              onPressed: _embedded != null || !_busy ? _openBrowser : null,
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: Text(
                _arabic
                    ? 'الدخول عبر Google أو المتصفح'
                    : 'Sign in with Google or browser',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
