// Browser storage keeps its existing JSON format; native gzip uses dart:io.
Future<String> encodeCatalogSnapshot(String raw) async => raw;

Future<String> decodeCatalogSnapshot(String raw, int maxCharacters) async =>
    raw;
