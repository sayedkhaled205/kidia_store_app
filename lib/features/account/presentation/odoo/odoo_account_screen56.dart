import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/app_design/application_identity_provider58.dart';
import '../../../../core/app_design/app_ui_controls.dart';
import '../../../page_builder/domain/cms_page_layout.dart';
import '../../../page_builder/domain/cms_footer_label.dart';
import '../../../page_builder/presentation/providers/cms_page_layout_providers.dart';
import '../../../page_builder/presentation/widgets/cms_page_chrome.dart';
import '../../../auth/presentation/providers/odoo_customer_providers51.dart';
import '../app_language_tile.dart';
import 'odoo_customer_chrome56.dart';
import 'odoo_customer_data56.dart';

/// Separate Odoo identity gate. No SID is converted to a Woo AuthSession/token.
/// A fresh login/re-login remounts private content even for the same uid.
class OdooCustomerGate56 extends ConsumerWidget {
  const OdooCustomerGate56({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(odooCustomerSession51Provider);
    final session = state.asData?.value;
    if (state.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(key: Key('odoo-session-loading')),
        ),
      );
    }
    if (state.hasError) {
      return Scaffold(
        body: OdooCustomerFailure56(
          error: state.error!,
          onRetry: () => ref.invalidate(odooCustomerSession51Provider),
        ),
      );
    }
    if (session?.authenticated != true) {
      return const OdooSignInScreen56(popOnSuccess: false);
    }
    return OdooCustomerLive56(key: ObjectKey(session), child: child);
  }
}

