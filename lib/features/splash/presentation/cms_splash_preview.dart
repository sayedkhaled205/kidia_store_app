import 'package:flutter/material.dart';

import '../../page_builder/presentation/providers/cms_preview_layout_bridge.dart';
import '../domain/splash_config.dart';
import 'splash_screen.dart';

/// Uses the actual application screen while listening to every editor change.
/// The normal startup provider deliberately resolves only once; it cannot serve
/// as a live design stream and remains untouched for Android and iOS.
class CmsSplashPreview extends StatefulWidget {
  const CmsSplashPreview({super.key, this.settings});

  final Stream<Map<String, dynamic>?>? settings;

  @override
  State<CmsSplashPreview> createState() => _CmsSplashPreviewState();
}

class _CmsSplashPreviewState extends State<CmsSplashPreview> {
  late final Stream<Map<String, dynamic>?> _settings =
      widget.settings ?? CmsPreviewLayoutBridge.splashSettings;

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>?>(
    stream: _settings,
    builder: (context, snapshot) {
      final settings = snapshot.data;
      if (settings == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final config = SplashConfig.fromJson(settings);
      if (!config.enabled) {
        return const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'شاشة البداية متوقفة. سيفتح التطبيق بدون انتظار مدتها.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
      return SplashScreen(config: config);
    },
  );
}
