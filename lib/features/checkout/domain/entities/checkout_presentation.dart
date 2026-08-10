/// Checkout layout choices persisted by the MobiShop builder.
enum CheckoutDesign {
  classic('classic'),
  summaryFirst('summary_first'),
  compact('compact');

  const CheckoutDesign(this.apiValue);

  final String apiValue;

  factory CheckoutDesign.fromApi(dynamic value) {
    return CheckoutDesign.values.firstWhere(
      (CheckoutDesign design) => design.apiValue == value?.toString(),
      orElse: () => CheckoutDesign.classic,
    );
  }
}

class CheckoutPresentation {
  const CheckoutPresentation({this.design = CheckoutDesign.classic});

  final CheckoutDesign design;

  factory CheckoutPresentation.fromJson(Map<String, dynamic> json) {
    return CheckoutPresentation(
      design: CheckoutDesign.fromApi(json['design']),
    );
  }
}