class OdooAccountScreen56 extends ConsumerWidget {
  const OdooAccountScreen56({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(odooCustomerSession51Provider);
    final session = sessionState.isLoading || sessionState.hasError
        ? null
        : sessionState.asData?.value;
    final customer = session?.customer;
    final profile = customer == null
        ? null
        : ref.watch(odooCustomerProfile56Provider).asData?.value;
    final signedIn = customer != null;
    final identity = ref.watch(applicationIdentity58Provider);
    final layout = ref.watch(cmsPageLayoutProvider('account')).value;
    final summary =
        layout?.element('account_summary') ??
        CmsPageLayout.fallback('account').element('account_summary');
    final menu =
        layout?.element('account_menu') ??
        CmsPageLayout.fallback('account').element('account_menu');
    final logout =
        layout?.element('logout_button') ??
        CmsPageLayout.fallback('account').element('logout_button');
    final ui = AppUiControlsScope.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final flat = menu.boolean('compact_family', false);
    final cardStyle = summary.string('card_style', 'elevated');
    final body = ListView(
      padding: EdgeInsets.symmetric(
        horizontal: layout == null ? 16 : cmsContentHorizontalPadding(layout),
        vertical: 16,
      ),
      children: [
        if (summary.enabled || !signedIn)
          CmsElementFrame(
            component: summary,
            child: Card(
              elevation: cardStyle == 'elevated' ? null : 0,
              shape: cardStyle == 'outlined'
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    )
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.account_circle_outlined,
                      size: summary.number('avatar_size', 58),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile?.name ??
                          customer?.name ??
                          identity?['app_name'] as String? ??
                          AppConfig.storeName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (customer != null && summary.boolean('show_email', true))
                      Text(customer.email, textAlign: TextAlign.center),
                    if (sessionState.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: LinearProgressIndicator(),
                      ),
                    if (!signedIn && !sessionState.isLoading) ...[
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const Key('odoo-account-sign-in'),
                        onPressed: () => context.push('/auth'),
                        child: Text(
                          cmsFooterLabel(
                            summary.string('guest_title', ''),
                            odooCopy56(context, 'تسجيل الدخول', 'Sign in'),
                            const [
                              'Sign in / Register',
                              'Sign in / Create account',
                              'تسجيل الدخول / إنشاء حساب',
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (sessionState.hasError)
                      Text(
                        odooCustomerError56(context, sessionState.error!),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (menu.enabled)
          CmsElementFrame(
            component: menu,
            child: Card(
              elevation: flat ? 0 : null,
              margin: flat ? const EdgeInsets.symmetric(horizontal: 16) : null,
              shape: flat ? const RoundedRectangleBorder() : null,
              child: Column(
                children: [
                  for (final entry in <(String, IconData, String, String)>[
                    (
                      '/orders',
                      Icons.receipt_long_outlined,
                      'طلباتي',
                      'My orders',
                    ),
                    (
                      '/addresses',
                      Icons.location_on_outlined,
                      'العناوين المحفوظة',
                      'Saved addresses',
                    ),
                    (
                      '/profile',
                      Icons.person_outline,
                      'بيانات حسابي',
                      'My profile',
                    ),
                    (
                      '/support',
                      Icons.support_agent,
                      'خدمة العملاء',
                      'Customer service',
                    ),
                  ])
                    if (menu.boolean('show_${entry.$1.substring(1)}', true))
                      ListTile(
                        minTileHeight: flat ? 64 : null,
                        leading: Icon(entry.$2),
                        title: Text(odooCopy56(context, entry.$3, entry.$4)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: sessionState.isLoading
                            ? null
                            : () => context.push(signedIn ? entry.$1 : '/auth'),
                      ),
                  if (!flat) const Divider(height: 1),
                  const AppLanguageTile(),
                ],
              ),
            ),
          ),
        if (!menu.enabled) const AppLanguageTile(),
        if (signedIn && logout.enabled) ...[
          const SizedBox(height: 16),
          CmsElementFrame(
            component: logout,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, ui.number('logout_height')),
                padding: EdgeInsets.symmetric(
                  horizontal: ui.number('logout_padding'),
                  vertical: 8,
                ),
                textStyle: TextStyle(fontSize: ui.number('logout_font_size')),
                iconSize: ui.number('logout_icon_size'),
              ),
              key: const Key('odoo-account-sign-out'),
              onPressed: () async {
                try {
                  await ref
                      .read(odooCustomerSession51Provider.notifier)
                      .signOut();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        odooCopy56(
                          context,
                          'تم تسجيل الخروج.',
                          'You have been signed out.',
                        ),
                      ),
                    ),
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        odooCopy56(
                          context,
                          'تم إنهاء الجلسة على الجهاز. تعذر تأكيد الخروج من السيرفر.',
                          'The device session was cleared. Server sign-out could not be confirmed.',
                        ),
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: Text(
                ui.text(
                  'logout_label',
                  arabic,
                  odooCopy56(context, 'تسجيل الخروج', 'Sign out'),
                ),
              ),
            ),
          ),
        ],
      ],
    );
    final page = layout == null
        ? Scaffold(
            appBar: AppBar(
              title: Text(odooCopy56(context, 'حسابي', 'Account')),
            ),
            body: body,
          )
        : CmsPageScaffold(
            layout: layout,
            defaultTitle: odooCopy56(context, 'حسابي', 'Account'),
            body: body,
          );
    // This entry stays available to guests, but a signed-in account needs the
    // same visible-route/resume checks as the protected customer screens.
    return signedIn && !sessionState.isLoading && !sessionState.hasError
        ? OdooCustomerLive56(key: ObjectKey(session), child: page)
        : page;
  }
}

class OdooSignInScreen56 extends ConsumerStatefulWidget {
  const OdooSignInScreen56({this.popOnSuccess = true, super.key});
  final bool popOnSuccess;
  @override
  ConsumerState<OdooSignInScreen56> createState() => _OdooSignInScreen56State();
}

class _OdooSignInScreen56State extends ConsumerState<OdooSignInScreen56> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  Object? _error;
  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _form.currentState?.validate() != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(odooCustomerSession51Provider.notifier)
          .signIn(login: _login.text.trim(), password: _password.text);
      if (!mounted) return;
      if (ref.read(odooCustomerSession51Provider).asData?.value.authenticated !=
          true) {
        return;
      }
      if (widget.popOnSuccess) {
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/account');
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) {
        _password.clear();
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final restoring = ref.watch(odooCustomerSession51Provider).isLoading;
    final identity = ref.watch(applicationIdentity58Provider);
    final ui = AppUiControlsScope.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    InputDecoration inputDecoration(String label) => InputDecoration(
      labelText: label,
      border: ui.values.containsKey('auth_field_radius')
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ui.number('auth_field_radius'),
              ),
            )
          : null,
      contentPadding: ui.values.containsKey('auth_field_padding')
          ? EdgeInsets.all(ui.number('auth_field_padding'))
          : null,
    );
    return Scaffold(
      backgroundColor: ui.values.containsKey('auth_background')
          ? ui.color('auth_background')
          : null,
      appBar: AppBar(
        title: Text(odooCopy56(context, 'تسجيل الدخول', 'Sign in')),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: ui.values.containsKey('auth_side_padding')
                ? ui.number('auth_side_padding')
                : 20,
            vertical: 20,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ui.values.containsKey('auth_top_spacing'))
                    SizedBox(height: ui.number('auth_top_spacing')),
                  Text(
                    ui.text(
                      'auth_title',
                      arabic,
                      identity?['app_name'] as String? ?? AppConfig.storeName,
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: ui.values.containsKey('auth_title_size')
                          ? ui.number('auth_title_size')
                          : null,
                      color: ui.values.containsKey('auth_title_color')
                          ? ui.color('auth_title_color')
                          : null,
                    ),
                  ),
                  if (ui.text('auth_intro', arabic, '').isNotEmpty)
                    Text(
                      ui.text('auth_intro', arabic, ''),
                      textAlign: TextAlign.center,
                    ),
                  SizedBox(
                    height: ui.values.containsKey('auth_logo_gap')
                        ? ui.number('auth_logo_gap')
                        : 24,
                  ),
                  TextFormField(
                    key: const Key('odoo-login'),
                    controller: _login,
                    enabled: !_busy && !restoring,
                    maxLength: 254,
                    autofillHints: const [AutofillHints.username],
                    decoration: inputDecoration(
                      odooCopy56(
                        context,
                        'البريد الإلكتروني / اسم الدخول',
                        'Email / login',
                      ),
                    ),
                    validator: (value) => value?.trim().isNotEmpty == true
                        ? null
                        : odooCopy56(
                            context,
                            'اكتب بيانات الدخول.',
                            'Enter your login.',
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('odoo-password'),
                    controller: _password,
                    enabled: !_busy && !restoring,
                    obscureText: _obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.password],
                    decoration:
                        inputDecoration(
                          odooCopy56(context, 'كلمة المرور', 'Password'),
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                    validator: (value) => value?.isNotEmpty == true
                        ? null
                        : odooCopy56(
                            context,
                            'اكتب كلمة المرور.',
                            'Enter your password.',
                          ),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        odooCustomerError56(context, _error!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton(
                    style: ui.values.containsKey('auth_button_height')
                        ? FilledButton.styleFrom(
                            minimumSize: Size(
                              0,
                              ui.number('auth_button_height'),
                            ),
                          )
                        : null,
                    key: const Key('odoo-login-submit'),
                    onPressed: _busy || restoring ? null : _submit,
                    child: _busy || restoring
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            ui.text(
                              'auth_continue',
                              arabic,
                              odooCopy56(context, 'دخول', 'Sign in'),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    odooCopy56(
                      context,
                      'لو محتاج حساب جديد أو نسيت كلمة المرور، افتح خيارات الدخول على موقع المتجر. بعدها ارجع وسجّل دخولك هنا.',
                      'For a new account or a forgotten password, open the sign-in options on the store website. Then return and sign in here.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  TextButton.icon(
                    key: const Key('odoo-website-account-help'),
                    onPressed: _busy || restoring
                        ? null
                        : () => context.push('/store-flow?route=/account-help'),
                    icon: const Icon(Icons.open_in_browser),
                    label: Text(
                      odooCopy56(
                        context,
                        'خيارات الدخول على موقع المتجر',
                        'Sign-in options on store website',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
