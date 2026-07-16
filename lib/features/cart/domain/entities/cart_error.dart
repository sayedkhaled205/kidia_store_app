class CartError {
  const CartError({required this.code, required this.message, this.statusCode});

  final String code;
  final String message;
  final int? statusCode;
}

enum CartFailureKind {
  invalidInput,
  configuration,
  timeout,
  connection,
  cancelled,
  certificate,
  unauthorized,
  notFound,
  conflict,
  server,
  invalidResponse,
  unknown,
}
