import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';


/// Abstract connectivity gate used by [KashierApi] to fail fast when the
/// device is offline. Implementations are injectable so tests can bypass
/// real platform plugins.
abstract class KashierConnectivityChecker {
  /// Returns `true` when a live internet route is available.
  Future<bool> hasInternet();
}

/// Internal connectivity watcher used to fail payment requests fast when
/// the device is offline or has no route to the Kashier backend.
///
/// Two signals are combined:
///   1. [Connectivity] (platform-reported link status) — instant, cheap,
///      but can be misleading (e.g. Wi-Fi connected to captive portal).
///   2. [InternetAddress.lookup] against a Kashier host — proves actual
///      reachability. Only used when the platform reports "online" to
///      confirm the link actually reaches the internet, or when the
///      cached status is stale.
///
/// Stream-based listeners keep the cached link status current so the
/// hot path (pre-flight before every HTTP call) is O(1).
///
/// The concrete instance used by the SDK is [instance]. Tests that don't
/// want to spin up the plugin binding can pass a different
/// [KashierConnectivityChecker] into [KashierApi].
class KashierConnectivity implements KashierConnectivityChecker {
  KashierConnectivity._();

  static final KashierConnectivity instance = KashierConnectivity._();

  /// Host used for the reachability lookup. Chosen to be the Kashier API
  /// domain so a green check proves actual route to the backend we need.
  static const String _reachabilityHost = 'api.kashier.io';

  /// Max time we wait on the DNS lookup before treating it as offline.
  static const Duration _lookupTimeout = Duration(seconds: 3);

  /// How long a reachability confirmation is trusted before we re-probe.
  static const Duration _reachabilityTtl = Duration(seconds: 10);

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  List<ConnectivityResult> _lastResults = const [ConnectivityResult.none];
  DateTime? _lastReachableAt;
  Future<void>? _startup;

  /// True when the `connectivity_plus` plugin channel is unreachable (e.g.
  /// unit tests running without a Flutter binding). In that case we treat
  /// the pre-flight as a no-op and rely on HTTP-layer [SocketException]
  /// handling to surface network errors.
  bool _pluginUnavailable = false;

  /// Starts listening to connectivity changes. Idempotent.
  Future<void> start() => _startup ??= _start();

  Future<void> _start() async {
    try {
      _lastResults = await _connectivity.checkConnectivity();
    } catch (e) {
      _pluginUnavailable = true;
      _lastResults = const [ConnectivityResult.none];
      return;
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        _lastResults = results;
        // A link change invalidates the reachability cache — the next
        // pre-flight must re-probe DNS.
        _lastReachableAt = null;
      },
      onError: (Object e) {
      },
    );
  }

  /// Cancels the listener. Safe to call even if [start] was not invoked.
  Future<void> dispose() async {
    await _startup;
    await _subscription?.cancel();
    _subscription = null;
    _startup = null;
    _pluginUnavailable = false;
    _lastReachableAt = null;
  }

  /// True when the platform reports any kind of network link.
  bool get _hasLink {
    return _lastResults.any((r) => r != ConnectivityResult.none);
  }

  /// Returns `true` only when the device has a live route to the internet.
  ///
  /// Fast path: if we confirmed reachability within [_reachabilityTtl],
  /// return the cached answer without hitting DNS.
  ///
  /// Slow path: DNS lookup against [_reachabilityHost]. Bounded by
  /// [_lookupTimeout] so a hung network never stalls the caller.
  @override
  Future<bool> hasInternet() async {
    // initialize() begins start() without awaiting it. Every first request must
    // join that same startup future before interpreting the default offline value.
    await start();

    // If the platform plugin isn't reachable (most commonly unit tests),
    // defer the offline verdict to the HTTP layer's SocketException path
    // rather than spuriously blocking every request.
    if (_pluginUnavailable) return true;

    if (!_hasLink) return false;

    final lastOk = _lastReachableAt;
    if (lastOk != null &&
        DateTime.now().difference(lastOk) < _reachabilityTtl) {
      return true;
    }

    try {
      final addresses = await InternetAddress.lookup(
        _reachabilityHost,
      ).timeout(_lookupTimeout);
      final reachable =
          addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty;
      if (reachable) _lastReachableAt = DateTime.now();
      return reachable;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (e) {
      // Unknown failure — be conservative and treat as offline so the
      // user sees the connection message instead of a cryptic error.
      return false;
    }
  }
}
