import 'package:flutter_riverpod/flutter_riverpod.dart';

final appStartupProvider = FutureProvider<void>((ref) async {
  // لاحقًا سنضع هنا:
  // 1. تحميل اللغة.
  // 2. قراءة الإعدادات المحلية.
  // 3. تحميل آخر Home Layout محفوظ.
  // 4. تجهيز خدمات الشبكة.
  await Future<void>.delayed(const Duration(seconds: 2));
});