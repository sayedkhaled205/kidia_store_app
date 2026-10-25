import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The desktop editor must allow grabbing the phone preview like a touchscreen.
class CmsPreviewScrollBehavior extends MaterialScrollBehavior {
  const CmsPreviewScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}
