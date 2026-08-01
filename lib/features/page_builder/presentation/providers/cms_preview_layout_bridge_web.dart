// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class CmsPreviewLayoutBridge {
  CmsPreviewLayoutBridge._();

  static final Map<String, Map<String, dynamic>> _current =
      <String, Map<String, dynamic>>{};
  static Map<String, dynamic>? _home;
  static Map<String, dynamic>? _category;
  static Map<String, dynamic>? _demoCatalog;
  static Completer<Map<String, dynamic>>? _demoCatalogReady;
  static final StreamController<String> _changes =
      StreamController<String>.broadcast();
  static final StreamController<String> _focusTargets =
      StreamController<String>.broadcast();
  static final StreamController<double> _homeScrollDeltas =
      StreamController<double>.broadcast();
  static bool _listening = false;
  static bool useDemoCatalog = false;

  static Stream<Map<String, dynamic>?> layoutsFor(String page) async* {
    _listen();
    yield _current[page];
    await for (final String changedPage in _changes.stream) {
      if (changedPage == page) yield _current[page];
    }
  }

  static Stream<Map<String, dynamic>?> get homeLayouts async* {
    _listen();
    yield _home;
    await for (final String changedPage in _changes.stream) {
      if (changedPage == 'home') yield _home;
    }
  }

  static Stream<Map<String, dynamic>?> get categorySettings async* {
    _listen();
    yield _category;
    await for (final String changedPage in _changes.stream) {
      if (changedPage == 'category') yield _category;
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

  static void _listen() {
    if (_listening) return;
    _listening = true;
    html.window.onMessage.listen((html.MessageEvent event) {
      dynamic message = event.data;
      if (message is String) {
        try {
          message = jsonDecode(message);
        } catch (_) {
          return;
        }
      }
      if (message is! Map) return;
      if (message['type'] == 'kidia-preview-scroll') {
        if ('${message['page'] ?? ''}' == 'home') {
          final double? delta = double.tryParse('${message['deltaY'] ?? ''}');
          if (delta != null && delta != 0) _homeScrollDeltas.add(delta);
        }
        return;
      }
      if (message['type'] == 'kidia-preview-focus') {
        if ('${message['page'] ?? ''}' == 'home') {
          final String target = '${message['target'] ?? ''}'.trim();
          if (target.isNotEmpty) _focusTargets.add(target);
        }
        return;
      }
      if (message['type'] != 'kidia-preview-layout') return;
      final String page = '${message['page'] ?? ''}';
      final dynamic rawLayout = message['layout'];
      if (page.isEmpty || rawLayout is! Map) return;
      final dynamic rawLayouts = message['layouts'];
      if (rawLayouts is Map) {
        for (final MapEntry<dynamic, dynamic> entry in rawLayouts.entries) {
          if (entry.value is! Map) continue;
          final String layoutPage = '${entry.key}'.trim();
          if (layoutPage.isEmpty) continue;
          _current[layoutPage] = Map<String, dynamic>.from(entry.value as Map);
          _changes.add(layoutPage);
        }
      } else {
        _current[page] = Map<String, dynamic>.from(rawLayout);
      }
      if (message['home'] is Map) {
        _home = Map<String, dynamic>.from(message['home'] as Map);
      }
      if (message['category'] is Map) {
        _category = Map<String, dynamic>.from(message['category'] as Map);
      }
      if (message['demo_catalog'] is Map) {
        _demoCatalog = Map<String, dynamic>.from(
          message['demo_catalog'] as Map,
        );
        final Completer<Map<String, dynamic>>? ready = _demoCatalogReady;
        if (ready != null && !ready.isCompleted) ready.complete(_demoCatalog!);
      }
      if (rawLayouts is! Map) _changes.add(page);
    });
    html.window.parent?.postMessage(
      jsonEncode(<String, String>{'type': 'kidia-flutter-preview-ready'}),
      '*',
    );
  }
}
