import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kashier_flutter_sdk/kashier_flutter_sdk.dart';
import 'package:mobishop_store_app/core/analytics/mobile_analytics.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_totals.dart';
import 'package:mobishop_store_app/features/checkout/application/checkout_controller.dart';
import 'package:mobishop_store_app/features/checkout/data/models/checkout_country_data.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_address.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_field_definition.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_presentation.dart';
import 'package:mobishop_store_app/features/checkout/domain/repositories/checkout_repository.dart';
import 'checkout_payment_continuation298.dart';
import 'providers/checkout_inline_payment95.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({
    required this.repository,
    super.key,
    this.customerEmail = '',
    this.onOrderSuccess,
    this.onBackToCart,
    this.onReviewOrders,
    this.design = CheckoutDesign.classic,
    this.isPreview = false,
  });

  final CheckoutRepository repository;
  final String customerEmail;
  final ValueChanged<CheckoutOrderResult>? onOrderSuccess;
  final VoidCallback? onBackToCart;
  final VoidCallback? onReviewOrders;
  final CheckoutDesign design;
  final bool isPreview;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late CheckoutController _controller;
  bool _checkoutTracked = false;
  final _inlineCard = KashierInlineCardController();
  bool _payingInline = false;
  CheckoutOrderResult? _paidResult;

  bool get _usesInlineCard =>
      _controller.needsPayment &&
      _controller.checkout?.nativePaymentAdapters[_controller
              .paymentMethodId] ==
          'kashier';

  @override
  void initState() {
    super.initState();
    _createController();
  }

  @override
  void didUpdateWidget(CheckoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.customerEmail != widget.customerEmail) {
      _controller.removeListener(_onControllerChanged);
      _controller.dispose();
      _inlineCard.clear();
      _paidResult = null;
      _payingInline = false;
      _checkoutTracked = false;
      _createController();
    }
  }

  void _createController() {
    _controller = CheckoutController(
      repository: widget.repository,
      initialEmail: widget.customerEmail,
    )..addListener(_onControllerChanged);
    _controller.load();
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    if (!_usesInlineCard) _inlineCard.clear();
    final Cart? cart = _controller.cart;
    if (!widget.isPreview &&
        !_checkoutTracked &&
        cart != null &&
        !cart.isEmpty &&
        (_controller.status == CheckoutStatus.ready ||
            _controller.status == CheckoutStatus.submitting)) {
      _checkoutTracked = true;
      _analytics?.trackInBackground(
        'begin_checkout',
        value: _cartValue(cart),
        currency: cart.totals.currency.code,
        authToken: _authToken,
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    _inlineCard.clear();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _CheckoutCopy copy = _CheckoutCopy.of(context);
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xffd9d9d9)),
    );
    return PopScope(
      canPop: !_payingInline,
      child: Theme(
        data: theme.copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 19,
            ),
            border: border,
            enabledBorder: border,
            disabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
            labelStyle: const TextStyle(fontSize: 16, color: Color(0xff727272)),
            floatingLabelStyle: const TextStyle(
              fontSize: 13,
              color: Color(0xff727272),
            ),
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              copy.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: !_payingInline,
          ),
          body: _InlineCheckoutCardScope(
            card: _inlineCard,
            processing: _payingInline,
            child: _buildBody(copy),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(_CheckoutCopy copy) {
    if (_paidResult != null) {
      return _CheckoutSuccess(result: _paidResult!, copy: copy);
    }
    // Keep the SDK-owned fields mounted while preparing the protected order.
    // The normal pending-order continuation is only a recovery path, never an
    // intermediate screen in the successful one-button checkout flow.
    if (_payingInline) {
      return _ready(copy);
    }
    switch (_controller.status) {
      case CheckoutStatus.initial:
      case CheckoutStatus.loading:
        return _CheckoutLoading(copy: copy);
      case CheckoutStatus.failure:
        return _CheckoutFailure(
          message: _controller.loadError ?? copy.loadFailure,
          retryLabel: copy.retry,
          onRetry: _controller.load,
        );
      case CheckoutStatus.success:
        final result = _controller.orderResult!;
        if (result.requiresRedirect ||
            result.status == 'pending' ||
            result.paymentStatus != 'success') {
          return CheckoutPaymentContinuation298(
            orderId: result.orderId,
            onReviewOrders: widget.onReviewOrders,
          );
        }
        return _CheckoutSuccess(result: _controller.orderResult!, copy: copy);
      case CheckoutStatus.ready:
      case CheckoutStatus.submitting:
        final Cart? cart = _controller.cart;
        if (cart == null || cart.isEmpty) {
          return _EmptyCheckout(
            copy: copy,
            onBack: widget.onBackToCart,
            unresolved: _controller.hasUnresolvedSubmission,
            onReviewOrders: widget.onReviewOrders,
            onRecover: _controller.canRecoverOrder ? _recoverOrder : null,
            recovering: _controller.isRecoveringOrder,
          );
        }
        return _ready(copy);
    }
  }

  Widget _ready(_CheckoutCopy copy) => Stack(
    children: [
      AbsorbPointer(
        absorbing: _payingInline,
        child: _CheckoutReady(
          formKey: _formKey,
          controller: _controller,
          copy: copy,
          onSubmit: _submit,
          design: widget.design,
          onReviewOrders: widget.onReviewOrders,
          onRecover: _recoverOrder,
        ),
      ),
      if (_payingInline)
        Positioned.fill(
          child: ColoredBox(
            color: Colors.white70,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    copy.completingPayment,
                    key: const Key('checkout-completing-payment'),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Future<void> _submit() async {
    if (_payingInline || _controller.isSubmitting || _controller.hasActiveSubmission) return;
    if (widget.isPreview) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_CheckoutCopy.of(context).previewOnly)),
      );
      return;
    }
    final bool controllerValid = _controller.validate();
    final bool formValid = _formKey.currentState?.validate() ?? false;
    final inline = _usesInlineCard;
    final cardValid = !inline || _inlineCard.validate();
    if (!controllerValid || !formValid || !cardValid) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final controller = _controller;
    final confirmedCart = controller.cart;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    bool isCurrent() => mounted && identical(controller, _controller);
    if (inline) setState(() => _payingInline = true);
    CheckoutOrderResult? result;
    try {
      result = await controller.submit();
      if (!isCurrent() || result == null) return;
      if (inline &&
          (result.paymentStatus != 'success' ||
              result.status == 'pending' ||
              result.requiresRedirect)) {
        final totals = confirmedCart!.totals;
        final units = totals.currency.minorUnit;
        final digits = totals.priceMinor.padLeft(units + 1, '0');
        final whole = units == 0
            ? digits
            : digits.substring(0, digits.length - units);
        final fraction = units == 0
            ? '00'
            : digits.substring(digits.length - units).padRight(2, '0');
        final paid = await ref.read(checkoutInlinePayment95Provider)(
          orderId: result.orderId,
          card: _inlineCard,
          amount: '$whole.$fraction',
          currency: totals.currency.code,
          arabic: arabic,
        );
        if (!isCurrent()) return;
        if (paid) {
          result = CheckoutOrderResult(
            orderId: result.orderId,
            status: 'processing',
            paymentStatus: 'success',
          );
          _paidResult = result;
        }
      }
    } catch (_) {
      // Preserve the exact receipt for authoritative recovery. Never submit a
      // second order/payment or report a charge as failed based on an SDK error.
    } finally {
      if (isCurrent() && inline) setState(() => _payingInline = false);
    }
    if (!isCurrent() || result == null) {
      return;
    }
    widget.onOrderSuccess?.call(result);
    if (result.paymentStatus != 'success' || result.requiresRedirect) return;
    final Cart? cart = confirmedCart;
    final MobileAnalytics? analytics = _analytics;
    final String authToken = _authToken;
    analytics?.trackInBackground(
      'purchase',
      value: cart == null ? 0 : _cartValue(cart),
      currency: cart?.totals.currency.code ?? '',
      orderId: result.orderId,
      authToken: authToken,
    );
    if (cart != null) {
      for (final item in cart.items) {
        final int lineMinor = int.tryParse(item.totals.totalMinor) ?? 0;
        analytics?.trackInBackground(
          'purchase_item',
          objectId: item.productId,
          label: item.name,
          value: lineMinor / math.pow(10, item.totals.currency.minorUnit),
          currency: item.totals.currency.code,
          orderId: result.orderId,
          authToken: authToken,
        );
      }
    }
  }

  Future<void> _recoverOrder() async {
    final result = await _controller.recoverPendingOrder();
    if (!mounted || result == null) return;
    // This is an existing exact receipt, not a new checkout or purchase event.
    // Do not repeat purchase analytics or replay any order POST.
    widget.onOrderSuccess?.call(result);
  }

  ProviderContainer? get _providerContainer {
    try {
      return ProviderScope.containerOf(context, listen: false);
    } on StateError {
      return null;
    }
  }

  MobileAnalytics? get _analytics =>
      _providerContainer?.read(mobileAnalyticsProvider);

  String get _authToken =>
      _providerContainer?.read(authControllerProvider).asData?.value?.token ??
      '';

  double _cartValue(Cart cart) {
    final int minor = int.tryParse(cart.totals.priceMinor) ?? 0;
    return minor / math.pow(10, cart.totals.currency.minorUnit);
  }
}

