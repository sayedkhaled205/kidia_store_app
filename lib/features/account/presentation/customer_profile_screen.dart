import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/core/theme/kidia_colors.dart';
import 'package:kidia_store_app/core/theme/kidia_spacing.dart';
import 'package:kidia_store_app/features/account/domain/entities/customer_account.dart';
import 'package:kidia_store_app/features/account/domain/repositories/customer_account_repository.dart';
import 'package:kidia_store_app/features/account/presentation/customer_phone_format.dart';
import 'package:kidia_store_app/features/account/presentation/providers/customer_account_providers.dart';
import 'package:kidia_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kidia_store_app/features/cart/presentation/widgets/cart_icon_button.dart';

class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isArabic = _isArabic(context);
    final AsyncValue<CustomerAccount> account = ref.watch(
      customerAccountProvider,
    );
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(isArabic ? 'بيانات حسابي' : 'My profile'),
        actions: <Widget>[
          CartIconButton(onPressed: () => context.push('/cart')),
        ],
      ),
      body: account.when(
        loading: () => const Center(
          child: CircularProgressIndicator(key: Key('profile-loading')),
        ),
        error: (Object error, StackTrace stackTrace) => _ProfileLoadError(
          isArabic: isArabic,
          onRetry: () => ref.invalidate(customerAccountProvider),
        ),
        data: (CustomerAccount value) => _ProfileForm(
          key: ValueKey<String>(value.profile.email),
          profile: value.profile,
          repository: ref.read(customerAccountRepositoryProvider),
          onSaved: () {
            ref.invalidate(customerAccountProvider);
            ref.invalidate(authControllerProvider);
          },
        ),
      ),
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({
    required this.profile,
    required this.repository,
    required this.onSaved,
    super.key,
  });

  final CustomerProfile profile;
  final CustomerAccountRepository repository;
  final VoidCallback onSaved;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _displayName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _alternatePhone;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.profile.firstName);
    _lastName = TextEditingController(text: widget.profile.lastName);
    _displayName = TextEditingController(text: widget.profile.displayName);
    _email = TextEditingController(text: widget.profile.email);
    _phone = TextEditingController(
      text: localEgyptianPhoneNumber(widget.profile.phone),
    );
    _alternatePhone = TextEditingController(
      text: localEgyptianPhoneNumber(widget.profile.alternatePhone),
    );
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _displayName.dispose();
    _email.dispose();
    _phone.dispose();
    _alternatePhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isArabic = _isArabic(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KidiaSpacing.md),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const CircleAvatar(
              radius: 42,
              backgroundColor: KidiaColors.primaryLight,
              foregroundColor: KidiaColors.primaryDark,
              child: Icon(Icons.person_rounded, size: 48),
            ),
            const SizedBox(height: KidiaSpacing.lg),
            TextFormField(
              key: const Key('profile-first-name'),
              controller: _firstName,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: isArabic ? 'الاسم الأول' : 'First name',
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: KidiaSpacing.sm),
            TextFormField(
              key: const Key('profile-last-name'),
              controller: _lastName,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: isArabic ? 'اسم العائلة' : 'Last name',
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: KidiaSpacing.sm),
            TextFormField(
              key: const Key('profile-display-name'),
              controller: _displayName,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              validator: (String? value) => (value?.trim().isEmpty ?? true)
                  ? isArabic
                        ? 'اسم العرض مطلوب'
                        : 'Display name is required'
                  : null,
              decoration: InputDecoration(
                labelText: isArabic ? 'اسم العرض' : 'Display name',
                helperText: isArabic
                    ? 'الاسم الذي يظهر داخل حسابك.'
                    : 'The name shown in your account.',
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: KidiaSpacing.sm),
            TextFormField(
              key: const Key('profile-phone'),
              controller: _phone,
              enabled: !_saving,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.telephoneNumber],
              validator: (String? value) => _phoneValidation(
                value,
                isArabic: isArabic,
                isRequired: true,
              ),
              decoration: InputDecoration(
                labelText: isArabic ? 'رقم الهاتف' : 'Phone number',
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: KidiaSpacing.sm),
            TextFormField(
              key: const Key('profile-alternate-phone'),
              controller: _alternatePhone,
              enabled: !_saving,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (String? value) => _phoneValidation(
                value,
                isArabic: isArabic,
              ),
              decoration: InputDecoration(
                labelText: isArabic
                    ? 'رقم الهاتف الاحتياطي'
                    : 'Alternate phone number',
                prefixIcon: const Icon(Icons.phone_in_talk_outlined),
              ),
            ),
            const SizedBox(height: KidiaSpacing.sm),
            TextFormField(
              key: const Key('profile-email'),
              controller: _email,
              enabled: !_saving,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.email],
              validator: (String? value) {
                final String email = value?.trim() ?? '';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return isArabic
                      ? 'أدخل بريدًا إلكترونيًا صحيحًا'
                      : 'Enter a valid email';
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: isArabic ? 'البريد الإلكتروني' : 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: KidiaSpacing.md),
              Text(
                _error!,
                key: const Key('profile-save-error'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: KidiaSpacing.lg),
            FilledButton.icon(
              key: const Key('save-customer-profile'),
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
                    ? 'حفظ التغييرات'
                    : 'Save changes',
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
      final CustomerProfile saved = await widget.repository.updateProfile(
        firstName: _firstName.text,
        lastName: _lastName.text,
        displayName: _displayName.text,
        email: _email.text,
        phone: _phone.text,
        alternatePhone: _alternatePhone.text,
      );
      _firstName.text = saved.firstName;
      _lastName.text = saved.lastName;
      _displayName.text = saved.displayName;
      _email.text = saved.email;
      _phone.text = localEgyptianPhoneNumber(saved.phone);
      _alternatePhone.text = localEgyptianPhoneNumber(saved.alternatePhone);
      widget.onSaved();
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _isArabic(context)
                  ? 'تم تحديث بيانات الحساب.'
                  : 'Account details updated.',
            ),
          ),
        );
    } on CustomerAccountRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _profileError(error, _isArabic(context));
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _isArabic(context)
              ? 'تعذر حفظ بيانات الحساب. حاول مرة أخرى.'
              : 'Could not save account details. Try again.';
        });
      }
    }
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.isArabic, required this.onRetry});

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
                  ? 'تعذر تحميل بيانات الحساب.'
                  : 'Could not load account details.',
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

