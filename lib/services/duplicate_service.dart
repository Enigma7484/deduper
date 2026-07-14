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
    final visited = <int>{};

    for (int i = 0; i < items.length; i++) {
      if (visited.contains(i)) continue;

      final component = <int>[];
      final queue = <int>[i];
      visited.add(i);

      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        component.add(current);

        for (int j = 0; j < items.length; j++) {
          if (visited.contains(j)) continue;

          final dist = _hashService.hammingDistanceBetween(
            items[current].perceptualHash,
            items[j].perceptualHash,
          );

          if (dist <= threshold) {
            visited.add(j);
            queue.add(j);
          }
        }
      }

      if (component.length > 1) {
        groups.add(DuplicateGroup(component.map((index) => items[index]).toList()));
      }
    }

    return groups;
  }
}
