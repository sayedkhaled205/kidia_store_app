import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'push_action_destination.dart';
import 'push_notification_service.dart';
import 'foreground_push_notice.dart';

class NativePushActionsHost extends StatefulWidget {
  const NativePushActionsHost({
    super.key,
    required this.router,
    required this.child,
    this.openedActions,
    this.pendingAction,
    this.foregroundNotices,
    this.onForegroundOpened,
  });
  final GoRouter router;
  final Widget child;
  final Stream<Map<String, dynamic>>? openedActions;
  final Map<String, dynamic>? pendingAction;
  final Stream<ForegroundPushNotice>? foregroundNotices;
  final Future<void> Function(Map<String, dynamic>)? onForegroundOpened;
  @override
  State<NativePushActionsHost> createState() => _NativePushActionsHostState();
}

class _NativePushActionsHostState extends State<NativePushActionsHost> {
  StreamSubscription<Map<String, dynamic>>? _subscription;
  StreamSubscription<ForegroundPushNotice>? _foregroundSubscription;
  ForegroundPushNotice? _notice;
  Timer? _noticeTimer;
  @override
  void initState() {
    super.initState();
    final service = PushNotificationService.instance;
    _subscription = (widget.openedActions ?? service.openedActions).listen(
      _open,
    );
    _foregroundSubscription =
        (widget.foregroundNotices ?? service.foregroundNotices).listen(
          _showNotice,
        );
    final pending = widget.openedActions == null
        ? service.takePendingOpenedAction()
        : widget.pendingAction;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(pending);
      });
    }
  }

  void _showNotice(ForegroundPushNotice notice) {
    if (!mounted ||
        notice.data['type'] == 'mobishop_store_change' ||
        (notice.title.trim().isEmpty && notice.body.trim().isEmpty)) {
      return;
    }
    _noticeTimer?.cancel();
    setState(() => _notice = notice);
    _noticeTimer = Timer(const Duration(seconds: 8), _dismissNotice);
  }

  void _dismissNotice() {
    _noticeTimer?.cancel();
    if (mounted && _notice != null) setState(() => _notice = null);
  }

  Future<void> _openNotice(ForegroundPushNotice notice) async {
    if (!identical(_notice, notice)) return;
    if (PushActionDestination.fromData(notice.data) == null) return;
    _dismissNotice();
    await _open(notice.data);
    try {
      await (widget.onForegroundOpened ??
          PushNotificationService.instance.recordForegroundOpened)(notice.data);
    } catch (_) {
      // Optional analytics must not interfere with navigation.
    }
  }

  Future<void> _open(Map<String, dynamic> data) async {
    if (!mounted) return;
    final destination = PushActionDestination.fromData(data);
    if (destination?.location != null) {
      widget.router.go(destination!.location!);
    } else if (destination?.externalUrl != null) {
      try {
        await launchUrl(
          destination!.externalUrl!,
          mode: LaunchMode.externalApplication,
        );
      } on Object {
        /* An unavailable browser must not crash the app. */
      }
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_foregroundSubscription?.cancel());
    _noticeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notice = _notice;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final colors = Theme.of(context).colorScheme;
    final canOpen =
        notice != null && PushActionDestination.fromData(notice.data) != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (notice != null)
          Positioned(
            top: 0,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: Semantics(
                liveRegion: true,
                child: Material(
                  key: const Key('foreground-push-banner'),
                  elevation: 8,
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: canOpen ? () => _openNotice(notice) : null,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              top: 5,
                              end: 10,
                            ),
                            child: Icon(
                              Icons.notifications_active_outlined,
                              color: colors.primary,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  notice.title.isEmpty
                                      ? (ar ? 'إشعار جديد' : 'New notification')
                                      : notice.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (notice.body.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    notice.body,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                                if (canOpen)
                                  TextButton(
                                    key: const Key('foreground-push-open'),
                                    onPressed: () => _openNotice(notice),
                                    child: Text(ar ? 'فتح' : 'Open'),
                                  ),
                              ],
                            ),
                          ),
                          Semantics(
                            label: MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                            child: IconButton(
                              key: const Key('foreground-push-dismiss'),
                              onPressed: _dismissNotice,
                              icon: const Icon(Icons.close, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
