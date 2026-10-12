import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'push_action_destination.dart';
import 'push_notification_service.dart';

class NativePushActionsHost extends StatefulWidget {
  const NativePushActionsHost({
    super.key,
    required this.router,
    required this.child,
    this.openedActions,
    this.pendingAction,
  });
  final GoRouter router;
  final Widget child;
  final Stream<Map<String, dynamic>>? openedActions;
  final Map<String, dynamic>? pendingAction;
  @override
  State<NativePushActionsHost> createState() => _NativePushActionsHostState();
}

class _NativePushActionsHostState extends State<NativePushActionsHost> {
  StreamSubscription<Map<String, dynamic>>? _subscription;
  @override
  void initState() {
    super.initState();
    final service = PushNotificationService.instance;
    _subscription = (widget.openedActions ?? service.openedActions).listen(
      _open,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
