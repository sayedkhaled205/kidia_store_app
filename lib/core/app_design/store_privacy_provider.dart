import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../commerce/commerce_connection.dart';
import '../config/app_config.dart';
import '../../features/auth/presentation/providers/native_auth_providers.dart';
import 'app_design_providers58.dart';

Uri? safeStorePrivacyUri(String value) {
  if (value.length > 2048) return null;
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}

/// Merchant policy, never a guessed route or the builder vendor's policy.
final storePrivacyProvider = Provider.autoDispose<Uri?>((ref) {
  final controls = ref
      .watch(portableAppDesign58Provider)
      ?.pageLayout('home')
      .settings['ui_controls_v1'];
  final configured = controls is Map ? controls['privacy_policy_url'] : null;
  final published = safeStorePrivacyUri(configured is String ? configured : '');
  if (published != null) return published;
  if (AppConfig.commercePlatform != CommercePlatform.wooCommerce) return null;
  return safeStorePrivacyUri(
    ref.watch(nativeAuthConfigProvider).value?.privacyPolicyUrl ?? '',
  );
});
