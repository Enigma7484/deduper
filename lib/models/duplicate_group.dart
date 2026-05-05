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
}