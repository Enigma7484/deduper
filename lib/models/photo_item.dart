class PhotoItem {
  final String id;
  final String title;
  final int width;
  final int height;
  final DateTime? createdAt;
  final String? filePath;
  final String perceptualHash;
  final double qualityScore;
  final int estimatedBytes;

  const PhotoItem({
    required this.id,
    required this.title,
    required this.width,
    required this.height,
    required this.createdAt,
    required this.filePath,
    required this.perceptualHash,
    required this.qualityScore,
    this.estimatedBytes = 0,
  });

  int get resolution => width * height;

  bool get isScreenshot {
    final lowerTitle = title.toLowerCase();
    return lowerTitle.contains('screenshot') ||
        width / height > 1.9 ||
        height / width > 1.9;
  }
}
