import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/push/native_push_actions_host.dart';
import '../core/app_design/application_identity_provider58.dart';
import '../core/live_updates/native_live_updates_host.dart';
import '../core/theme/mobishop_theme.dart';
import '../core/theme/preview_identity_theme.dart';
import 'app_router.dart';
export '../features/page_builder/presentation/providers/preview_identity_provider.dart';

class MobiShopApp extends ConsumerWidget {
  const MobiShopApp({super.key, this.router});

  /// Allows widget tests and embedders to provide an isolated router without
  /// mutating the application-wide router provider.
  final GoRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter routerConfig = router ?? ref.watch(appRouterProvider);
    final Map<String, dynamic>? identity = ref.watch(applicationIdentity58Provider);
    final Locale configuredLocale = _configuredStoreLocale(
      identity?['language'] as String?,
    );
    final String direction = '${identity?['direction'] ?? ''}';
    final bool rightToLeft = direction == 'rtl'
        ? true
        : direction == 'ltr'
        ? false
        : AppConfig.isRightToLeft;

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: identity?['app_name'] as String? ?? AppConfig.storeName,
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
          ? previewIdentityTheme(MobiShopTheme.light, identity)
          : identity == null
          ? MobiShopTheme.light
          : applicationIdentityTheme(MobiShopTheme.light, identity),
      builder: (context, child) {
        final Widget app = Directionality(
          textDirection: rightToLeft ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
        if (!AppConfig.isCmsPreview) {
          return NativePushActionsHost(
            router: routerConfig,
            child: NativeLiveUpdatesHost(child: app),
          );
        }

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

Locale _configuredStoreLocale([String? previewLocale]) {
  final List<String> parts = (previewLocale ?? AppConfig.storeLocale)
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
