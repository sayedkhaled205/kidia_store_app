import 'dart:async';
import 'dart:convert';

import 'store_change_signal.dart';
import 'store_change_transport.dart';

/// Foreground revision reconciliation complements immediate push hints.
/// It never holds a PHP worker in a long poll or overlaps revision requests.
final class StoreLiveUpdates {
  StoreLiveUpdates({
    required this.transport,
    required String configuredOrigin,
    required this.currentSessionToken,
    this.interval = const Duration(seconds: 3),
    this.maxBackoff = const Duration(seconds: 60),
    this.coalesceDelay = const Duration(milliseconds: 100),
  }) {
    if (interval < const Duration(seconds: 1) || maxBackoff < interval) {
      throw ArgumentError('Live-update intervals must be bounded.');
    }
    _queue = StoreChangeSignalQueue(
      configuredOrigin: configuredOrigin,
      currentSessionScope: () => sessionScope,
    );
  }

  final StoreChangeTransport transport;
  final String? Function() currentSessionToken;
  final Duration interval;
  final Duration maxBackoff;
  final Duration coalesceDelay;
  late final StoreChangeSignalQueue _queue;
  final _changes = StreamController<Set<StoreChangeDomain>>.broadcast();
  final _revisions = <StoreChangeDomain, String>{};
  Timer? _timer;
  Timer? _hintTimer;
  String? _scope;
  String? _scopeToken;
  bool _active = false;
  bool _disposed = false;
  bool _pendingRead = false;
  bool _pendingForce = false;
  int _failures = 0;
  Future<void>? _reading;

  Stream<Set<StoreChangeDomain>> get changes => _changes.stream;
  String? get sessionScope =>
      _scopeToken != null && _scopeToken == currentSessionToken()
      ? _scope
      : null;

  void setActive(bool value) {
    if (_disposed || _active == value) return;
    _active = value;
    _timer?.cancel();
    _hintTimer?.cancel();
    _hintTimer = null;
    if (!value) _queue.drain();
    if (value) unawaited(reconcile(force: true));
  }

  /// Login/logout/user-switch invalidates private baselines before any read.
  void sessionChanged() {
    if (_disposed) return;
    _scope = null;
    _scopeToken = null;
    _revisions.removeWhere((domain, _) => domain.requiresSession);
    _queue.drain();
    if (_active) unawaited(reconcile(force: true));
  }

  /// Raw FCM data must be exactly the allowlisted change envelope. Marketing
  /// messages, payloads with URLs/PII and mismatched session hints are rejected.
  bool acceptHint(Object? raw) {
    if (!_active || _disposed || raw is! Map) return false;
    final payload = <Object?, Object?>{...raw};
    final domains = payload['domains'];
    if (domains is String) {
      if (domains.length > 128) return false;
      try {
        payload['domains'] = jsonDecode(domains);
      } catch (_) {
        return false;
      }
    }
    if (!_queue.add(payload)) return false;
    _hintTimer ??= Timer(coalesceDelay, () {
      _hintTimer = null;
      if (!_active || _disposed) return;
      final domains = _queue.drain();
      if (domains.isNotEmpty) _changes.add(domains);
      unawaited(reconcile());
    });
    return true;
  }

  /// Resume/reconnect uses force so missed or unsupported push delivery cannot
  /// leave an already open screen relying on its pre-suspension cache.
  Future<void> reconcile({bool force = false}) {
    if (_disposed || !_active) return Future<void>.value();
    _pendingRead = true;
    _pendingForce = _pendingForce || force;
    _timer?.cancel();
    return _reading ??= _readLoop();
  }

  Future<void> _readLoop() async {
    try {
      // Coalesce concurrent hints/session changes. Two batches bound one burst.
      for (int batch = 0; batch < 2 && _pendingRead && _active; batch++) {
        _pendingRead = false;
        final force = _pendingForce;
        _pendingForce = false;
        final requestToken = currentSessionToken();
        try {
          final snapshot = await transport.readRevisions(
            sessionToken: requestToken,
          );
          if (_disposed || !_active) return;
          if (requestToken != currentSessionToken()) {
            _pendingRead = true;
            _pendingForce = true;
            continue;
          }
          final recovered = _failures > 0;
          _failures = 0;
          _scope = snapshot.sessionScope;
          _scopeToken = snapshot.sessionScope != null ? requestToken : null;
          final changed = <StoreChangeDomain>{};
          for (final entry in snapshot.revisions.entries) {
            if (entry.key.requiresSession && sessionScope == null) continue;
            if (force || recovered || _revisions[entry.key] != entry.value) {
              changed.add(entry.key);
            }
            _revisions[entry.key] = entry.value;
          }
          if (changed.isNotEmpty) _changes.add(Set.unmodifiable(changed));
        } catch (_) {
          if (!_disposed && _active) _failures = (_failures + 1).clamp(0, 8);
          // No cached customer payload is substituted, no unhandled network
          // errors, and no permission bypass when the endpoint rejects a read.
        }
      }
    } finally {
      _reading = null;
      if (_active && !_disposed) {
        final delay = _pendingRead ? Duration.zero : _nextDelay();
        _timer = Timer(delay, () => unawaited(reconcile()));
      }
    }
  }

  Duration _nextDelay() {
    final milliseconds = interval.inMilliseconds * (1 << _failures);
    return Duration(
      milliseconds: milliseconds.clamp(0, maxBackoff.inMilliseconds),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _active = false;
    _timer?.cancel();
    _hintTimer?.cancel();
    _queue.dispose();
    unawaited(_changes.close());
  }
}
