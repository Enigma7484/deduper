import '../models/duplicate_group.dart';
import '../models/photo_item.dart';
import 'hash_service.dart';

class DuplicateService {
  final HashService _hashService = HashService();

  List<DuplicateGroup> groupSimilar(
    List<PhotoItem> items, {
    int threshold = 8,
  }) {
    final groups = <DuplicateGroup>[];
    final used = <int>{};

    for (int i = 0; i < items.length; i++) {
      if (used.contains(i)) continue;

      final currentGroup = <PhotoItem>[items[i]];
      used.add(i);

      for (int j = i + 1; j < items.length; j++) {
        if (used.contains(j)) continue;

        final dist = _hashService.hammingDistanceBetween(
          items[i].perceptualHash,
          items[j].perceptualHash,
        );

        if (dist <= threshold) {
          currentGroup.add(items[j]);
          used.add(j);
        }
      }

      if (currentGroup.length > 1) {
        groups.add(DuplicateGroup(currentGroup));
      }
    }

    return groups;
  }
}