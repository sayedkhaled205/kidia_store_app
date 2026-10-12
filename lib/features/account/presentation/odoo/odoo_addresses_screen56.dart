import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/commerce/odoo_customer_client51.dart';
import '../../../auth/presentation/providers/odoo_customer_providers51.dart';
import 'odoo_customer_chrome56.dart';
import 'odoo_customer_data56.dart';

class OdooAddressesScreen56 extends ConsumerWidget {
  const OdooAddressesScreen56({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(odooCustomerAddresses56Provider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          odooCopy56(context, 'العناوين المحفوظة', 'Saved addresses'),
        ),
      ),
      body: state.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => OdooCustomerFailure56(
          error: error,
          onRetry: () => ref.invalidate(odooCustomerAddresses56Provider),
        ),
        data: (addresses) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(odooCustomerAddresses56Provider);
            await ref.read(odooCustomerAddresses56Provider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _card(
                context,
                ref,
                addresses.primary,
                odooCopy56(context, 'العنوان الرئيسي', 'Primary address'),
              ),
              for (final address in addresses.items)
                _card(
                  context,
                  ref,
                  address,
                  odooCopy56(
                    context,
                    address.type == 'invoice'
                        ? 'عنوان الفاتورة'
                        : 'عنوان التوصيل',
                    address.type == 'invoice'
                        ? 'Invoice address'
                        : 'Delivery address',
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('odoo-address-create'),
                onPressed: () =>
                    _edit(context, ref, addresses.primary, creating: true),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(odooCopy56(context, 'إضافة عنوان', 'Add address')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    WidgetRef ref,
    OdooCustomerAddress51 address,
    String title,
  ) => Card(
    key: Key('odoo-address-${address.id}'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            [
              for (final key in [
                'name',
                'street',
                'street2',
                'city',
                'state_name',
                'country_code',
                'zip',
                'phone',
                'mobile',
              ])
                if (address.values[key]?.isNotEmpty == true)
                  address.values[key]!,
            ].join('\n'),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => _edit(context, ref, address),
              icon: const Icon(Icons.edit_outlined),
              label: Text(odooCopy56(context, 'تعديل', 'Edit')),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    OdooCustomerAddress51 address, {
    bool creating = false,
  }) async {
    final session = ref.read(odooCustomerSession51Provider).asData?.value;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _OdooAddressEditor56(address: address, creating: creating),
    );
    if (saved != true ||
        !context.mounted ||
        !identical(
          session,
          ref.read(odooCustomerSession51Provider).asData?.value,
        )) {
      return;
    }
    ref.invalidate(odooCustomerAddresses56Provider);
    ref.invalidate(odooCustomerProfile56Provider);
  }
}

class _OdooAddressEditor56 extends ConsumerStatefulWidget {
  const _OdooAddressEditor56({required this.address, required this.creating});
  final OdooCustomerAddress51 address;
  final bool creating;
  @override
  ConsumerState<_OdooAddressEditor56> createState() =>
      _OdooAddressEditor56State();
}

class _OdooAddressEditor56State extends ConsumerState<_OdooAddressEditor56> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  String _type = 'delivery';
  bool _busy = false;
  Object? _error;
  late final OdooCustomerSession51? _boundSession;
  @override
  void initState() {
    super.initState();
    _boundSession = ref.read(odooCustomerSession51Provider).asData?.value;
    _fields = {
      for (final key in [
        'name',
        'phone',
        'mobile',
        'street',
        'street2',
        'city',
        'zip',
      ])
        key: TextEditingController(
          text: widget.creating && key != 'name'
              ? ''
              : widget.address.values[key] ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _form.currentState?.validate() != true) return;
    final client = ref.read(odooCustomerClient51Provider);
    final session = ref.read(odooCustomerSession51Provider).asData?.value;
    if (session?.authenticated != true ||
        !client.isAuthenticated ||
        !identical(session, _boundSession)) {
      Navigator.of(context).pop(false);
      return;
    }
    final patch = <String, dynamic>{
      for (final e in _fields.entries)
        if (widget.creating ||
            e.value.text.trim() != widget.address.values[e.key])
          e.key: e.value.text.trim(),
      if (widget.creating) ...{
        'type': _type,
        if (widget.address.countryId != null)
          'country_id': widget.address.countryId,
        if (widget.address.stateId != null) 'state_id': widget.address.stateId,
      },
    };
    if (patch.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.creating) {
        await client.createAddress(patch);
      } else {
        await client.updateAddress(widget.address.id, patch);
      }
      if (!mounted ||
          !identical(
            session,
            ref.read(odooCustomerSession51Provider).asData?.value,
          )) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      if (!client.isAuthenticated) {
        Navigator.of(context).pop(false);
        ref.invalidate(odooCustomerSession51Provider);
        return;
      }
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(odooCustomerSession51Provider).asData?.value;
    // A modal sits above the route gate. Remove sensitive editor contents if
    // logout/session expiry happens while it is open.
    if (session?.authenticated != true || !identical(session, _boundSession)) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          odooCopy56(
            context,
            'انتهت جلسة الحساب.',
            'The account session ended.',
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                odooCopy56(
                  context,
                  widget.creating ? 'إضافة عنوان' : 'تعديل العنوان',
                  widget.creating ? 'Add address' : 'Edit address',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (widget.creating)
                DropdownButtonFormField<String>(
                  key: const Key('odoo-address-type'),
                  initialValue: _type,
                  decoration: InputDecoration(
                    labelText: odooCopy56(
                      context,
                      'نوع العنوان',
                      'Address type',
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'delivery',
                      child: Text(odooCopy56(context, 'توصيل', 'Delivery')),
                    ),
                    DropdownMenuItem(
                      value: 'invoice',
                      child: Text(odooCopy56(context, 'فاتورة', 'Invoice')),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _type = value!),
                ),
              for (final e in _fields.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextFormField(
                    key: Key('odoo-address-field-${e.key}'),
                    controller: e.value,
                    enabled: !_busy,
                    maxLength: e.key == 'phone' || e.key == 'mobile'
                        ? 120
                        : 240,
                    keyboardType: e.key == 'phone' || e.key == 'mobile'
                        ? TextInputType.phone
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: switch (e.key) {
                        'name' => odooCopy56(context, 'الاسم', 'Name'),
                        'street' => odooCopy56(context, 'العنوان', 'Street'),
                        'street2' => odooCopy56(
                          context,
                          'تفاصيل إضافية',
                          'Address line 2',
                        ),
                        'city' => odooCopy56(context, 'المدينة', 'City'),
                        'zip' => odooCopy56(
                          context,
                          'الرمز البريدي',
                          'Postcode',
                        ),
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
                                  'Enter a name.',
                                ),
                  ),
                ),
              if (widget.address.values['country_code']?.isNotEmpty == true)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(odooCopy56(context, 'الدولة', 'Country')),
                  subtitle: Text(widget.address.values['country_code']!),
                  trailing: const Icon(Icons.lock_outline),
                ),
              // The current server contract does not offer country/state options.
              // Existing IDs are preserved; new addresses inherit the primary
              // region. Never invent geography IDs or send human labels as IDs.
              if (widget.address.values['state_name']?.isNotEmpty == true)
                Text(widget.address.values['state_name']!),
              if (_error != null) Text(odooCustomerError56(context, _error!)),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('odoo-address-save'),
                onPressed: _busy ? null : _save,
                child: Text(
                  odooCopy56(
                    context,
                    _busy ? 'جاري الحفظ…' : 'حفظ',
                    _busy ? 'Saving…' : 'Save',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
