import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'cms_preview_replay_stream.dart';

class CmsPreviewLayoutBridge {
  CmsPreviewLayoutBridge._();

  static final Map<String, Map<String, dynamic>> _current =
      <String, Map<String, dynamic>>{};
  static Map<String, dynamic>? _home;
  static Map<String, dynamic>? _category;
  static Map<String, dynamic>? _splash;
  static Map<String, dynamic>? _identity;
  static Completer<Map<String, dynamic>>? _splashReady;
  static Map<String, dynamic>? _demoCatalog;
  static Completer<Map<String, dynamic>>? _demoCatalogReady;
  static int _catalogRevision = 0;
  static String _catalogSignature = '';
  static final StreamController<int> _catalogChanges =
      StreamController<int>.broadcast();
  static final Map<int, Completer<Map<String, dynamic>>> _catalogRequests =
      <int, Completer<Map<String, dynamic>>>{};
  static int _nextCatalogRequest = 0;
  static final Map<int, Completer<Map<String, dynamic>>> _authRequests = {};
  static int _nextAuthRequest = 0;
  static final Map<int, Completer<Map<String, dynamic>>> _checkoutRequests = {};
  static int _nextCheckoutRequest = 0;
  static final StreamController<String> _changes =
      StreamController<String>.broadcast();
  static final StreamController<String> _focusTargets =
      StreamController<String>.broadcast();
  static final StreamController<double> _homeScrollDeltas =
      StreamController<double>.broadcast();
  static bool _listening = false;
  static bool useDemoCatalog = false;
  static bool useLiveCatalog = false;

  static void editElement(String page, String target, String? item) {
    web.window.parent?.postMessage(
      jsonEncode({
        'type': 'mobishop-preview-edit',
        'page': page,
        'target': target,
        'item': ?item,
      }).toJS,
      web.window.location.origin.toJS,
    );
  }

  static Map<String, dynamic>? get currentHomeLayout => _home;

  static Future<Map<String, dynamic>> fetchCheckoutConfiguration() async {
    _listen();
    final requestId = ++_nextCheckoutRequest;
    final result = Completer<Map<String, dynamic>>();
    _checkoutRequests[requestId] = result;
    web.window.parent?.postMessage(
      jsonEncode({
        'type': 'mobishop-preview-checkout-config-request',
        'request_id': requestId,
      }).toJS,
      web.window.location.origin.toJS,
    );
    try {
      final data = await result.future.timeout(const Duration(seconds: 25));
      if (data['error'] != null ||
          data['fields'] is! List ||
          data['payment_methods'] is! List) {
        throw const FormatException(
          'Checkout preview configuration unavailable.',
        );
      }
      return data;
    } finally {
      _checkoutRequests.remove(requestId);
    }
  }

  static Future<Map<String, dynamic>> fetchAuthConfiguration() async {
    _listen();
    final requestId = ++_nextAuthRequest;
    final result = Completer<Map<String, dynamic>>();
    _authRequests[requestId] = result;
    web.window.parent?.postMessage(
      jsonEncode({
        'type': 'mobishop-preview-auth-config-request',
        'request_id': requestId,
      }).toJS,
      web.window.location.origin.toJS,
    );
    try {
      return await result.future.timeout(const Duration(seconds: 25));
    } finally {
      _authRequests.remove(requestId);
    }
  }

  static int get catalogRevision => _catalogRevision;

  static Stream<int> get catalogChanges {
    _listen();
    return _catalogChanges.stream;
  }

  static Future<Map<String, dynamic>> fetchCatalogPage(
    Map<String, dynamic> query,
  ) async {
    _listen();
    final int requestId = ++_nextCatalogRequest;
    final Completer<Map<String, dynamic>> result =
        Completer<Map<String, dynamic>>();
    _catalogRequests[requestId] = result;
    web.window.parent?.postMessage(
      jsonEncode(<String, dynamic>{
        'type': 'mobishop-preview-catalog-request',
        'request_id': requestId,
        'query': query,
      }).toJS,
      web.window.location.origin.toJS,
    );
    try {
      return await result.future.timeout(const Duration(seconds: 25));
    } finally {
      _catalogRequests.remove(requestId);
    }
  }

  static Stream<Map<String, dynamic>?> layoutsFor(String page) async* {
    _listen();
    yield _current[page];
    await for (final String changedPage in _changes.stream) {
      if (changedPage == page) yield _current[page];
    }
  }

  static Stream<Map<String, dynamic>?> get homeLayouts {
    _listen();
    return replayPreviewValue(_changes.stream, 'home', () => _home);
  }

  static Stream<Map<String, dynamic>?> get identitySettings {
    _listen();
    return replayPreviewValue(_changes.stream, 'identity', () => _identity);
  }

  static Stream<Map<String, dynamic>?> get categorySettings async* {
    _listen();
    yield _category;
    await for (final String changedPage in _changes.stream) {
      if (changedPage == 'category') yield _category;
    }
  }

  static Stream<Map<String, dynamic>?> get splashSettings async* {
    _listen();
    yield _splash;
    await for (final String changedPage in _changes.stream) {
      if (changedPage == 'splash') yield _splash;
    }
  }

  static Stream<String> get homeFocusTargets {
    _listen();
    return _focusTargets.stream;
  }

  static Stream<double> get homeScrollDeltas {
    _listen();
    return _homeScrollDeltas.stream;
  }

