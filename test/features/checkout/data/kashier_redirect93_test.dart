import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
// Exercise the patched SDK's actual WebView construction, not a duplicate URL helper.
// ignore: implementation_imports
import 'package:kashier_flutter_sdk/src/ui/card/three_ds_webview_sheet.dart';

class _WebViewPlatform93 extends InAppWebViewPlatform {
  final requests = <PlatformInAppWebViewWidgetCreationParams>[];
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    requests.add(params);
    return _WebView93(params);
  }
}

class _WebView93 extends PlatformInAppWebViewWidget {
  _WebView93(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
  @override
  void dispose() {}
  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('bank challenge retains provider authentication parameters exactly', (
    tester,
  ) async {
    final previous = InAppWebViewPlatform.instance;
    final platform = _WebViewPlatform93();
    InAppWebViewPlatform.instance = platform;
    addTearDown(() {
      if (previous != null) InAppWebViewPlatform.instance = previous;
    });
    const redirect =
        'https://payments.kashier.io/3ds-redirect?orderId=test-only&redirectHtml=dGVzdA%3D%3D&mode=test';
    await tester.pumpWidget(
      MaterialApp(
        home: ThreeDSWebViewSheet(
          redirectUrl: redirect,
          merchantRedirect: 'https://merchant.example/return',
          onComplete: (_) {},
          onCancel: () {},
        ),
      ),
    );
    expect(
      platform.requests.single.initialUrlRequest!.url.toString(),
      redirect,
    );
    expect(platform.requests.single.initialSettings!.javaScriptEnabled, true);
    // Security challenges stay within the SDK; no certificate override is installed.
    expect(platform.requests.single.onReceivedServerTrustAuthRequest, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
