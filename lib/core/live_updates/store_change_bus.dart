import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps Native consumers independent of auth/transport orchestration.
final class StoreCatalogChangeBus {
  final _catalog = StreamController<int>.broadcast();
  int _revision = 0;
  Stream<int> get catalogChanges => _catalog.stream;
  void notifyCatalogChanged() {
    if (!_catalog.isClosed) _catalog.add(++_revision);
  }

  void dispose() {
    unawaited(_catalog.close());
  }
}

final storeCatalogChangeBusProvider = Provider<StoreCatalogChangeBus>((
  Ref ref,
) {
  final bus = StoreCatalogChangeBus();
  ref.onDispose(bus.dispose);
  return bus;
});
