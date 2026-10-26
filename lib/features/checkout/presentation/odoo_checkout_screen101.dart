import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/odoo_customer_providers51.dart';
import '../../cart/data/odoo/odoo_cart85.dart';
import '../../cart/presentation/providers/cart_state_providers.dart';
import '../data/odoo/odoo_checkout101.dart';
import '../domain/entities/checkout_presentation.dart';
import 'checkout_presentation_provider.dart';

final odooCheckout101Provider = FutureProvider.autoDispose<OdooCheckoutApi101>((
  ref,
) async {
  await ref.watch(odooCustomerSession51Provider.future);
  if (!ref.mounted) throw StateError('Checkout closed');
  final client = ref.watch(odooCustomerClient51Provider);
  final epoch = client.sessionEpoch85;
  final uid = client.customer?.id;
  return OdooCheckout101(
    client,
    isCurrent: () {
      if (!ref.mounted ||
          client.sessionEpoch85 != epoch ||
          client.customer?.id != uid) {
        return false;
      }
      final session = ref.read(odooCustomerSession51Provider);
      return !session.isLoading &&
          !session.hasError &&
          session.asData?.value.customer?.id == uid;
    },
  );
}, retry: (count, error) => null);

class OdooCheckoutScreen101 extends ConsumerWidget {
  const OdooCheckoutScreen101({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkout = ref.watch(odooCheckout101Provider);
    return checkout.when(
      skipLoadingOnReload: false,
      skipLoadingOnRefresh: false,
      data: (api) => OdooCheckoutForm101(
        key: ObjectKey(api),
        api: api,
        design:
            ref.watch(checkoutPresentationProvider).value?.design ??
            CheckoutDesign.classic,
        onCartChanged: () => ref.invalidate(cartControllerProvider),
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, stack) => Scaffold(
        appBar: AppBar(title: Text(_label(context, 'إتمام الطلب', 'Checkout'))),
        body: Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(odooCheckout101Provider),
            child: Text(_label(context, 'إعادة المحاولة', 'Retry')),
          ),
        ),
      ),
    );
  }
}

String _label(BuildContext context, String ar, String en) =>
    Directionality.of(context) == TextDirection.rtl ? ar : en;

/// Only native widgets. No HTML, URL launcher, payment claim or order creation.
class OdooCheckoutForm101 extends StatefulWidget {
  const OdooCheckoutForm101({
    super.key,
    required this.api,
    this.onCartChanged,
    this.design = CheckoutDesign.classic,
  });
  final OdooCheckoutApi101 api;
  final VoidCallback? onCartChanged;
  final CheckoutDesign design;
  @override
  State<OdooCheckoutForm101> createState() => _OdooCheckoutForm101State();
}

