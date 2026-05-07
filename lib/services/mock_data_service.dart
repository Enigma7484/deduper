import '../models/duplicate_group.dart';
import '../models/photo_item.dart';

class MockDataService {
  List<DuplicateGroup> getDemoGroups() {
    final now = DateTime.now();

    return [
      DuplicateGroup([
        PhotoItem(
          id: 'g1_1',
          title: 'Beach Shot Original',
          width: 3024,
          height: 4032,
          createdAt: now.subtract(const Duration(days: 1)),
          filePath: null,
          perceptualHash: '1010101010101010',
          qualityScore: 94,
          estimatedBytes: 4200000,
        ),
        PhotoItem(
          id: 'g1_2',
          title: 'Beach Shot WhatsApp Copy',
          width: 2048,
          height: 2732,
          createdAt: now.subtract(const Duration(days: 1)),
          filePath: null,
          perceptualHash: '1010101010101011',
          qualityScore: 51,
          estimatedBytes: 1800000,
        ),
        PhotoItem(
          id: 'g1_3',
          title: 'Beach Screenshot',
          width: 1170,
          height: 2532,
          createdAt: now.subtract(const Duration(days: 1)),
          filePath: null,
          perceptualHash: '1010101010101111',
          qualityScore: 38,
          estimatedBytes: 1300000,
        ),
      ]),
      DuplicateGroup([
        PhotoItem(
          id: 'g2_1',
          title: 'Cat Pic Sharp',
          width: 3000,
          height: 4000,
          createdAt: now.subtract(const Duration(days: 3)),
          filePath: null,
          perceptualHash: '1111000011110000',
          qualityScore: 91,
          estimatedBytes: 3700000,
        ),
        PhotoItem(
          id: 'g2_2',
          title: 'Cat Pic Blurry',
          width: 3000,
          height: 4000,
          createdAt: now.subtract(const Duration(days: 3)),
          filePath: null,
          perceptualHash: '1111000011110001',
          qualityScore: 62,
          estimatedBytes: 3400000,
        ),
      ]),
      DuplicateGroup([
        PhotoItem(
          id: 'g3_1',
          title: 'Document Original',
          width: 1440,
          height: 1920,
          createdAt: now.subtract(const Duration(days: 7)),
          filePath: null,
          perceptualHash: '0000111100001111',
          qualityScore: 46,
          estimatedBytes: 900000,
        ),
        PhotoItem(
          id: 'g3_2',
          title: 'Document Compressed Copy',
          width: 720,
          height: 960,
          createdAt: now.subtract(const Duration(days: 7)),
          filePath: null,
          perceptualHash: '0000111100001110',
          qualityScore: 21,
          estimatedBytes: 460000,
        ),
      ]),
    ];
  }
}
