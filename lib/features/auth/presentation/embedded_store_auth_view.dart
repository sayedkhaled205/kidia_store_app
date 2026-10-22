import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum StoreAuthNavigation { allow, callback, externalAuthentication, block }

/// Only merchant HTTPS pages can become the embedded top-level document.
/// Events identified as child frames cannot finish login or request a browser.
/// Platform WebViews may report popup requests as top-level navigation.
class StoreAuthNavigationPolicy {
  const StoreAuthNavigationPolicy({
    required this.store,
    required this.callbackScheme,
  });
  final Uri store;
  final String callbackScheme;

  bool isStorePage(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      uri.origin == store.origin;

  StoreAuthNavigation classify(String url, {required bool isMainFrame}) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.userInfo.isNotEmpty) {
      return StoreAuthNavigation.block;
    }
    if (uri.scheme == callbackScheme) {
      return isMainFrame
          ? StoreAuthNavigation.callback
          : StoreAuthNavigation.block;
    }
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      return StoreAuthNavigation.block;
    }
    if (!isMainFrame || isStorePage(uri)) return StoreAuthNavigation.allow;
    return StoreAuthNavigation.externalAuthentication;
  }
}

class EmbeddedStoreAuthRequest {
  const EmbeddedStoreAuthRequest({
    required this.uri,
    required this.store,
    required this.callbackScheme,
    required this.onComplete,
    required this.onExternalAuthentication,
    required this.onFailure,
  });
  final Uri uri;
  final Uri store;
  final String callbackScheme;
  final ValueChanged<String> onComplete;
  final VoidCallback onExternalAuthentication;
  final VoidCallback onFailure;
}

typedef EmbeddedStoreAuthBuilder = Widget Function(EmbeddedStoreAuthRequest);

/// Widget tests substitute the platform-view presenter at this boundary.
final embeddedStoreAuthBuilderProvider = Provider<EmbeddedStoreAuthBuilder>(
  (ref) =>
      (request) => EmbeddedStoreAuthView(
        key: ValueKey(request.uri.toString()),
        request: request,
      ),
);

class EmbeddedStoreAuthView extends StatefulWidget {
  const EmbeddedStoreAuthView({super.key, required this.request});
  final EmbeddedStoreAuthRequest request;
  @override
  State<EmbeddedStoreAuthView> createState() => _EmbeddedStoreAuthViewState();
}

class _EmbeddedStoreAuthViewState extends State<EmbeddedStoreAuthView> {
  late final _policy = StoreAuthNavigationPolicy(
    store: widget.request.store,
    callbackScheme: widget.request.callbackScheme,
  );
  WebViewController? _controller;
  Uri? _mainFrame;
  String? _bridgeNonce;
  bool _loading = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (!_policy.isStorePage(widget.request.uri)) {
        throw const FormatException('Invalid embedded authentication origin.');
      }
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              _navigate(request.url, isMainFrame: request.isMainFrame),
          onPageStarted: (url) {
            _bridgeNonce = null;
            final uri = Uri.tryParse(url);
            _mainFrame = uri != null && _policy.isStorePage(uri) ? uri : null;
            if (mounted && !_finished) setState(() => _loading = true);
          },
          onPageFinished: (url) async {
            if (!mounted || _finished) return;
            final uri = Uri.tryParse(url);
            if (uri == null || !_policy.isStorePage(uri)) return;
            _mainFrame = uri;
            await _installPopupGuard(controller);
            if (mounted && !_finished) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) _fail();
          },
          onHttpError: (error) {
            if (error.request?.uri == _mainFrame &&
                (error.response?.statusCode ?? 0) >= 400) {
              _fail();
            }
          },
          onSslAuthError: (error) async {
            await error.cancel();
            _fail();
          },
        ),
      );
      await controller.addJavaScriptChannel(
        'MobiShopAuthPopup',
        onMessageReceived: (message) => _popup(controller, message.message),
      );
      // WebView cookies are separate from the user's browser. Do not clear the
      // shared WebView store: other embedded checkout sessions may use it.
      if (!mounted || _finished) return;
      _mainFrame = widget.request.uri;
      setState(() => _controller = controller);
      await controller.loadRequest(widget.request.uri);
    } catch (_) {
      _fail();
    }
  }

  NavigationDecision _navigate(String url, {required bool isMainFrame}) {
    if (_finished || !mounted) return NavigationDecision.prevent;
    switch (_policy.classify(url, isMainFrame: isMainFrame)) {
      case StoreAuthNavigation.allow:
        return NavigationDecision.navigate;
      case StoreAuthNavigation.callback:
        _finished = true;
        widget.request.onComplete(url);
      case StoreAuthNavigation.externalAuthentication:
        _finished = true;
        widget.request.onExternalAuthentication();
      case StoreAuthNavigation.block:
        if (isMainFrame) _fail();
    }
    return NavigationDecision.prevent;
  }

  Future<void> _installPopupGuard(WebViewController controller) async {
    final random = Random.secure();
    final nonce = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _bridgeNonce = nonce;
    try {
      // The nonce is injected only in the merchant's top-level document.
      // Child frames cannot use the channel to complete login or open a browser.
      // No form values, cookies, HTML or credentials are read or transferred.
      await controller.runJavaScript('''
(() => {
  if (window !== window.top || location.origin !== ${jsonEncode(widget.request.store.origin)}) return;
  const nonce = ${jsonEncode(nonce)};
  const send = (value) => {
    try {
      const url = new URL(String(value), location.href).href;
      MobiShopAuthPopup.postMessage(JSON.stringify({nonce, url}));
    } catch (_) {}
  };
  window.open = (url) => { if (url) send(url); return null; };
  if (window.__mobishopAuthPopupClick) document.removeEventListener('click', window.__mobishopAuthPopupClick, true);
  window.__mobishopAuthPopupClick = (event) => {
    const link = event.target && event.target.closest ? event.target.closest('a[href]') : null;
    if (link && link.target && link.target !== '_self') {
      event.preventDefault(); event.stopImmediatePropagation(); send(link.href);
    }
  };
  document.addEventListener('click', window.__mobishopAuthPopupClick, true);
})();
''');
    } catch (_) {
      _fail();
    }
  }

  Future<void> _popup(WebViewController controller, String message) async {
    if (!mounted || _finished || _bridgeNonce == null || _mainFrame == null) {
      return;
    }
    try {
      final data = jsonDecode(message);
      if (data is! Map ||
          data['nonce'] != _bridgeNonce ||
          data['url'] is! String) {
        return;
      }
      final current = Uri.tryParse(await controller.currentUrl() ?? '');
      if (!mounted ||
          _finished ||
          current == null ||
          !_policy.isStorePage(current)) {
        return;
      }
      final url = data['url'] as String;
      if (_navigate(url, isMainFrame: true) == NavigationDecision.navigate) {
        await controller.loadRequest(Uri.parse(url));
      }
    } catch (_) {
      _fail();
    }
  }

  void _fail() {
    if (!mounted || _finished) return;
    _finished = true;
    widget.request.onFailure();
  }

  @override
  void dispose() {
    _finished = true;
    _bridgeNonce = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (_controller case final controller?)
        WebViewWidget(controller: controller),
      if (_loading) const LinearProgressIndicator(),
    ],
  );
}
