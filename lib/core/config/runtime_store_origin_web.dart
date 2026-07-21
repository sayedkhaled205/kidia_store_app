// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class RuntimeStoreOrigin {
  const RuntimeStoreOrigin._();

  static String get value => html.window.location.origin;
}
