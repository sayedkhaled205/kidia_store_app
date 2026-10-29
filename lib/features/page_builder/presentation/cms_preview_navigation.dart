import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Explicit editor navigation dismisses temporary preview UI before routing.
/// Design refreshes and normal mobile navigation do not use this function.
void navigateCmsPreview(GoRouter router, String path) {
  router.routerDelegate.navigatorKey.currentState?.popUntil(
    (route) => route is! PopupRoute,
  );
  router.go(path);
}