class _OdooCheckoutForm101State extends State<OdooCheckoutForm101> {
  final _formKey = GlobalKey<FormState>();
  OdooAddressForm101? _form;
  OdooShipping101? _shipping;
  Map<String, String> _draft = {};
  bool _busy = true, _sameAddress = true, _failed = false;
  int _generation = 0, _fieldsGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OdooCheckoutForm101 old) {
    super.didUpdateWidget(old);
    if (!identical(old.api, widget.api)) {
      _form = null;
      _shipping = null;
      _draft = {};
      _sameAddress = true;
      _load();
    }
  }

  Future<void> _load({
    String type = 'billing',
    int? countryId,
    bool preserve = false,
  }) async {
    final ticket = ++_generation;
    final previous = preserve
        ? Map<String, String>.from(_draft)
        : <String, String>{};
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final form = await widget.api.form(type: type, countryId: countryId);
      if (!mounted || ticket != _generation) return;
      setState(() {
        _form = form;
        _shipping = null;
        _fieldsGeneration++;
        _draft = {for (final field in form.fields) field.name: field.value};
        for (final field in form.fields) {
          final saved = previous[field.name];
          if (!field.readonly &&
              saved != null &&
              field.name != 'country_id' &&
              field.name != 'state_id') {
            _draft[field.name] = saved;
          }
        }
        if (!preserve && type == 'billing') {
          _sameAddress = form.useSameAddress;
        }
        if (!form.separateShippingAllowed) _sameAddress = true;
      });
    } catch (_) {
      if (mounted && ticket == _generation) {
        setState(() {
          _failed = true;
          // A rejected country must not remain selected visually while the
          // retained draft still belongs to the previous country.
          _fieldsGeneration++;
        });
      }
    } finally {
      if (mounted && ticket == _generation) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_busy || _form == null || !_formKey.currentState!.validate()) return;
    final ticket = ++_generation;
    final form = _form!;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final shipping = await widget.api.save(
        type: form.addressType,
        fields: Map<String, String>.from(_draft),
        useForShipping: form.addressType == 'billing' && _sameAddress,
      );
      if (!mounted || ticket != _generation) return;
      widget.onCartChanged?.call();
      if (form.addressType == 'billing' && !_sameAddress) {
        await _load(type: 'delivery');
      } else {
        setState(() {
          _shipping = shipping;
        });
      }
    } catch (_) {
      if (mounted && ticket == _generation) {
        setState(() {
          _failed = true;
        });
      }
    } finally {
      if (mounted && ticket == _generation) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _select(int id) async {
    if (_busy || _shipping == null) return;
    final ticket = ++_generation;
    final revision = _shipping!.cart.revision;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final shipping = await widget.api.select(id, revision);
      if (!mounted || ticket != _generation) return;
      setState(() {
        _shipping = shipping;
      });
      widget.onCartChanged?.call();
    } catch (_) {
      // A rejected quote must not leave an old selected rate or total usable.
      if (!mounted || ticket != _generation) return;
      setState(() {
        _shipping = null;
        _failed = true;
      });
    } finally {
      if (mounted && ticket == _generation) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _money(String minor, OdooCart85 cart) {
    final digits = cart.cart.totals.currency.minorUnit;
    final padded = minor.padLeft(digits + 1, '0');
    final number = digits == 0
        ? padded
        : '${padded.substring(0, padded.length - digits)}.${padded.substring(padded.length - digits)}';
    return '${cart.cart.totals.currency.code} $number';
  }

  Widget _field(OdooAddressField101 field) {
    final value = _draft[field.name] ?? '';
    String? validate(String? value) =>
        field.required && (value == null || value.trim().isEmpty)
        ? _label(context, 'هذا الحقل مطلوب', 'This field is required')
        : null;
    final decoration = InputDecoration(
      labelText: field.label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      isDense: widget.design == CheckoutDesign.compact,
    );
    final key = ValueKey('address-$_fieldsGeneration-${field.name}');
    if (field.kind == 'select') {
      return DropdownButtonFormField<String>(
        key: key,
        initialValue: field.choices.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: decoration,
        validator: validate,
        items: field.choices.entries
            .map((v) => DropdownMenuItem(value: v.key, child: Text(v.value)))
            .toList(),
        onChanged: _busy || field.readonly
            ? null
            : (selected) {
                if (field.name == 'country_id') {
                  _load(
                    type: _form!.addressType,
                    countryId: int.tryParse(selected ?? ''),
                    preserve: true,
                  );
                } else {
                  setState(() {
                    _draft[field.name] = selected ?? '';
                  });
                }
              },
      );
    }
    return TextFormField(
      key: key,
      initialValue: value,
      decoration: decoration,
      readOnly: field.readonly,
      enabled: !_busy,
      keyboardType: field.kind == 'email'
          ? TextInputType.emailAddress
          : field.kind == 'tel'
          ? TextInputType.phone
          : TextInputType.text,
      validator: validate,
      onChanged: (text) => _draft[field.name] = text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = _form;
    final shipping = _shipping;
    return Scaffold(
      key: const Key('odoo-native-checkout'),
      appBar: AppBar(title: Text(_label(context, 'إتمام الطلب', 'Checkout'))),
      body: ListView(
        padding: EdgeInsets.all(
          widget.design == CheckoutDesign.compact ? 12 : 16,
        ),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (form != null && shipping == null) ...[
            Text(
              _label(
                context,
                form.addressType == 'billing'
                    ? 'بيانات الفاتورة'
                    : 'عنوان الشحن',
                form.addressType == 'billing'
                    ? 'Billing address'
                    : 'Shipping address',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  for (final field in form.fields)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: widget.design == CheckoutDesign.compact
                            ? 8
                            : 12,
                      ),
                      child: _field(field),
                    ),
                ],
              ),
            ),
            if (form.addressType == 'billing' && form.separateShippingAllowed)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _label(
                    context,
                    'استخدام نفس العنوان للشحن',
                    'Use this address for shipping',
                  ),
                ),
                value: _sameAddress,
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _sameAddress = v;
                      }),
              ),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_label(context, 'حفظ ومتابعة', 'Save and continue')),
            ),
          ],
          if (shipping != null) ...[
            if (widget.design == CheckoutDesign.summaryFirst) _total(shipping),
            TextButton(
              onPressed: _busy ? null : () => _load(),
              child: Text(_label(context, 'تعديل العنوان', 'Edit address')),
            ),
            if (shipping.cart.cart.needsShipping) ...[
              Text(
                _label(context, 'طريقة الشحن', 'Shipping method'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (shipping.rates.isEmpty)
                Text(
                  _label(
                    context,
                    'لا توجد طريقة شحن متاحة لهذا العنوان.',
                    'No shipping method is available for this address.',
                  ),
                ),
              for (final rate in shipping.rates)
                ListTile(
                  key: ValueKey('carrier-${rate.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    rate.selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(rate.name),
                  trailing: Text(_money(rate.amount, shipping.cart)),
                  onTap: _busy ? null : () => _select(rate.id),
                ),
            ],
            const Divider(),
            if (widget.design != CheckoutDesign.summaryFirst) _total(shipping),
            // Payment is deliberately unavailable until the merchant payment
            // adapter has passed verification. Never submit a website handoff.
            Text(
              _label(
                context,
                'إتمام الدفع غير متاح في التطبيق لهذا المتجر حاليًا. لم يتم إنشاء طلب.',
                'Payment is currently unavailable in the app for this store. No order has been placed.',
              ),
            ),
          ],
          if (_failed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _label(
                  context,
                  'تعذر تحديث بيانات الطلب. راجع البيانات وحاول مرة أخرى.',
                  'Unable to update checkout. Review your details and retry.',
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_failed && form == null)
            TextButton(
              onPressed: _busy ? null : () => _load(),
              child: Text(_label(context, 'إعادة المحاولة', 'Retry')),
            ),
        ],
      ),
    );
  }

  Widget _total(OdooShipping101 shipping) => ListTile(
    title: Text(_label(context, 'الإجمالي', 'Total')),
    trailing: Text(
      _money(shipping.cart.cart.totals.priceMinor, shipping.cart),
      key: const Key('checkout-total'),
    ),
  );
}
