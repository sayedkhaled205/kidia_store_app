import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/commerce/odoo_customer_client51.dart';
import '../../../auth/presentation/providers/odoo_customer_providers51.dart';
import 'odoo_customer_chrome56.dart';
import 'odoo_customer_data56.dart';

class OdooProfileScreen56 extends ConsumerStatefulWidget {
  const OdooProfileScreen56({super.key});
  @override
  ConsumerState<OdooProfileScreen56> createState() =>
      _OdooProfileScreen56State();
}

class _OdooProfileScreen56State extends ConsumerState<OdooProfileScreen56> {
  OdooCustomerProfile51? _verified;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(odooCustomerProfile56Provider);
    final client = ref.watch(odooCustomerClient51Provider);
    final fresh = state.asData?.value;
    if (fresh != null &&
        client.isAuthenticated &&
        fresh.id == client.customer?.id &&
        fresh.partnerId == client.customer?.partnerId) {
      _verified = fresh;
    }
    if (!client.isAuthenticated) _verified = null;
    final verified = _verified;
    return Scaffold(
      appBar: AppBar(
        title: Text(odooCopy56(context, 'بيانات حسابي', 'My profile')),
        actions: [
          IconButton(
            key: const Key('odoo-profile-refresh'),
            tooltip: odooCopy56(context, 'تحديث', 'Refresh'),
            onPressed: () => ref.invalidate(odooCustomerProfile56Provider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: verified != null
          ? _OdooProfileForm56(
              key: ValueKey((verified.id, verified.partnerId)),
              profile: verified,
              loading: state.isLoading,
              refreshError: state.error,
              onRetry: () => ref.invalidate(odooCustomerProfile56Provider),
            )
          : state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : OdooCustomerFailure56(
              error:
                  state.error ??
                  const OdooCustomerException51('customer_session_required'),
              onRetry: () => ref.invalidate(odooCustomerSession51Provider),
            ),
    );
  }
}

class _OdooProfileForm56 extends ConsumerStatefulWidget {
  const _OdooProfileForm56({
    required this.profile,
    required this.loading,
    required this.refreshError,
    required this.onRetry,
    super.key,
  });
  final OdooCustomerProfile51 profile;
  final bool loading;
  final Object? refreshError;
  final VoidCallback onRetry;
  @override
  ConsumerState<_OdooProfileForm56> createState() => _OdooProfileForm56State();
}

class _OdooProfileForm56State extends ConsumerState<_OdooProfileForm56> {
  final _form = GlobalKey<FormState>();
  late OdooCustomerProfile51 _base;
  late final Map<String, TextEditingController> _fields;
  bool _saving = false;
  Object? _saveError;
  bool _changedElsewhere = false;

  Map<String, String> _values(OdooCustomerProfile51 p) => {
    'name': p.name,
    'phone': p.phone,
    'mobile': p.mobile,
  };
  bool get _dirty => _fields.entries.any(
    (field) => field.value.text != _values(_base)[field.key],
  );

  @override
  void initState() {
    super.initState();
    _base = widget.profile;
    _fields = {
      for (final e in _values(_base).entries)
        e.key: TextEditingController(text: e.value),
    };
  }

  @override
  void didUpdateWidget(covariant _OdooProfileForm56 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.profile, oldWidget.profile)) return;
    if (!_dirty && !_saving) {
      _replace(widget.profile);
    } else if (_values(widget.profile).toString() !=
        _values(_base).toString()) {
      _changedElsewhere = true;
    }
  }

  void _replace(OdooCustomerProfile51 profile) {
    _base = profile;
    for (final e in _values(profile).entries) {
      _fields[e.key]!.text = e.value;
    }
    _changedElsewhere = false;
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _form.currentState?.validate() != true) return;
    final patch = <String, String>{
      for (final e in _fields.entries)
        if (e.value.text != _values(_base)[e.key]) e.key: e.value.text.trim(),
    };
    if (patch.isEmpty) return;
    final client = ref.read(odooCustomerClient51Provider);
    if (client.customer?.id != _base.id ||
        client.customer?.partnerId != _base.partnerId) {
      ref.invalidate(odooCustomerSession51Provider);
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final updated = await client.updateProfile(patch);
      if (!mounted) return;
      setState(() => _replace(updated));
      ref.invalidate(odooCustomerProfile56Provider);
      ref.invalidate(odooCustomerAddresses56Provider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            odooCopy56(
              context,
              'تم حفظ بيانات الحساب.',
              'Your profile was saved.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      if (!client.isAuthenticated) {
        ref.invalidate(odooCustomerSession51Provider);
      }
      setState(() => _saveError = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.loading) const LinearProgressIndicator(),
                  if (widget.refreshError != null) ...[
                    Text(odooCustomerError56(context, widget.refreshError!)),
                    TextButton(
                      onPressed: widget.onRetry,
                      child: Text(
                        odooCopy56(context, 'إعادة المحاولة', 'Try again'),
                      ),
                    ),
                  ],
                  if (_changedElsewhere)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        odooCopy56(
                          context,
                          'اتحدثت بيانات الحساب من المتجر. احتفظنا بالتعديلات اللي لسه ما حفظتهاش.',
                          'The store profile changed. Your unsaved edits have been kept.',
                        ),
                      ),
                    ),
                  for (final e in _fields.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        key: Key('odoo-profile-${e.key}'),
                        controller: e.value,
                        enabled: !_saving,
                        keyboardType: e.key == 'name'
                            ? TextInputType.name
                            : TextInputType.phone,
                        maxLength: e.key == 'name' ? 240 : 120,
                        decoration: InputDecoration(
                          labelText: switch (e.key) {
                            'name' => odooCopy56(context, 'الاسم', 'Name'),
                            'phone' => odooCopy56(context, 'التليفون', 'Phone'),
                            _ => odooCopy56(context, 'الموبايل', 'Mobile'),
                          },
                        ),
                        validator: e.key != 'name'
                            ? null
                            : (value) => value?.trim().isNotEmpty == true
                                  ? null
                                  : odooCopy56(
                                      context,
                                      'اكتب الاسم.',
                                      'Enter your name.',
                                    ),
                      ),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      odooCopy56(context, 'البريد الإلكتروني', 'Email'),
                    ),
                    subtitle: Text(widget.profile.email),
                    trailing: const Icon(Icons.lock_outline),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(odooCopy56(context, 'اسم الدخول', 'Login')),
                    subtitle: Text(widget.profile.login),
                    trailing: const Icon(Icons.lock_outline),
                  ),
                  if (_saveError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        odooCustomerError56(context, _saveError!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton(
                    key: const Key('odoo-profile-save'),
                    onPressed: _saving ? null : _save,
                    child: Text(
                      odooCopy56(
                        context,
                        _saving ? 'جاري الحفظ…' : 'حفظ التعديلات',
                        _saving ? 'Saving…' : 'Save changes',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
