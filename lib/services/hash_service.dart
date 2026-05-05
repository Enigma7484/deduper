import 'dart:io';
import 'package:image_hashing/image_hashing.dart';

class HashService {
  Future<String> computeHash(File file) async {
    final hasher = AHash(useCV: false);
    final hash = hasher.encodeImage(file.path);

    if (hash == null || hash.isEmpty) {
      throw Exception('Failed to generate image hash for ${file.path}');
    }

    return hash;
  }

  int hammingDistanceBetween(String a, String b) {
    return hammingDistance(a, b, size: 64);
  }
}