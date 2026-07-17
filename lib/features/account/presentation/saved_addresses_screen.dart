import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/core/theme/kidia_colors.dart';
import 'package:kidia_store_app/core/theme/kidia_radius.dart';
import 'package:kidia_store_app/core/theme/kidia_spacing.dart';
import 'package:kidia_store_app/features/account/domain/entities/customer_account.dart';
import 'package:kidia_store_app/features/account/domain/repositories/customer_account_repository.dart';
import 'package:kidia_store_app/features/account/presentation/customer_phone_format.dart';
import 'package:kidia_store_app/features/account/presentation/providers/customer_account_providers.dart';
import 'package:kidia_store_app/features/cart/presentation/widgets/cart_icon_button.dart';

class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isArabic = _isArabic(context);
    final AsyncValue<CustomerAccount> account = ref.watch(
      customerAccountProvider,
    );
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(isArabic ? 'العناوين المحفوظة' : 'Saved addresses'),
        actions: <Widget>[
          CartIconButton(onPressed: () => context.push('/cart')),
        ],
      ),
      body: account.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            key: Key('saved-addresses-loading'),
          ),
        ),
        error: (Object error, StackTrace stackTrace) => _AccountPageError(
          message: _errorMessage(error, isArabic),
          retryLabel: isArabic ? 'إعادة المحاولة' : 'Try again',
          onRetry: () => ref.invalidate(customerAccountProvider),
        ),
        data: (CustomerAccount value) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(customerAccountProvider);
            await ref.read(customerAccountProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(KidiaSpacing.md),
            children: <Widget>[
              _AddressCard(
                key: const Key('shipping-address-card'),
                icon: Icons.local_shipping_outlined,
                title: isArabic ? 'عنوان الشحن' : 'Shipping address',
                address: value.billing,
                emptyText: isArabic
                    ? 'لم يتم حفظ عنوان شحن بعد.'
                    : 'No shipping address has been saved yet.',
                editLabel: value.billing.isEmpty
                    ? isArabic
                          ? 'إضافة عنوان'
                          : 'Add address'
                    : isArabic
                    ? 'تعديل'
                    : 'Edit',
                onEdit: () => _editAddress(
                  context,
                  ref,
                  account: value,
                  type: CustomerAddressType.billing,
                  editorTitle: isArabic ? 'عنوان الشحن' : 'Shipping address',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editAddress(
    BuildContext context,
    WidgetRef ref, {
    required CustomerAccount account,
    required CustomerAddressType type,
    required String editorTitle,
  }) async {
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => _AddressEditor(
        title: editorTitle,
        address: account.address(type),
        fields: account.fieldsFor(type),
        repository: ref.read(customerAccountRepositoryProvider),
      ),
    );
    if (saved != true || !context.mounted) {
      return;
    }
    ref.invalidate(customerAccountProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _isArabic(context)
                ? 'تم حفظ العنوان بنجاح.'
                : 'Address saved successfully.',
          ),
        ),
      );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.icon,
    required this.title,
    required this.address,
    required this.emptyText,
    required this.editLabel,
    required this.onEdit,
    super.key,
  });

  final IconData icon;
  final String title;
  final CustomerAddress address;
  final String emptyText;
  final String editLabel;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final List<String> lines = _addressLines(address);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(KidiaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: KidiaColors.primaryLight,
                    borderRadius: BorderRadius.circular(KidiaRadius.sm),
                  ),
                  child: Icon(icon, color: KidiaColors.primaryDark),
                ),
                const SizedBox(width: KidiaSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KidiaSpacing.md),
            if (lines.isEmpty)
              Text(
                emptyText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KidiaColors.textSecondary,
                ),
              )
            else
              for (final String line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line),
                ),
            const SizedBox(height: KidiaSpacing.md),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: Text(editLabel),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _addressLines(CustomerAddress address) {
    String value(String suffix) => address.valueFor(
      '${address.type == CustomerAddressType.billing ? 'billing' : 'shipping'}_$suffix',
    );
    final String name = <String>[
      value('first_name'),
      value('last_name'),
    ].where((String part) => part.isNotEmpty).join(' ');
    final String area = <String>[
      value('city'),
      value('state'),
    ].where((String part) => part.isNotEmpty).join('، ');
    return <String>[
      name,
      value('company'),
      value('address_1'),
      value('address_2'),
      area,
      localEgyptianPhoneNumber(value('phone')),
      value('email'),
    ].where((String line) => line.isNotEmpty).toList(growable: false);
  }
}

class _AddressEditor extends StatefulWidget {
  const _AddressEditor({
    required this.title,
    required this.address,
    required this.fields,
    required this.repository,
  });

  final String title;
  final CustomerAddress address;
  final List<CustomerAddressField> fields;
  final CustomerAccountRepository repository;

