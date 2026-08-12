import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'settings_store.dart';

Future<void>? _iosMigration;
const _downloadableExtensions = <String>{
  '.pdf',
  '.mp3',
  '.m4a',
  '.aac',
  '.wav',
  '.ogg',
};

Future<Directory> downloadStorageRoot(SettingsStore settings) async {
  if (Platform.isWindows) {
    return Directory(settings.localDataRoot);
  }

  if (!Platform.isIOS) {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'tocfl'));
  }

  final documents = await getApplicationDocumentsDirectory();
  final visibleRoot = Directory(p.join(documents.path, 'tocfl'));
  await visibleRoot.create(recursive: true);
  await _ensureReadme(visibleRoot);
  _iosMigration ??= _migrateLegacyIosDownloads(visibleRoot);
  await _iosMigration;
  return visibleRoot;
}

Future<void> _ensureReadme(Directory visibleRoot) async {
  final file = File(p.join(visibleRoot.path, 'README.txt'));
  if (await file.exists()) return;
  await file.writeAsString(
    'Thư mục đề TOCFL đã tải để học ngoại tuyến.\n'
    'Có thể xem tại Files > On My iPhone > TOCFL Exam > tocfl.\n',
    flush: true,
  );
}

Future<void> _migrateLegacyIosDownloads(Directory visibleRoot) async {
  final support = await getApplicationSupportDirectory();
  final legacyRoot = Directory(p.join(support.path, 'tocfl'));
  if (!await legacyRoot.exists()) return;

  await for (final entity in legacyRoot.list(recursive: true)) {
    if (entity is! File) continue;
    final relativePath = p.relative(entity.path, from: legacyRoot.path);
    final extension = p.extension(relativePath).toLowerCase();
    if (!_downloadableExtensions.contains(extension)) continue;

    final destination = File(p.join(visibleRoot.path, relativePath));
    if (await destination.exists()) continue;
    await destination.parent.create(recursive: true);
    try {
      await entity.rename(destination.path);
    } on FileSystemException {
      try {
        await entity.copy(destination.path);
        await entity.delete();
      } on FileSystemException {
        continue;
      }
    }
  }
}
