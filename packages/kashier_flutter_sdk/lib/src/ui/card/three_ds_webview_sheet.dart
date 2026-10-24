import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../kashier_colors.dart';
import '../kashier_localizations.dart';
import 'three_ds_challenge_detector.dart';
import 'three_ds_otp_visibility_controller.dart';
import 'three_ds_status_view.dart';

enum _ThreeDSStage {
  webViewChallenge,
  challengeCompletionShowingLoader,
  challengeCompletionReconciling,
}

/// 3DS authentication WebView screen.
///
/// Loads the FEP verify page in the main [InAppWebView], keeping its WebSocket
/// alive while the ACS challenge runs in a native popup.
///
/// The 3DS flow calls window.open() to launch the ACS challenge.
/// [flutter_inappwebview]'s [onCreateWindow] callback intercepts this at the
/// native WKWebView level (UIDelegate.createWebViewWithConfiguration) and
/// creates a second [InAppWebView] with the matching windowId to host the
/// popup. This keeps the FEP WebSocket alive in the main frame.
///
/// When the popup sees /v3/orders/.../3ds-redirect (Mastercard's
/// challenge-complete signal), it is dismissed. The main WebView's FEP
/// WebSocket then fires the payment result, and [onComplete] is called
/// with the terminal payment status.
class ThreeDSWebViewSheet extends StatefulWidget {
  /// The 3DS challenge URL from [CardPaymentResponse.redirectUrl].
  final String redirectUrl;

  /// The merchant redirect URL from the session.
  /// When the bank redirects here, we intercept and extract the result.
  final String? merchantRedirect;

  /// Called when the 3DS flow completes (success or failure).
  /// Passes the query parameters from the redirect URL.
  final void Function(Map<String, String> queryParams) onComplete;

  /// Called when the sheet decides reconcile should begin.
  final VoidCallback? onReconcileRequested;

  /// Called when the user cancels the 3DS flow.
  final VoidCallback onCancel;

  const ThreeDSWebViewSheet({
    super.key,
    required this.redirectUrl,
    required this.merchantRedirect,
    required this.onComplete,
    this.onReconcileRequested,
    required this.onCancel,
  });

  @override
  State<ThreeDSWebViewSheet> createState() => _ThreeDSWebViewSheetState();
}

class _ThreeDSWebViewSheetState extends State<ThreeDSWebViewSheet> {
  static const _loaderDelay = Duration(seconds: 10);
  static const _reconcileDelay = Duration(seconds: 20);

  /// Fallback for the frictionless (no-OTP-challenge) flow. When the main
  /// frame lands on the FEP verify page with paymentStatus=INITIATED and no
  /// ACS challenge popup opens, the verify page's own JS/Socket.IO is the
  /// only thing that would redirect to a terminal result. If that page's JS
  /// breaks (observed: "JSON Parse error: Unexpected identifier undefined"),
  /// the sheet would hang forever. This timer triggers the handler's
  /// reconcile safety net instead.
  ///
  /// Cancelled the moment a challenge popup opens (live OTP flow) or an
  /// OTP submit is detected, so it never affects the working challenge path.
  static const _verifyFallbackDelay = Duration(seconds: 15);

  InAppWebViewController? _mainController;
  InAppWebViewController? _popupController;
  final ThreeDSOtpVisibilityController _otpVisibilityController =
      ThreeDSOtpVisibilityController(
    loaderDelay: _loaderDelay,
    reconcileDelay: _reconcileDelay,
  );
  final List<Timer> _challengeProbeTimers = [];
  Timer? _verifyFallbackTimer;

  /// The verify-page URL the frictionless fallback was armed on. Any
  /// main-frame navigation off this URL means a challenge (in-frame ACS for
  /// CIB / Banque Misr / etc.) or a redirect is loading — the fallback must
  /// be cancelled so it never interrupts a live OTP entry.
  String? _verifyFallbackArmedUrl;

  /// Latched the first time a challenge-presentation console marker is seen.
  /// Some ACS providers (Banque Misr / MPGS) emit the marker *before* the
  /// verify page finishes loading, so the cancel-on-marker path would no-op
  /// (timer not armed yet). Once latched, the fallback is never armed.
  bool _challengePresentedSeen = false;

