import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_design/store_privacy_provider.dart';

final storePrivacyLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

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
      onPressed: () async {
        var opened = false;
        try {
          opened = await ref.read(storePrivacyLauncherProvider)(uri);
        } catch (_) {
          /* Keep the account screen usable when no browser is available. */
        }
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ar
                    ? 'تعذر فتح سياسة الخصوصية. حاول مرة أخرى.'
                    : 'Unable to open the privacy policy. Please retry.',
              ),
            ),
          );
        }
      },
      child: Text(
        ar ? 'سياسة الخصوصية' : 'Privacy Policy',
        style: const TextStyle(decoration: TextDecoration.underline),
      ),
    );
  }
}
