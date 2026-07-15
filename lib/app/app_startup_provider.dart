import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';

final FutureProvider<void> appStartupProvider = FutureProvider<void>(
  (Ref ref) async {
    AppConfig.validate();
  },
);