  static Future<Map<String, dynamic>> get demoCatalog {
    _listen();
    final Map<String, dynamic>? current = _demoCatalog;
    if (current != null) return Future<Map<String, dynamic>>.value(current);
    _demoCatalogReady ??= Completer<Map<String, dynamic>>();
    return _demoCatalogReady!.future;
  }

  static Future<Map<String, dynamic>> get splashConfig {
    _listen();
    final Map<String, dynamic>? current = _splash;
    if (current != null) return Future<Map<String, dynamic>>.value(current);
    _splashReady ??= Completer<Map<String, dynamic>>();
    return _splashReady!.future;
  }

  static void _listen() {
    if (_listening) return;
    _listening = true;
    web.window.addEventListener(
      'message',
      ((web.MessageEvent event) {
        if (event.origin != web.window.location.origin) return;
        if (event.source != web.window.parent) {
          return;
        }
        dynamic message = event.data.dartify();
        if (message is String) {
          try {
            message = jsonDecode(message);
          } catch (_) {
            return;
          }
        }
        if (message is! Map) return;
        if (message['type'] == 'mobishop-preview-checkout-config-response') {
          final requestId = int.tryParse('${message['request_id'] ?? ''}');
          final waiting = _checkoutRequests[requestId];
          if (waiting != null && !waiting.isCompleted) {
            waiting.complete(Map<String, dynamic>.from(message));
          }
          return;
        }
        if (message['type'] == 'mobishop-preview-auth-config-response') {
          final requestId = int.tryParse('${message['request_id'] ?? ''}');
          final waiting = _authRequests[requestId];
          if (waiting != null && !waiting.isCompleted) {
            waiting.complete(Map<String, dynamic>.from(message));
          }
          return;
        }
        if (message['type'] == 'mobishop-preview-catalog-response') {
          final int? requestId = int.tryParse('${message['request_id'] ?? ''}');
          final Completer<Map<String, dynamic>>? waiting =
              _catalogRequests[requestId];
          if (waiting != null && !waiting.isCompleted) {
            waiting.complete(Map<String, dynamic>.from(message));
          }
          return;
        }
        if (message['type'] == 'mobishop-preview-scroll') {
          if ('${message['page'] ?? ''}' == 'home') {
            final double? delta = double.tryParse('${message['deltaY'] ?? ''}');
            if (delta != null && delta != 0) _homeScrollDeltas.add(delta);
          }
          return;
        }
        if (message['type'] == 'mobishop-preview-focus') {
          if ('${message['page'] ?? ''}' == 'home') {
            final String target = '${message['target'] ?? ''}'.trim();
            if (target.isNotEmpty) _focusTargets.add(target);
          }
          return;
        }
        if (message['type'] != 'mobishop-preview-layout') return;
        if (message['identity'] is Map) {
          _identity = Map<String, dynamic>.from(message['identity'] as Map);
          _changes.add('identity');
        }
        if (message['splash'] is Map) {
          _splash = Map<String, dynamic>.from(message['splash'] as Map);
          final Completer<Map<String, dynamic>>? ready = _splashReady;
          if (ready != null && !ready.isCompleted) ready.complete(_splash!);
        }
        final String page = '${message['page'] ?? ''}';
        final dynamic rawLayout = message['layout'];
        if (page.isEmpty || rawLayout is! Map) return;
        final dynamic rawLayouts = message['layouts'];
        final Set<String> changedPages = <String>{page};
        if (rawLayouts is Map) {
          for (final MapEntry<dynamic, dynamic> entry in rawLayouts.entries) {
            if (entry.value is! Map) continue;
            final String layoutPage = '${entry.key}'.trim();
            if (layoutPage.isEmpty) continue;
            _current[layoutPage] = Map<String, dynamic>.from(
              entry.value as Map,
            );
            changedPages.add(layoutPage);
          }
        } else {
          _current[page] = Map<String, dynamic>.from(rawLayout);
        }
        if (message['home'] is Map) {
          _home = Map<String, dynamic>.from(message['home'] as Map);
          web.document.documentElement?.setAttribute(
            'data-preview-home-blocks',
            '${(_home!['blocks'] as List?)?.length ?? 0}',
          );
        }
        if (message['category'] is Map) {
          _category = Map<String, dynamic>.from(message['category'] as Map);
        }
        bool catalogChanged = false;
        if (message['demo_catalog'] is Map) {
          final bool hadCatalog = _demoCatalog != null;
          _demoCatalog = Map<String, dynamic>.from(
            message['demo_catalog'] as Map,
          );
          final String nextSignature = jsonEncode(_demoCatalog);
          if (nextSignature != _catalogSignature) {
            _catalogSignature = nextSignature;
            _catalogRevision++;
            // Initial requests already wait for the first catalog packet. Only
            // later source changes should ask active consumers to refresh.
            catalogChanged = hadCatalog;
          }
          final Completer<Map<String, dynamic>>? ready = _demoCatalogReady;
          if (ready != null && !ready.isCompleted) {
            ready.complete(_demoCatalog!);
          }
        }
        // Publish only after the complete packet has been installed. Otherwise
        // subscribers can observe new page settings with stale/missing catalog.
        if (message['splash'] is Map) changedPages.add('splash');
        for (final String changedPage in changedPages) {
          _changes.add(changedPage);
        }
        if (catalogChanged) _catalogChanges.add(_catalogRevision);
      }).toJS,
    );
    web.window.parent?.postMessage(
      jsonEncode(<String, String>{
        'type': 'mobishop-flutter-preview-ready',
      }).toJS,
      web.window.location.origin.toJS,
    );
  }
}
