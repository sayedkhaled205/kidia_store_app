import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/core/theme/mobishop_colors.dart';
import 'package:mobishop_store_app/core/theme/mobishop_spacing.dart';
import 'package:mobishop_store_app/features/account/data/network/customer_account_api_transport.dart';
import 'package:mobishop_store_app/features/account/domain/entities/customer_account.dart';
import 'package:mobishop_store_app/features/account/domain/repositories/customer_account_repository.dart';
import 'package:mobishop_store_app/features/account/presentation/customer_phone_format.dart';
import 'package:mobishop_store_app/features/account/presentation/providers/customer_account_providers.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/cart/presentation/widgets/cart_icon_button.dart';

import 'profile_network_failure_stub.dart'
    if (dart.library.io) 'profile_network_failure_io.dart';

class CustomerProfileScreen extends ConsumerStatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  ConsumerState<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends ConsumerState<CustomerProfileScreen> {
  (int, String)? _scope;
  CustomerAccount? _verifiedAccount;
  CustomerAccount? _blockedAccount;
  CustomerAccount? _previousAccount;
  int _sessionGeneration = 0;
  AsyncValue<CustomerAccount> _account = const AsyncLoading();

  @override
  void initState() {
    super.initState();
    // Reopening the protected route can flush a retained session-dependent
    // repository. Subscribe outside build so that flush can safely schedule
    // the ancestor ProviderScope. Riverpod closes this listener on disposal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listenManual(customerAccountProvider, (previous, next) {
        if (!mounted) return;
        setState(() => _account = next);
      }, fireImmediately: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isArabic = _isArabic(context);
    final auth = ref.watch(authControllerProvider);
    final session = auth.value;
    final (int, String)? scope =
        !auth.hasError &&
            session != null &&
            !session.isExpired &&
            session.token.trim().isNotEmpty
        ? (session.user.id, session.token)
        : null;
    final AsyncValue<CustomerAccount> account = _account;
    final CustomerAccount? value = account.value;
    if (_scope != scope) {
      // A retained AsyncValue may still belong to the previous login, even
      // when the same customer signs in again with a different session.
      _blockedAccount = _verifiedAccount ?? _previousAccount;
      _verifiedAccount = null;
      _scope = scope;
      _sessionGeneration++;
    }
    final bool recoverable =
        account.hasError && _recoverableProfileRefresh(account.error!);
    if ((account.hasError && !recoverable) ||
        (value != null && scope != null && value.profile.id != scope.$1)) {
      _blockedAccount = value;
      _verifiedAccount = null;
    } else if (scope != null &&
        !account.isLoading &&
        !account.hasError &&
        value != null &&
        value.profile.id == scope.$1 &&
        !identical(value, _blockedAccount)) {
      _verifiedAccount = value;
      _blockedAccount = null;
    }
    _previousAccount = value;
    final CustomerAccount? displayed = scope == null ? null : _verifiedAccount;
    void retry() => ref.invalidate(customerAccountProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(isArabic ? 'بيانات حسابي' : 'My profile'),
        actions: <Widget>[
          CartIconButton(onPressed: () => context.push('/cart')),
        ],
      ),
      body: displayed != null
          ? _ProfileForm(
              // Keep the exact form mounted through background reads and network
              // failures; changing its parent topology would discard a dirty draft.
              key: ValueKey<(int, int)>((
                displayed.profile.id,
                _sessionGeneration,
              )),
              profile: displayed.profile,
              repository: ref.read(customerAccountRepositoryProvider),
              refreshFailed: recoverable,
              onRetry: retry,
              onSaved: (CustomerProfile saved) {
                ref
                    .read(authControllerProvider.notifier)
                    .updateUserFromServer(
                      AuthUser(
                        id: saved.id,
                        email: saved.email,
                        firstName: saved.firstName,
                        lastName: saved.lastName,
                        displayName: saved.displayName,
                      ),
                    );
                ref.invalidate(customerAccountProvider);
              },
            )
          : account.isLoading || (auth.isLoading && !auth.hasValue)
          ? const Center(
              child: CircularProgressIndicator(key: Key('profile-loading')),
            )
          : _ProfileLoadError(isArabic: isArabic, onRetry: retry),
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({
    required this.profile,
    required this.repository,
    required this.onSaved,
    required this.refreshFailed,
    required this.onRetry,
    super.key,
  });

  final CustomerProfile profile;
  final CustomerAccountRepository repository;
  final ValueChanged<CustomerProfile> onSaved;
  final bool refreshFailed;
  final VoidCallback onRetry;

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
  bool _saving = false;
  String? _error;
  late CustomerProfile _displayedProfile;

  @override
  void initState() {
    super.initState();
    _displayedProfile = widget.profile;
    _firstName = TextEditingController(text: widget.profile.firstName);
    _lastName = TextEditingController(text: widget.profile.lastName);
    _displayName = TextEditingController(text: widget.profile.displayName);
    _email = TextEditingController(text: widget.profile.email);
    _phone = TextEditingController(
      text: localEgyptianPhoneNumber(widget.profile.phone),
    );
  }

