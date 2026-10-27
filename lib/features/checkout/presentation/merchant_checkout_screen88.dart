import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../cart/presentation/providers/cart_providers.dart';
import '../../cart/presentation/providers/cart_state_providers.dart';

/// Credentials are sent only by Dio to the configured merchant. The WebView
/// receives a short-lived, single-use POST ticket, never a mobile bearer token.
class MerchantCheckoutTicket88 {
  const MerchantCheckoutTicket88(this.uri, this.checkout, this.ticket);
  final Uri uri;
  final Uri checkout;
  final String ticket;

  static MerchantCheckoutTicket88 parse(Uri store, dynamic value) {
    if (value is! Map || value['protocol'] != 88) {
      throw const FormatException('Merchant checkout is unavailable.');
    }
    final uri = Uri.tryParse(value['url'] is String ? value['url'] : '');
    final base = store.path.endsWith('/') ? store.path : '${store.path}/';
    final ticket = value['ticket'];
    final checkout = Uri.tryParse(
      value['checkout_url'] is String ? value['checkout_url'] : '',
    );
    if (uri == null ||
        store.scheme != 'https' ||
        uri.scheme != 'https' ||
        uri.origin != store.origin ||
        uri.userInfo.isNotEmpty ||
        uri.path != base ||
        uri.fragment.isNotEmpty ||
        uri.query != 'mobishop-checkout88=1' ||
        ticket is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(ticket) ||
        ticket.length != 64 ||
        checkout == null ||
        checkout.scheme != 'https' ||
        checkout.origin != store.origin ||
        checkout.userInfo.isNotEmpty ||
        checkout.hasQuery ||
        checkout.hasFragment ||
        !checkout.path.startsWith(base) ||
        checkout.path == base) {
      throw const FormatException('Invalid merchant checkout session.');
    }
    return MerchantCheckoutTicket88(uri, checkout, ticket);
  }

  Uint8List get body => Uint8List.fromList(utf8.encode('ticket=$ticket'));
}

class MerchantCheckoutScreen88 extends ConsumerStatefulWidget {
  const MerchantCheckoutScreen88({super.key});
  @override
  ConsumerState<MerchantCheckoutScreen88> createState() =>
      _MerchantCheckoutScreen88State();
}

