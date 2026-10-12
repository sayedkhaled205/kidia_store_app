import 'dart:collection';

/// An invalidation hint, not customer data or an authority to perform a write.
enum StoreChangeDomain {
  catalog,
  stock,
  orders,
  profile;

  bool get requiresSession =>
      this == StoreChangeDomain.orders || this == StoreChangeDomain.profile;
}

/// Pure version-1 contract. Does not fetch URLs, persist data, or emit events.
///
/// [sessionScope] must be the current server-issued, non-secret session scope,
/// not a customer ID, bearer token, or value taken from the incoming message.
/// Firebase data payloads may encode `version` as the string `1`. `domains`
/// is a list at this boundary; a transport must decode its envelope first.
final class StoreChangeSignal {
  StoreChangeSignal._({
    required this.storeOrigin,
    required this.revision,
    required Set<StoreChangeDomain> domains,
    required this.sessionScope,
  }) : domains = Set<StoreChangeDomain>.unmodifiable(domains);

  static const int maxRevisionLength = 128;
  static const int maxSessionScopeLength = 192;
  static const Set<String> _keys = <String>{
    'version',
    'type',
    'store_origin',
    'domain',
    'domains',
    'revision',
    'session_scope',
  };

  final String storeOrigin;
  final String revision;
  final Set<StoreChangeDomain> domains;
  final String? sessionScope;

  static StoreChangeSignal? tryParse(
    Object? payload, {
    required String configuredOrigin,
    String? sessionScope,
  }) {
    if (payload is! Map || !_isHttpsOrigin(configuredOrigin)) return null;
    if (payload.keys.any(
      (Object? key) => key is! String || !_keys.contains(key),
    )) {
      return null;
    }
    final Object? version = payload['version'];
    if (!((version is int && version == 1) || version == '1') ||
        payload['type'] != 'mobishop_store_change' ||
        payload['store_origin'] != configuredOrigin) {
      return null;
    }
    final Object? revision = payload['revision'];
    if (!_boundedText(revision, maxRevisionLength)) return null;

    final bool single = payload.containsKey('domain');
    final bool multiple = payload.containsKey('domains');
    if (single == multiple) return null;
    final Object? rawDomains = single
        ? <Object?>[payload['domain']]
        : payload['domains'];
    if (rawDomains is! List || rawDomains.isEmpty || rawDomains.length > 4) {
      return null;
    }
    final Set<StoreChangeDomain> domains = <StoreChangeDomain>{};
    for (final Object? raw in rawDomains) {
      final StoreChangeDomain? domain = switch (raw) {
        'catalog' => StoreChangeDomain.catalog,
        'stock' => StoreChangeDomain.stock,
        'orders' => StoreChangeDomain.orders,
        'profile' => StoreChangeDomain.profile,
        _ => null,
      };
      if (domain == null) return null;
      domains.add(domain);
    }
    final Object? incomingScope = payload['session_scope'];
    final bool privateAllowed =
        _boundedText(sessionScope, maxSessionScopeLength) &&
        _boundedText(incomingScope, maxSessionScopeLength) &&
        incomingScope == sessionScope;
    domains.removeWhere(
      (StoreChangeDomain domain) => domain.requiresSession && !privateAllowed,
    );
    if (domains.isEmpty) return null;
    return StoreChangeSignal._(
      storeOrigin: configuredOrigin,
      revision: revision as String,
      domains: domains,
      sessionScope:
          domains.any((StoreChangeDomain domain) => domain.requiresSession)
          ? sessionScope
          : null,
    );
  }

  static bool _isHttpsOrigin(String value) {
    if (value != value.trim() || !_boundedText(value, 2048)) return false;
    final Uri? uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.hasAuthority &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.path.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  static bool _boundedText(Object? value, int limit) =>
      value is String &&
      value.isNotEmpty &&
      value.length <= limit &&
      value.trim().isNotEmpty &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);
}

/// A bounded, explicitly drained coalescer. No timer or application wiring.
///
/// Revisions are opaque: they are compared for equality, never sorted. Only
/// refresh hints are coalesced; this is not financial-operation replay safety.
/// Private hints are checked again at [drain] after possible logout/user switch.
final class StoreChangeSignalQueue {
  StoreChangeSignalQueue({
    required this.configuredOrigin,
    String? Function()? currentSessionScope,
    this.maxRevisions = 256,
  }) : _currentSessionScope = currentSessionScope ?? (() => null) {
    if (maxRevisions < 1 || maxRevisions > 4096) {
      throw RangeError.range(maxRevisions, 1, 4096, 'maxRevisions');
    }
  }

  final String configuredOrigin;
  final int maxRevisions;
  final String? Function() _currentSessionScope;
  final LinkedHashSet<_RevisionKey> _seen = LinkedHashSet<_RevisionKey>();
  final Map<StoreChangeDomain, String?> _pending =
      <StoreChangeDomain, String?>{};
  bool _disposed = false;

  bool add(Object? payload) {
    if (_disposed) return false;
    final StoreChangeSignal? signal = StoreChangeSignal.tryParse(
      payload,
      configuredOrigin: configuredOrigin,
      sessionScope: _currentSessionScope(),
    );
    if (signal == null) return false;
    bool added = false;
    for (final StoreChangeDomain domain in signal.domains) {
      final String? scope = domain.requiresSession ? signal.sessionScope : null;
      final _RevisionKey key = _RevisionKey(domain, scope, signal.revision);
      if (!_seen.add(key)) continue;
      if (_seen.length > maxRevisions) _seen.remove(_seen.first);
      _pending[domain] = scope;
      added = true;
    }
    return added;
  }

  Set<StoreChangeDomain> drain() {
    if (_disposed) return const <StoreChangeDomain>{};
    final String? scope = _currentSessionScope();
    final Set<StoreChangeDomain> domains = <StoreChangeDomain>{
      for (final MapEntry<StoreChangeDomain, String?> item in _pending.entries)
        if (!item.key.requiresSession ||
            (StoreChangeSignal._boundedText(
                  scope,
                  StoreChangeSignal.maxSessionScopeLength,
                ) &&
                item.value == scope))
          item.key,
    };
    _pending.clear();
    return Set<StoreChangeDomain>.unmodifiable(domains);
  }

  void dispose() {
    _disposed = true;
    _pending.clear();
    _seen.clear();
  }
}

final class _RevisionKey {
  const _RevisionKey(this.domain, this.scope, this.revision);

  final StoreChangeDomain domain;
  final String? scope;
  final String revision;

  @override
  bool operator ==(Object other) =>
      other is _RevisionKey &&
      domain == other.domain &&
      scope == other.scope &&
      revision == other.revision;

  @override
  int get hashCode => Object.hash(domain, scope, revision);
}
