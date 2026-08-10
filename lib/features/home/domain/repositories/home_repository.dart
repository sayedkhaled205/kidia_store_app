import 'package:mobishop_store_app/features/home/domain/entities/home_layout.dart';

abstract interface class HomeRepository {
  Future<HomeLayout> getHomeLayout({
    required String locale,
  });
}
