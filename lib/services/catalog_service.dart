import 'dart:convert';
import 'dart:io';

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
    final client = HttpClient();
    try {
      final uri = Uri.parse('$remoteRoot/tocfl_catalog.json');
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Không tải được catalog: HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      return response.transform(utf8.decoder).join();
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
