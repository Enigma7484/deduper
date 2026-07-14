import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/duplicate_group.dart';
import '../models/photo_item.dart';
import '../models/scan_summary.dart';

class ScanCacheService {
  Future<void> save(ScanSummary summary) async {
    final file = await _cacheFile();
    final payload = {
      'scannedCount': summary.scannedCount,
      'elapsedMillis': summary.elapsed.inMilliseconds,
      'mode': summary.mode.name,
      'scopeLabel': summary.scopeLabel,
      'groups': summary.groups
          .map((group) => group.items.map(_photoToJson).toList())
          .toList(),
      'candidates': summary.candidates.map(_photoToJson).toList(),
    };

    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  Future<ScanSummary?> load() async {
    final file = await _cacheFile();
    if (!await file.exists()) return null;

    try {
      final payload =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final groupsPayload = payload['groups'] as List<dynamic>? ?? [];
      final groups = groupsPayload
          .map(
            (group) => DuplicateGroup(
              (group as List<dynamic>)
                  .map((item) => _photoFromJson(item as Map<String, dynamic>))
                  .toList(),
            ),
          )
          .where((group) => group.items.length > 1)
          .toList();
      final candidatesPayload = payload['candidates'] as List<dynamic>? ?? [];
      final candidates = candidatesPayload
          .map((item) => _photoFromJson(item as Map<String, dynamic>))
          .toList();
      final modeName = payload['mode'] as String?;
      final mode = CleanupMode.values.firstWhere(
        (value) => value.name == modeName,
        orElse: () => CleanupMode.similar,
      );

      if (groups.isEmpty && candidates.isEmpty) return null;

      return ScanSummary(
        groups: groups,
        candidates: candidates,
        scannedCount: payload['scannedCount'] as int? ?? 0,
        elapsed: Duration(milliseconds: payload['elapsedMillis'] as int? ?? 0),
        mode: mode,
        scopeLabel: payload['scopeLabel'] as String? ?? 'Photo library',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final file = await _cacheFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _cacheFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/last_scan.json');
  }

  Map<String, dynamic> _photoToJson(PhotoItem item) {
    return {
      'id': item.id,
      'title': item.title,
      'width': item.width,
      'height': item.height,
      'createdAt': item.createdAt?.toIso8601String(),
      'filePath': item.filePath,
      'perceptualHash': item.perceptualHash,
      'qualityScore': item.qualityScore,
      'estimatedBytes': item.estimatedBytes,
    };
  }

  PhotoItem _photoFromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'] as String?;
    return PhotoItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      createdAt: createdAt == null ? null : DateTime.tryParse(createdAt),
      filePath: json['filePath'] as String?,
      perceptualHash: json['perceptualHash'] as String? ?? '',
      qualityScore: (json['qualityScore'] as num?)?.toDouble() ?? 0,
      estimatedBytes: json['estimatedBytes'] as int? ?? 0,
    );
  }
}
