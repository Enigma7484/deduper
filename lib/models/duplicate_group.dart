import 'photo_item.dart';

class DuplicateGroup {
  final List<PhotoItem> items;

  const DuplicateGroup(this.items);

  PhotoItem get best {
    final sorted = [...items]
      ..sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
    return sorted.first;
  }

  List<PhotoItem> get suggestedDuplicates {
    final bestId = best.id;
    return items.where((item) => item.id != bestId).toList();
  }

  int get reclaimableBytes {
    return suggestedDuplicates.fold(0, (sum, item) => sum + item.estimatedBytes);
  }

  double get confidence {
    if (items.length >= 4) return 0.96;
    if (items.length == 3) return 0.91;
    return 0.84;
  }
}
