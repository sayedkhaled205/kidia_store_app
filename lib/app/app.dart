import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/theme/kidia_theme.dart';
import 'app_router.dart';

class KidiaApp extends ConsumerWidget {
  const KidiaApp({super.key, this.router});

  /// Allows widget tests and embedders to provide an isolated router without
  /// mutating the application-wide router provider.
  final GoRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter routerConfig = router ?? ref.watch(appRouterProvider);
    final Locale configuredLocale = _configuredStoreLocale();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConfig.storeName,
      routerConfig: routerConfig,
      locale: configuredLocale,
      supportedLocales: <Locale>[
        configuredLocale,
        if (configuredLocale.languageCode != 'ar') const Locale('ar'),
        if (configuredLocale.languageCode != 'en') const Locale('en'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: KidiaTheme.light,
      builder: (context, child) {
        return Directionality(
          textDirection: AppConfig.isRightToLeft
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

Locale _configuredStoreLocale() {
  final List<String> parts = AppConfig.storeLocale
      .trim()
      .split(RegExp('[-_]'))
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    return const Locale('en');
  }

  return Locale.fromSubtags(
    languageCode: parts.first.toLowerCase(),
    countryCode: parts.length > 1 ? parts[1].toUpperCase() : null,
  );
}
