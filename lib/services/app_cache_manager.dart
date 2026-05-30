import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppCacheManager {
  static const key = 'sapapnj_media_cache';
  
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 15),
      maxNrOfCacheObjects: 1500,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
