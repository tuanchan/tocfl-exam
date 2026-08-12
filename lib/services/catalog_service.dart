import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/tocfl_models.dart';
import 'settings_store.dart';

class CatalogService {
  CatalogService(this.settings);

  final SettingsStore settings;

  Future<TocflCatalog> load() async {
    if (Platform.isWindows) {
      final file = File(p.join(settings.localDataRoot, 'tocfl_catalog.json'));
      if (await file.exists()) {
        return _decode(await file.readAsString());
      }
    }
    final cached = await _cachedCatalogFile();
    try {
      final body = await _downloadCatalog();
      await cached.parent.create(recursive: true);
      await cached.writeAsString(body, flush: true);
      return _decode(body);
    } catch (error) {
      if (await cached.exists()) return _decode(await cached.readAsString());
      if (Platform.isWindows) {
        throw StateError(
          'Không tìm thấy catalog tại ${settings.localDataRoot} và không '
          'tải được từ R2: $error',
        );
      }
      rethrow;
    }
  }

  Future<String> _downloadCatalog() async {
    final remoteRoot = settings.remoteDataRoot.trim().isEmpty
        ? SettingsStore.defaultRemoteDataRoot
        : settings.remoteDataRoot;
    final uri = Uri.parse('$remoteRoot/tocfl_catalog.json');
    Object? lastError;

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        return await _downloadCatalogOnce(uri);
      } catch (error) {
        lastError = error;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt));
        }
      }
    }

    throw HttpException(
      'Không tải được catalog sau 3 lần thử: $lastError',
      uri: uri,
    );
  }

  Future<String> _downloadCatalogOnce(Uri uri) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    client.idleTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Không tải được catalog: HTTP ${response.statusCode}',
          uri: uri,
        );
      }

      final expectedLength = response.contentLength;
      final builder = BytesBuilder(copy: false);
      await response
          .forEach(builder.add)
          .timeout(const Duration(seconds: 60));
      final bytes = builder.takeBytes();
      if (expectedLength >= 0 && bytes.length != expectedLength) {
        throw HttpException(
          'Catalog tải chưa đầy đủ: ${bytes.length}/$expectedLength byte',
          uri: uri,
        );
      }
      return utf8.decode(bytes);
    } finally {
      client.close(force: true);
    }
  }

  TocflCatalog _decode(String source) =>
      TocflCatalog.fromJson(jsonDecode(source) as Map<String, dynamic>);

  Future<File> _cachedCatalogFile() async {
    final root = await getApplicationSupportDirectory();
    return File(p.join(root.path, 'tocfl', 'tocfl_catalog.json'));
  }
}

class AssetLocationService {
  AssetLocationService(this.settings);

  final SettingsStore settings;

  Future<String?> resolve(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;
    final normalized = relativePath.replaceAll('/', p.separator);
    if (Platform.isWindows) {
      final file = File(p.join(settings.localDataRoot, normalized));
      return await file.exists() ? file.path : null;
    }
    final root = await getApplicationSupportDirectory();
    final file = File(p.join(root.path, 'tocfl', normalized));
    return await file.exists() ? file.path : null;
  }
}