String _profileError(CustomerAccountRepositoryException error, bool isArabic) {
  return switch (error.kind) {
    CustomerAccountFailureKind.conflict => isArabic
        ? 'البريد الإلكتروني مستخدم في حساب آخر.'
        : 'That email is already used by another account.',
    CustomerAccountFailureKind.invalidInput => isArabic
        ? 'راجع البيانات المكتوبة وحاول مرة أخرى.'
        : 'Check the entered details and try again.',
    CustomerAccountFailureKind.unauthorized => isArabic
        ? 'انتهت جلسة الحساب. سجّل الدخول من جديد.'
        : 'Your session expired. Sign in again.',
    _ => isArabic
        ? 'تعذر حفظ بيانات الحساب. حاول مرة أخرى.'
        : 'Could not save account details. Try again.',
  };
}

bool _isArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

String? _phoneValidation(
  String? value, {
  required bool isArabic,
  bool isRequired = false,
}) {
  final String phone = value?.trim() ?? '';
  if (phone.isEmpty) {
    if (!isRequired) {
      return null;
    }
    return isArabic ? 'رقم الهاتف مطلوب' : 'Phone number is required';
  }
  final String digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8 || digits.length > 15) {
    return isArabic ? 'أدخل رقم هاتف صحيحًا' : 'Enter a valid phone number';
  }
  return null;
}
