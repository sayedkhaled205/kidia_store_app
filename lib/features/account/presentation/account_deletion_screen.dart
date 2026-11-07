import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../auth/presentation/providers/native_auth_providers.dart';
import '../../auth/data/native_auth_sdk.dart';
import '../application/account_identity_deletion.dart';
import '../data/network/customer_account_api_transport.dart';
import '../data/storage/account_deletion_receipt_store.dart';
import 'providers/customer_account_providers.dart';

final accountDeletionAppleSdkProvider =
    Provider.autoDispose<NativeAppleDeletionSdk>((ref) {
      final sdk = FirebaseNativeAuthSdk();
      ref.onDispose(() => unawaited(sdk.cancel()));
      return sdk;
    });

final accountDeletionTransportProvider =
    Provider<CustomerAccountDeletionTransport>((ref) {
      final transport = ref.watch(customerAccountApiTransportProvider);
      if (transport is! CustomerAccountDeletionTransport) {
        throw StateError('Account deletion is unavailable.');
      }
      return transport as CustomerAccountDeletionTransport;
    });

final accountDeletionAvailabilityProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final response = await ref
      .watch(accountDeletionTransportProvider)
      .deletionAvailability();
  return response['available'] == true;
});

final accountDeletionReceiptStoreProvider =
    Provider<AccountDeletionReceiptStore>(
      (ref) => AccountDeletionReceiptStore(AppConfig.apiBaseUrl),
    );
final accountDeletionReceiptProvider =
    FutureProvider.autoDispose<AccountDeletionReceipt?>(
      (ref) => ref.watch(accountDeletionReceiptStoreProvider).read(),
    );

