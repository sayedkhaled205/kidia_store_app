import 'package:flutter/material.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_totals.dart';
import 'package:kidia_store_app/features/checkout/application/checkout_controller.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_address.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:kidia_store_app/features/checkout/domain/repositories/checkout_repository.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    required this.repository,
    super.key,
    this.onOrderSuccess,
    this.onBackToCart,
  });

  final CheckoutRepository repository;
  final ValueChanged<CheckoutOrderResult>? onOrderSuccess;
  final VoidCallback? onBackToCart;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late CheckoutController _controller;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  @override
  void didUpdateWidget(CheckoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _controller.removeListener(_onControllerChanged);
      _controller.dispose();
      _createController();
    }
  }

  void _createController() {
    _controller = CheckoutController(repository: widget.repository)
      ..addListener(_onControllerChanged);
    _controller.load();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _CheckoutCopy copy = _CheckoutCopy.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(copy.title)),
      body: _buildBody(copy),
    );
  }

  Widget _buildBody(_CheckoutCopy copy) {
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
        return _CheckoutSuccess(result: _controller.orderResult!, copy: copy);
      case CheckoutStatus.ready:
      case CheckoutStatus.submitting:
        final Cart? cart = _controller.cart;
        if (cart == null || cart.isEmpty) {
          return _EmptyCheckout(copy: copy, onBack: widget.onBackToCart);
        }
        return _CheckoutReady(
          formKey: _formKey,
          controller: _controller,
          copy: copy,
          onSubmit: _submit,
        );
    }
  }

  Future<void> _submit() async {
    final bool controllerValid = _controller.validate();
    final bool formValid = _formKey.currentState?.validate() ?? false;
    if (!controllerValid || !formValid) {
      return;
    }
    final CheckoutOrderResult? result = await _controller.submit();
    if (!mounted || result == null) {
      return;
    }
    widget.onOrderSuccess?.call(result);
  }
}

class _CheckoutReady extends StatelessWidget {
  const _CheckoutReady({
    required this.formKey,
    required this.controller,
    required this.copy,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final CheckoutController controller;
  final _CheckoutCopy copy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 920;
        final Widget form = Form(
          key: formKey,
          child: _CheckoutForm(controller: controller, copy: copy),
        );
        final Widget summary = _OrderSummary(
          controller: controller,
          copy: copy,
          onSubmit: onSubmit,
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  key: const Key('checkout-form-scroll'),
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 16, 40),
                  child: form,
                ),
              ),
              SizedBox(
                width: 390,
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 24, 40),
                  child: summary,
                ),
              ),
            ],
          );
        }

        return SingleChildScrollView(
          key: const Key('checkout-form-scroll'),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 36),
          child: Column(
            children: <Widget>[form, const SizedBox(height: 18), summary],
          ),
        );
      },
    );
  }
}

class _CheckoutForm extends StatelessWidget {
  const _CheckoutForm({required this.controller, required this.copy});

  final CheckoutController controller;
  final _CheckoutCopy copy;

  @override
  Widget build(BuildContext context) {
    final bool enabled = !controller.isSubmitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _CheckoutSection(
          title: copy.billingAddress,
          icon: Icons.receipt_long_outlined,
          child: _AddressFields(
            keyPrefix: 'billing',
            address: controller.billingAddress,
            enabled: enabled,
            requiresEmail: true,
            copy: copy,
            errorFor: controller.errorFor,
            onChanged: controller.updateBillingAddress,
          ),
        ),
        if (controller.needsShipping) ...<Widget>[
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
        _PaymentSection(controller: controller, copy: copy),
      ],
    );
  }
}

class _AddressFields extends StatelessWidget {
  const _AddressFields({
    required this.keyPrefix,
    required this.address,
    required this.enabled,
    required this.requiresEmail,
    required this.copy,
    required this.errorFor,
    required this.onChanged,
  });

