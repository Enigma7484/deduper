import 'package:deduper/services/hash_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes binary 64-bit hashes to 16-character hex', () {
    final service = HashService();

    expect(
      service.normalizeHash(
          '1111000011110000111100001111000011110000111100001111000011110000'),
      'f0f0f0f0f0f0f0f0',
    );
  });

  test('pads short hexadecimal hashes', () {
    final service = HashService();

    expect(service.normalizeHash('abc'), '0000000000000abc');
  });

  test('rejects non-hex and non-binary hash values', () {
    final service = HashService();

    expect(() => service.normalizeHash('hash-with-invalid-chars'),
        throwsFormatException);
  });
}
