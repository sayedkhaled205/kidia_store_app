import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_design/application_identity_provider58.dart';
import '../config/app_config.dart';

const supportedAppLocales = <Locale>[Locale('ar'), Locale('en')];

/// Only the phone's primary language decides the automatic app language.
/// A secondary Arabic preference must not turn a French phone Arabic.
Locale resolveDeviceAppLocale(Locale? device) =>
    Locale(device?.languageCode.toLowerCase() == 'ar' ? 'ar' : 'en');

final deviceLocaleProvider = NotifierProvider<DeviceLocaleController, Locale>(
  DeviceLocaleController.new,
);

class DeviceLocaleController extends Notifier<Locale>
    with WidgetsBindingObserver {
  @override
  Locale build() {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    binding.addObserver(this);
    ref.onDispose(() => binding.removeObserver(this));
    return binding.platformDispatcher.locales.firstOrNull ?? const Locale('en');
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    state = locales?.firstOrNull ?? const Locale('en');
  }
}

enum AppLanguage { system, ar, en }

final appLanguagePreferencesProvider = Provider<Future<SharedPreferences>>(
  (_) => SharedPreferences.getInstance(),
);

final appLanguagePreferenceProvider =
    AsyncNotifierProvider<AppLanguageController, AppLanguage>(
      AppLanguageController.new,
    );

class AppLanguageController extends AsyncNotifier<AppLanguage> {
  String get _key => 'mobishop.app_language:${AppConfig.apiBaseUrl}';
  Future<void> _writes = Future<void>.value();

  @override
  Future<AppLanguage> build() async {
    // Trying a language in the editor never changes customer preferences.
    if (AppConfig.isCmsPreview) return AppLanguage.system;
    try {
      final preferences = await ref.watch(appLanguagePreferencesProvider);
      final saved = preferences.getString(_key);
      return AppLanguage.values.firstWhere(
        (value) => value.name == saved,
        orElse: () => AppLanguage.system,
      );
    } catch (_) {
      return AppLanguage.system;
    }
  }

  Future<void> select(AppLanguage language) async {
    // Serialize writes so rapid changes also restore the last selection.
    final operation = _writes.then((_) async {
      if (!AppConfig.isCmsPreview) {
        final preferences = await ref.read(appLanguagePreferencesProvider);
        final saved = await preferences.setString(_key, language.name);
        if (!saved) throw StateError('Could not save app language');
      }
      if (ref.mounted) state = AsyncData(language);
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }
}

final appLocaleProvider = Provider<Locale>((ref) {
  final preference =
      ref.watch(appLanguagePreferenceProvider).value ?? AppLanguage.system;
  if (preference != AppLanguage.system) return Locale(preference.name);
  // The editor's selected language simulates a phone language. Native builds
  // always use the phone, even if an older saved design pins Arabic or RTL.
  if (AppConfig.isCmsPreview) {
    final identity = ref.watch(applicationIdentity58Provider);
    final simulated = '${identity?['language'] ?? ''}'.trim();
    if (simulated.isNotEmpty) {
      return resolveDeviceAppLocale(
        Locale(simulated.split(RegExp('[-_]')).first),
      );
    }
  }
  return resolveDeviceAppLocale(ref.watch(deviceLocaleProvider));
});
