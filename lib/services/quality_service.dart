class QualityService {
  double score({
    required int width,
    required int height,
  }) {
    return (width * height).toDouble();
  }
}