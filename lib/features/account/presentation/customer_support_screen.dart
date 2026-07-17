import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/core/theme/kidia_colors.dart';
import 'package:kidia_store_app/core/theme/kidia_radius.dart';
import 'package:kidia_store_app/core/theme/kidia_spacing.dart';
import 'package:kidia_store_app/features/account/domain/entities/customer_account.dart';
import 'package:kidia_store_app/features/account/presentation/providers/customer_account_providers.dart';
import 'package:kidia_store_app/features/cart/presentation/widgets/cart_icon_button.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerSupportScreen extends ConsumerWidget {
  const CustomerSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isArabic = _isArabic(context);
    final AsyncValue<CustomerAccount> account = ref.watch(
      customerAccountProvider,
    );
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(isArabic ? 'خدمة العملاء' : 'Customer service'),
        actions: <Widget>[
          CartIconButton(onPressed: () => context.push('/cart')),
        ],
      ),
      body: account.when(
        loading: () => const Center(
          child: CircularProgressIndicator(key: Key('support-loading')),
        ),
        error: (Object error, StackTrace stackTrace) => _SupportError(
          isArabic: isArabic,
          onRetry: () => ref.invalidate(customerAccountProvider),
        ),
        data: (CustomerAccount value) => _SupportContent(
          details: value.support,
          isArabic: isArabic,
        ),
      ),
    );
  }
}

class _SupportContent extends StatelessWidget {
  const _SupportContent({required this.details, required this.isArabic});

  final CustomerSupportDetails details;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final List<_SupportAction> actions = <_SupportAction>[
      if (details.whatsapp.trim().isNotEmpty)
        _SupportAction(
          id: 'whatsapp',
          icon: Icons.chat_outlined,
          label: isArabic ? 'واتساب' : 'WhatsApp',
          value: details.whatsapp,
          uri: _whatsappUri(details.whatsapp),
        ),
      if (details.phone.trim().isNotEmpty)
        _SupportAction(
          id: 'phone',
          icon: Icons.phone_outlined,
          label: isArabic ? 'اتصال هاتفي' : 'Phone call',
          value: details.phone,
          uri: Uri(scheme: 'tel', path: details.phone.trim()),
        ),
      if (details.email.trim().isNotEmpty)
        _SupportAction(
          id: 'email',
          icon: Icons.email_outlined,
          label: isArabic ? 'البريد الإلكتروني' : 'Email',
          value: details.email,
          uri: Uri(
            scheme: 'mailto',
            path: details.email.trim(),
            queryParameters: <String, String>{
              'subject': isArabic ? 'خدمة عملاء Kidia' : 'Kidia customer service',
            },
          ),
        ),
      if (details.contactUrl != null)
        _SupportAction(
          id: 'website',
          icon: Icons.language_rounded,
          label: isArabic ? 'صفحة تواصل معنا' : 'Contact page',
          value: isArabic ? 'فتح الموقع' : 'Open website',
          uri: details.contactUrl!,
        ),
    ];
    return ListView(
      padding: const EdgeInsets.all(KidiaSpacing.md),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(KidiaSpacing.lg),
          decoration: BoxDecoration(
            color: KidiaColors.primaryLight,
            borderRadius: BorderRadius.circular(KidiaRadius.lg),
          ),
          child: Column(
            children: <Widget>[
              const Icon(
                Icons.support_agent_rounded,
                size: 64,
                color: KidiaColors.primaryDark,
              ),
              const SizedBox(height: KidiaSpacing.sm),
              Text(
                isArabic ? 'إحنا هنا علشان نساعدك' : 'We are here to help',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: KidiaSpacing.xs),
              Text(
                isArabic
                    ? 'اختار طريقة التواصل المناسبة، وسيتم فتحها في التطبيق المخصص.'
                    : 'Choose a contact method and it will open in its dedicated app.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KidiaColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KidiaSpacing.lg),
        if (actions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(KidiaSpacing.lg),
              child: Text(
                isArabic
                    ? 'بيانات التواصل غير متاحة حاليًا.'
                    : 'Contact details are not available right now.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (int index = 0; index < actions.length; index++) ...<Widget>[
                  ListTile(
                    key: Key('support-action-${actions[index].id}'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: KidiaSpacing.md,
                      vertical: KidiaSpacing.xs,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: KidiaColors.primaryLight,
                        borderRadius: BorderRadius.circular(KidiaRadius.sm),
                      ),
                      child: Icon(
                        actions[index].icon,
                        color: KidiaColors.primaryDark,
                      ),
                    ),
                    title: Text(
                      actions[index].label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        actions[index].value,
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      ),
                    ),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => _open(context, actions[index].uri),
                  ),
                  if (index < actions.length - 1) const Divider(),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تعذر فتح وسيلة التواصل.'
                  : 'Could not open this contact method.',
            ),
          ),
        );
    }
  }

  Uri _whatsappUri(String phone) {
    final String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return Uri.https('wa.me', '/$digits');
  }
}

class _SupportAction {
  const _SupportAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.value,
    required this.uri,
  });

  final String id;
  final IconData icon;
  final String label;
  final String value;
  final Uri uri;
}

class _SupportError extends StatelessWidget {
  const _SupportError({required this.isArabic, required this.onRetry});

  final bool isArabic;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KidiaSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 52),
            const SizedBox(height: KidiaSpacing.md),
            Text(
              isArabic
                  ? 'تعذر تحميل بيانات خدمة العملاء.'
                  : 'Could not load customer service details.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KidiaSpacing.md),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(isArabic ? 'إعادة المحاولة' : 'Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
