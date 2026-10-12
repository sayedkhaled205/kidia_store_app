import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/page_builder/presentation/providers/preview_identity_provider.dart';
import '../commerce/commerce_connection.dart';
import '../config/app_config.dart';
import 'app_design_providers58.dart';

/// Branding only: customer identity, session and catalog are separate providers.
final applicationIdentity58Provider = Provider<Map<String, dynamic>?>((ref) {
  if (AppConfig.isCmsPreview) {
    return ref.watch(previewIdentityProvider).asData?.value;
  }
  try {
    if (AppConfig.commercePlatform == CommercePlatform.wooCommerce) {
      return AppConfig.nativeIdentity;
    }
    return ref.watch(portableAppDesign58Provider)?.identity;
  } catch (_) {
    // The startup/Home/chrome providers display the actual configuration error.
    // Do not crash MaterialApp before its error/retry UI can be mounted, or
    // invent a foreign store identity while its approved design is unavailable.
    return null;
  }
});
