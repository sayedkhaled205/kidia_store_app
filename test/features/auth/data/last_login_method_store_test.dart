import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobishop_store_app/features/auth/data/storage/last_login_method_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'last method persists locally, stores are isolated, corrupt values ignored',
    () async {
      SharedPreferences.setMockInitialValues({});
      final a = LastLoginMethodStore(Uri.parse('https://shop.example/a/'));
      final b = LastLoginMethodStore(Uri.parse('https://shop.example/b/'));
      expect(await a.read(), isNull);
      await a.save(LastLoginMethod.google);
      expect(
        await LastLoginMethodStore(Uri.parse('https://shop.example/a')).read(),
        LastLoginMethod.google,
      );
      expect(await b.read(), isNull);
      await b.save(LastLoginMethod.facebook);
      expect(await a.read(), LastLoginMethod.google);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().length, 2);
      for (final key in prefs.getKeys()) {
        await prefs.setString(key, 'unrecognized');
      }
      expect(await a.read(), isNull);
      expect(await b.read(), isNull);
    },
  );
}
