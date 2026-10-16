import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commerce/commerce_connection.dart';
import '../config/app_config.dart';
import 'app_design_bundle58.dart';

/// Native builds use their approved public design, including central-builder
/// Woo builds. Only legacy Woo builds without a bundle read WordPress layouts.
/// The live CMS preview continues to receive its unsaved design from the bridge.
final portableAppDesign58Provider = Provider<AppDesignBundle58?>((ref) {
  if (AppConfig.isCmsPreview ||
      (AppConfig.commercePlatform == CommercePlatform.wooCommerce &&
          AppConfig.appDesignBundle.trim().isEmpty)) {
    return null;
  }
  AppConfig.validateStoreConnection();
  try {
    return AppDesignBundle58.fromEncoded(
      AppConfig.appDesignBundle,
      platform: AppConfig.commercePlatform,
      storeOrigin: AppConfig.commerceConnection.storeOrigin,
    );
  } on FormatException catch (error) {
    throw AppConfigurationException(error.message.toString());
  }
});
