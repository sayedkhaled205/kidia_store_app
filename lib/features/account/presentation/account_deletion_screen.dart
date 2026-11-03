import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/network/customer_account_api_transport.dart';
import 'providers/customer_account_providers.dart';

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

/// Capturing the account ID prevents reauthentication from changing the target.
class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({required this.userId, super.key});
  final int userId;

  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  bool _confirmed = false;
  bool _busy = false;
  bool _pending = false;
  bool _reauth = false;
  String? _error;
  String? _deletedToken;
  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';
  String _text(String ar, String en) => _ar ? ar : en;

  Future<void> _delete() async {
    final session = ref.read(authControllerProvider).value;
    if (_busy ||
        !_confirmed ||
        session == null ||
        session.isExpired ||
        session.user.id != widget.userId) {
      return;
    }
    final token = session.token;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(accountDeletionTransportProvider)
          .requestDeletion();
      if (result['status'] != 'pending' || result['user_id'] != widget.userId) {
        throw const FormatException('Invalid deletion response');
      }
      _deletedToken = token;
      if (mounted) setState(() => _pending = true);
      await ref
          .read(authControllerProvider.notifier)
          .completeAccountDeletion(token);
    } on CustomerAccountTransportException catch (error) {
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
      if (mounted) {
        setState(
          () => _error = _text(
            'تعذر إكمال الخطوة الآن. حاول مرة أخرى.',
            'Could not complete this step. Please retry.',
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
    if (token == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .completeAccountDeletion(token);
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).value;
    final sameAccount =
        session != null &&
        !session.isExpired &&
        session.user.id == widget.userId;
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
              _pending
                  ? Icons.check_circle_outline
                  : Icons.person_remove_outlined,
              size: 48,
            ),
            const SizedBox(height: 20),
            Text(
              _pending
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
              _pending
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
            if (_pending)
              FilledButton(
                onPressed: _busy ? null : _closePending,
                child: Text(_text('تم', 'Done')),
              )
            else if (!sameAccount)
              Text(
                _text(
                  'الحساب الحالي تغيّر أو انتهت الجلسة. ارجع لحسابي وافتح الحذف للحساب المطلوب.',
                  'Your account changed or the session expired. Return to Account and open deletion for the intended account.',
                ),
              )
            else if (availability?.isLoading == true)
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
