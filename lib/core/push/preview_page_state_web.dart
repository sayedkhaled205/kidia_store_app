import 'dart:convert';
import 'package:web/web.dart' as web;

final _states = <String, String>{};
void reportPreviewCatalog(String route, String state) {
  _states[route] = state;
  if (_states.length > 20) _states.remove(_states.keys.first);
  web.document.documentElement?.setAttribute(
    'data-preview-catalog-links',
    jsonEncode(_states),
  );
}
