import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';

class HomeLayout {
  HomeLayout({
    required this.version,
    required this.page,
    required this.locale,
    required this.updatedAt,
    required List<HomeBlock> blocks,
  }) : blocks = List<HomeBlock>.unmodifiable(blocks);

  final int version;
  final String page;
  final String locale;
  final DateTime updatedAt;

  /// نسخة غير قابلة للتعديل لحماية ترتيب الـBlocks القادم من WordPress.
  final List<HomeBlock> blocks;

  List<HomeBlock> get enabledBlocks {
    return List<HomeBlock>.unmodifiable(
      blocks.where((HomeBlock block) => block.enabled),
    );
  }

  bool get isEmpty => enabledBlocks.isEmpty;

  bool get isNotEmpty => enabledBlocks.isNotEmpty;
}