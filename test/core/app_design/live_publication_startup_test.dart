import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/app/app_startup_provider.dart';
import 'package:mobishop_store_app/core/app_design/app_design_bundle58.dart';
import 'package:mobishop_store_app/core/app_design/app_design_providers58.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/features/splash/presentation/splash_providers.dart';

import 'app_design_fixture58.dart';

final _publication = NotifierProvider<_Publication, AppDesignBundle58>(
  _Publication.new,
);

class _Publication extends Notifier<AppDesignBundle58> {
  @override
  AppDesignBundle58 build() => design('First');
  void publish(String name) => state = design(name);
}

AppDesignBundle58 design(String name) {
  final json = appDesignFixture58();
  json['identity']['app_name'] = name;
  json['splash']['enabled'] = false;
  return AppDesignBundle58.fromEncoded(
    base64Encode(utf8.encode(jsonEncode(json))),
    platform: CommercePlatform.odoo,
    storeOrigin: Uri.parse(appDesignOrigin58),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'successive publications do not restart completed app startup',
    () async {
      final container = ProviderContainer(
        overrides: [
          portableAppDesign58Provider.overrideWith(
            (ref) => ref.watch(_publication),
          ),
          splashConfigProvider.overrideWith(
            (ref) async => ref.watch(_publication).splash,
          ),
        ],
      );
      addTearDown(container.dispose);
      final states = <AsyncValue<void>>[];
      container.listen(
        appStartupProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      final started = container.read(appStartupProvider.future);
      await started;
      states.clear();
      for (final name in ['Second', 'Third', 'First']) {
        container.read(_publication.notifier).publish(name);
        await container.pump();
        expect(
          container.read(portableAppDesign58Provider)!.identity['app_name'],
          name,
        );
        expect(
          identical(container.read(appStartupProvider.future), started),
          isTrue,
          reason: 'A design update must not replay splash or remount the shell',
        );
        expect(states.where((state) => state.isLoading), isEmpty);
      }
    },
  );
}
