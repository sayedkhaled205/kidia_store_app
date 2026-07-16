import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';

final appStartupProvider = FutureProvider<void>((ref) async {
  AppConfig.validateStoreConnection();
});
