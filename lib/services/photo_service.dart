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

class PhotoService {
  Future<bool> requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    return result.isAuth || result.hasAccess;
  }

  Future<void> openSettings() {
    return PhotoManager.openSetting();
  }

  Future<void> presentLimitedLibraryPicker() {
    return PhotoManager.presentLimited(type: RequestType.image);
  }

  Future<List<RawPhotoAsset>> loadRecentImages({int limit = 200}) async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    if (paths.isEmpty) return [];

    final album = paths.first;
    final assets = await album.getAssetListPaged(page: 0, size: limit);

    final output = <RawPhotoAsset>[];

    for (final asset in assets) {
      final file = await asset.file;

      if (file != null && await file.exists()) {
        output.add(
          RawPhotoAsset(
            asset: asset,
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
