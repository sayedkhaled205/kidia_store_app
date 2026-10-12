import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/commerce/odoo_customer_client51.dart';
import '../../../auth/presentation/providers/odoo_customer_providers51.dart';
import 'odoo_customer_data56.dart';

bool odooArabic56(BuildContext context) =>
    Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

String odooCopy56(BuildContext context, String arabic, String english) =>
    odooArabic56(context) ? arabic : english;

String odooCustomerError56(BuildContext context, Object error) {
  final code = error is OdooCustomerException51 ? error.code : '';
  return switch (code) {
    'customer_session_required' || 'customer_session_changed' => odooCopy56(
      context,
      'انتهت جلسة الحساب. سجّل الدخول من جديد.',
      'Your account session ended. Please sign in again.',
    ),
    'invalid_credentials' || 'access_denied' => odooCopy56(
      context,
      'بيانات الدخول غير صحيحة أو الحساب غير متاح لهذا المتجر.',
      'The credentials are incorrect or this account is unavailable for this store.',
    ),
    'customer_request_timeout' || 'customer_connection_failed' => odooCopy56(
      context,
      'تعذر الاتصال بالمتجر. حاول مرة أخرى.',
      'Could not connect to the store. Please try again.',
    ),
    _ => odooCopy56(
      context,
      'تعذر إكمال الطلب بأمان. حاول مرة أخرى.',
      'The request could not be completed safely. Please try again.',
    ),
  };
}

class OdooCustomerFailure56 extends StatelessWidget {
  const OdooCustomerFailure56({
    required this.error,
    required this.onRetry,
    super.key,
  });
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          Text(
            odooCustomerError56(context, error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: Text(odooCopy56(context, 'إعادة المحاولة', 'Try again')),
          ),
        ],
      ),
    ),
  );
}

/// A visible Native customer route checks revisions on resume and in the
/// foreground. A hidden route or background application never polls. This is
/// read-after-resume/foreground polling, not a promise of zero-latency push.
class OdooCustomerLive56 extends ConsumerStatefulWidget {
  const OdooCustomerLive56({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<OdooCustomerLive56> createState() => _OdooCustomerLive56State();
}

class _OdooCustomerLive56State extends ConsumerState<OdooCustomerLive56>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground = true;
  bool _reading = false;
  OdooCustomerRevision51? _revision;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_refresh(force: true));
  }

  Future<void> _refresh({bool force = false}) async {
    if (!mounted ||
        !_foreground ||
        _reading ||
        !TickerMode.valuesOf(context).enabled ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final session = ref.read(odooCustomerSession51Provider).asData?.value;
    final client = ref.read(odooCustomerClient51Provider);
    if (session == null) return;
    if (!session.authenticated || !client.isAuthenticated) {
      ref.invalidate(odooCustomerSession51Provider);
      return;
    }
    _reading = true;
    try {
      final revision = await client.revision();
      if (!mounted ||
          !identical(
            session,
            ref.read(odooCustomerSession51Provider).asData?.value,
          )) {
        return;
      }
      final previous = _revision;
      _revision = revision;
      if (force || previous == null || previous.profile != revision.profile) {
        ref.invalidate(odooCustomerProfile56Provider);
      }
      if (force ||
          previous == null ||
          previous.addresses != revision.addresses) {
        ref.invalidate(odooCustomerAddresses56Provider);
      }
      if (force || previous == null || previous.orders != revision.orders) {
        ref.invalidate(odooCustomerOrders56Provider);
        ref.invalidate(odooCustomerOrder56Provider);
      }
    } catch (_) {
      if (mounted && !client.isAuthenticated) {
        // Clear the UI identity too, without restoring a revoked local SID.
        ref.invalidate(odooCustomerSession51Provider);
      }
      // A transient revision outage must not discard an unsaved form draft.
    } finally {
      _reading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
