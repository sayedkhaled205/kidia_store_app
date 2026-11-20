import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/account/domain/entities/customer_account.dart';
import 'package:mobishop_store_app/features/account/domain/repositories/customer_account_repository.dart';
import 'package:mobishop_store_app/features/account/presentation/providers/customer_account_providers.dart';

void main() {
  testWidgets(
    'account failure exposes retry without a background request loop',
    (tester) async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [
          customerAccountRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      container.listen(customerAccountProvider, (_, _) {});
      await tester.pump(const Duration(milliseconds: 1));
      expect(container.read(customerAccountProvider).hasError, true);
      expect(container.read(customerAccountProvider).isLoading, false);
      await tester.pump(const Duration(minutes: 1));
      expect(repository.reads, 1);
      repository.offline = false;
      container.invalidate(customerAccountProvider);
      expect(
        (await container.read(customerAccountProvider.future)).profile.id,
        1,
      );
      expect(repository.reads, 2);
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}

class _Repository implements CustomerAccountRepository {
  int reads = 0;
  bool offline = true;
  @override
  Future<CustomerAccount> getAccount() async {
    reads++;
    if (offline) {
      throw const CustomerAccountRepositoryException(
        kind: CustomerAccountFailureKind.connection,
        message: 'Offline',
      );
    }
    return CustomerAccount(
      profile: const CustomerProfile(id: 1, email: 'test@example.invalid'),
      billing: CustomerAddress(type: CustomerAddressType.billing),
      shipping: CustomerAddress(type: CustomerAddressType.shipping),
      support: const CustomerSupportDetails(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
