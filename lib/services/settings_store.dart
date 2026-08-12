import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore extends ChangeNotifier {
  static const defaultGeminiModel = 'gemini-3.1-flash-lite';
  static const publicDevelopmentUrl =
      'https://pub-df7e277e704540ee850d5574a16bd35d.r2.dev';
  static const defaultRemoteDataRoot = '$publicDevelopmentUrl/tai_lieu_tocfl';
  static const _darkModeKey = 'appearance.darkMode';
  static const _geminiKey = 'gemini.apiKey';
  static const _geminiModelKey = 'gemini.model';
  static const _dataRootKey = 'data.localRoot';
  static const _remoteRootKey = 'data.remoteRoot';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  bool darkMode = false;
  String geminiApiKey = '';
  String geminiModel = defaultGeminiModel;
  String localDataRoot = '';
  String _remoteDataRoot = defaultRemoteDataRoot;

  String get remoteDataRoot =>
      _remoteDataRoot.trim().isEmpty ? defaultRemoteDataRoot : _remoteDataRoot;

  Future<void> load() async {
    darkMode = await _preferences.getBool(_darkModeKey) ?? false;
    geminiApiKey = await _preferences.getString(_geminiKey) ?? '';
    final savedGeminiModel =
        (await _preferences.getString(_geminiModelKey))?.trim() ?? '';
    geminiModel =
        savedGeminiModel.isEmpty || savedGeminiModel == 'gemini-2.5-flash'
        ? defaultGeminiModel
        : savedGeminiModel;
    if (geminiModel != savedGeminiModel) {
      await _preferences.setString(_geminiModelKey, geminiModel);
    }
    localDataRoot = await _preferences.getString(_dataRootKey) ?? '';
    // Nguồn đề là cấu hình của ứng dụng, không phải thiết lập người dùng.
    // Ghi đè giá trị cũ để các máy từng lưu nhầm URL tự sửa sau khi cập nhật.
    _remoteDataRoot = defaultRemoteDataRoot;
    await _preferences.setString(_remoteRootKey, remoteDataRoot);
    if (localDataRoot.trim().isEmpty && Platform.isWindows) {
      localDataRoot = _detectWindowsDataRoot();
    }
  }

  String _detectWindowsDataRoot() {
    final candidates = <String>[
      Platform.environment['TOCFL_DATA_ROOT'] ?? '',
      '${Directory.current.path}${Platform.pathSeparator}tai_lieu_tocfl',
      Directory.current.parent.path,
      r'D:\StudyLangue\TOCFL\fullexam\tai_lieu_tocfl',
    ];
    for (final value in candidates) {
      if (value.isNotEmpty &&
          File(
            '$value${Platform.pathSeparator}tocfl_catalog.json',
          ).existsSync()) {
        return value;
      }
    }
    return r'D:\StudyLangue\TOCFL\fullexam\tai_lieu_tocfl';
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    await _preferences.setBool(_darkModeKey, value);
    notifyListeners();
  }

  Future<void> saveConnectionSettings({
    required String apiKey,
    required String model,
    required String localRoot,
  }) async {
    geminiApiKey = apiKey.trim();
    geminiModel = model.trim().isEmpty ? defaultGeminiModel : model.trim();
    localDataRoot = localRoot.trim();
    _remoteDataRoot = defaultRemoteDataRoot;
    await _preferences.setString(_geminiKey, geminiApiKey);
    await _preferences.setString(_geminiModelKey, geminiModel);
    await _preferences.setString(_dataRootKey, localDataRoot);
    await _preferences.setString(_remoteRootKey, remoteDataRoot);
    notifyListeners();
  }

  Future<void> saveGeminiSettings({
    required String apiKey,
    required String model,
  }) async {
    geminiApiKey = apiKey.trim();
    geminiModel = model.trim().isEmpty ? defaultGeminiModel : model.trim();
    await _preferences.setString(_geminiKey, geminiApiKey);
    await _preferences.setString(_geminiModelKey, geminiModel);
    notifyListeners();
  }
}
