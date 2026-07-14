import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

class RawPhotoAsset {
  final AssetEntity asset;
  final File file;

  RawPhotoAsset({
    required this.asset,
    required this.file,
  });
}

class QueuedPhotoAsset {
  final AssetEntity asset;

  const QueuedPhotoAsset(this.asset);

  String get id => asset.id;
  String get title => asset.title ?? 'Untitled';
  int get width => asset.width;
  int get height => asset.height;
  DateTime get createdAt => asset.createDateTime;

  Future<File?> resolveFile({
    Duration timeout = const Duration(seconds: 4),
  }) {
    return asset.file.timeout(timeout, onTimeout: () => null);
  }
}

class PhotoAlbumOption {
  final String id;
  final String name;
  final int assetCount;

  const PhotoAlbumOption({
    required this.id,
    required this.name,
    required this.assetCount,
  });
}

class PhotoService {
  Future<bool> requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    return result.isAuth || result.hasAccess;
  }

  Future<void> openSettings() {
    return PhotoManager.openSetting();
  }

  Future<void> presentLimitedLibraryPicker() {
    if (!Platform.isIOS) return Future.value();
    return PhotoManager.presentLimited(type: RequestType.image);
  }

  Future<List<PhotoAlbumOption>> loadImageAlbums() async {
    final paths = await _loadImagePaths(onlyAll: false);
    final albums = <PhotoAlbumOption>[];

    for (final path in paths) {
      final count = await path.assetCountAsync;
      if (count <= 0) continue;
      albums.add(
        PhotoAlbumOption(
          id: path.id,
          name: path.name,
          assetCount: count,
        ),
      );
    }

    albums.sort((a, b) {
      if (a.name == 'Recent' || a.name == 'Recents') return -1;
      if (b.name == 'Recent' || b.name == 'Recents') return 1;
      return b.assetCount.compareTo(a.assetCount);
    });

    return albums;
  }

  Future<List<QueuedPhotoAsset>> loadRecentImageAssets(
      {int limit = 200}) async {
    final paths = await _loadImagePaths(onlyAll: true);
    return _loadAssetsFromPath(paths.isEmpty ? null : paths.first,
        limit: limit);
  }

  Future<List<QueuedPhotoAsset>> loadAlbumImageAssets({
    required String albumId,
    required int limit,
  }) async {
    final paths = await _loadImagePaths(onlyAll: false);
    AssetPathEntity? selected;
    for (final path in paths) {
      if (path.id == albumId) {
        selected = path;
        break;
      }
    }

    return _loadAssetsFromPath(selected, limit: limit);
  }

  Future<List<AssetPathEntity>> _loadImagePaths({required bool onlyAll}) {
    return PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: onlyAll,
      hasAll: true,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
  }

  Future<List<QueuedPhotoAsset>> _loadAssetsFromPath(
    AssetPathEntity? album, {
    required int limit,
  }) async {
    if (album == null) return [];

    final assets = await album.getAssetListPaged(page: 0, size: limit);
    return assets.map(QueuedPhotoAsset.new).toList();
  }

  Future<List<RawPhotoAsset>> loadRecentImages({int limit = 200}) async {
    final assets = await loadRecentImageAssets(limit: limit);

    final output = <RawPhotoAsset>[];

    for (final asset in assets) {
      final file = await asset.resolveFile();

      if (file != null && await file.exists()) {
        output.add(
          RawPhotoAsset(
            asset: asset.asset,
            file: file,
          ),
        );
      }
    }

    return output;
  }

  Future<List<String>> deleteAssetsById(List<String> ids) {
    return PhotoManager.editor.deleteWithIds(ids);
  }
}
