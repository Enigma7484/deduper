import 'package:deduper/models/photo_item.dart';
import 'package:deduper/services/duplicate_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groups near-identical perceptual hashes', () {
    final service = DuplicateService();
    final groups = service.groupSimilar(
      const [
        PhotoItem(
          id: 'a',
          title: 'A',
          width: 100,
          height: 100,
          createdAt: null,
          filePath: null,
          perceptualHash: '0000000000000000',
          qualityScore: 10,
          estimatedBytes: 100,
        ),
        PhotoItem(
          id: 'b',
          title: 'B',
          width: 100,
          height: 100,
          createdAt: null,
          filePath: null,
          perceptualHash: '0000000000000001',
          qualityScore: 8,
          estimatedBytes: 80,
        ),
        PhotoItem(
          id: 'c',
          title: 'C',
          width: 100,
          height: 100,
          createdAt: null,
          filePath: null,
          perceptualHash: '1111111111111111',
          qualityScore: 6,
          estimatedBytes: 60,
        ),
      ],
    );

    expect(groups, hasLength(1));
    expect(groups.first.best.id, 'a');
    expect(groups.first.reclaimableBytes, 80);
  });
}
