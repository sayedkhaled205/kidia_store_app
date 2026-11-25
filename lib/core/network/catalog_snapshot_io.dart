import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

const _prefix = 'catalog-gzip-v1:';
const _compressionThreshold = 32 * 1024;

/// SharedPreferences rewrites its backing file on Android. Keep large public
/// snapshots small without changing their data, timestamps or freshness rules.
Future<String> encodeCatalogSnapshot(String raw) async {
  if (raw.length < _compressionThreshold) return raw;
  return compute(_encode, raw, debugLabel: 'catalog-cache-encode');
}

String _encode(String raw) {
  final compressed = GZipCodec(level: 1).encode(utf8.encode(raw));
  final encoded = '$_prefix${base64Encode(compressed)}';
  return encoded.length < raw.length ? encoded : raw;
}

Future<String> decodeCatalogSnapshot(String raw, int maxCharacters) async {
  if (!raw.startsWith(_prefix)) return raw; // Legacy JSON remains readable.
  return compute(_decode, (
    raw,
    maxCharacters,
  ), debugLabel: 'catalog-cache-decode');
}

String _decode((String, int) input) {
  final (raw, maxCharacters) = input;
  // The existing cache limit counts UTF-16 units. A unit can require up to
  // three UTF-8 bytes; preserve Arabic/Chinese caches while bounding inflation.
  final output = _LimitedBytes(maxCharacters * 3);
  final compressed = base64Decode(raw.substring(_prefix.length));
  if (compressed.length < 18) {
    throw const FormatException('Truncated catalog snapshot');
  }
  final decoder = gzip.decoder.startChunkedConversion(output);
  decoder.add(compressed);
  decoder.close();
  final expectedBytes = ByteData.sublistView(
    compressed,
  ).getUint32(compressed.length - 4, Endian.little);
  if (expectedBytes != output.bytes.length) {
    throw const FormatException('Incomplete catalog snapshot');
  }
  final decoded = utf8.decode(output.bytes.takeBytes());
  if (decoded.length > maxCharacters) {
    throw const FormatException('Catalog snapshot exceeds its size limit');
  }
  return decoded;
}

class _LimitedBytes implements Sink<List<int>> {
  _LimitedBytes(this.limit);
  final int limit;
  final bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (chunk.length > limit - bytes.length) {
      throw const FormatException('Catalog snapshot exceeds its size limit');
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}
