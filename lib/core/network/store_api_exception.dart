enum StoreApiFailureKind {
  configuration,
  timeout,
  connection,
  cancelled,
  certificate,
  unauthorized,
  notFound,
  server,
  invalidResponse,
  unknown,
}

class StoreApiException implements Exception {
  const StoreApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.cause,
  });

  final StoreApiFailureKind kind;
  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}
