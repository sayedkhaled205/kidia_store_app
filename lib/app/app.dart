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
      // Flutter Web otherwise inherits the desktop browser platform. That
      // changes Material metrics and interaction defaults even though the
      // preview is rendered inside a phone-sized viewport. The CMS preview is
      // an Android application preview, so make it use the same platform
      // defaults as the installed app without changing native builds.
      theme: AppConfig.isCmsPreview
          ? KidiaTheme.light.copyWith(platform: TargetPlatform.android)
          : KidiaTheme.light,
      builder: (context, child) {
        final Widget app = Directionality(
          textDirection: AppConfig.isRightToLeft
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
        if (!AppConfig.isCmsPreview) return app;

        // WordPress inherits the desktop accessibility/text environment. Do
        // not let that environment resize only the embedded preview; the
        // phone and the preview must calculate the same header/footer slots.
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.noScaling,
            boldText: false,
            navigationMode: NavigationMode.traditional,
          ),
          child: app,
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
