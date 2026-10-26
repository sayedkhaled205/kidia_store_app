import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
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
    final page = Scaffold(
      appBar: AppBar(title: Text(odooCopy56(context, 'حسابي', 'Account'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.account_circle_outlined, size: 58),
                  const SizedBox(height: 12),
                  Text(
                    profile?.name ?? customer?.name ?? AppConfig.storeName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (customer != null)
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
                        odooCopy56(context, 'تسجيل الدخول', 'Sign in'),
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
          const SizedBox(height: 12),
          Card(
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
                  ListTile(
                    leading: Icon(entry.$2),
                    title: Text(odooCopy56(context, entry.$3, entry.$4)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: sessionState.isLoading
                        ? null
                        : () => context.push(signedIn ? entry.$1 : '/auth'),
                  ),
                const Divider(height: 1),
                const AppLanguageTile(),
              ],
            ),
          ),
          if (signedIn) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
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
              label: Text(odooCopy56(context, 'تسجيل الخروج', 'Sign out')),
            ),
          ],
        ],
      ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(odooCopy56(context, 'تسجيل الدخول', 'Sign in')),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppConfig.storeName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('odoo-login'),
                    controller: _login,
                    enabled: !_busy && !restoring,
                    maxLength: 254,
                    autofillHints: const [AutofillHints.username],
                    decoration: InputDecoration(
                      labelText: odooCopy56(
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
                    decoration: InputDecoration(
                      labelText: odooCopy56(context, 'كلمة المرور', 'Password'),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
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
                    key: const Key('odoo-login-submit'),
                    onPressed: _busy || restoring ? null : _submit,
                    child: _busy || restoring
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(odooCopy56(context, 'دخول', 'Sign in')),
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
