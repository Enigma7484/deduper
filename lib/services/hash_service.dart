import 'dart:io';

import 'package:image_hashing/image_hashing.dart';

class HashService {
  static final _hexPattern = RegExp(r'^[0-9a-fA-F]+$');
  static final _binaryPattern = RegExp(r'^[01]+$');

  Future<String> computeHash(File file) async {
    final hasher = AHash(useCV: false);
    final hash = hasher.encodeImage(file.path);

    if (hash == null || hash.isEmpty) {
      throw Exception('Failed to generate image hash for ${file.path}');
    }

    return normalizeHash(hash);
  }

  int hammingDistanceBetween(String a, String b) {
    return hammingDistance(normalizeHash(a), normalizeHash(b), size: 64);
  }

  String normalizeHash(String hash) {
    final normalized = hash.trim().toLowerCase();

    if (normalized.length == 64 && _binaryPattern.hasMatch(normalized)) {
      return BigInt.parse(normalized, radix: 2)
          .toRadixString(16)
          .padLeft(16, '0');
    }

    if (normalized.length <= 16 && _hexPattern.hasMatch(normalized)) {
      return normalized.padLeft(16, '0');
    }

    throw FormatException('Invalid image hash format', hash);
  }
}
