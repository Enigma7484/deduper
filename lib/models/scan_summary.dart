import 'duplicate_group.dart';

class ScanSummary {
  final List<DuplicateGroup> groups;
  final int scannedCount;
  final Duration elapsed;

  const ScanSummary({
    required this.groups,
    required this.scannedCount,
    required this.elapsed,
  });

  int get duplicateCount {
    return groups.fold(0, (sum, group) => sum + group.suggestedDuplicates.length);
  }

  int get reclaimableBytes {
    return groups.fold(0, (sum, group) => sum + group.reclaimableBytes);
  }

  double get averageConfidence {
    if (groups.isEmpty) return 0;
    final total = groups.fold<double>(0, (sum, group) => sum + group.confidence);
    return total / groups.length;
  }
}
