import 'package:flutter/material.dart';
import 'package:kidia_store_app/features/brands/domain/entities/store_brand.dart';
import 'package:kidia_store_app/features/catalog/presentation/catalog_copy.dart';
import 'package:kidia_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';

class CatalogProductFilterSheet extends StatefulWidget {
  const CatalogProductFilterSheet({
    required this.initialFilters,
    required this.currencyMinorUnit,
    required this.minimumAvailableMinor,
    required this.maximumAvailableMinor,
    required this.brands,
    super.key,
  });

  final CatalogProductFilters initialFilters;
  final int currencyMinorUnit;
  final String minimumAvailableMinor;
  final String maximumAvailableMinor;
  final List<StoreBrand> brands;

  static Future<CatalogProductFilters?> show(
    BuildContext context, {
    required CatalogProductFilters initialFilters,
    required int currencyMinorUnit,
    required String minimumAvailableMinor,
    required String maximumAvailableMinor,
    required List<StoreBrand> brands,
  }) {
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
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(copy.onSaleOnly),
                secondary: const Icon(Icons.local_offer_outlined),
                value: _onSaleOnly,
                onChanged: (bool value) => setState(() {
                  _onSaleOnly = value;
                }),
              ),
              if (widget.brands.isNotEmpty) ...<Widget>[
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
              const Divider(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
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
                      validator: (String? value) =>
                          _priceValidator(value, copy),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
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
                      validator: (String? value) =>
                          _priceValidator(value, copy),
                    ),
                  ),
                ],
              ),
              if (_rangeError != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _rangeError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _submit(copy),
                child: Text(copy.apply),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(
                  CatalogProductFilters(
                    sizeTaxonomy: widget.initialFilters.sizeTaxonomy,
                    sizeTerm: widget.initialFilters.sizeTerm,
                    sizeLabel: widget.initialFilters.sizeLabel,
                  ),
                ),
                child: Text(copy.reset),
              ),
            ],
          ),
        ),
      ),
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
        sizeTaxonomy: widget.initialFilters.sizeTaxonomy,
        sizeTerm: widget.initialFilters.sizeTerm,
        sizeLabel: widget.initialFilters.sizeLabel,
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
