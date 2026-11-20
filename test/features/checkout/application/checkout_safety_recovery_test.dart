import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/checkout/application/checkout_controller.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_field_definition.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:mobishop_store_app/features/checkout/domain/repositories/checkout_repository.dart';
import '../support/checkout_test_data.dart';

final _custom = CheckoutFieldDefinition(
  key: 'delivery_hint',
  group: CheckoutFieldGroup.order,
  type: CheckoutFieldType.text,
  label: 'Delivery hint',
);
CheckoutState _state({bool enforced = false}) => CheckoutState(
  cart: checkoutCart(needsShipping: false, paymentMethods: ['cod', 'bacs']),
  serverSafetyRequired: true,
  serverSafetyEnforced: enforced,
  fieldDefinitions: [_custom],
);

class _SafetyRepository extends FakeCheckoutRepository
    implements CheckoutSafetyRepository {
  _SafetyRepository() : super(state: _state());
  int safetyCalls = 0;
  Completer<bool> gate = Completer<bool>();
  @override
  Future<bool> refreshCheckoutSafety() {
    safetyCalls++;
    return gate.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'duplicate safety taps share a read and preserve latest draft',
    () async {
      final repo = _SafetyRepository();
      final controller = CheckoutController(repository: repo);
      addTearDown(controller.dispose);
      await controller.load();
      controller.updateBillingAddress(
        controller.billingAddress.copyWith(address1: 'Draft street'),
      );
      controller.setCustomerNote('Draft note');
      controller.setPaymentMethod('bacs');
      controller.setFieldValue('delivery_hint', 'Draft instructions');
      final first = controller.refreshSafety();
      final second = controller.refreshSafety();
      expect(repo.safetyCalls, 1);
      expect(controller.isRefreshingSafety, true);
      expect(controller.canSubmit, false);
      controller.setCustomerNote('Edited during safety read');
      controller.setFieldValue('delivery_hint', 'Latest instructions');
      repo.gate.complete(true);
      await Future.wait([first, second]);
      expect(controller.billingAddress.address1, 'Draft street');
      expect(controller.customerNote, 'Edited during safety read');
      expect(controller.paymentMethodId, 'bacs');
      expect(controller.valueForField(_custom), 'Latest instructions');
      expect(controller.checkout!.serverSafetyEnforced, true);
      expect(
        repo.loadCalls,
        1,
        reason: 'Refreshing safety must not reload/reset checkout.',
      );
      expect(repo.submitCalls, 0);
    },
  );
  test(
    'failed safety retry remains available and starts no automatic loop',
    () async {
      final repo = _SafetyRepository();
      final controller = CheckoutController(repository: repo);
      addTearDown(controller.dispose);
      await controller.load();
      final first = controller.refreshSafety();
      repo.gate.completeError(
        const CheckoutRepositoryException(
          kind: CheckoutFailureKind.connection,
          message: 'Synthetic offline',
        ),
      );
      await first;
      expect(controller.canRefreshSafety, true);
      expect(controller.canSubmit, false);
      expect(repo.safetyCalls, 1);
      repo.gate = Completer<bool>();
      final second = controller.refreshSafety();
      repo.gate.complete(true);
      await second;
      expect(controller.checkout!.serverSafetyEnforced, true);
      expect(repo.safetyCalls, 2);
      expect(repo.submitCalls, 0);
    },
  );
  test('late safety result cannot overwrite a newer checkout load', () async {
    final repo = _SafetyRepository();
    final controller = CheckoutController(repository: repo);
    addTearDown(controller.dispose);
    await controller.load();
    final pending = controller.refreshSafety();
    repo.state = _state(enforced: false);
    await controller.load();
    repo.gate.complete(true);
    await pending;
    expect(controller.checkout!.serverSafetyEnforced, false);
    expect(controller.canRefreshSafety, true);
    expect(repo.submitCalls, 0);
  });
  test(
    'disposing during safety read commits nothing and throws nothing',
    () async {
      final repo = _SafetyRepository();
      final controller = CheckoutController(repository: repo);
      await controller.load();
      final pending = controller.refreshSafety();
      controller.dispose();
      repo.gate.complete(true);
      await pending;
      expect(repo.submitCalls, 0);
    },
  );
  for (final contradictoryProof in [false, true]) {
    test(
      'unknown POST stays locked even if not-dispatched proof=$contradictoryProof',
      () async {
        final repo = _SafetyRepository()..state = _state(enforced: true);
        repo.onSubmit = (_) async => throw CheckoutRepositoryException(
          kind: CheckoutFailureKind.connection,
          message: 'Synthetic uncertain dispatch',
          requiresOutcomeRecovery: true,
          confirmedNotDispatched: contradictoryProof,
        );
        final controller = CheckoutController(repository: repo);
        addTearDown(controller.dispose);
        await controller.load();
        controller.setPaymentMethod('cod');
        await controller.submit();
        expect(controller.hasUnresolvedSubmission, true);
        expect(controller.canRefreshSafety, false);
        await controller.refreshSafety();
        await controller.submit();
        expect(repo.submitCalls, 1);
        expect(repo.safetyCalls, 0);
      },
    );
  }
}
