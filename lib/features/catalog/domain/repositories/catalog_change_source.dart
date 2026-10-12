import 'dart:async';

/// Optional read-only data-change capability. Native repositories receive
/// verified platform invalidations; the embedded preview uses its trusted bridge.
abstract interface class CatalogChangeSource {
  Stream<int> get catalogChanges;
}