  @override
  State<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<_AddressEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final Map<String, String> _values;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _values = <String, String>{...widget.address.values};
    for (final String key in _values.keys.toList(growable: false)) {
      if (key.endsWith('_phone')) {
        _values[key] = localEgyptianPhoneNumber(_values[key] ?? '');
      }
    }
    for (final CustomerAddressField field in widget.fields) {
      if ((_values[field.key]?.trim() ?? '').isEmpty &&
          field.defaultValue.trim().isNotEmpty) {
        _values[field.key] = field.defaultValue.trim();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isArabic = _isArabic(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (BuildContext context, ScrollController controller) => Form(
        key: _formKey,
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            KidiaSpacing.md,
            KidiaSpacing.md,
            KidiaSpacing.md,
            MediaQuery.viewInsetsOf(context).bottom + KidiaSpacing.lg,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('close-address-editor'),
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: KidiaSpacing.md),
            for (final CustomerAddressField field in widget.fields)
              if (field.isVisible) ...<Widget>[
                _AddressField(
                  field: field,
                  initialValue: _values[field.key] ?? '',
                  enabled: !_saving,
                  onChanged: (String value) => _values[field.key] = value,
                ),
                const SizedBox(height: KidiaSpacing.sm),
              ],
            if (_error != null) ...<Widget>[
              Text(
                _error!,
                key: const Key('address-save-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: KidiaSpacing.sm),
            ],
            FilledButton.icon(
              key: const Key('save-customer-address'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _saving
                    ? isArabic
                          ? 'جارٍ الحفظ...'
                          : 'Saving...'
                    : isArabic
                    ? 'حفظ العنوان'
                    : 'Save address',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updateAddress(
        CustomerAddress(type: widget.address.type, values: _values),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on CustomerAccountRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _errorMessage(error, _isArabic(context));
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _isArabic(context)
              ? 'تعذر حفظ العنوان. حاول مرة أخرى.'
              : 'Could not save the address. Try again.';
        });
      }
    }
  }
}

class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.field,
    required this.initialValue,
    required this.enabled,
    required this.onChanged,
  });

  final CustomerAddressField field;
  final String initialValue;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isArabic = _isArabic(context);
    String? validator(String? value) {
      final String text = value?.trim() ?? '';
      if (field.required && text.isEmpty) {
        return isArabic ? 'هذا الحقل مطلوب' : 'This field is required';
      }
      if (field.type == CustomerAddressFieldType.email &&
          text.isNotEmpty &&
          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
        return isArabic ? 'أدخل بريدًا إلكترونيًا صحيحًا' : 'Enter a valid email';
      }
      return null;
    }

    if (field.type == CustomerAddressFieldType.select &&
        field.options.isNotEmpty) {
      final String? value = field.options.containsKey(initialValue)
          ? initialValue
          : null;
      return DropdownButtonFormField<String>(
        key: Key('customer-address-${field.key}'),
        initialValue: value,
        items: field.options.entries
            .map(
              (MapEntry<String, String> entry) => DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(growable: false),
        onChanged: enabled
            ? (String? selected) => onChanged(selected ?? '')
            : null,
        validator: validator,
        decoration: InputDecoration(labelText: field.label),
      );
    }
    return TextFormField(
      key: Key('customer-address-${field.key}'),
      initialValue: initialValue,
      enabled: enabled,
      minLines: field.type == CustomerAddressFieldType.textarea ? 3 : 1,
      maxLines: field.type == CustomerAddressFieldType.textarea ? 5 : 1,
      keyboardType: switch (field.type) {
        CustomerAddressFieldType.email => TextInputType.emailAddress,
        CustomerAddressFieldType.telephone => TextInputType.phone,
        _ => TextInputType.text,
      },
      autofillHints: field.autocomplete.isEmpty
          ? null
          : <String>[field.autocomplete],
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.placeholder.isEmpty ? null : field.placeholder,
      ),
    );
  }
}

class _AccountPageError extends StatelessWidget {
  const _AccountPageError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: KidiaSpacing.md),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

String _errorMessage(Object error, bool isArabic) {
  if (error is CustomerAccountRepositoryException) {
    return switch (error.kind) {
      CustomerAccountFailureKind.unauthorized => isArabic
          ? 'انتهت جلسة الحساب. سجّل الدخول من جديد.'
          : 'Your session expired. Sign in again.',
      CustomerAccountFailureKind.connection ||
      CustomerAccountFailureKind.timeout => isArabic
          ? 'تعذر الاتصال بالمتجر. تحقق من الإنترنت وحاول مرة أخرى.'
          : 'Could not reach the store. Check your connection and try again.',
      _ => isArabic
          ? 'تعذر تحميل بيانات الحساب. حاول مرة أخرى.'
          : 'Could not load account data. Try again.',
    };
  }
  return isArabic
      ? 'تعذر تحميل بيانات الحساب. حاول مرة أخرى.'
      : 'Could not load account data. Try again.';
}