/// Capturing the account ID prevents reauthentication from changing the target.
class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({this.userId, super.key});
  final int? userId;

  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  bool _confirmed = false;
  bool _busy = false;
  bool _pending = false;
  bool _completed = false;
  bool _restoring = true;
  bool _reauth = false;
  bool _unconfirmedReceipt = false;
  bool _preparedReceipt = false;
  late final String _storeScope;
  String? _error;
  String? _deletedToken;
  AccountDeletionReceipt? _receipt;
  AppleDeletionCheckpoint? _appleCheckpoint;
  int? get _targetUserId => widget.userId ?? _receipt?.userId;
  bool get _sameMerchant => AppConfig.apiBaseUrl == _storeScope;
  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';
  String _text(String ar, String en) => _ar ? ar : en;

  @override
  void initState() {
    super.initState();
    _storeScope = AppConfig.apiBaseUrl;
    Future.microtask(_restoreReceipt);
  }

  Future<void> _restoreReceipt() async {
    try {
      final saved = await ref.read(accountDeletionReceiptStoreProvider).read();
      if (!mounted || !_sameMerchant) return;
      if (saved != null &&
          (widget.userId == null || saved.userId == widget.userId)) {
        _receipt = saved;
        await _recoverAccepted();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _text(
            'تعذر قراءة حالة الحذف. حاول مرة أخرى.',
            'Could not read the deletion status. Please retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<bool> _recoverAccepted() async {
    final receipt = _receipt;
    if (receipt == null || !_sameMerchant) return false;
    final response = await ref
        .read(accountDeletionTransportProvider)
        .deletionStatus(receipt.receipt);
    final status = response['status'];
    if (mounted &&
        _sameMerchant &&
        (status == 'unknown' || status == 'prepared')) {
      setState(() {
        _unconfirmedReceipt =
            status == 'unknown' &&
            _appleCheckpoint == null &&
            receipt.appleCheckpoint == null;
        _preparedReceipt = status == 'prepared';
      });
    }
    if (status != 'pending' && status != 'completed') return false;
    if (!mounted || !_sameMerchant) return true;
    setState(() {
      _pending = true;
      _completed = status == 'completed';
      _unconfirmedReceipt = false;
      _preparedReceipt = false;
      _error = null;
    });
    final current = ref.read(authControllerProvider).value;
    // A receipt may outlive the original session; never sign out its replacement.
    if (current != null &&
        current.user.id == receipt.userId &&
        receipt.matchesSession(current.token)) {
      _deletedToken = current.token;
      await ref
          .read(authControllerProvider.notifier)
          .completeAccountDeletion(current.token);
    }
    return true;
  }

  Future<void> _checkStatus() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _recoverAccepted() && mounted && !_preparedReceipt) {
        setState(
          () => _error = _text(
            'لم يتم تأكيد طلب الحذف. لو انتهت الجلسة، سجّل الدخول مرة أخرى ثم أعد الطلب.',
            'Deletion is not confirmed. If your session expired, sign in again and retry the request.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _text(
            'تعذر تحديث الحالة. حاول مرة أخرى.',
            'Could not refresh status. Please retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final session = ref.read(authControllerProvider).value;
    if (_busy ||
        _restoring ||
        !_confirmed ||
        !_sameMerchant ||
        session == null ||
        session.isExpired ||
        session.user.id != _targetUserId) {
      return;
    }
    final token = session.token;
    bool isCurrentAccount() {
      if (!mounted || !_sameMerchant) return false;
      final current = ref.read(authControllerProvider).value;
      return current?.user.id == session.user.id &&
          current?.token == token &&
          current?.isExpired == false;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receiptStore = ref.read(accountDeletionReceiptStoreProvider);
      _receipt = await receiptStore.prepare(session.user.id, token);
      if (!isCurrentAccount()) {
        throw StateError('The account changed before confirmation');
      }
      ref.invalidate(accountDeletionReceiptProvider);
      final transport = ref.read(accountDeletionTransportProvider);
      if (transport is! CustomerAccountIdentityDeletionTransport) {
        throw StateError('Identity deletion is unavailable');
      }
      await requestAccountIdentityDeletion(
        transport: transport as CustomerAccountIdentityDeletionTransport,
        receipt: _receipt!.receipt,
        expectedSession: token,
        userId: session.user.id,
        appleSdk: ref.read(accountDeletionAppleSdkProvider),
        loadAppleConfig: () async {
          if (ref.read(nativeAuthConfigProvider).hasError) {
            ref.invalidate(nativeAuthConfigProvider);
          }
          final config = await ref.read(nativeAuthConfigProvider.future);
          if (!config.allows('apple')) {
            throw StateError('Apple sign-in is unavailable');
          }
          return {'firebase': config.firebase};
        },
        isApplePlatform: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
        isCurrentAccount: isCurrentAccount,
        appleCheckpoint: _appleCheckpoint ?? _receipt!.appleCheckpoint,
        persistAppleCheckpoint: (checkpoint) async {
          // Keep successful SDK evidence in memory if secure storage fails so
          // a same-screen retry first retries persistence, never Apple sign-in.
          _appleCheckpoint = checkpoint;
          // This only records success for the captured receipt. The store
          // rejects replacement receipts/sessions; the flow checks the current
          // account again before finalization or local sign-out.
          _receipt = await receiptStore.saveAppleCheckpoint(checkpoint);
          if (isCurrentAccount()) {
            ref.invalidate(accountDeletionReceiptProvider);
          }
        },
      );
      _deletedToken = token;
      if (mounted) {
        setState(() {
          _pending = true;
          _preparedReceipt = false;
          _unconfirmedReceipt = false;
        });
      }
      await ref
          .read(authControllerProvider.notifier)
          .completeAccountDeletion(token);
    } on AppleDeletionRequiresIos {
      if (mounted) {
        setState(() {
          _preparedReceipt = true;
          _error = _text(
            'الحساب مرتبط بأبل. أكمل حذف الحساب من تطبيق الآيفون، أو تواصل مع خدمة العملاء للمساعدة.',
            'This account is linked to Apple. Complete deletion in the iPhone app, or contact customer service for help.',
          );
        });
      }
    } on CustomerAccountTransportException catch (error) {
      try {
        if (await _recoverAccepted()) return;
      } catch (_) {
        /* Keep the receipt for a later status check. */
      }
      if (mounted) {
        setState(() {
          _reauth = error.code == 'mobishop_account_deletion_reauth';
          _error = _reauth
              ? _text(
                  'سجّل الدخول مرة أخرى لتأكيد إن الحساب حسابك، ثم أكّد الحذف.',
                  'Sign in again to confirm this is your account, then confirm deletion.',
                )
              : _text(
                  'تعذر تأكيد الطلب الآن. حاول مرة أخرى. لو اتقبل قبل انقطاع الاتصال، لن يتكرر الحذف.',
                  'We could not confirm the request. Please retry. An accepted request will not be duplicated.',
                );
        });
      }
    } catch (_) {
      try {
        if (await _recoverAccepted()) return;
      } catch (_) {
        /* Keep the receipt. A provider error cannot establish completion. */
      }
      if (mounted) {
        setState(
          () => _error = _text(
            'لم يتم تأكيد اكتمال الحذف. حدّث حالة الطلب قبل المحاولة مرة أخرى.',
            'Deletion completion is not confirmed. Check the request status before retrying.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInAgain() async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AuthScreen()));
    if (!mounted) return;
    ref.invalidate(accountDeletionAvailabilityProvider);
    setState(() {
      _reauth = false;
      _confirmed = false;
      _error = null;
    });
  }

  Future<void> _closePending() async {
    final token = _deletedToken;
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (token != null) {
        await ref
            .read(authControllerProvider.notifier)
            .completeAccountDeletion(token);
      }
      if (_completed && _receipt != null) {
        await ref
            .read(accountDeletionReceiptStoreProvider)
            .clear(_receipt!.receipt);
        ref.invalidate(accountDeletionReceiptProvider);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _text(
            'طلب الحذف اتسجل. تعذر مسح جلسة الجهاز؛ حاول مرة أخرى.',
            'Deletion is requested. Local sign-out could not finish; please retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismissUnconfirmed() async {
    if (_busy || !_unconfirmedReceipt || _receipt == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(accountDeletionReceiptStoreProvider)
          .clear(_receipt!.receipt);
      ref.invalidate(accountDeletionReceiptProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _text(
            'تعذر إغلاق المتابعة. حاول مرة أخرى.',
            'Could not dismiss status. Please retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep this screen's SDK alive across the confirmation awaits; disposal cancels it.
    ref.watch(accountDeletionAppleSdkProvider);
    final session = ref.watch(authControllerProvider).value;
    final sameAccount =
        _sameMerchant &&
        session != null &&
        !session.isExpired &&
        session.user.id == _targetUserId;
    final availability = !_pending && sameAccount
        ? ref.watch(accountDeletionAvailabilityProvider)
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(_text('حذف الحساب', 'Delete account'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              _completed
                  ? Icons.check_circle_outline
                  : _pending
                  ? Icons.hourglass_top
                  : Icons.person_remove_outlined,
              size: 48,
            ),
            const SizedBox(height: 20),
            Text(
              _completed
                  ? _text('تم حذف الحساب', 'Account deleted')
                  : _pending
                  ? _text(
                      'تم تسجيل طلب حذف حسابك',
                      'Account deletion requested',
                    )
                  : _text(
                      'هل تريد حذف حسابك نهائيًا؟',
                      'Permanently delete your account?',
                    ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              _completed
                  ? _text(
                      'اكتمل حذف الحساب والبيانات المرتبطة به. قد يحتفظ المتجر بسجلات الطلبات المطلوبة قانونًا.',
                      'Your account and associated data have been deleted. The store may retain legally required order records.',
                    )
                  : _pending
                  ? _text(
                      'تتم معالجة الحذف تلقائيًا. لن تتمكن من تسجيل الدخول بهذا الحساب أثناء الحذف. قد يحتفظ المتجر بسجلات الطلبات المطلوبة قانونًا.',
                      'Deletion is processed automatically. This account cannot sign in while deletion is in progress. The store may retain legally required order records.',
                    )
                  : _text(
                      'سيُحذف حسابك وبياناتك المرتبطة به، ولن تتمكن من استعادته. قد يحتفظ المتجر بسجلات الطلبات المطلوبة قانونًا. هذا لا يلغي الطلبات أو يطلب استرداد مبالغ.',
                      'Your account and its associated personal data will be removed and cannot be restored. The store may retain legally required order records. This does not cancel orders or request refunds.',
                    ),
            ),
            const SizedBox(height: 24),
            if (_preparedReceipt && !_pending) ...[
              Text(
                _text(
                  'طلبك محفوظ، لكن تنفيذ الحذف لم يتأكد بعد. أكّد الحذف لاستكماله، أو تواصل مع خدمة العملاء إذا تعذر التأكيد.',
                  'Your request is saved, but deletion is not confirmed. Confirm deletion to continue, or contact customer service if confirmation fails.',
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_unconfirmedReceipt && !_pending) ...[
              Text(
                _text(
                  'إخفاء المتابعة من الجهاز لا يلغي طلب حذف مقبول.',
                  'Dismissing this status does not cancel an accepted deletion request.',
                ),
              ),
              TextButton(
                key: const Key('dismiss-deletion-status'),
                onPressed: _busy ? null : _dismissUnconfirmed,
                child: Text(_text('إغلاق المتابعة', 'Dismiss status')),
              ),
            ],
            if (_restoring)
              const Center(child: CircularProgressIndicator())
            else if (_pending) ...[
              if (!_completed)
                OutlinedButton(
                  key: const Key('check-deletion-status'),
                  onPressed: _busy ? null : _checkStatus,
                  child: Text(
                    _text('تحديث حالة الحذف', 'Check deletion status'),
                  ),
                ),
              FilledButton(
                onPressed: _busy ? null : _closePending,
                child: Text(_text('تم', 'Done')),
              ),
            ] else if (!sameAccount) ...[
              Text(
                _text(
                  'الحساب الحالي تغيّر أو انتهت الجلسة. ارجع لحسابي وافتح الحذف للحساب المطلوب.',
                  'Your account changed or the session expired. Return to Account and open deletion for the intended account.',
                ),
              ),
              if (_receipt != null)
                TextButton(
                  key: const Key('check-deletion-status'),
                  onPressed: _busy ? null : _checkStatus,
                  child: Text(
                    _text('تحديث حالة الحذف', 'Check deletion status'),
                  ),
                ),
            ] else if (availability?.isLoading == true)
              const Center(child: CircularProgressIndicator())
            else if (availability?.value != true) ...[
              Text(
                _text(
                  'خدمة حذف الحساب غير متاحة حاليًا. حاول مرة أخرى.',
                  'Account deletion is currently unavailable. Please retry.',
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.invalidate(accountDeletionAvailabilityProvider),
                child: Text(_text('حاول مرة أخرى', 'Retry')),
              ),
            ] else ...[
              CheckboxListTile(
                key: const Key('confirm-account-deletion'),
                value: _confirmed,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _confirmed = v == true),
                title: Text(
                  _text(
                    'أفهم أن حذف الحساب نهائي',
                    'I understand deletion is permanent',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_reauth)
                FilledButton(
                  onPressed: _busy ? null : _signInAgain,
                  child: Text(
                    _text('تأكيد تسجيل الدخول', 'Sign in to confirm'),
                  ),
                )
              else
                FilledButton(
                  key: const Key('request-account-deletion'),
                  onPressed: _confirmed && !_busy ? _delete : null,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _text(
                            'حذف حسابي نهائيًا',
                            'Permanently delete my account',
                          ),
                        ),
                ),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(_text('إلغاء', 'Cancel')),
              ),
              if (_receipt != null)
                TextButton(
                  key: const Key('check-deletion-status'),
                  onPressed: _busy ? null : _checkStatus,
                  child: Text(
                    _text('تحديث حالة الحذف', 'Check deletion status'),
                  ),
                ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
