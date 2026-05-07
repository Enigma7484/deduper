class QualityService {
  double score({
    required int width,
    required int height,
    required int fileBytes,
    DateTime? createdAt,
  }) {
    final megapixels = (width * height) / 1000000;
    final densityScore = megapixels * 22;
    final fileScore = fileBytes <= 0
        ? 0.0
        : (fileBytes / 1000000).clamp(0, 18).toDouble();
    final freshnessScore = createdAt == null
        ? 0
        : DateTime.now().difference(createdAt).inDays <= 30
            ? 3
            : 0;

    return densityScore + fileScore + freshnessScore;
  }
}
