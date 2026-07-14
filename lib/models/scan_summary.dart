import 'duplicate_group.dart';
import 'photo_item.dart';

enum CleanupMode { similar, screenshots, large }

class ScanSummary {
  final List<DuplicateGroup> groups;
  final List<PhotoItem> candidates;
  final int scannedCount;
  final Duration elapsed;
  final CleanupMode mode;
  final String scopeLabel;

  const ScanSummary({
    required this.groups,
    this.candidates = const [],
    required this.scannedCount,
    required this.elapsed,
    this.mode = CleanupMode.similar,
    this.scopeLabel = 'Photo library',
  });

  int get opportunityCount =>
      mode == CleanupMode.similar ? duplicateCount : candidates.length;

  int get duplicateCount {
    return groups.fold(
        0, (sum, group) => sum + group.suggestedDuplicates.length);
  }

  int get reclaimableBytes {
    if (mode != CleanupMode.similar) {
      return candidates.fold(0, (sum, item) => sum + item.estimatedBytes);
    }
    return groups.fold(0, (sum, group) => sum + group.reclaimableBytes);
  }

  double get averageConfidence {
    if (groups.isEmpty) return 0;
    final total =
        groups.fold<double>(0, (sum, group) => sum + group.confidence);
    return total / groups.length;
  }
}
