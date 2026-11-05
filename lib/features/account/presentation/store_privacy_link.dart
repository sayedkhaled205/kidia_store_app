import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'store_privacy_screen.dart';
import '../../../core/app_design/store_privacy_provider.dart';

class StorePrivacyLink extends ConsumerWidget {
  const StorePrivacyLink({
    this.policyUri,
    this.useStorePolicy = true,
    super.key,
  });
  final Uri? policyUri;
  final bool useStorePolicy;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = useStorePolicy
        ? ref.watch(storePrivacyProvider) ?? policyUri
        : policyUri;
    if (uri == null) return const SizedBox.shrink();
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return TextButton(
      key: const Key('store-privacy-policy'),
      onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => StorePrivacyScreen(uri: uri)),
      ),
      child: Text(
        ar ? 'سياسة الخصوصية' : 'Privacy Policy',
        style: const TextStyle(decoration: TextDecoration.underline),
      ),
    );
  }
}
