class PhotoItem {
  final String id;
  final String title;
  final int width;
  final int height;
  final DateTime? createdAt;
  final String? filePath;
  final String perceptualHash;
  final double qualityScore;

  const PhotoItem({
    required this.id,
    required this.title,
    required this.width,
    required this.height,
    required this.createdAt,
    required this.filePath,
    required this.perceptualHash,
    required this.qualityScore,
  });

  int get resolution => width * height;
}