  final String keyPrefix;
  final CheckoutAddress address;
  final bool enabled;
  final bool requiresEmail;
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
          _field(
            name: 'state',
            label: copy.stateOptional,
            value: address.state,
            onChanged: (String value) =>
                onChanged(address.copyWith(state: value)),
          ),
          _field(
            name: 'postcode',
            label: copy.postcodeOptional,
            value: address.postcode,
            onChanged: (String value) =>
                onChanged(address.copyWith(postcode: value)),
          ),
          _field(
            name: 'country',
            label: copy.countryCode,
            value: address.country,
            capitalization: TextCapitalization.characters,
            onChanged: (String value) =>
                onChanged(address.copyWith(country: value)),
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
            label: copy.phoneOptional,
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
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.controller, required this.copy});

  final CheckoutController controller;
  final _CheckoutCopy copy;

  @override
  Widget build(BuildContext context) {
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
                        label: copy.paymentMethodLabel(method),
                        selected: controller.paymentMethodId == method,
                        enabled: !controller.isSubmitting,
                        onTap: () => controller.setPaymentMethod(method),
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
  });

  final String methodId;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
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
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.controller,
    required this.copy,
    required this.onSubmit,
  });

  final CheckoutController controller;
  final _CheckoutCopy copy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final Cart cart = controller.cart!;
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
            value: _formatMinor(
              cart.totals.shippingMinor,
              cart.totals.currency,
            ),
          ),
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
              message: controller.submitError!,
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('checkout-place-order'),
            onPressed: controller.canSubmit && !controller.isSubmitting
                ? onSubmit
                : null,
            icon: controller.isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_outline),
            label: Text(
              controller.isSubmitting ? copy.placingOrder : copy.placeOrder,
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
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
  const _EmptyCheckout({required this.copy, this.onBack});

  final _CheckoutCopy copy;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.remove_shopping_cart_outlined, size: 64),
            const SizedBox(height: 16),
            Text(copy.emptyCart, textAlign: TextAlign.center),
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
            if (result.requiresRedirect) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                copy.secureRedirect,
                key: const Key('checkout-redirect-required'),
                textAlign: TextAlign.center,
              ),
            ],
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
  if (field.endsWith('country')) {
    return rawError.contains('two-letter')
        ? copy.countryInvalid
        : copy.countryRequired;
  }
  if (field.endsWith('email')) {
    return rawError.contains('valid') ? copy.emailInvalid : copy.emailRequired;
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
  String get stateOptional =>
      arabic ? 'المحافظة (اختياري)' : 'State (optional)';
  String get postcodeOptional =>
      arabic ? 'الرمز البريدي (اختياري)' : 'Postcode (optional)';
  String get countryCode =>
      arabic ? 'كود الدولة من حرفين' : 'Two-letter country code';
  String get email => arabic ? 'البريد الإلكتروني' : 'Email';
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
      ? 'نعرض الطرق التي يرسلها المتجر فقط. أي بيانات خاصة ببوابة دفع أو بطاقة يجب أن تتم من خلال تكامل آمن مخصص أو صفحة تحويل.'
      : 'Only methods returned by the store are shown. Gateway-specific or card data requires a dedicated secure integration or redirect.';
  String get summary => arabic ? 'ملخص الطلب' : 'Order summary';
  String get discount => arabic ? 'الخصم' : 'Discount';
  String get shipping => arabic ? 'الشحن' : 'Shipping';
  String get total => arabic ? 'الإجمالي' : 'Total';
  String get placeOrder => arabic ? 'تأكيد الطلب' : 'Place order';
  String get placingOrder => arabic ? 'جارٍ تأكيد الطلب…' : 'Placing order…';
  String get emptyCart => arabic ? 'سلة التسوق فارغة.' : 'Your cart is empty.';
  String get backToCart => arabic ? 'العودة إلى السلة' : 'Back to cart';
  String get orderReceived => arabic ? 'تم استلام طلبك' : 'Order received';
  String get secureRedirect => arabic
      ? 'تحتاج طريقة الدفع إلى متابعة آمنة. سيعالج التطبيق رابط التحويل من خلال التكامل المخصص.'
      : 'Payment requires a secure next step. The app integration should handle the returned redirect.';
  String get firstNameRequired =>
      arabic ? 'الاسم الأول مطلوب.' : 'First name is required.';
  String get lastNameRequired =>
      arabic ? 'اسم العائلة مطلوب.' : 'Last name is required.';
  String get addressRequired =>
      arabic ? 'عنوان الشارع مطلوب.' : 'Street address is required.';
  String get cityRequired => arabic ? 'المدينة مطلوبة.' : 'City is required.';
  String get countryRequired =>
      arabic ? 'كود الدولة مطلوب.' : 'Country code is required.';
  String get countryInvalid =>
      arabic ? 'استخدم كود دولة من حرفين.' : 'Use a two-letter country code.';
  String get emailRequired =>
      arabic ? 'البريد الإلكتروني مطلوب.' : 'Email is required.';
  String get emailInvalid => arabic
      ? 'أدخل بريدًا إلكترونيًا صحيحًا.'
      : 'Enter a valid email address.';
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
