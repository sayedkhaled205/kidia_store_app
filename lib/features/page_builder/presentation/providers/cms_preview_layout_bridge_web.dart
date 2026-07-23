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
  static final StreamController<String> _changes =
      StreamController<String>.broadcast();
  static final StreamController<String> _focusTargets =
      StreamController<String>.broadcast();
  static bool _listening = false;

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
      _current[page] = Map<String, dynamic>.from(rawLayout);
      if (page == 'home' && message['home'] is Map) {
        _home = Map<String, dynamic>.from(message['home'] as Map);
      }
      if (page == 'category' && message['category'] is Map) {
        _category = Map<String, dynamic>.from(message['category'] as Map);
      }
      _changes.add(page);
    });
    html.window.parent?.postMessage(
      jsonEncode(<String, String>{'type': 'kidia-flutter-preview-ready'}),
      '*',
    );
  }
}