class _MerchantCheckoutScreen88State
    extends ConsumerState<MerchantCheckoutScreen88> {
  WebViewController? _web;
  bool _busy = true;
  bool _failed = false;
  int _generation = 0;
  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final generation = ++_generation;
    final session = ref.read(authControllerProvider).value;
    if (session == null || session.isExpired) return;
    final identity = (session.user.id, session.token);
    bool current() {
      if (!mounted || generation != _generation) return false;
      final state = ref.read(authControllerProvider);
      final now = state.value;
      return !state.hasError &&
          now != null &&
          !now.isExpired &&
          now.user.id == identity.$1 &&
          now.token == identity.$2;
    }

    setState(() {
      _busy = true;
      _failed = false;
      _web = null;
    });
    try {
      final store = ref.read(cartStoreUriProvider);
      await ref.read(cartRepositoryProvider).getCart();
      if (!current()) return;
      final token = ref.read(cartTokenStoreProvider).read();
      if (token == null || token.isEmpty) throw StateError('Missing basket.');
      final base = store.path.endsWith('/') ? store.path : '${store.path}/';
      final endpoint = store.replace(
        path: '${base}wp-json/mobishop/v1/customer/checkout/session',
        query: '',
        fragment: '',
      );
      final response = await ref
          .read(cartDioProvider)
          .postUri<dynamic>(
            endpoint,
            data: const <String, dynamic>{},
            options: Options(
              followRedirects: false,
              headers: {
                'X-MobiShop-Channel': 'mobile',
                'X-MobiShop-Session': session.token,
                'Cart-Token': token,
                'Accept': 'application/json',
              },
            ),
          );
      if (!current()) return;
      final ticket = MerchantCheckoutTicket88.parse(store, response.data);
      final web = WebViewController();
      await web.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (web.platform is AndroidWebViewController) {
        // Bank 3DS challenges can use an HTTPS iframe from a separate origin.
        await (WebViewCookieManager().platform as AndroidWebViewCookieManager)
            .setAcceptThirdPartyCookies(
              web.platform as AndroidWebViewController,
              true,
            );
      }
      var basketTransferred = false;
      await web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (!current()) return NavigationDecision.prevent;
            final uri = Uri.tryParse(request.url);
            // Gateway and bank HTTPS challenges remain in this screen. No
            // credentials are forwarded as headers, no JavaScript card bridge.
            if (uri == null ||
                uri.scheme != 'https' ||
                uri.host.isEmpty ||
                uri.userInfo.isNotEmpty) {
              return NavigationDecision.prevent;
            }
            if (request.isMainFrame && uri.origin == store.origin) {
              final checkoutPath = ticket.checkout.path.replaceFirst(
                RegExp(r'/$'),
                '',
              );
              final checkoutRoute =
                  uri.path == checkoutPath ||
                  uri.path.startsWith('$checkoutPath/');
              final bootstrap = uri == ticket.uri;
              final gatewayCallback =
                  uri.path == ticket.uri.path &&
                  uri.queryParameters.containsKey('wc-api');
              if (!checkoutRoute && !bootstrap && !gatewayCallback) {
                // Site chrome links never turn checkout into a website browser.
                ref.invalidate(cartControllerProvider);
                context.go('/cart');
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            if (current()) setState(() => _busy = true);
          },
          onPageFinished: (url) {
            if (!current()) return;
            final uri = Uri.tryParse(url);
            if (!basketTransferred &&
                uri != null &&
                uri.origin == store.origin &&
                uri.path == ticket.checkout.path) {
              basketTransferred = true;
              // The browser now uses the authenticated Woo session. Do not
              // resurrect the pre-login guest basket when returning to Native.
              ref.read(cartTokenStoreProvider).clear();
              ref.invalidate(cartControllerProvider);
            }
            setState(() => _busy = false);
          },
          onWebResourceError: (error) {
            if (current() && error.isForMainFrame == true) {
              setState(() {
                _failed = true;
                _busy = false;
              });
            }
          },
          onSslAuthError: (error) async {
            await error.cancel();
            if (current()) {
              setState(() {
                _failed = true;
                _busy = false;
              });
            }
          },
        ),
      );
      if (!current()) return;
      setState(() => _web = web);
      await web.loadRequest(
        ticket.uri,
        method: LoadRequestMethod.post,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: ticket.body,
      );
    } catch (_) {
      if (current()) {
        setState(() {
          _failed = true;
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Remove the document immediately if a different account replaces this one.
    ref.watch(authControllerProvider);
    return Scaffold(
      key: const Key('merchant-checkout88'),
      appBar: AppBar(
        title: Text(_ar ? 'إتمام الطلب' : 'Checkout'),
        actions: [
          IconButton(
            tooltip: _ar ? 'طلباتي' : 'My orders',
            onPressed: () => context.push('/orders'),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: _failed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _ar
                            ? 'تعذر فتح إتمام الطلب. لو كنت بدأت الدفع، راجع طلباتك قبل المحاولة مرة أخرى.'
                            : 'Checkout could not be opened. If payment was started, review your orders before trying again.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => context.push('/orders'),
                        child: Text(_ar ? 'عرض طلباتي' : 'My orders'),
                      ),
                      TextButton(
                        onPressed: _open,
                        child: Text(
                          _ar ? 'إعادة فتح السلة' : 'Reopen checkout',
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  if (_web != null) WebViewWidget(controller: _web!),
                  if (_busy)
                    const Align(
                      alignment: Alignment.topCenter,
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
      ),
    );
  }
}
