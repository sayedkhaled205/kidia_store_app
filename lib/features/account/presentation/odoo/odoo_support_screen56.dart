import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_design/app_support_provider.dart';
import 'odoo_customer_chrome56.dart';

/// Public customer contacts do not instantiate a Woo cart/bearer transport.
class OdooSupportScreen56 extends ConsumerWidget {
  const OdooSupportScreen56({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final support = ref.watch(appSupportProvider);
    final phone = support.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    final email = support.email.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(odooCopy56(context, 'خدمة العملاء', 'Customer service')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (RegExp(r'^[0-9]{7,15}$').hasMatch(phone))
            Card(
              child: ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: Text(odooCopy56(context, 'واتساب', 'WhatsApp')),
                subtitle: Text(support.whatsapp),
                onTap: () => _open(context, Uri.https('wa.me', '/$phone')),
              ),
            ),
          if (email.isNotEmpty && !email.contains(RegExp(r'[\r\n]')))
            Card(
              child: ListTile(
                leading: const Icon(Icons.email_outlined),
                title: Text(odooCopy56(context, 'البريد الإلكتروني', 'Email')),
                subtitle: Text(email),
                onTap: () => _open(context, Uri(scheme: 'mailto', path: email)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      /* Keep platform error text out of the customer UI. */
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            odooCopy56(
              context,
              'تعذر فتح وسيلة التواصل.',
              'Could not open this contact method.',
            ),
          ),
        ),
      );
    }
  }
}
