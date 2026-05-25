import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service to download and cache DOOM WAD files and js-dos library from GitHub
class DoomCacheService {
  static const String _baseUrl = 'https://raw.githubusercontent.com/Emmanuel1017/Angular-Resume/master/src/assets/doom';

  // js-dos library files that need to be cached (v6.22)
  static const List<String> _jsDosFiles = [
    'js-dos.js',
    'wdosbox.js',
  ];

  static final DoomCacheService _instance = DoomCacheService._internal();
  factory DoomCacheService() => _instance;
  DoomCacheService._internal();

  /// Download a WAD file and cache it locally
  /// Returns the local file path if successful, null otherwise
  Future<String?> getCachedWadFile(
    String filename, {
    Function(double)? onProgress,
  }) async {
    try {
      // Get cache directory
      final cacheDir = await getApplicationCacheDirectory();
      final wadDir = Directory('${cacheDir.path}/doom_wads');

      // Create doom_wads directory if it doesn't exist
      if (!await wadDir.exists()) {
        await wadDir.create(recursive: true);
      }

      final localFile = File('${wadDir.path}/$filename');

      // If file already exists and is valid, return it
      if (await localFile.exists()) {
        final size = await localFile.length();
        if (size > 1000000) { // At least 1MB (WAD files are 5-7MB)
          debugPrint('[DoomCache] Using cached file: ${localFile.path}');
          return localFile.path;
        } else {
          debugPrint('[DoomCache] Cached file too small, re-downloading');
          await localFile.delete();
        }
      }

      // Download from GitHub
      debugPrint('[DoomCache] Downloading $filename from GitHub...');
      final url = '$_baseUrl/$filename';
      debugPrint('[DoomCache] URL: $url');

      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      debugPrint('[DoomCache] Response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('[DoomCache] Download failed: ${response.statusCode}');
        debugPrint('[DoomCache] Response headers: ${response.headers}');
        return null;
      }

      final contentLength = response.contentLength ?? 0;
      int downloadedBytes = 0;

      // Stream download with progress
      final bytes = <int>[];
      await for (var chunk in response.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;

        if (contentLength > 0 && onProgress != null) {
          final progress = downloadedBytes / contentLength;
          onProgress(progress);
        }
      }

      // Write to cache file
      await localFile.writeAsBytes(bytes);
      debugPrint('[DoomCache] Cached ${bytes.length} bytes to ${localFile.path}');

      return localFile.path;
    } catch (e, stackTrace) {
      debugPrint('[DoomCache] Error caching WAD file: $e');
      debugPrint('[DoomCache] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get the size of a cached WAD file in bytes
  Future<int?> getCachedFileSize(String filename) async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final localFile = File('${cacheDir.path}/doom_wads/$filename');

      if (await localFile.exists()) {
        return await localFile.length();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Clear all cached WAD files
  Future<void> clearCache() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final wadDir = Directory('${cacheDir.path}/doom_wads');

      if (await wadDir.exists()) {
        await wadDir.delete(recursive: true);
        debugPrint('[DoomCache] Cleared all cached WAD files');
      }
    } catch (e) {
      debugPrint('[DoomCache] Error clearing cache: $e');
    }
  }

  /// Check if a WAD file is cached
  Future<bool> isCached(String filename) async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final localFile = File('${cacheDir.path}/doom_wads/$filename');
      return await localFile.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get total cache size in MB
  Future<double> getCacheSizeMB() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final wadDir = Directory('${cacheDir.path}/doom_wads');

      if (!await wadDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (var entity in wadDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize / (1024 * 1024); // Convert to MB
    } catch (e) {
      return 0;
    }
  }

  /// Download and cache js-dos library files from GitHub
  /// Returns true if all files were cached successfully
  Future<bool> cacheJsDosLibrary({Function(String, double)? onProgress}) async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final jsDosDir = Directory('${cacheDir.path}/jsdos_lib');

      // Create jsdos_lib directory if it doesn't exist
      if (!await jsDosDir.exists()) {
        await jsDosDir.create(recursive: true);
      }

      // Check if all files already exist
      bool allCached = true;
      for (final filename in _jsDosFiles) {
        final localFile = File('${jsDosDir.path}/$filename');
        if (!await localFile.exists()) {
          allCached = false;
          break;
        }
      }

      if (allCached) {
        debugPrint('[DoomCache] js-dos library already cached');
        return true;
      }

      // Download each file
      for (int i = 0; i < _jsDosFiles.length; i++) {
        final filename = _jsDosFiles[i];
        final localFile = File('${jsDosDir.path}/$filename');

        if (await localFile.exists()) {
          debugPrint('[DoomCache] $filename already cached, skipping');
          continue;
        }

        debugPrint('[DoomCache] Downloading $filename from GitHub...');
        final url = '$_baseUrl/$filename';

        final request = http.Request('GET', Uri.parse(url));
        final response = await request.send();

        if (response.statusCode != 200) {
          debugPrint('[DoomCache] Failed to download $filename: ${response.statusCode}');
          return false;
        }

        final contentLength = response.contentLength ?? 0;
        int downloadedBytes = 0;

        // Stream download with progress
        final bytes = <int>[];
        await for (var chunk in response.stream) {
          bytes.addAll(chunk);
          downloadedBytes += chunk.length;

          if (contentLength > 0 && onProgress != null) {
            final progress = (i + (downloadedBytes / contentLength)) / _jsDosFiles.length;
            onProgress(filename, progress);
          }
        }

        // Write to cache file
        await localFile.writeAsBytes(bytes);
        debugPrint('[DoomCache] Cached $filename (${bytes.length} bytes)');
      }

      debugPrint('[DoomCache] js-dos library fully cached');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[DoomCache] Error caching js-dos library: $e');
      debugPrint('[DoomCache] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get the local path to a cached js-dos library file
  Future<String?> getJsDosFilePath(String filename) async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final localFile = File('${cacheDir.path}/jsdos_lib/$filename');

      if (await localFile.exists()) {
        return localFile.path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if js-dos library is fully cached
  Future<bool> isJsDosCached() async {
    try {
      for (final filename in _jsDosFiles) {
        final path = await getJsDosFilePath(filename);
        if (path == null) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
