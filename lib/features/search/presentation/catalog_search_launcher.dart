import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/features/catalog/presentation/catalog_copy.dart';

Future<void> showCatalogSearch(
  BuildContext context, {
  String initialQuery = '',
}) async {
  final String? query = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) => _CatalogSearchOverlay(initialQuery: initialQuery),
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.12),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
  );
  final String normalizedQuery = query?.trim() ?? '';
  if (!context.mounted || normalizedQuery.isEmpty) {
    return;
  }

  context.push('/search?q=${Uri.encodeQueryComponent(normalizedQuery)}');
}

class _CatalogSearchOverlay extends StatefulWidget {
  const _CatalogSearchOverlay({required this.initialQuery});

  final String initialQuery;

  @override
  State<_CatalogSearchOverlay> createState() =>
      _CatalogSearchOverlayState();
}

class _CatalogSearchOverlayState extends State<_CatalogSearchOverlay> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery.trim());
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String query = _controller.text.trim();
    if (query.isEmpty) {
      return;
    }
    Navigator.of(context).pop(query);
  }

  @override
  Widget build(BuildContext context) {
    final CatalogCopy copy = CatalogCopy.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: AlignmentDirectional.topCenter,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 0),
            child: Material(
              key: const Key('catalog-search-top-overlay'),
              color: colors.surface,
              elevation: 8,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  key: const Key('catalog-search-overlay-field'),
                  controller: _controller,
                  autofocus: true,
                  autocorrect: false,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: copy.searchHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 26.4),
                    suffixIcon: IconButton(
                      key: const Key('catalog-search-overlay-submit'),
                      tooltip: copy.search,
                      onPressed: _submit,
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 26.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
