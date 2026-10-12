import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commerce/commerce_connection.dart';
import '../config/app_config.dart';
import 'app_design_bundle58.dart';

/// The legacy Woo and live CMS preview paths stay exactly separate. A foreign
/// build must supply saved public design before creating any WordPress reader.
final portableAppDesign58Provider = Provider<AppDesignBundle58?>((ref) {
  if (AppConfig.isCmsPreview ||
      AppConfig.commercePlatform == CommercePlatform.wooCommerce) {
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