  @override
  void didUpdateWidget(covariant _ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_saving || _hasUnsavedChanges) return;
    _displayProfile(widget.profile);
  }

  bool get _hasUnsavedChanges =>
      _firstName.text != _displayedProfile.firstName ||
      _lastName.text != _displayedProfile.lastName ||
      _displayName.text != _displayedProfile.displayName ||
      _email.text != _displayedProfile.email;

  void _displayProfile(CustomerProfile profile) {
    _displayedProfile = profile;
    _firstName.text = profile.firstName;
    _lastName.text = profile.lastName;
    _displayName.text = profile.displayName;
    _email.text = profile.email;
    _phone.text = localEgyptianPhoneNumber(profile.phone);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _displayName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isArabic = _isArabic(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MobiShopSpacing.md),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.refreshFailed) ...<Widget>[
              Material(
                key: const Key('profile-refresh-warning'),
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.cloud_off_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isArabic
                              ? 'تعذر تحديث البيانات. تغييراتك المكتوبة محفوظة هنا.'
                              : 'Could not refresh. Your unsaved changes are kept here.',
                        ),
                      ),
                      TextButton(
                        key: const Key('profile-refresh-retry'),
                        onPressed: widget.onRetry,
                        child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: MobiShopSpacing.sm),
            ],
            const CircleAvatar(
              radius: 42,
              backgroundColor: MobiShopColors.primaryLight,
              foregroundColor: MobiShopColors.primaryDark,
              child: Icon(Icons.person_rounded, size: 48),
            ),
            const SizedBox(height: MobiShopSpacing.lg),
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
            const SizedBox(height: MobiShopSpacing.sm),
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
            const SizedBox(height: MobiShopSpacing.sm),
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
            const SizedBox(height: MobiShopSpacing.sm),
            TextFormField(
              key: const Key('profile-phone'),
              controller: _phone,
              readOnly: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.telephoneNumber],
              decoration: InputDecoration(
                labelText: isArabic ? 'رقم هاتف الحساب' : 'Account phone',
                helperText: isArabic
                    ? 'رقم تسجيل الدخول ثابت ولا يتغير من بيانات الشحن.'
                    : 'Your sign-in phone is separate from shipping details.',
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: MobiShopSpacing.sm),
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
              const SizedBox(height: MobiShopSpacing.md),
              Text(
                _error!,
                key: const Key('profile-save-error'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: MobiShopSpacing.lg),
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
        phone: widget.profile.phone,
        alternatePhone: widget.profile.alternatePhone,
      );
      if (!mounted) return;
      _displayProfile(saved);
      widget.onSaved(saved);
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
        padding: const EdgeInsets.all(MobiShopSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 52),
            const SizedBox(height: MobiShopSpacing.md),
            Text(
              isArabic
                  ? 'تعذر تحميل بيانات الحساب.'
                  : 'Could not load account details.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MobiShopSpacing.md),
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
    CustomerAccountFailureKind.conflict =>
      isArabic
          ? 'البريد الإلكتروني مستخدم في حساب آخر.'
          : 'That email is already used by another account.',
    CustomerAccountFailureKind.invalidInput =>
      isArabic
          ? 'راجع البيانات المكتوبة وحاول مرة أخرى.'
          : 'Check the entered details and try again.',
    CustomerAccountFailureKind.unauthorized =>
      isArabic
          ? 'انتهت جلسة الحساب. سجّل الدخول من جديد.'
          : 'Your session expired. Sign in again.',
    _ =>
      isArabic
          ? 'تعذر حفظ بيانات الحساب. حاول مرة أخرى.'
          : 'Could not save account details. Try again.',
  };
}

bool _isArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

bool _recoverableProfileRefresh(Object error) {
  if (error is! CustomerAccountRepositoryException ||
      error.statusCode == 401 ||
      error.statusCode == 403) {
    return false;
  }
  if (error.kind == CustomerAccountFailureKind.connection ||
      error.kind == CustomerAccountFailureKind.timeout) {
    return true;
  }
  if (error.kind == CustomerAccountFailureKind.server) {
    return error.statusCode == null || error.statusCode! >= 500;
  }
  // Dio can label a socket/header interruption as "unknown". Only an
  // evidenced network cause qualifies; malformed data/certificates do not.
  if (error.kind != CustomerAccountFailureKind.unknown) return false;
  final Object? cause = error.cause;
  final Object? networkCause = cause is CustomerAccountTransportException
      ? cause.cause
      : cause;
  return networkCause is DioException &&
      networkCause.response == null &&
      networkCause.type == DioExceptionType.unknown &&
      isRecoverableProfileNetworkCause(networkCause.error);
}
