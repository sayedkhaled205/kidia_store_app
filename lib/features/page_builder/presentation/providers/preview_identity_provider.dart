import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cms_preview_layout_bridge.dart';

final previewIdentityProvider = StreamProvider<Map<String, dynamic>?>(
  (ref) => CmsPreviewLayoutBridge.identitySettings,
);
