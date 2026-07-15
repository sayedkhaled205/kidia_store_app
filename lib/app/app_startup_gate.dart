import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/splash/presentation/splash_screen.dart';
import 'app_startup_provider.dart';

class AppStartupGate extends ConsumerWidget {
  const AppStartupGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<void> startupState = ref.watch(appStartupProvider);

    return startupState.when(
      loading: SplashScreen.new,
      error: (Object error, StackTrace stackTrace) {
        return StartupErrorScreen(
          error: error,
          onRetry: () => ref.invalidate(appStartupProvider),
        );
      },
      data: (_) => child,
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              const Text(
                'تعذر تشغيل التطبيق',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onRetry,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
