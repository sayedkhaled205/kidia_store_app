import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/core/theme/kidia_colors.dart';
import 'package:kidia_store_app/core/theme/kidia_radius.dart';
import 'package:kidia_store_app/core/theme/kidia_spacing.dart';
import 'package:kidia_store_app/features/account/presentation/customer_phone_format.dart';
import 'package:kidia_store_app/features/cart/presentation/widgets/cart_icon_button.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerSupportScreen extends StatelessWidget {
  const CustomerSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isArabic = _isArabic(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(isArabic ? 'خدمة العملاء' : 'Customer service'),
        actions: <Widget>[
          CartIconButton(onPressed: () => context.push('/cart')),
        ],
      ),
      body: _SupportContent(isArabic: isArabic),
    );
  }
}

class _SupportContent extends StatelessWidget {
  const _SupportContent({required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final List<_SupportAction> actions = <_SupportAction>[
      _SupportAction(
        id: 'whatsapp',
        icon: Icons.chat_outlined,
        label: isArabic ? 'واتساب' : 'WhatsApp',
        value: localEgyptianPhoneNumber(AppConfig.supportWhatsApp),
        uri: _whatsappUri(AppConfig.supportWhatsApp),
      ),
      _SupportAction(
        id: 'email',
        icon: Icons.email_outlined,
        label: isArabic ? 'البريد الإلكتروني' : 'Email',
        value: AppConfig.supportEmail,
        uri: Uri(
          scheme: 'mailto',
          path: AppConfig.supportEmail,
          queryParameters: <String, String>{
            'subject': isArabic ? 'خدمة عملاء Kidia' : 'Kidia customer service',
          },
        ),
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
        for (int index = 0; index < actions.length; index++) ...<Widget>[
          Card(
            key: Key('support-action-${actions[index].id}'),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: KidiaSpacing.md,
                vertical: KidiaSpacing.sm,
              ),
              leading: Container(
                width: 48,
                height: 48,
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
          ),
          if (index < actions.length - 1)
            const SizedBox(height: KidiaSpacing.sm),
        ],
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

bool _isArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
