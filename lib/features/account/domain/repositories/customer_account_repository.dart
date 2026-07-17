import 'package:kidia_store_app/features/account/domain/entities/customer_account.dart';

abstract interface class CustomerAccountRepository {
  Future<CustomerAccount> getAccount();

  Future<CustomerProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String displayName,
    required String email,
    required String phone,
    required String alternatePhone,
  });

  Future<CustomerAddress> updateAddress(CustomerAddress address);
}

enum CustomerAccountFailureKind {
  configuration,
  invalidInput,
  unauthorized,
  conflict,
  timeout,
  connection,
  certificate,
  server,
  invalidResponse,
  unknown,
}

class CustomerAccountRepositoryException implements Exception {
  const CustomerAccountRepositoryException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.cause,
  });

  final CustomerAccountFailureKind kind;
  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}
