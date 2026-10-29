import 'package:flutter/material.dart';
import 'package:mobishop_store_app/features/brands/domain/entities/store_brand.dart';
import 'package:mobishop_store_app/features/catalog/presentation/catalog_copy.dart';
import 'package:mobishop_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';

class CatalogProductFilterSheet extends StatefulWidget {
  const CatalogProductFilterSheet({
    required this.initialFilters,
    required this.currencyMinorUnit,
    required this.minimumAvailableMinor,
    required this.maximumAvailableMinor,
    required this.brands,
    required this.showPrice,
    required this.showSale,
    required this.showBrand,
    this.showSizes = true,
    this.showColors = true,
    this.availableSizes = const [],
    this.availableColors = const [],
    this.loadOptions,
    super.key,
  });

  final CatalogProductFilters initialFilters;
  final int currencyMinorUnit;
  final String minimumAvailableMinor;
  final String maximumAvailableMinor;
  final List<StoreBrand> brands;
  final bool showPrice;
  final bool showSale;
  final bool showBrand;
  final bool showSizes, showColors;
  final List<CatalogSizeOption> availableSizes, availableColors;
  final Future<CatalogFilterOptions> Function()? loadOptions;

  static Future<CatalogProductFilters?> show(
    BuildContext context, {
    required CatalogProductFilters initialFilters,
    required int currencyMinorUnit,
    required String minimumAvailableMinor,
    required String maximumAvailableMinor,
    required List<StoreBrand> brands,
    bool showPrice = true,
    bool showSale = true,
    bool showBrand = true,
    bool sidePanel = false,
    bool showSizes = true,
    bool showColors = true,
    List<CatalogSizeOption> availableSizes = const [],
    List<CatalogSizeOption> availableColors = const [],
    Future<CatalogFilterOptions> Function()? loadOptions,
  }) {
    if (sidePanel) {
      return showGeneralDialog<CatalogProductFilters>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        barrierColor: Colors.black45,
        pageBuilder: (context, animation, secondaryAnimation) => Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width * .75,
            height: double.infinity,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    Expanded(
                      child: CatalogProductFilterSheet(
                        initialFilters: initialFilters,
                        currencyMinorUnit: currencyMinorUnit,
                        minimumAvailableMinor: minimumAvailableMinor,
                        maximumAvailableMinor: maximumAvailableMinor,
                        brands: brands,
                        showPrice: showPrice,
                        showSale: showSale,
                        showBrand: showBrand,
                        showSizes: showSizes,
                        showColors: showColors,
                        availableSizes: availableSizes,
                        availableColors: availableColors,
                        loadOptions: loadOptions,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return showModalBottomSheet<CatalogProductFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => CatalogProductFilterSheet(
        initialFilters: initialFilters,
        currencyMinorUnit: currencyMinorUnit,
        minimumAvailableMinor: minimumAvailableMinor,
        maximumAvailableMinor: maximumAvailableMinor,
        brands: brands,
        showPrice: showPrice,
        showSale: showSale,
        showBrand: showBrand,
        showSizes: showSizes,
        showColors: showColors,
        availableSizes: availableSizes,
        availableColors: availableColors,
        loadOptions: loadOptions,
      ),
    );
  }

  @override
  State<CatalogProductFilterSheet> createState() =>
      _CatalogProductFilterSheetState();
}

class _CatalogProductFilterSheetState extends State<CatalogProductFilterSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _minimumController;
  late final TextEditingController _maximumController;
  late bool _onSaleOnly;
  int? _brandId;
  String? _rangeError;
  late List<CatalogSizeOption> _sizes, _colors;
  late List<CatalogTagOption> _tags;
  CatalogFilterOptions _options = const CatalogFilterOptions();
  bool _loading = false, _optionsFailed = false;
  Future<void> _loadOptions() async {
    if (widget.loadOptions == null) return;
    setState(() {
      _loading = true;
      _optionsFailed = false;
    });
    try {
      final options = await widget.loadOptions!();
      if (mounted) {
        setState(() {
          _options = options;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _optionsFailed = true;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _minimumController = TextEditingController(
      text: _minorToDecimal(
        widget.initialFilters.minimumPriceMinor,
        widget.currencyMinorUnit,
      ),
    );
    _maximumController = TextEditingController(
      text: _minorToDecimal(
        widget.initialFilters.maximumPriceMinor,
        widget.currencyMinorUnit,
      ),
    );
    _onSaleOnly = widget.initialFilters.onSaleOnly;
    _brandId = widget.initialFilters.brandId;
    _sizes = [...widget.initialFilters.sizes];
    _colors = [...widget.initialFilters.colors];
    _tags = [...widget.initialFilters.tags];
    _loadOptions();
  }

  @override
  void dispose() {
    _minimumController.dispose();
    _maximumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CatalogCopy copy = CatalogCopy.of(context);
    final ThemeData theme = Theme.of(context);
    final String minimumAvailable = _minorToDecimal(
      widget.minimumAvailableMinor,
      widget.currencyMinorUnit,
    );
    final String maximumAvailable = _minorToDecimal(
      widget.maximumAvailableMinor,
      widget.currencyMinorUnit,
    );

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                copy.filters,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (widget.showSale)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(copy.onSaleOnly),
                  secondary: const Icon(Icons.local_offer_outlined),
                  value: _onSaleOnly,
                  onChanged: (bool value) => setState(() {
                    _onSaleOnly = value;
                  }),
                ),
              if (widget.showBrand && widget.brands.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  key: const Key('catalog-brand-filter'),
                  initialValue:
                      widget.brands.any(
                        (StoreBrand brand) => brand.id == _brandId,
                      )
                      ? _brandId
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: copy.brand,
                    prefixIcon: const Icon(Icons.verified_outlined),
                  ),
                  items: <DropdownMenuItem<int?>>[
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(copy.allBrands),
                    ),
                    ...widget.brands.map(
                      (StoreBrand brand) => DropdownMenuItem<int?>(
                        value: brand.id,
                        child: Text(
                          brand.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (int? value) => setState(() {
                    _brandId = value;
                  }),
                ),
              ],
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                ),
              if (_optionsFailed)
                TextButton.icon(
                  onPressed: _loadOptions,
                  icon: const Icon(Icons.refresh),
                  label: Text(copy.retry),
                ),
              if (widget.showSizes)
                _choices<CatalogSizeOption>(
                  copy.size,
                  [...widget.availableSizes, ..._options.sizes, ..._sizes],
                  _sizes,
                  (v) => v.label,
                  (v) => setState(() => _sizes = v),
                ),
              if (widget.showColors)
                _choices<CatalogSizeOption>(
                  copy.color,
                  [...widget.availableColors, ..._options.colors, ..._colors],
                  _colors,
                  (v) => v.label,
                  (v) => setState(() => _colors = v),
                ),
              _choices<CatalogTagOption>(
                copy.productTags,
                [..._options.tags, ..._tags],
                _tags,
                (v) => v.label,
                (v) => setState(() => _tags = v),
              ),
              if (widget.showPrice) const Divider(height: 20),
              if (widget.showPrice) ...[
                TextFormField(
                  key: const Key('catalog-minimum-price'),
                  controller: _minimumController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: copy.minimumPrice,
                    hintText: minimumAvailable.isEmpty
                        ? null
                        : minimumAvailable,
                  ),
                  validator: (value) => _priceValidator(value, copy),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('catalog-maximum-price'),
                  controller: _maximumController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: copy.maximumPrice,
                    hintText: maximumAvailable.isEmpty
                        ? null
                        : maximumAvailable,
                  ),
                  validator: (value) => _priceValidator(value, copy),
                ),
              ],
              if (_rangeError != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _rangeError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => _submit(copy),
                child: Text(copy.apply),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const CatalogProductFilters()),
                child: Text(copy.reset),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choices<T>(
    String title,
    List<T> values,
    List<T> selected,
    String Function(T) label,
    ValueChanged<List<T>> onChange,
  ) {
    final options = values.toSet().toList();
    if (options.isEmpty) return const SizedBox.shrink();
    return _FilterChoiceSection<T>(
      key: ValueKey(title),
      title: title,
      options: options,
      selected: selected,
      label: label,
      onChange: onChange,
    );
  }

  String? _priceValidator(String? value, CatalogCopy copy) {
    final String normalized = (value ?? '').trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(normalized)) {
      return copy.invalidPrice;
    }
    final int separator = normalized.indexOf('.');
    final int fractionLength = separator < 0
        ? 0
        : normalized.length - separator - 1;
    return fractionLength <= _safeMinorUnit(widget.currencyMinorUnit)
        ? null
        : copy.invalidPrice;
  }

  void _submit(CatalogCopy copy) {
    setState(() {
      _rangeError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final String minimum = _decimalToMinor(
      _minimumController.text,
      widget.currencyMinorUnit,
    );
    final String maximum = _decimalToMinor(
      _maximumController.text,
      widget.currencyMinorUnit,
    );
    if (minimum.isNotEmpty &&
        maximum.isNotEmpty &&
        BigInt.parse(minimum) > BigInt.parse(maximum)) {
      setState(() {
        _rangeError = copy.invalidRange;
      });
      return;
    }

    Navigator.of(context).pop(
      CatalogProductFilters(
        onSaleOnly: _onSaleOnly,
        minimumPriceMinor: minimum,
        maximumPriceMinor: maximum,
        brandId: _brandId,
        brandLabel: _selectedBrandLabel(),
        sizes: _sizes,
        colors: _colors,
        tags: _tags,
      ),
    );
  }

  String _selectedBrandLabel() {
    for (final StoreBrand brand in widget.brands) {
      if (brand.id == _brandId) {
        return brand.name;
      }
    }
    return '';
  }
}

String _minorToDecimal(String source, int minorUnit) {
  final String value = source.trim();
  if (!RegExp(r'^\d+$').hasMatch(value)) {
    return '';
  }
  final int scale = _safeMinorUnit(minorUnit);
  if (scale == 0) {
    return value;
  }
  final String padded = value.padLeft(scale + 1, '0');
  final int split = padded.length - scale;
  final String fraction = padded
      .substring(split)
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty
      ? padded.substring(0, split)
      : '${padded.substring(0, split)}.$fraction';
}

String _decimalToMinor(String source, int minorUnit) {
  final String value = source.trim().replaceAll(',', '.');
  if (value.isEmpty || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(value)) {
    return '';
  }

  final int scale = _safeMinorUnit(minorUnit);
  final List<String> parts = value.split('.');
  final String whole = parts.first;
  final String fraction = parts.length == 1 ? '' : parts.last;
  final String scaledFraction = scale == 0
      ? ''
      : fraction.padRight(scale, '0').substring(0, scale);
  return BigInt.parse('$whole$scaledFraction').toString();
}

int _safeMinorUnit(int value) {
  if (value < 0) {
    return 0;
  }
  return value > 12 ? 12 : value;
}

class _FilterChoiceSection<T> extends StatefulWidget {
  const _FilterChoiceSection({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.label,
    required this.onChange,
  });
  final String title;
  final List<T> options, selected;
  final String Function(T) label;
  final ValueChanged<List<T>> onChange;
  @override
  State<_FilterChoiceSection<T>> createState() =>
      _FilterChoiceSectionState<T>();
}

class _FilterChoiceSectionState<T> extends State<_FilterChoiceSection<T>> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final options = widget.options.where(
      (option) =>
          widget.label(option).toLowerCase().contains(search.toLowerCase()),
    );
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(widget.title),
      subtitle: widget.selected.isEmpty
          ? null
          : Text(
              widget.selected.map(widget.label).join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      children: [
        if (widget.options.length > 12)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: CatalogCopy.of(context).search,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => search = value),
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text(widget.label(option)),
                  selected: widget.selected.contains(option),
                  selectedColor: colors.primary.withValues(alpha: .12),
                  labelStyle: TextStyle(color: colors.onSurface),
                  side: BorderSide(color: colors.primary.withValues(alpha: .3)),
                  onSelected: (selected) => widget.onChange(
                    selected
                        ? [...widget.selected, option]
                        : widget.selected
                              .where((value) => value != option)
                              .toList(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
