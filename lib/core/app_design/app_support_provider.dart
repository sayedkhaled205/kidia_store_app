import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'app_ui_controls_provider.dart';

/// Public merchant contacts only, from the same accepted publication as the UI.
/// No customer information or authentication transport is involved.
final appSupportProvider = Provider<AppSupport>((ref) {
  final ui = ref.watch(appUiControlsProvider);
  return AppSupport(
    whatsapp: ui.boolean('support_whatsapp_enabled')
        ? ui.values['support_whatsapp'] as String? ?? AppConfig.supportWhatsApp
        : '',
    email: ui.boolean('support_email_enabled')
        ? ui.values['support_contact_email'] as String? ??
              AppConfig.supportEmail
        : '',
  );
});

class AppSupport {
  const AppSupport({required this.whatsapp, required this.email});
  final String whatsapp;
  final String email;
}
