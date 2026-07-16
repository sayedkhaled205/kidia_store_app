import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/features/catalog/presentation/catalog_copy.dart';

Future<void> showCatalogSearch(
  BuildContext context, {
  String initialQuery = '',
}) async {
  final String? query = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) =>
        _CatalogSearchSheet(initialQuery: initialQuery),
  );
  final String normalizedQuery = query?.trim() ?? '';
  if (!context.mounted || normalizedQuery.isEmpty) {
    return;
  }

  context.push('/search?q=${Uri.encodeQueryComponent(normalizedQuery)}');
}

class _CatalogSearchSheet extends StatefulWidget {
  const _CatalogSearchSheet({required this.initialQuery});

  final String initialQuery;

  @override
  State<_CatalogSearchSheet> createState() => _CatalogSearchSheetState();
}

class _CatalogSearchSheetState extends State<_CatalogSearchSheet> {
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
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        16,
        16,
        16 + keyboardInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            copy.search,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
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
                icon: const Icon(Icons.arrow_forward_rounded, size: 26.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