  // windowId received from onCreateWindow — used to bind the popup InAppWebView.
  int? _popupWindowId;

  bool _popupLoading = false;
  String? _errorMessage;
  bool _completed = false;
  bool _reconcileRequested = false;
  _ThreeDSStage _stage = _ThreeDSStage.webViewChallenge;

  /// True after an ACS challenge submit until it proves still active/invalid.
  bool _challengeCompletionCandidate = false;

  static InAppWebViewSettings get _mainSettings => InAppWebViewSettings(
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true,
        supportMultipleWindows: true,
        mediaPlaybackRequiresUserGesture: false,
        sharedCookiesEnabled: true,
        useShouldInterceptAjaxRequest: false,
        useShouldInterceptFetchRequest: false,
        // Terminal URLs (merchant redirect / gateway callback) can be hit
        // inside an ACS iframe, where no main-frame navigation callback
        // ever fires. onLoadResource sees every frame's loads.
        useOnLoadResource: true,
        // Disable iOS WKWebView edge-swipe back navigation. Mid-3DS history
        // navigation reloads the FEP verify page and triggers a second OTP
        // to be sent. The user should leave the flow only via the X button.
        allowsBackForwardNavigationGestures: false,
      );

  static InAppWebViewSettings get _popupSettings => InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        sharedCookiesEnabled: true,
        useShouldInterceptAjaxRequest: false,
        useShouldInterceptFetchRequest: false,
        allowsBackForwardNavigationGestures: false,
      );

  // ── Main WebView callbacks ──────────────────────────────────────────────────

  void _checkTerminalStatus(WebUri? url) {
    if (url == null || _completed) return;
    final uri = url.uriValue;
    final urlStr = url.toString();

    // Intercept the configured merchant redirect URL (prefix match).
    final merchantRedirect = widget.merchantRedirect;
    if (merchantRedirect != null &&
        merchantRedirect.isNotEmpty &&
        urlStr.startsWith(merchantRedirect)) {
      _completed = true;
      _otpVisibilityController.cancel();
      _cancelChallengeProbeTimers();
      _cancelVerifyFallback();
      _mainController?.stopLoading();
      widget.onComplete(_queryParams(uri));
      return;
    }

    // Intercept the FEP payment result URL.
    const terminalStatuses = {
      'SUCCESS',
      'CAPTURED',
      'FAILED',
      'EXPIRED',
      'DECLINED',
      'VOIDED',
    };
    final params = _queryParams(uri);
    if (params.containsKey('paymentStatus') &&
        params.containsKey('orderId') &&
        terminalStatuses.contains(params['paymentStatus'])) {
      _completed = true;
      _otpVisibilityController.cancel();
      _cancelChallengeProbeTimers();
      _cancelVerifyFallback();
      _mainController?.stopLoading();
      widget.onComplete(params);
      return;
    }

    // 🚨 FIX FOR BANQUE MISR (VISA) WHITE SCREEN 🚨
    // If the bank hijacks the main frame instead of using a popup, they will eventually
    // redirect to Kashier's gateway callback. This URL is a blank HTML page meant to close
    // a popup. We intercept it here to prevent the white screen and trigger reconciliation.
    if (urlStr.contains('/v3/orders/') &&
        urlStr.contains('redirect') &&
        !urlStr.contains('/3dsRedirect/')) {
      // Ensure we don't catch the initial FEP launch URL

      _mainController?.stopLoading();
      _requestReconcileMode();
      return;
    }
  }

  void _onConsoleMessageContent(String message) {
    if (_completed) return;

    // A real ACS challenge (CIB/Wibmo, Banque Misr/MPGS, NBE, ...) is being
    // presented into the verify page over Socket.IO without a URL change.
    // Cancel the frictionless fallback immediately so it can never interrupt
    // a live OTP entry. This fires ~1s after the socket connects, long
    // before the fallback timer; the frictionless-stuck path never emits
    // these markers so its recovery is unaffected.
    if (ThreeDSChallengeDetector.indicatesChallengePresented(message)) {
      if (!_challengePresentedSeen) {
        _challengePresentedSeen = true;
      }
      // Cancels if already armed (CIB: marker after arm). The latch above
      // handles the reverse order (Banque Misr: marker before arm).
      _cancelVerifyFallback();
    }

    if (ThreeDSChallengeDetector.hasInvalidOtpText(message)) {
      _markChallengeStillActive('invalid OTP text in JS console');
      return;
    }

    if (_challengeCompletionCandidate) {
      if (ThreeDSChallengeDetector.indicatesOtpFormReRender(message)) {
        _markChallengeStillActive('OTP form re-rendered after submit');
        return;
      }
      if (message.contains('applied updates') ||
          message.contains('challenge Info Text') ||
          message.contains('challengeInfoText')) {
        _scheduleChallengeStateProbe(const Duration(milliseconds: 500));
      }
      return;
    }

    if (ThreeDSChallengeDetector.isOtpSubmitMessage(message)) {
      // Real challenge in progress (popup or in-frame). The OTP-submit
      // reconcile path owns completion now; drop the frictionless fallback.
      _cancelVerifyFallback();
      _challengeCompletionCandidate = true;
      _otpVisibilityController.onChallengeCompletionCandidate(
        onShowLoader: _showLoaderOverlay,
        onReconcileRequested: _requestReconcileMode,
      );
      _scheduleChallengeStateProbe(const Duration(milliseconds: 500));
      _scheduleChallengeStateProbe(const Duration(seconds: 2));
    }
  }

  void _showLoaderOverlay() {
    if (!mounted || _completed || _reconcileRequested) return;
    setState(() {
      _stage = _ThreeDSStage.challengeCompletionShowingLoader;
    });
  }

  void _requestReconcileMode() {
    if (!mounted || _completed || _reconcileRequested) return;
    _reconcileRequested = true;
    _challengeCompletionCandidate = false;
    _otpVisibilityController.cancel();
    _cancelChallengeProbeTimers();
    _cancelVerifyFallback();
    setState(() {
      _stage = _ThreeDSStage.challengeCompletionReconciling;
    });
    widget.onReconcileRequested?.call();
  }

  void _markChallengeStillActive(String reason) {
    if (!_challengeCompletionCandidate || _completed) return;
    _challengeCompletionCandidate = false;
    _otpVisibilityController.onChallengeStillActive();
    _cancelChallengeProbeTimers();
    _cancelVerifyFallback();
    if (mounted && _stage != _ThreeDSStage.webViewChallenge) {
      setState(() {
        _stage = _ThreeDSStage.webViewChallenge;
      });
    }
  }

  void _scheduleChallengeStateProbe(Duration delay) {
    if (_completed || !_challengeCompletionCandidate) return;
    late final Timer timer;
    timer = Timer(delay, () {
      _challengeProbeTimers.remove(timer);
      _probeChallengeState();
    });
    _challengeProbeTimers.add(timer);
  }

  Future<void> _probeChallengeState() async {
    if (_completed || !_challengeCompletionCandidate) return;
    final mainText = await _readBodyText(_mainController);
    if (ThreeDSChallengeDetector.hasInvalidOtpText(mainText)) {
      _markChallengeStillActive('invalid OTP text in main WebView');
      return;
    }

    final popupText = await _readBodyText(_popupController);
    if (ThreeDSChallengeDetector.hasInvalidOtpText(popupText)) {
      _markChallengeStillActive('invalid OTP text in popup WebView');
    }
  }

  Future<String> _readBodyText(InAppWebViewController? controller) async {
    if (controller == null) return '';
    try {
      final value = await controller.evaluateJavascript(
        source: "document.body ? document.body.innerText : ''",
      );
      return value?.toString() ?? '';
    } catch (e) {
      return '';
    }
  }

  void _cancelChallengeProbeTimers() {
    for (final timer in _challengeProbeTimers) {
      timer.cancel();
    }
    _challengeProbeTimers.clear();
  }

  /// Arms the frictionless-flow fallback when the main frame settles on the
  /// FEP verify page with paymentStatus=INITIATED. No-op for the challenge
  /// path: a popup or OTP submit cancels this well before it fires.
  void _maybeArmVerifyFallback(WebUri? url) {
    if (url == null ||
        _completed ||
        _reconcileRequested ||
        _challengeCompletionCandidate ||
        _challengePresentedSeen ||
        _popupWindowId != null ||
        _verifyFallbackTimer != null) {
      return;
    }
    final urlStr = url.toString();
    if (!urlStr.contains('/verify/')) return;
    final params = _queryParams(url.uriValue);
    if (params['paymentStatus'] != 'INITIATED') return;

    _verifyFallbackArmedUrl = urlStr;
    _verifyFallbackTimer = Timer(_verifyFallbackDelay, () async {
      _verifyFallbackTimer = null;
      if (!mounted ||
          _completed ||
          _reconcileRequested ||
          _challengeCompletionCandidate ||
          _popupWindowId != null) {
        return;
      }
      // Defense in depth on top of the navigation-based cancel: if the main
      // frame is showing an OTP / challenge form (in-frame ACS that did not
      // change the URL), the user is still typing — do NOT reconcile. The
      // OTP-submit path owns completion for that flow.
      final challengeVisible = await _mainFrameShowsChallenge();
      if (!mounted ||
          _completed ||
          _reconcileRequested ||
          _challengeCompletionCandidate ||
          _popupWindowId != null) {
        return;
      }
      if (challengeVisible) {
        return;
      }
      _requestReconcileMode();
    });
  }

  /// Cancels the frictionless fallback as soon as the main frame leaves the
  /// verify page. A challenge (popup-less, in-frame ACS) or a gateway
  /// redirect always navigates away; the frictionless stuck page never does.
  void _cancelVerifyFallbackOnNavigation(WebUri? url) {
    if (_verifyFallbackTimer == null || url == null) return;
    final armed = _verifyFallbackArmedUrl;
    if (armed == null) return;
    final newBase = url.toString().split('?').first;
    final armedBase = armed.split('?').first;
    if (newBase == armedBase) return; // still the same verify page
    _cancelVerifyFallback();
  }

  /// Probes the main WebView (and any same-origin sub-frames) for an OTP /
  /// challenge input. Used only to gate the fallback; failure is treated as
  /// "no challenge" so the genuine frictionless-stuck case still recovers.
  Future<bool> _mainFrameShowsChallenge() async {
    final controller = _mainController;
    if (controller == null) return false;
    try {
      final result = await controller.evaluateJavascript(
        source: '''
(function(){
  try {
    var sel = "input[type=password],input[type=tel]," +
      "input[autocomplete*=one-time-code]," +
      "input[name*=otp i],input[id*=otp i]," +
      "input[name*=OTP],input[id*=OTP]," +
      "input[name*=code i],input[id*=code i]";
    if (document.querySelector(sel)) return "1";
    var t = (document.body ? document.body.innerText : "").toLowerCase();
    if (t.indexOf("otp") > -1 || t.indexOf("one-time") > -1 ||
        t.indexOf("one time") > -1 || t.indexOf("verification code") > -1 ||
        t.indexOf("passcode") > -1 || t.indexOf("enter the code") > -1) {
      return "1";
    }
    for (var i = 0; i < window.frames.length; i++) {
      try { if (window.frames[i].document.querySelector(sel)) return "1"; }
      catch (e) {}
    }
    return "0";
  } catch (e) { return "0"; }
})();
''',
      );
      return result?.toString().contains('1') ?? false;
    } catch (e) {
      return false;
    }
  }

  void _cancelVerifyFallback() {
    _verifyFallbackTimer?.cancel();
    _verifyFallbackTimer = null;
    _verifyFallbackArmedUrl = null;
  }

  /// Handles the user cancelling the 3DS flow (X button, swipe, or
  /// system back). Swaps the UI to the verifying view immediately so the
  /// user sees instant feedback, then lets the handler's reconcile safety
  /// net run and deliver the terminal cancel/failure/success result.
  void _onCancelTapped() {
    if (_completed) return;
    _otpVisibilityController.cancel();
    _cancelChallengeProbeTimers();
    _cancelVerifyFallback();
    _mainController?.stopLoading();
    if (mounted) {
      setState(() {
        _stage = _ThreeDSStage.challengeCompletionReconciling;
      });
    }
    widget.onCancel();
  }

  Future<bool?> _onCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction createWindowAction,
  ) async {
    if (!mounted) return false;
    // Challenge popup opened = live OTP flow. The frictionless fallback must
    // not fire while the user works through the ACS challenge.
    _cancelVerifyFallback();
    setState(() {
      _popupWindowId = createWindowAction.windowId;
      _popupLoading = true;
    });
    return true;
  }

  // ── Popup WebView callbacks ────────────────────────────────────────────────

  void _dismissPopup() {
    if (mounted) {
      setState(() {
        _popupWindowId = null;
        _popupLoading = false;
      });
    }
  }

  // ── Retry ─────────────────────────────────────────────────────────────────

  void _onRetry() {
    _otpVisibilityController.cancel();
    _cancelVerifyFallback();
    setState(() {
      _completed = false;
      _reconcileRequested = false;
      _errorMessage = null;
      _popupWindowId = null;
      _popupLoading = false;
      _popupController = null;
      _challengeCompletionCandidate = false;
      _challengePresentedSeen = false;
      _stage = _ThreeDSStage.webViewChallenge;
    });
    _mainController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(widget.redirectUrl)),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  // Keep Kashier's returned redirect URL intact. Its current 3ds-redirect page
  // decodes redirectHtml to initialize issuer authentication before device-data
  // submission. Removing it produces a blank challenge with no bank OTP.
  // Only the provider page executes it; we do not decode/inject authentication
  // HTML, bypass TLS/WAF errors, or substitute a merchant checkout page.

  Map<String, String> _queryParams(Uri? uri) {
    if (uri == null) return {};
    return uri.queryParameters.cast<String, String>();
  }

  @override
  void dispose() {
    _otpVisibilityController.cancel();
    _cancelChallengeProbeTimers();
    _cancelVerifyFallback();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isReconciling =
        _stage == _ThreeDSStage.challengeCompletionShowingLoader ||
            _stage == _ThreeDSStage.challengeCompletionReconciling;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isReconciling || _completed) return;
        _onCancelTapped();
      },
      child: SizedBox(
        height: screenHeight,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // ── Top bar ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _onCancelTapped,
                          splashRadius: 22,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          icon: const Icon(
                            Icons.close,
                            size: 24,
                            color: KashierColors.contentPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            KashierLocalizations.verifyingPayment(context),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: KashierColors.contentPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: KashierColors.strokeInput),
                  Expanded(
                    child: _errorMessage != null
                        ? _buildErrorView()
                        : _buildWebViewStack(hidden: false),
                  ),
                ],
              ),
              if (isReconciling)
                const Positioned.fill(
                  child: ThreeDSStatusView(
                    mode: ThreeDSStatusViewMode.verifying,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebViewStack({required bool hidden}) {
    return Offstage(
      offstage: hidden,
      child: IgnorePointer(
        ignoring: hidden,
        child: ExcludeSemantics(
          excluding: hidden,
          child: FocusScope(
            canRequestFocus: !hidden,
            child: Stack(
              children: [
                // Main WebView
                InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(widget.redirectUrl),
                  ),
                  initialSettings: _mainSettings,
                  onWebViewCreated: (controller) {
                    _mainController = controller;
                    controller.addJavaScriptHandler(
                      handlerName: 'onWindowOpen',
                      callback: (args) {
                        final url =
                            args.isNotEmpty ? args[0].toString() : 'unknown';
                        if (_popupWindowId == null && mounted) {
                          _mainController?.loadUrl(
                            urlRequest: URLRequest(url: WebUri(url)),
                          );
                        }
                      },
                    );
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    // Issuer-controlled page output — log metadata only,
                    // never the message content.
                    _onConsoleMessageContent(consoleMessage.message);
                  },
                  onLoadStart: (controller, url) {
                    _cancelVerifyFallbackOnNavigation(url);
                    _checkTerminalStatus(url);
                  },
                  onLoadStop: (controller, url) {
                    _checkTerminalStatus(url);
                    _maybeArmVerifyFallback(url);
                    _otpVisibilityController.onMainPageFinished(
                      url?.toString(),
                      onReconcileRequested: _requestReconcileMode,
                    );
                  },
                  onUpdateVisitedHistory: (controller, url, androidIsReload) {
                    _cancelVerifyFallbackOnNavigation(url);
                    _checkTerminalStatus(url);
                  },
                  onLoadResource: (controller, resource) {
                    // Banque Misr (Visa) completes 3DS inside an ACS iframe:
                    // the gateway callback and merchant redirect load in that
                    // iframe, so no main-frame callback ever fires for them.
                    _checkTerminalStatus(resource.url);
                  },
                  onReceivedError: (controller, request, error) {
                    if (_stage ==
                        _ThreeDSStage.challengeCompletionReconciling) {
                      return;
                    }
                    if (_completed) return;

                    // Android reports errors for a redirect target before any
                    // load callback fires for it, and terminal URLs can fail
                    // inside an ACS iframe. If the failing URL is a terminal
                    // URL (merchant redirect / FEP result), complete the flow
                    // instead of surfacing the merchant page failure —
                    // regardless of which frame it happened in.
                    _checkTerminalStatus(request.url);
                    if (_completed ||
                        _stage ==
                            _ThreeDSStage.challengeCompletionReconciling) {
                      return;
                    }
                    if (!(request.isForMainFrame ?? true)) return;

                    if (mounted) {
                      setState(() {
                        _errorMessage = error.description;
                      });
                    }
                  },
                  onReceivedHttpError: (controller, request, response) {
                    if (_stage ==
                        _ThreeDSStage.challengeCompletionReconciling) {
                      return;
                    }
                    if (_completed) return;

                    // Android delivers the HTTP status of a redirect target
                    // before any load callback fires for it (iOS never
                    // reports HTTP errors), and it can arrive from an ACS
                    // iframe. The merchant redirect URL is not required to
                    // resolve — reaching it IS the terminal signal, so
                    // intercept before treating it as a failure.
                    _checkTerminalStatus(request.url);
                    if (_completed ||
                        _stage ==
                            _ThreeDSStage.challengeCompletionReconciling) {
                      return;
                    }
                    if (!(request.isForMainFrame ?? true)) return;

                    if (mounted) {
                      setState(() {
                        _errorMessage =
                            KashierLocalizations.threeDsVerificationFailed(
                          context,
                          response.statusCode ?? 0,
                        );
                      });
                    }
                  },
                  onCreateWindow: _onCreateWindow,
                ),

                // Popup WebView
                if (_popupWindowId != null)
                  Stack(
                    children: [
                      InAppWebView(
                        windowId: _popupWindowId!,
                        initialSettings: _popupSettings,
                        onWebViewCreated: (controller) {
                          _popupController = controller;
                        },
                        onConsoleMessage: (controller, consoleMessage) {
                          // Issuer-controlled page output — log metadata
                          // only, never the message content.
                          _onConsoleMessageContent(consoleMessage.message);
                        },
                        onLoadStart: (controller, url) {
                        },
                        onLoadStop: (controller, url) {
                          if (mounted) {
                            setState(() => _popupLoading = false);
                          }

                          // Safe catch-all for gateway redirects in the popup
                          if (url != null &&
                              url.toString().contains('/v3/orders/') &&
                              url.toString().contains('redirect')) {
                            _dismissPopup();
                          }
                        },
                        onCloseWindow: (controller) {
                          _dismissPopup();
                        },
                        onReceivedError: (controller, request, error) {
                          if (!(request.isForMainFrame ?? true)) return;
                        },
                      ),
                      if (_popupLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            color: KashierColors.primary,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: KashierColors.feedbackError,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: KashierColors.contentSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: _onCancelTapped,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KashierColors.contentPrimary,
                    side: const BorderSide(color: KashierColors.strokeInput),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(KashierLocalizations.cancel(context)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KashierColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(KashierLocalizations.tryAgain(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