class _InlineCheckoutCardScope extends InheritedWidget {
  const _InlineCheckoutCardScope({
    required this.card,
    required this.processing,
    required super.child,
  });
  final KashierInlineCardController card;
  final bool processing;
  static _InlineCheckoutCardScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_InlineCheckoutCardScope>();
  @override
  bool updateShouldNotify(_InlineCheckoutCardScope oldWidget) =>
      oldWidget.card != card || oldWidget.processing != processing;
}

class _CheckoutReady extends StatelessWidget {
  const _CheckoutReady({
    required this.formKey,
    required this.controller,
    required this.copy,
    required this.onSubmit,
    required this.design,
    this.onReviewOrders,
    required this.onRecover,
  });

  final GlobalKey<FormState> formKey;
  final CheckoutController controller;
  final _CheckoutCopy copy;
  final VoidCallback onSubmit;
  final CheckoutDesign design;
  final VoidCallback? onReviewOrders;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    return _CheckoutDesignScope(
      design: design,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 920;
          final Widget form = Form(
            key: formKey,
            child: Column(
              children: [
                if (controller.savedAddresses.isNotEmpty)
                  _SavedCheckoutAddresses92(controller: controller),
                _CheckoutForm(
                  key: ValueKey(controller.addressSelectionRevision),
                  controller: controller,
                  copy: copy,
                ),
              ],
            ),
          );
          final Widget summary = _OrderSummary(
            controller: controller,
            copy: copy,
            onSubmit: onSubmit,
            onReviewOrders: onReviewOrders,
            onRecover: onRecover,
          );

          if (wide) {
            final List<Widget> columns = design == CheckoutDesign.summaryFirst
                ? <Widget>[
                    SizedBox(
                      width: 390,
                      child: SingleChildScrollView(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          24,
                          24,
                          16,
                          40,
                        ),
                        child: summary,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        key: const Key('checkout-form-scroll'),
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          16,
                          24,
                          24,
                          40,
                        ),
                        child: form,
                      ),
                    ),
                  ]
                : <Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        key: const Key('checkout-form-scroll'),
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          24,
                          24,
                          16,
                          40,
                        ),
                        child: form,
                      ),
                    ),
                    SizedBox(
                      width: 390,
                      child: SingleChildScrollView(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          16,
                          24,
                          24,
                          40,
                        ),
                        child: summary,
                      ),
                    ),
                  ];
            return Row(
              key: Key('checkout-design-${design.apiValue}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: columns,
            );
          }

          final List<Widget> content = design == CheckoutDesign.summaryFirst
              ? <Widget>[summary, const SizedBox(height: 18), form]
              : <Widget>[form, const SizedBox(height: 18), summary];
          return SingleChildScrollView(
            key: const Key('checkout-form-scroll'),
            primary: true,
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 36),
            child: Column(
              key: Key('checkout-design-${design.apiValue}'),
              children: content,
            ),
          );
        },
      ),
    );
  }
}

