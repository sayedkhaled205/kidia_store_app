import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An anchored panel that stays usable when the viewport or keyboard changes.
Future<T?> showCatalogToolbarPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final anchorContext = context;
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, animation, secondaryAnimation) => SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final media = MediaQuery.of(context);
          final anchor = anchorContext.mounted
              ? anchorContext.findRenderObject() as RenderBox?
              : null;
          final desiredTop = anchor != null && anchor.attached && anchor.hasSize
              ? anchor.localToGlobal(Offset(0, anchor.size.height)).dy -
                    media.padding.top
              : 0.0;
          final height = math.max(
            0.0,
            constraints.maxHeight - media.viewInsets.bottom,
          );
          // Preserve enough space for the close control, choices and actions.
          final top = desiredTop.clamp(
            0.0,
            math.max(0.0, height - math.min(280.0, height)),
          );
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: top.toDouble()),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (height - top).toDouble(),
                ),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: IconButton(
                          key: const Key('catalog-panel-close'),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      Flexible(child: builder(context)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

