import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/shared_preferences_wishlist_repository.dart';
import '../domain/repositories/wishlist_repository.dart';

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return SharedPreferencesWishlistRepository.forConfiguredStore();
});
