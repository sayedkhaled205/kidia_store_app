import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../commerce/commerce_connection.dart';
import '../config/app_config.dart';
import '../../features/auth/presentation/providers/native_auth_providers.dart';
import '../commerce/store_policy_discovery.dart';
export '../commerce/store_policy_discovery.dart' show safeStorePrivacyUri;

final discoveredStorePrivacyProvider = FutureProvider.autoDispose<Uri?>((
  ref,
) async {
  if (!AppConfig.hasConfiguredStore) return null;
  return discoverPublicPolicy(AppConfig.commerceConnection);
}, retry: (_, _) => null);

final storePrivacyProvider = Provider.autoDispose<Uri?>((ref) {
  if (AppConfig.commercePlatform == CommercePlatform.wooCommerce ||
      AppConfig.isCmsPreview) {
    return safeStorePrivacyUri(
      ref.watch(nativeAuthConfigProvider).value?.privacyPolicyUrl ?? '',
    );
  }
  return ref.watch(discoveredStorePrivacyProvider).asData?.value;
});
