import 'package:flutter/material.dart';

/// Opens directly below the catalog controls, retaining the page behind it.
Future<T?> showCatalogToolbarPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final RenderBox? anchor = context.findRenderObject() as RenderBox?;
  final double top = anchor == null
      ? MediaQuery.paddingOf(context).top
      : anchor.localToGlobal(Offset(0, anchor.size.height)).dy;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, animation, secondaryAnimation) => Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height - top -
                      MediaQuery.paddingOf(context).bottom)
                  .clamp(0, double.infinity),
            ),
            child: SingleChildScrollView(child: builder(context)),
          ),
        ),
      ),
    ),
  );
}
