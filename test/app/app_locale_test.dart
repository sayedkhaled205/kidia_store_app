import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobishop_store_app/app/app.dart';
import 'package:mobishop_store_app/core/app_design/application_identity_provider58.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/localization/app_locale_provider.dart';
import 'package:mobishop_store_app/features/account/presentation/app_language_tile.dart';
import 'package:mobishop_store_app/features/auth/presentation/auth_copy.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in [
    'ar_EG',
    'ar_SA',
    'en_US',
    'fr_FR',
    'de_DE',
    'ur_PK',
    'he_IL',
  ]) {
    testWidgets(
      'phone $language chooses its supported language and direction',
      (tester) async {
        final parts = language.split('_');
        tester.binding.platformDispatcher.localesTestValue = [
          Locale(parts[0], parts[1]),
          const Locale('ar'),
        ];
        addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
        final expected = parts[0] == 'ar' ? 'ar' : 'en';
        await _pumpApp(tester);
        expect(find.text('locale:$expected'), findsOneWidget);
        expect(
          find.text('direction:${expected == 'ar' ? 'rtl' : 'ltr'}'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expect(
          find.text(
            expected == 'ar'
                ? 'رقم الموبايل أو البريد الإلكتروني'
                : 'Phone number or email',
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: AppConfig.isCmsPreview,
    );
  }

  testWidgets(
    'automatic language follows a phone language change while open',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = [
        const Locale('ar', 'EG'),
      ];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      await _pumpApp(tester);
      expect(find.text('locale:ar'), findsOneWidget);
      tester.binding.platformDispatcher.localesTestValue = [
        const Locale('fr', 'FR'),
      ];
      await tester.pumpAndSettle();
      expect(find.text('locale:en'), findsOneWidget);
      expect(find.text('direction:ltr'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: AppConfig.isCmsPreview,
  );

  testWidgets(
    'guest can choose and restore a language, then return to phone language',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = [
        const Locale('ar', 'EG'),
      ];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      await _pumpApp(tester);
      await tester.tap(find.byKey(const Key('account-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('app-language-en')));
      await tester.pumpAndSettle();
      expect(find.text('locale:en'), findsOneWidget);
      expect(find.text('direction:ltr'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpApp(tester);
      expect(find.text('locale:en'), findsOneWidget);
      await tester.tap(find.byKey(const Key('account-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('app-language-system')));
      await tester.pumpAndSettle();
      expect(find.text('locale:ar'), findsOneWidget);
      expect(find.text('direction:rtl'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpApp(tester);
      expect(find.text('locale:ar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: AppConfig.isCmsPreview,
  );

  test(
    'rapid language selections persist the last choice across restart',
    () async {
      final container = ProviderContainer();
      await container.read(appLanguagePreferenceProvider.future);
      final controller = container.read(appLanguagePreferenceProvider.notifier);
      await Future.wait([
        controller.select(AppLanguage.ar),
        controller.select(AppLanguage.en),
      ]);
      container.dispose();
      final reopened = ProviderContainer();
      addTearDown(reopened.dispose);
      expect(
        await reopened.read(appLanguagePreferenceProvider.future),
        AppLanguage.en,
      );
    },
    skip: AppConfig.isCmsPreview,
  );

  testWidgets(
    'editor keeps language simulation without pinning native language',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = [const Locale('en')];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      await _pumpApp(tester);
      expect(find.text('locale:ar'), findsOneWidget);
      await tester.tap(find.byKey(const Key('account-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('app-language-en')));
      await tester.pumpAndSettle();
      expect(find.text('locale:en'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !AppConfig.isCmsPreview,
  );

  testWidgets('default header copy follows language while custom copy stays', (
    tester,
  ) async {
    for (final language in ['ar', 'en']) {
      for (final custom in [false, true]) {
        final base = CmsPageLayout.fallback('account');
        final layout = CmsPageLayout(
          page: 'account',
          header: CmsPageComponent(
            id: 'header',
            type: 'app_header',
            enabled: true,
            settings: {
              'height': 110,
              'title': custom ? 'My brand' : 'حسابي',
              'search_placeholder': custom ? 'Find a gift' : 'Search products',
              'layout_json': {
                'rows': [
                  {
                    'columns': [
                      {
                        'width': 100,
                        'items': ['title'],
                      },
                    ],
                  },
                  {
                    'columns': [
                      {
                        'width': 100,
                        'items': ['search_bar'],
                      },
                    ],
                  },
                ],
              },
            },
          ),
          elements: base.elements,
          footer: base.footer,
        );
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: Locale(language),
              supportedLocales: supportedAppLocales,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: Scaffold(
                appBar: CmsPageAppBar(
                  layout: layout,
                  defaultTitle: language == 'ar' ? 'حسابي' : 'Account',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            custom
                ? 'My brand'
                : language == 'ar'
                ? 'حسابي'
                : 'Account',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            custom
                ? 'Find a gift'
                : language == 'ar'
                ? 'ابحث عن المنتجات'
                : 'Search products',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              Text('locale:${Localizations.localeOf(context).languageCode}'),
              Text('direction:${Directionality.of(context).name}'),
              Text(AuthCopy.of(context).identifier),
              const AppLanguageTile(),
            ],
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Stale saved branding must not override the native phone locale or RTL.
        applicationIdentity58Provider.overrideWithValue({
          'language': 'ar',
          'direction': 'rtl',
        }),
      ],
      child: MobiShopApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
}
