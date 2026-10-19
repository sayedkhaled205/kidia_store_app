import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/commerce/commerce_connection.dart';
import '../core/commerce/hosted_commerce_destination297.dart';
import '../core/config/app_config.dart';

typedef HostedCommerceLauncher297 = Future<bool> Function(Uri destination);
final hostedCommerceLauncher297Provider = Provider<HostedCommerceLauncher297>(
  (_) =>
      (destination) =>
          launchUrl(destination, mode: LaunchMode.inAppBrowserView),
);

bool get usesHostedOdooCart297 =>
    !AppConfig.isCmsPreview &&
    AppConfig.commercePlatform == CommercePlatform.odoo;

Future<void> openHostedProduct297(
  BuildContext context,
  WidgetRef ref,
  Uri? permalink,
) async {
  final destination = HostedCommerceDestination297.product(
    AppConfig.commerceConnection,
    permalink,
  );
  var opened = false;
  if (destination != null) {
    try {
      opened = await ref.read(hostedCommerceLauncher297Provider)(destination);
    } catch (_) {}
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          Localizations.localeOf(context).languageCode == 'ar'
              ? 'تعذر فتح المنتج في المتجر. حاول مرة أخرى.'
              : 'Unable to open this product in the store. Please retry.',
        ),
      ),
    );
  }
}

/// A deliberate handoff to the store's own buyer flow, using the browser's
/// existing session. No native cart/session success is inferred from returning.
class HostedCommerceScreen297 extends ConsumerStatefulWidget {
  const HostedCommerceScreen297({
    required this.destination,
    required this.route,
    super.key,
  });
  final Uri destination;
  final String route;
  @override
  ConsumerState<HostedCommerceScreen297> createState() =>
      _HostedCommerceScreen297State();
}

class _HostedCommerceScreen297State
    extends ConsumerState<HostedCommerceScreen297> {
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open();
    });
  }

  Future<void> _open() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    var opened = false;
    try {
      opened = await ref.read(hostedCommerceLauncher297Provider)(
        widget.destination,
      );
    } catch (_) {}
    if (mounted) {
      setState(() {
        _busy = false;
        _failed = !opened;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final title = switch (widget.route) {
      '/cart' => ar ? 'السلة' : 'Cart',
      '/checkout' => ar ? 'إتمام الطلب' : 'Checkout',
      '/auth' => ar ? 'تسجيل الدخول' : 'Sign in',
      '/support' => ar ? 'تواصل مع المتجر' : 'Contact the store',
      _ => ar ? 'حسابي' : 'My account',
    };
    return Scaffold(
      key: const Key('hosted-commerce-screen'),
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.open_in_browser, size: 40),
              const SizedBox(height: 16),
              Text(
                _failed
                    ? (ar
                          ? 'تعذر فتح المتجر. حاول مرة أخرى.'
                          : 'Unable to open the store. Please retry.')
                    : (ar
                          ? 'كمّل في صفحة المتجر باستخدام نفس حسابك وسلتك هناك.'
                          : 'Continue on the store using your existing account and basket there.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _open,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(ar ? 'متابعة في المتجر' : 'Continue on store'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
