import 'package:kidia_store_app/features/home/data/models/home_block_model.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_layout.dart';

abstract final class HomeLayoutModel {
  const HomeLayoutModel._();

  static HomeLayout fromJson(Map<String, dynamic> json) {
    final int version = _requiredPositiveInt(
      json,
      'version',
    );

    final String page = _requiredString(
      json,
      'page',
    );

    final String locale = _requiredString(
      json,
      'locale',
    );

    final DateTime updatedAt = _requiredDateTime(
      json,
      'updated_at',
    );

    final List<HomeBlock> blocks = _parseBlocks(
      json,
      'blocks',
    );

    return HomeLayout(
      version: version,
      page: page,
      locale: locale,
      updatedAt: updatedAt,
      blocks: blocks,
    );
  }

  static List<HomeBlock> _parseBlocks(
      Map<String, dynamic> json,
      String key,
      ) {
    final dynamic value = json[key];

    if (value is! List) {
      throw FormatException(
        'Missing or invalid home layout list field: $key',
      );
    }

    final List<HomeBlock> blocks = <HomeBlock>[];

    for (int index = 0; index < value.length; index++) {
      final dynamic rawBlock = value[index];

      if (rawBlock is! Map) {
        throw FormatException(
          'Invalid home block at index $index.',
        );
      }

      try {
        final Map<String, dynamic> blockJson =
        Map<String, dynamic>.from(rawBlock);

        blocks.add(
          HomeBlockModel.fromJson(blockJson),
        );
      } on FormatException {
        // A single unknown or incomplete CMS block must not prevent
        // the remaining valid home blocks from rendering.
        continue;
      }
    }

    return List<HomeBlock>.unmodifiable(blocks);
  }

  static String _requiredString(
      Map<String, dynamic> json,
      String key,
      ) {
    final dynamic value = json[key];

    if (value is! String) {
      throw FormatException(
        'Missing or invalid string field: $key',
      );
    }

    final String normalized = value.trim();

    if (normalized.isEmpty) {
      throw FormatException(
        'String field cannot be empty: $key',
      );
    }

    return normalized;
  }

  static int _requiredPositiveInt(
      Map<String, dynamic> json,
      String key,
      ) {
    final dynamic value = json[key];

    final int? parsedValue = switch (value) {
      int number => number,
      num number => number.toInt(),
      String text => int.tryParse(text.trim()),
      _ => null,
    };

    if (parsedValue == null) {
      throw FormatException(
        'Missing or invalid integer field: $key',
      );
    }

    if (parsedValue <= 0) {
      throw FormatException(
        'Integer field must be greater than zero: $key',
      );
    }

    return parsedValue;
  }

  static DateTime _requiredDateTime(
      Map<String, dynamic> json,
      String key,
      ) {
    final String value = _requiredString(
      json,
      key,
    );

    final DateTime? parsedValue = DateTime.tryParse(value);

    if (parsedValue == null) {
      throw FormatException(
        'Invalid date field: $key',
      );
    }

    return parsedValue.toUtc();
  }
}