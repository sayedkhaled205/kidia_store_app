import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../kashier_sdk.dart';
import 'kashier_colors.dart';

/// An overlay widget that renders a bottom-sheet-like container
/// on top of the merchant's app.
///
/// Manages its own backdrop, animation, and dismiss behavior
/// without depending on the merchant's navigator.
///
/// Uses a lightweight [MaterialApp] internally to provide the full
/// Material widget infrastructure (Localizations, Overlay, MediaQuery)
/// that text fields and other Material widgets need.
class KashierPaymentOverlay extends StatefulWidget {
  /// The sheet content to display.
  final Widget child;

  /// Called when the user taps the backdrop or the sheet requests dismissal.
  final VoidCallback onDismiss;

  /// When true, the sheet expands to fill the screen (used for 3DS WebView).
  final bool fullScreen;

  const KashierPaymentOverlay({
    super.key,
    required this.child,
    required this.onDismiss,
    this.fullScreen = false,
  });

  @override
  State<KashierPaymentOverlay> createState() => _KashierPaymentOverlayState();
}

class _KashierPaymentOverlayState extends State<KashierPaymentOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _backdropOpacity;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _backdropOpacity = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: KashierSDK.language.locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorSchemeSeed: KashierColors.primary,
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // Backdrop
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.fullScreen ? null : _dismiss,
                child: AnimatedBuilder(
                  animation: _backdropOpacity,
                  builder: (context, child) => ColoredBox(
                    color:
                        Colors.black.withValues(alpha: _backdropOpacity.value),
                  ),
                ),
              ),
            ),

            // Bottom sheet / full-screen container
            Positioned(
              left: 0,
              right: 0,
              top: widget.fullScreen ? 0 : null,
              bottom: 0,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: widget.fullScreen
                        ? BorderRadius.zero
                        : const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  // Animate height changes between sheets so switching
                  // from a taller sheet (landing) to a shorter one
                  // (wallet phone input) slides smoothly instead of
                  // snapping. Anchored to the bottom so growth/shrink
                  // happens at the top edge of the sheet.
                  child: widget.fullScreen
                      ? widget.child
                      : AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          alignment: Alignment.bottomCenter,
                          child: widget.child,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
