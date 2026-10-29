import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/localization/app_locale_provider.dart';
import '../features/checkout/data/network/native_payment_client92.dart';
import '../core/push/native_push_actions_host.dart';
import '../core/app_design/application_identity_provider58.dart';
import '../core/app_design/live_app_design_provider.dart';
import '../core/app_design/app_ui_controls.dart';
import '../core/app_design/app_ui_controls_provider.dart';
import '../core/live_updates/native_live_updates_host.dart';
import '../core/theme/mobishop_theme.dart';
import '../core/theme/preview_identity_theme.dart';
import '../core/theme/published_message_theme.dart';
import '../core/theme/cms_preview_scroll_behavior.dart';
import 'app_router.dart';
import '../features/page_builder/presentation/widgets/preview_edit_region.dart';
export '../features/page_builder/presentation/providers/preview_identity_provider.dart';

class MobiShopApp extends ConsumerWidget {
  const MobiShopApp({super.key, this.router});

  /// Allows widget tests and embedders to provide an isolated router without
  /// mutating the application-wide router provider.
  final GoRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter routerConfig = router ?? ref.watch(appRouterProvider);
    final uiControls = ref.watch(appUiControlsProvider);
    final Map<String, dynamic>? identity = ref.watch(
      applicationIdentity58Provider,
    );
    final Locale configuredLocale = ref.watch(appLocaleProvider);
    final bool rightToLeft = configuredLocale.languageCode == 'ar';

    return MaterialApp.router(
      scrollBehavior: AppConfig.isCmsPreview
          ? const CmsPreviewScrollBehavior()
          : null,
      debugShowCheckedModeBanner: false,
      title: identity?['app_name'] as String? ?? AppConfig.storeName,
      routerConfig: routerConfig,
      locale: configuredLocale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Flutter Web otherwise inherits the desktop browser platform. That
      // changes Material metrics and interaction defaults even though the
      // preview is rendered inside a phone-sized viewport. The CMS preview is
      // an Android application preview, so make it use the same platform
      // defaults as the installed app without changing native builds.
      theme: publishedMessageTheme(
        AppConfig.isCmsPreview
            ? previewIdentityTheme(MobiShopTheme.light, identity)
            : identity == null
            ? MobiShopTheme.light
            : applicationIdentityTheme(MobiShopTheme.light, identity),
        uiControls,
      ),
      builder: (context, child) {
        // Protect every route and overlay, including the payment SDK's
        // separate host. Page SafeAreas consume the remaining insets without
        // adding the navigation gap twice. App bars still own the status-bar
        // inset and Scaffold can resize using the unchanged keyboard insets.
        final Widget app = ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            child: NativePaymentHost92(
              child: Directionality(
                textDirection: rightToLeft
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: AppUiControlsScope(
                  controls: uiControls,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
        if (!AppConfig.isCmsPreview) {
          return NativePushActionsHost(
            router: routerConfig,
            child: LiveAppDesignHost(
              router: routerConfig,
              child: NativeLiveUpdatesHost(child: app),
            ),
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
          child: PreviewEditInspector(child: app),
        );
      },
    );
  }
}
