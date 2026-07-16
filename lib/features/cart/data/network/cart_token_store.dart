abstract interface class CartTokenStore {
  String? read();

  void write(String token);

  void clear();
}

/// Cart tokens identify a shopper's cart and are intentionally kept in memory
/// by default. Applications that need process-restoration can inject a secure,
/// store-scoped implementation without changing the repository.
class MemoryCartTokenStore implements CartTokenStore {
  String? _token;

  @override
  String? read() => _token;

  @override
  void write(String token) {
    final String value = token.trim();
    if (value.isEmpty) {
      clear();
      return;
    }
    _token = value;
  }

  @override
  void clear() {
    _token = null;
  }
}
