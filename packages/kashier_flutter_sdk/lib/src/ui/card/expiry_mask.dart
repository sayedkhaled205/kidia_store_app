import 'package:flutter/material.dart';

/// A visual continuation of the expiry hint. It never changes the editable
/// value, selection, formatter, validation or submitted payment data.
class ExpiryMask extends StatelessWidget {
  const ExpiryMask({
    required this.controller,
    required this.child,
    required this.padding,
    required this.style,
    required this.hintColor,
    super.key,
  });

  final TextEditingController controller;
  final Widget child;
  final EdgeInsets padding;
  final TextStyle style;
  final Color hintColor;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        child: child,
        builder: (context, value, field) {
          final digits = value.text.replaceAll(RegExp(r'\D'), '').length;
          final remaining = switch (digits) {
            1 => 'M/YY',
            2 => '/YY',
            3 => 'Y',
            _ => '',
          };
          return Stack(children: [
            field!,
            if (remaining.isNotEmpty)
              Positioned(
                left: padding.left,
                top: padding.top,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: value.text,
                            style: const TextStyle(color: Colors.transparent)),
                        TextSpan(
                            text: remaining,
                            style: TextStyle(color: hintColor)),
                      ]),
                      key: const ValueKey('expiry-remaining-mask'),
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.merge(style) ??
                          style,
                    ),
                  ),
                ),
              ),
          ]);
        },
      );
}
