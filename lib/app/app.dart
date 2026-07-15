import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/theme/kidia_theme.dart';
import 'app_router.dart';

class WooMobileCmsApp extends ConsumerWidget {
  const WooMobileCmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: KidiaTheme.light,
      routerConfig: ref.watch(appRouterProvider),
      builder: (BuildContext context, Widget? child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