class _SavedCheckoutAddresses92 extends StatelessWidget {
  const _SavedCheckoutAddresses92({required this.controller});
  final CheckoutController controller;
  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(
              ar ? 'عناوينك المحفوظة' : 'Your saved addresses',
              style: Theme.of(context).textTheme.titleMedium,
            )),
            TextButton.icon(
              key: const Key('checkout-new-address'),
              onPressed: controller.isSubmitting ? null : controller.enterNewAddress,
              icon: const Icon(Icons.add, size: 18),
              label: Text(ar ? 'عنوان جديد' : 'New address'),
            ),
          ]),
          if (controller.selectedSavedAddressId != null && !controller.showBillingEditor)
            Align(alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                key: const Key('checkout-edit-address'),
                onPressed: controller.isSubmitting ? null : controller.editSavedAddress,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(ar ? 'تعديل العنوان' : 'Edit address'),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 112,
            child: ListView.separated(
              key: const Key('checkout-saved-addresses'),
              scrollDirection: Axis.horizontal,
              itemCount: controller.savedAddresses.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final address = controller.savedAddresses[index];
                final selected = controller.selectedSavedAddressId == address.id;
                return SizedBox(
                  width: 240,
                  child: OutlinedButton(
                    key: ValueKey('checkout-address-${address.id}'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                      backgroundColor: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                    ),
                    onPressed: controller.isSubmitting
                        ? null
                        : () => controller.selectSavedAddress(address.values, addressId: address.id),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text(address.label,
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                            if (selected) Icon(Icons.check_circle,
                              key: ValueKey('checkout-address-selected-${address.id}'), size: 20),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            [
                                  address.values['address_1'],
                                  address.values['city'],
                                  address.values['phone'],
                                ]
                                .whereType<String>()
                                .where((v) => v.isNotEmpty)
                                .join(' · '),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutForm extends StatelessWidget {
  const _CheckoutForm({
    required this.controller,
    required this.copy,
    super.key,
  });

  final CheckoutController controller;
  final _CheckoutCopy copy;

  @override
  Widget build(BuildContext context) {
    final bool enabled = !controller.isSubmitting;
    if (controller.hasDynamicFields) {
      return _DynamicCheckoutForm(
        controller: controller,
        copy: copy,
        enabled: enabled,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (controller.showBillingEditor)
        _CheckoutSection(
          title: copy.billingAddress,
          icon: Icons.receipt_long_outlined,
          child: _AddressFields(
            keyPrefix: 'billing',
            address: controller.billingAddress,
            enabled: enabled,
            requiresEmail: false,
            requiresPhone: true,
            copy: copy,
            errorFor: controller.errorFor,
            onChanged: controller.updateBillingAddress,
          ),
        ),
        if (controller.allowDifferentShippingAddress) ...<Widget>[
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            key: const Key('checkout-different-shipping-toggle'),
            contentPadding: EdgeInsets.zero,
            title: Text(copy.differentShipping),
            subtitle: Text(copy.differentShippingHint),
            value: controller.shipToDifferentAddress,
            onChanged: enabled ? controller.setShipToDifferentAddress : null,
          ),
          if (controller.shipToDifferentAddress)
            _CheckoutSection(
              title: copy.shippingAddress,
              icon: Icons.local_shipping_outlined,
              child: _AddressFields(
                keyPrefix: 'shipping',
                address: controller.shippingAddress,
                enabled: enabled,
                requiresEmail: false,
                requiresPhone: false,
                copy: copy,
                errorFor: controller.errorFor,
                onChanged: controller.updateShippingAddress,
              ),
            ),
        ],
        const SizedBox(height: 16),
        _CheckoutSection(
          title: copy.orderNote,
          icon: Icons.edit_note_outlined,
          child: TextFormField(
            key: const Key('checkout-customer-note'),
            initialValue: controller.customerNote,
            enabled: enabled,
            minLines: 3,
            maxLines: 5,
            maxLength: 1000,
            onChanged: controller.setCustomerNote,
            decoration: InputDecoration(
              hintText: copy.orderNoteHint,
              errorText: _localizedError(
                copy,
                'customerNote',
                controller.errorFor('customerNote'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (controller.supportsShippingQuotes && controller.needsShipping) ...[
          _ShippingSection(controller: controller, copy: copy),
          const SizedBox(height: 16),
        ],
        _PaymentSection(controller: controller, copy: copy),
      ],
    );
  }
}

class _DynamicCheckoutForm extends StatelessWidget {
  const _DynamicCheckoutForm({
    required this.controller,
    required this.copy,
    required this.enabled,
  });

  final CheckoutController controller;
  final _CheckoutCopy copy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final List<CheckoutFieldDefinition> billing = controller.fieldsFor(
      CheckoutFieldGroup.billing,
    );
    final List<CheckoutFieldDefinition> shipping = controller.fieldsFor(
      CheckoutFieldGroup.shipping,
    );
    final List<CheckoutFieldDefinition> order = controller.fieldsFor(
      CheckoutFieldGroup.order,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (billing.isNotEmpty && controller.showBillingEditor)
          _CheckoutSection(
            title: copy.billingAddress,
            icon: Icons.receipt_long_outlined,
            child: _DynamicFieldList(
              fields: billing,
              controller: controller,
              enabled: enabled,
            ),
          ),
        if (controller.allowDifferentShippingAddress &&
            shipping.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            key: const Key('checkout-different-shipping-toggle'),
            contentPadding: EdgeInsets.zero,
            title: Text(copy.differentShipping),
            subtitle: Text(copy.differentShippingHint),
            value: controller.shipToDifferentAddress,
            onChanged: enabled ? controller.setShipToDifferentAddress : null,
          ),
          if (controller.shipToDifferentAddress)
            _CheckoutSection(
              title: copy.shippingAddress,
              icon: Icons.local_shipping_outlined,
              child: _DynamicFieldList(
                fields: shipping,
                controller: controller,
                enabled: enabled,
              ),
            ),
        ],
        if (order.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _CheckoutSection(
            title: copy.orderNote,
            icon: Icons.edit_note_outlined,
            child: _DynamicFieldList(
              fields: order,
              controller: controller,
              enabled: enabled,
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (controller.supportsShippingQuotes && controller.needsShipping) ...[
          _ShippingSection(controller: controller, copy: copy),
          const SizedBox(height: 16),
        ],
        _PaymentSection(controller: controller, copy: copy),
      ],
    );
  }
}

class _DynamicFieldList extends StatelessWidget {
  const _DynamicFieldList({
    required this.fields,
    required this.controller,
    required this.enabled,
  });

  final List<CheckoutFieldDefinition> fields;
  final CheckoutController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int index = 0; index < fields.length; index++) ...<Widget>[
          _DynamicCheckoutField(
            field: fields[index],
            controller: controller,
            enabled: enabled,
          ),
          if (index != fields.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _DynamicCheckoutField extends StatelessWidget {
  const _DynamicCheckoutField({
    required this.field,
    required this.controller,
    required this.enabled,
  });

  final CheckoutFieldDefinition field;
  final CheckoutController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final String value = controller.valueForField(field);
    final String label = field.required ? '${field.label} *' : field.label;
    final String? error = controller.errorFor(field.key);
    if (field.type == CheckoutFieldType.checkbox) {
      return SwitchListTile.adaptive(
        key: Key('checkout-dynamic-${field.key}'),
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: error == null
            ? null
            : Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
        value: value == '1' || value.toLowerCase() == 'yes',
        onChanged: enabled
            ? (bool selected) =>
                  controller.setFieldValue(field.key, selected ? '1' : '0')
            : null,
      );
    }
    if (field.type == CheckoutFieldType.select && field.options.isNotEmpty) {
      final String? selected = field.options.containsKey(value) ? value : null;
      return DropdownButtonFormField<String>(
        key: Key('checkout-dynamic-${field.key}'),
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: field.placeholder.isEmpty ? null : field.placeholder,
          errorText: error,
        ),
        items: field.options.entries
            .map(
              (MapEntry<String, String> option) => DropdownMenuItem<String>(
                value: option.key,
                child: Text(
                  option.value.isEmpty ? option.key : option.value,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        onChanged: enabled
            ? (String? selectedValue) =>
                  controller.setFieldValue(field.key, selectedValue ?? '')
            : null,
      );
    }

    return TextFormField(
      key: Key('checkout-dynamic-${field.key}'),
      initialValue: value,
      enabled: enabled,
      minLines: field.type == CheckoutFieldType.textarea ? 3 : 1,
      maxLines: field.type == CheckoutFieldType.textarea ? 5 : 1,
      keyboardType: switch (field.type) {
        CheckoutFieldType.email => TextInputType.emailAddress,
        CheckoutFieldType.telephone => TextInputType.phone,
        _ => TextInputType.text,
      },
      autofillHints: field.autocomplete.isEmpty
          ? null
          : <String>[field.autocomplete],
      onChanged: (String next) => controller.setFieldValue(field.key, next),
      validator: (_) => controller.errorFor(field.key),
      decoration: InputDecoration(
        labelText: label,
        hintText: field.placeholder.isEmpty ? null : field.placeholder,
        errorText: error,
      ),
    );
  }
}

class _AddressFields extends StatelessWidget {
  const _AddressFields({
    required this.keyPrefix,
    required this.address,
    required this.enabled,
    required this.requiresEmail,
    required this.requiresPhone,
    required this.copy,
    required this.errorFor,
    required this.onChanged,
  });

  final String keyPrefix;
  final CheckoutAddress address;
  final bool enabled;
  final bool requiresEmail;
  final bool requiresPhone;
  final _CheckoutCopy copy;
  final String? Function(String field) errorFor;
  final ValueChanged<CheckoutAddress> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool twoColumns = constraints.maxWidth >= 620;
        final List<Widget> fields = <Widget>[
          _field(
            name: 'firstName',
            label: copy.firstName,
            value: address.firstName,
            onChanged: (String value) =>
                onChanged(address.copyWith(firstName: value)),
          ),
          _field(
            name: 'lastName',
            label: copy.lastName,
            value: address.lastName,
            onChanged: (String value) =>
                onChanged(address.copyWith(lastName: value)),
          ),
          _field(
            name: 'company',
            label: copy.companyOptional,
            value: address.company,
            onChanged: (String value) =>
                onChanged(address.copyWith(company: value)),
          ),
          _field(
            name: 'address1',
            label: copy.address1,
            value: address.address1,
            onChanged: (String value) =>
                onChanged(address.copyWith(address1: value)),
          ),
          _field(
            name: 'address2',
            label: copy.address2Optional,
            value: address.address2,
            onChanged: (String value) =>
                onChanged(address.copyWith(address2: value)),
          ),
          _field(
            name: 'city',
            label: copy.city,
            value: address.city,
            onChanged: (String value) =>
                onChanged(address.copyWith(city: value)),
          ),
          _stateField(
            name: 'state',
            label: copy.state,
            value: address.state,
            country: address.country,
            onChanged: (String value) =>
                onChanged(address.copyWith(state: value)),
          ),
          if (requiresEmail)
            _field(
              name: 'email',
              label: copy.email,
              value: address.email,
              keyboardType: TextInputType.emailAddress,
              onChanged: (String value) =>
                  onChanged(address.copyWith(email: value)),
            ),
          _field(
            name: 'phone',
            label: requiresPhone ? copy.phone : copy.phoneOptional,
            value: address.phone,
            keyboardType: TextInputType.phone,
            onChanged: (String value) =>
                onChanged(address.copyWith(phone: value)),
          ),
        ];

        if (!twoColumns) {
          return Column(
            children: fields
                .expand(
                  (Widget field) => <Widget>[field, const SizedBox(height: 12)],
                )
                .toList(growable: false),
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: fields
              .map(
                (Widget field) => SizedBox(
                  width: (constraints.maxWidth - 12) / 2,
                  child: field,
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _field({
    required String name,
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    final String fieldKey = '$keyPrefix.$name';
    return TextFormField(
      key: Key('checkout-$keyPrefix-$name'),
      initialValue: value,
      enabled: enabled,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      onChanged: onChanged,
      validator: (_) => _localizedError(copy, fieldKey, errorFor(fieldKey)),
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _stateField({
    required String name,
    required String label,
    required String value,
    required String country,
    required ValueChanged<String> onChanged,
  }) {
    final String fieldKey = '$keyPrefix.$name';
    final Map<String, String> states = CheckoutCountryData.statesFor(country);
    if (states.isEmpty) {
      return _field(
        name: name,
        label: label,
        value: value,
        onChanged: onChanged,
      );
    }
    return DropdownButtonFormField<String>(
      key: Key('checkout-$keyPrefix-$name'),
      initialValue: states.containsKey(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        errorText: _localizedError(copy, fieldKey, errorFor(fieldKey)),
      ),
      hint: Text(copy.chooseGovernorate),
      items: states.entries
          .map(
            (MapEntry<String, String> state) => DropdownMenuItem<String>(
              value: state.key,
              child: Text(state.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: enabled ? (String? next) => onChanged(next ?? '') : null,
    );
  }
}

class _ShippingSection extends StatelessWidget {
  const _ShippingSection({required this.controller, required this.copy});
  final CheckoutController controller;
  final _CheckoutCopy copy;
  @override
  Widget build(BuildContext context) => _CheckoutSection(
    title: copy.shipping,
    icon: Icons.local_shipping_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.isUpdatingShipping) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(copy.calculatingShipping),
        ] else if (!controller.shippingQuoteCurrent ||
            controller.cart!.hasCalculatedShipping != true)
          Text(copy.shippingAddressNeeded)
        else if (controller.cart!.shippingPackages.isEmpty ||
            controller.cart!.shippingPackages.any(
              (package) => package.rates.isEmpty,
            ))
          Text(copy.noShippingRates),
        if (controller.shippingQuoteCurrent)
          for (final package in controller.cart!.shippingPackages) ...[
            if (controller.cart!.shippingPackages.length > 1)
              Text(package.name),
            for (final rate in package.rates)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PaymentMethodTile(
                  methodId: 'shipping-${package.id}-${rate.id}',
                  label:
                      '${rate.name} — ${_formatMinor((BigInt.parse(rate.priceMinor) + BigInt.parse(rate.taxMinor)).toString(), rate.currency)}',
                  selected: rate.selected,
                  enabled:
                      !controller.isSubmitting &&
                      !controller.hasUnresolvedSubmission,
                  onTap: () =>
                      controller.selectShippingRate(package.id, rate.id),
                ),
              ),
          ],
        if (controller.addressUpdateError != null) ...[
          _InlineError(message: controller.addressUpdateError!),
          TextButton(
            onPressed: controller.refreshShipping,
            child: Text(copy.retry),
          ),
        ],
      ],
    ),
  );
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.controller, required this.copy});

  final CheckoutController controller;
  final _CheckoutCopy copy;

  @override
  Widget build(BuildContext context) {
    final inline = _InlineCheckoutCardScope.of(context);
    return _CheckoutSection(
      title: copy.payment,
      icon: Icons.payments_outlined,
      child: controller.needsPayment
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (controller.paymentMethodIds.isEmpty)
                  _InlineError(message: copy.noPaymentMethods)
                else
                  for (final String method in controller.paymentMethodIds)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PaymentMethodTile(
                        methodId: method,
                        label:
                            controller.paymentMethodLabel(method) ??
                            copy.paymentMethodLabel(method),
                        selected: controller.paymentMethodId == method,
                        enabled:
                            !controller.isSubmitting &&
                            controller.paymentMethodSupported(method),
                        onTap: () => controller.setPaymentMethod(method),
                        trailing:
                            controller
                                    .checkout
                                    ?.nativePaymentAdapters[method] ==
                                'kashier'
                            ? const CardBrandIcon(iconHeight: 17)
                            : null,
                        expandedChild:
                            controller.paymentMethodId == method &&
                                controller
                                        .checkout
                                        ?.nativePaymentAdapters[method] ==
                                    'kashier' &&
                                inline != null
                            ? KashierInlineCardForm(
                                key: const Key('checkout-inline-card'),
                                controller: inline.card,
                                enabled:
                                    !inline.processing &&
                                    !controller.isSubmitting,
                              )
                            : null,
                      ),
                    ),
                if (controller.errorFor('paymentMethod') != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    _localizedError(
                      copy,
                      'paymentMethod',
                      controller.errorFor('paymentMethod'),
                    )!,
                    key: const Key('checkout-payment-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  copy.gatewayDisclaimer,
                  key: const Key('checkout-gateway-disclaimer'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            )
          : Row(
              children: <Widget>[
                const Icon(Icons.check_circle_outline),
                const SizedBox(width: 8),
                Expanded(child: Text(copy.noPaymentRequired)),
              ],
            ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.methodId,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.expandedChild,
    this.trailing,
  });

  final String methodId;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget? expandedChild;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? const Color(0xfff5f5f5) : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('checkout-payment-$methodId'),
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
          if (expandedChild != null) ...[
            const Divider(height: 1, color: Color(0xffdddddd)),
            Padding(padding: const EdgeInsets.all(16), child: expandedChild!),
          ],
        ],
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.controller,
    required this.copy,
    required this.onSubmit,
    this.onReviewOrders,
    required this.onRecover,
  });

  final CheckoutController controller;
  final _CheckoutCopy copy;
  final VoidCallback onSubmit;
  final VoidCallback? onReviewOrders;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    final Cart cart = controller.cart!;
    final inline =
        controller.checkout?.nativePaymentAdapters[controller
            .paymentMethodId] ==
        'kashier';
    return _CheckoutSection(
      title: copy.summary,
      icon: Icons.shopping_bag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SummaryLine(
            label: copy.items(cart.itemsCount),
            value: _formatMinor(cart.totals.itemsMinor, cart.totals.currency),
          ),
          if (cart.totals.discountMinor != '0')
            _SummaryLine(
              label: copy.discount,
              value:
                  '-${_formatMinor(cart.totals.discountMinor, cart.totals.currency)}',
            ),
          _SummaryLine(
            label: copy.shipping,
            value:
                controller.needsShipping &&
                    (!controller.shippingQuoteCurrent ||
                        !cart.hasCalculatedShipping)
                ? copy.shippingPending
                : _formatMinor(cart.totals.shippingMinor, cart.totals.currency),
          ),
          if (controller.isUpdatingShipping) ...<Widget>[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 6),
            Text(
              copy.calculatingShipping,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (controller.addressUpdateError != null) ...<Widget>[
            const SizedBox(height: 10),
            _InlineError(message: controller.addressUpdateError!),
          ],
          const Divider(height: 26),
          _SummaryLine(
            label: copy.total,
            value: _formatMinor(cart.totals.priceMinor, cart.totals.currency),
            emphasized: true,
          ),
          if (controller.errorFor('cart') != null) ...<Widget>[
            const SizedBox(height: 10),
            _InlineError(message: copy.emptyCart),
          ],
          if (controller.submitError != null) ...<Widget>[
            const SizedBox(height: 10),
            _InlineError(
              key: const Key('checkout-submit-error'),
              message: controller.hasUnresolvedSubmission
                  ? copy.unresolvedOrder
                  : copy.orderSubmissionError(controller.submitError!),
            ),
          ],
          if (controller.checkout?.serverSafetyRequired == true &&
              controller.checkout?.serverSafetyEnforced != true) ...<Widget>[
            const SizedBox(height: 10),
            _InlineError(
              key: const Key('checkout-safety-unavailable'),
              message: copy.safetyUnavailable,
            ),
          ],
          if (controller.hasUnresolvedSubmission &&
              (controller.canRecoverOrder ||
                  controller.isRecoveringOrder)) ...<Widget>[
            const SizedBox(height: 10),
            _RecoverOrderButton(
              copy: copy,
              onRecover: controller.canRecoverOrder ? onRecover : null,
              recovering: controller.isRecoveringOrder,
            ),
          ],
          if (controller.hasUnresolvedSubmission &&
              onReviewOrders != null) ...<Widget>[
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('checkout-review-orders'),
              onPressed: onReviewOrders,
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(copy.reviewOrders),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('checkout-place-order'),
            onPressed:
                controller.canSubmit &&
                    !controller.isSubmitting &&
                    !controller.isUpdatingCustomer
                ? onSubmit
                : null,
            icon: controller.isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_outline),
            label: Text(
              controller.isSubmitting
                  ? copy.placingOrder
                  : inline
                  ? copy.payAndPlaceOrder
                  : copy.placeOrder,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = emphasized
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _CheckoutDesignScope extends InheritedWidget {
  const _CheckoutDesignScope({required this.design, required super.child});

  final CheckoutDesign design;

  static CheckoutDesign of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_CheckoutDesignScope>()
            ?.design ??
        CheckoutDesign.classic;
  }

  @override
  bool updateShouldNotify(_CheckoutDesignScope oldWidget) {
    return oldWidget.design != design;
  }
}

class _CheckoutSection extends StatelessWidget {
  const _CheckoutSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final CheckoutDesign design = _CheckoutDesignScope.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double padding = design == CheckoutDesign.compact ? 12 : 0;
    final Widget content = Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (design == CheckoutDesign.compact) ...[
                Icon(icon, size: 19),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: design == CheckoutDesign.compact ? 18 : 22,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: design == CheckoutDesign.compact ? 10 : 16),
          child,
        ],
      ),
    );
    if (design == CheckoutDesign.compact) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: content,
      );
    }
    if (design == CheckoutDesign.classic) return content;
    return Card(
      margin: EdgeInsets.zero,
      color: design == CheckoutDesign.summaryFirst
          ? colors.surfaceContainerLowest
          : null,
      shape: design == CheckoutDesign.summaryFirst
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.primary.withValues(alpha: .28)),
            )
          : null,
      child: content,
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutLoading extends StatelessWidget {
  const _CheckoutLoading({required this.copy});

  final _CheckoutCopy copy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(copy.loading),
        ],
      ),
    );
  }
}

class _CheckoutFailure extends StatelessWidget {
  const _CheckoutFailure({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: 58,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              key: const Key('checkout-load-error'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.tonal(
              key: const Key('checkout-retry'),
              onPressed: onRetry,
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCheckout extends StatelessWidget {
  const _EmptyCheckout({
    required this.copy,
    this.onBack,
    this.unresolved = false,
    this.onReviewOrders,
    this.onRecover,
    this.recovering = false,
  });

  final _CheckoutCopy copy;
  final VoidCallback? onBack;
  final bool unresolved;
  final VoidCallback? onReviewOrders;
  final VoidCallback? onRecover;
  final bool recovering;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              unresolved
                  ? Icons.help_outline
                  : Icons.remove_shopping_cart_outlined,
              size: 64,
            ),
            const SizedBox(height: 16),
            if (unresolved) ...<Widget>[
              _InlineError(
                key: const Key('checkout-submit-error'),
                message: copy.unresolvedOrder,
              ),
              const SizedBox(height: 12),
              if (onRecover != null || recovering)
                _RecoverOrderButton(
                  copy: copy,
                  onRecover: onRecover,
                  recovering: recovering,
                ),
              if (onReviewOrders != null)
                TextButton.icon(
                  key: const Key('checkout-review-orders'),
                  onPressed: onReviewOrders,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(copy.reviewOrders),
                ),
            ],
            if (!unresolved) Text(copy.emptyCart, textAlign: TextAlign.center),
            if (onBack != null) ...<Widget>[
              const SizedBox(height: 18),
              FilledButton.tonal(
                key: const Key('checkout-back-to-cart'),
                onPressed: onBack,
                child: Text(copy.backToCart),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecoverOrderButton extends StatelessWidget {
  const _RecoverOrderButton({
    required this.copy,
    required this.onRecover,
    required this.recovering,
  });
  final _CheckoutCopy copy;
  final VoidCallback? onRecover;
  final bool recovering;
  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    key: const Key('checkout-recover-order'),
    onPressed: recovering ? null : onRecover,
    icon: recovering
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.manage_search_outlined),
    label: Text(recovering ? copy.recoveringOrder : copy.recoverOrder),
  );
}

class _CheckoutSuccess extends StatelessWidget {
  const _CheckoutSuccess({required this.result, required this.copy});

  final CheckoutOrderResult result;
  final _CheckoutCopy copy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.check_circle_rounded,
              size: 84,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              copy.orderReceived,
              key: const Key('checkout-success'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(copy.orderNumber(result.orderId)),
          ],
        ),
      ),
    );
  }
}

String? _localizedError(_CheckoutCopy copy, String field, String? rawError) {
  if (rawError == null) {
    return null;
  }
  if (field.endsWith('firstName')) {
    return copy.firstNameRequired;
  }
  if (field.endsWith('lastName')) {
    return copy.lastNameRequired;
  }
  if (field.endsWith('address1')) {
    return copy.addressRequired;
  }
  if (field.endsWith('city')) {
    return copy.cityRequired;
  }
  if (field.endsWith('state')) {
    return copy.stateRequired;
  }
  if (field.endsWith('country')) {
    return rawError.contains('two-letter')
        ? copy.countryInvalid
        : copy.countryRequired;
  }
  if (field.endsWith('email')) {
    return rawError.contains('valid') ? copy.emailInvalid : copy.emailRequired;
  }
  if (field.endsWith('phone')) {
    return copy.phoneRequired;
  }
  if (field == 'paymentMethod') {
    return copy.paymentRequired;
  }
  if (field == 'customerNote') {
    return copy.noteTooLong;
  }
  return rawError;
}

String _formatMinor(String rawMinor, CartCurrency currency) {
  final BigInt? parsed = BigInt.tryParse(rawMinor.trim());
  if (parsed == null) {
    return rawMinor;
  }
  final bool negative = parsed.isNegative;
  final String absolute = parsed.abs().toString();
  final int scale = currency.minorUnit < 0
      ? 0
      : currency.minorUnit > 8
      ? 8
      : currency.minorUnit;
  final String amount;
  if (scale == 0) {
    amount = '${negative ? '-' : ''}$absolute';
  } else {
    final String padded = absolute.padLeft(scale + 1, '0');
    final int splitAt = padded.length - scale;
    amount =
        '${negative ? '-' : ''}${padded.substring(0, splitAt)}${currency.decimalSeparator}${padded.substring(splitAt)}';
  }
  if (currency.prefix.isEmpty &&
      currency.suffix.isEmpty &&
      currency.symbol.isNotEmpty) {
    return '${currency.symbol}$amount';
  }
  return '${currency.prefix}$amount${currency.suffix}';
}

class _CheckoutCopy {
  const _CheckoutCopy._(this.arabic);

  final bool arabic;

  static _CheckoutCopy of(BuildContext context) {
    return _CheckoutCopy._(
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar',
    );
  }

  String get title => arabic ? 'إتمام الطلب' : 'Checkout';
  String get unresolvedOrder => arabic
      ? 'ممكن يكون المتجر استلم طلبك، لكن لم نتأكد من النتيجة. راجع طلباتك أو تواصل مع المتجر قبل إنشاء طلب آخر. إعادة الإرسال متوقفة لتجنب تكرار الطلب.'
      : 'The store may have received this order, but its result could not be confirmed. '
            'Check your order history or contact the store before placing another order. '
            'Retrying is disabled here to avoid a duplicate.';
  String get reviewOrders => arabic ? 'راجع طلباتي' : 'Review my orders';
  String orderSubmissionError(String message) =>
      arabic &&
          message ==
              'The store confirmed that the previous attempt was rejected before payment. Review current totals and confirm again.'
      ? 'المتجر أكد إن المحاولة السابقة اترفضت قبل الدفع. راجع الإجمالي الحالي وأكّد الطلب من جديد.'
      : message;
  String get recoverOrder =>
      arabic ? 'تحقق من نتيجة الطلب' : 'Check this order result';
  String get recoveringOrder =>
      arabic ? 'جارٍ التحقق من نتيجة الطلب…' : 'Checking this order result…';
  String get safetyUnavailable => arabic
      ? 'تأكيد الطلب متوقف مؤقتًا لأن حماية الشراء على المتجر لم يتم التحقق منها. يمكنك مراجعة السلة، ولن نرسل طلبًا بدون التحقق.'
      : 'Order confirmation is temporarily unavailable because the store checkout safety contract is unverified. You can review the cart; no order will be sent without verification.';
  String get previewOnly => arabic
      ? 'معاينة فقط — لم يتم إنشاء طلب.'
      : 'Preview only — no order was created.';
  String get loading => arabic ? 'جارٍ تحميل الطلب…' : 'Loading checkout…';
  String get loadFailure => arabic
      ? 'تعذر تحميل صفحة الدفع. حاول مرة أخرى.'
      : 'Unable to load checkout. Please try again.';
  String get retry => arabic ? 'إعادة المحاولة' : 'Retry';
  String get billingAddress => arabic ? 'عنوان الفاتورة' : 'Billing address';
  String get shippingAddress => arabic ? 'عنوان الشحن' : 'Shipping address';
  String get differentShipping =>
      arabic ? 'الشحن إلى عنوان مختلف' : 'Ship to a different address';
  String get differentShippingHint => arabic
      ? 'استخدم عنوان الفاتورة عند إيقاف هذا الخيار.'
      : 'Billing address is used when this is off.';
  String get firstName => arabic ? 'الاسم الأول' : 'First name';
  String get lastName => arabic ? 'اسم العائلة' : 'Last name';
  String get companyOptional =>
      arabic ? 'الشركة (اختياري)' : 'Company (optional)';
  String get address1 => arabic ? 'عنوان الشارع' : 'Street address';
  String get address2Optional => arabic
      ? 'تفاصيل إضافية للعنوان (اختياري)'
      : 'Apartment, suite, etc. (optional)';
  String get city => arabic ? 'المدينة' : 'City';
  String get state => arabic ? 'المحافظة *' : 'State *';
  String get chooseGovernorate => arabic ? 'اختر المحافظة' : 'Choose a state';
  String get countryCode =>
      arabic ? 'كود الدولة من حرفين' : 'Two-letter country code';
  String get email => arabic ? 'البريد الإلكتروني' : 'Email';
  String get phone => arabic ? 'الهاتف *' : 'Phone *';
  String get phoneOptional => arabic ? 'الهاتف (اختياري)' : 'Phone (optional)';
  String get orderNote => arabic ? 'ملاحظة الطلب' : 'Order note';
  String get orderNoteHint =>
      arabic ? 'ملاحظات اختيارية عن طلبك.' : 'Optional notes about your order.';
  String get payment => arabic ? 'طريقة الدفع' : 'Payment';
  String get noPaymentMethods => arabic
      ? 'لا توجد طريقة دفع متاحة من المتجر لهذا الطلب.'
      : 'The store returned no payment method for this order.';
  String get noPaymentRequired => arabic
      ? 'هذا الطلب لا يحتاج إلى دفع.'
      : 'No payment is required for this order.';
  String get gatewayDisclaimer => arabic
      ? 'اختَر طريقة الدفع المناسبة.'
      : 'Choose your preferred payment method.';
  String get summary => arabic ? 'ملخص الطلب' : 'Order summary';
  String get discount => arabic ? 'الخصم' : 'Discount';
  String get shipping => arabic ? 'الشحن' : 'Shipping';
  String get shippingPending => arabic ? 'لم يُحسب بعد' : 'Not calculated yet';
  String get shippingAddressNeeded => arabic
      ? 'حدد عنوان التوصيل لعرض خيارات الشحن وأسعارها.'
      : 'Enter your delivery address to see shipping options and prices.';
  String get noShippingRates => arabic
      ? 'لا تتوفر طريقة شحن لهذا العنوان. راجع العنوان أو تواصل مع المتجر.'
      : 'No shipping option is available for this address. Check the address or contact the store.';
  String get calculatingShipping => arabic
      ? 'جارٍ حساب الشحن حسب المحافظة والعنوان…'
      : 'Calculating shipping for this address…';
  String get total => arabic ? 'الإجمالي' : 'Total';
  String get placeOrder => arabic ? 'تأكيد الطلب' : 'Place order';
  String get payAndPlaceOrder =>
      arabic ? 'الدفع وتأكيد الطلب' : 'Pay and place order';
  String get completingPayment => arabic
      ? 'جارٍ إتمام الدفع وتأكيد الطلب…'
      : 'Completing payment and confirming your order…';
  String get placingOrder => arabic ? 'جارٍ تأكيد الطلب…' : 'Placing order…';
  String get emptyCart => arabic ? 'سلة التسوق فارغة.' : 'Your cart is empty.';
  String get backToCart => arabic ? 'العودة إلى السلة' : 'Back to cart';
  String get orderReceived => arabic ? 'تم استلام طلبك' : 'Order received';
  String get firstNameRequired =>
      arabic ? 'الاسم الأول مطلوب.' : 'First name is required.';
  String get lastNameRequired =>
      arabic ? 'اسم العائلة مطلوب.' : 'Last name is required.';
  String get addressRequired =>
      arabic ? 'عنوان الشارع مطلوب.' : 'Street address is required.';
  String get cityRequired => arabic ? 'المدينة مطلوبة.' : 'City is required.';
  String get stateRequired => arabic ? 'اختر المحافظة.' : 'Choose a state.';
  String get countryRequired =>
      arabic ? 'كود الدولة مطلوب.' : 'Country code is required.';
  String get countryInvalid =>
      arabic ? 'استخدم كود دولة من حرفين.' : 'Use a two-letter country code.';
  String get emailRequired =>
      arabic ? 'البريد الإلكتروني مطلوب.' : 'Email is required.';
  String get emailInvalid => arabic
      ? 'أدخل بريدًا إلكترونيًا صحيحًا.'
      : 'Enter a valid email address.';
  String get phoneRequired =>
      arabic ? 'رقم الهاتف مطلوب.' : 'Phone is required.';
  String get paymentRequired =>
      arabic ? 'اختر طريقة الدفع.' : 'Choose a payment method.';
  String get noteTooLong =>
      arabic ? 'ملاحظة الطلب طويلة جدًا.' : 'The order note is too long.';

  String items(int count) => arabic ? '$count منتج' : '$count items';
  String orderNumber(int orderId) =>
      arabic ? 'رقم الطلب: $orderId' : 'Order number: $orderId';

  String paymentMethodLabel(String methodId) {
    return switch (methodId.toLowerCase()) {
      'cod' => arabic ? 'الدفع عند الاستلام' : 'Cash on delivery',
      'bacs' => arabic ? 'تحويل بنكي مباشر' : 'Direct bank transfer',
      'cheque' => arabic ? 'الدفع بشيك' : 'Check payments',
      'paypal' => 'PayPal',
      _ => methodId,
    };
  }
}
