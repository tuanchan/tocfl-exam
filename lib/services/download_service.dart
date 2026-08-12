import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/tocfl_models.dart';
import 'download_storage.dart';
import 'settings_store.dart';

class LevelDownloadProgress {
  const LevelDownloadProgress({
    required this.completed,
    required this.total,
    required this.currentFile,
  });

  final int completed;
  final int total;
  final String currentFile;

  double get ratio => total == 0 ? 0 : completed / total;
}

class DownloadService {
  DownloadService(this.settings);

  final SettingsStore settings;

  Future<void> downloadLevel({
    required String levelCode,
    required List<ExamDocument> documents,
    required ValueChanged<LevelDownloadProgress> onProgress,
  }) async {
    final remoteRoot = settings.remoteDataRoot.trim().isEmpty
        ? SettingsStore.defaultRemoteDataRoot
        : settings.remoteDataRoot;
    final paths = <String>{};
    for (final document in documents.where(
      (item) => item.levelCode == levelCode,
    )) {
      paths.add(document.pdfPath);
      if (document.audioPath?.isNotEmpty == true) {
        paths.add(document.audioPath!);
      }
      if (document.transcriptPath?.isNotEmpty == true) {
        paths.add(document.transcriptPath!);
      }
    }
    final values = paths.toList(growable: false)..sort();
    final destinationRoot = (await downloadStorageRoot(settings)).path;
    final client = HttpClient();
    try {
      var completed = 0;
      for (final relativePath in values) {
        onProgress(
          LevelDownloadProgress(
            completed: completed,
            total: values.length,
            currentFile: relativePath,
          ),
        );
        final destination = File(
          p.join(destinationRoot, relativePath.replaceAll('/', p.separator)),
        );
        if (!await destination.exists() || await destination.length() == 0) {
          await destination.parent.create(recursive: true);
          final uri = Uri.parse(
            '$remoteRoot/${relativePath.split('/').map(Uri.encodeComponent).join('/')}',
          );
          final request = await client.getUrl(uri);
          final response = await request.close();
          if (response.statusCode < HttpStatus.ok ||
              response.statusCode >= HttpStatus.multipleChoices) {
            throw HttpException('HTTP ${response.statusCode}: $relativePath');
          }
          final temporary = File('${destination.path}.download');
          final output = temporary.openWrite();
          await response.pipe(output);
          if (await destination.exists()) await destination.delete();
          await temporary.rename(destination.path);
        }
        completed++;
      }
      onProgress(
        LevelDownloadProgress(
          completed: completed,
          total: values.length,
          currentFile: '',
        ),
      );
    } finally {
      client.close(force: true);
    }
  }
}
