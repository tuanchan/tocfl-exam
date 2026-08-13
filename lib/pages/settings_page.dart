import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../core/app_toast.dart';
import '../services/gemini_service.dart';
import '../services/settings_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.reloadCatalog,
  });

  final SettingsStore settings;
  final Future<void> Function() reloadCatalog;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _apiKey;
  late final TextEditingController _localRoot;
  List<GeminiModelOption> _models = const [];
  late String _selectedModel;
  String? _modelError;
  bool _loadingModels = false;
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    _apiKey = TextEditingController(text: widget.settings.geminiApiKey);
    _localRoot = TextEditingController(text: widget.settings.localDataRoot);
    _selectedModel = widget.settings.geminiModel;
    if (_apiKey.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadModels());
    }
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _localRoot.dispose();
    super.dispose();
  }

  List<GeminiModelOption> get _selectableModels {
    final values = [..._models];
    if (!values.any((model) => model.id == _selectedModel)) {
      values.insert(
        0,
        GeminiModelOption(
          id: _selectedModel,
          displayName: 'Đang lưu: $_selectedModel',
          description: 'Model chưa được xác minh với API key hiện tại.',
        ),
      );
    }
    return values;
  }

  GeminiModelOption? get _selectedModelInfo {
    for (final model in _selectableModels) {
      if (model.id == _selectedModel) return model;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final models = _selectableModels;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Cài đặt',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        AppSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Giao diện',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('Chế độ tối')),
                  Switch(
                    value: widget.settings.darkMode,
                    onChanged: widget.settings.setDarkMode,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gemini',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKey,
                obscureText: !_showApiKey,
                onChanged: (_) {
                  if (_modelError != null) setState(() => _modelError = null);
                },
                decoration: InputDecoration(
                  labelText: 'API key Gemini',
                  suffixIcon: IconButton(
                    tooltip: _showApiKey ? 'Ẩn API key' : 'Hiện API key',
                    onPressed: () => setState(() => _showApiKey = !_showApiKey),
                    icon: Icon(
                      _showApiKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('gemini-model-$_selectedModel-${models.length}'),
                initialValue: _selectedModel,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Model hỗ trợ generateContent',
                  prefixIcon: _loadingModels
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                ),
                items: models
                    .map(
                      (model) => DropdownMenuItem(
                        value: model.id,
                        child: Text(
                          '${model.label}  •  ${model.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _loadingModels
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedModel = value);
                        }
                      },
              ),
              if (_selectedModelInfo?.description.trim().isNotEmpty ==
                  true) ...[
                const SizedBox(height: 8),
                Text(
                  _selectedModelInfo!.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_modelError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _modelError!,
                  style: const TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppTextButton(
                    label: 'Lấy API key',
                    compact: true,
                    filled: true,
                    onPressed: _openGeminiKeyPage,
                  ),
                  AppTextButton(
                    label: _loadingModels
                        ? 'Đang tải model...'
                        : 'Tải danh sách model',
                    compact: true,
                    filled: true,
                    onPressed: _loadingModels ? null : _loadModels,
                  ),
                  AppTextButton(
                    label: 'Lưu Gemini',
                    compact: true,
                    filled: true,
                    danger: true,
                    onPressed: _saveGemini,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.settings.geminiApiKey.isEmpty
                    ? 'Chưa có key đã lưu.'
                    : 'Key và model sẽ tự khôi phục khi mở lại ứng dụng.',
              ),
            ],
          ),
        ),
        if (Platform.isWindows) ...[
          const SizedBox(height: 12),
          AppSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nguồn tài liệu',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _localRoot,
                  decoration: const InputDecoration(
                    labelText: 'Thư mục lưu tài liệu trên Windows',
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.cloud_done_outlined,
                            color: AppColors.blue,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nguồn đề đã được cấu hình sẵn',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        widget.settings.remoteDataRoot,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ứng dụng tự dùng nguồn Cloudflare R2 này; người dùng không cần nhập URL.',
                ),
                const SizedBox(height: 12),
                AppTextButton(
                  label: 'Lưu thư mục Windows',
                  expand: true,
                  filled: true,
                  onPressed: _saveConnection,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _loadModels() async {
    final key = _apiKey.text.trim();
    if (key.isEmpty) {
      setState(() => _modelError = 'Hãy nhập API key Gemini trước.');
      return;
    }
    setState(() {
      _loadingModels = true;
      _modelError = null;
    });
    try {
      final values = await GeminiService(
        widget.settings,
      ).listGenerateContentModels(apiKey: key);
      if (!mounted) return;
      var nextModel = _selectedModel;
      if (!values.any((model) => model.id == nextModel)) {
        nextModel = values
            .firstWhere(
              (model) => model.id == SettingsStore.defaultGeminiModel,
              orElse: () => values.first,
            )
            .id;
      }
      setState(() {
        _models = values;
        _selectedModel = nextModel;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _modelError = 'Không tải được danh sách model: $error');
      }
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _saveConnection() async {
    await widget.settings.saveConnectionSettings(
      apiKey: _apiKey.text,
      model: _selectedModel,
      localRoot: _localRoot.text,
    );
    await widget.reloadCatalog();
    if (mounted) {
      AppToast.show(
        context,
        'Đã lưu thư mục Windows.',
        tone: AppToastTone.success,
      );
    }
  }

  Future<void> _saveGemini() async {
    await widget.settings.saveGeminiSettings(
      apiKey: _apiKey.text,
      model: _selectedModel,
    );
    if (!mounted) return;
    AppToast.show(
      context,
      _apiKey.text.trim().isEmpty
          ? 'Đã xóa API key Gemini.'
          : 'Đã lưu API key và model $_selectedModel.',
      tone: AppToastTone.success,
    );
    setState(() {});
  }

  Future<void> _openGeminiKeyPage() async {
    final opened = await launchUrl(
      Uri.parse('https://aistudio.google.com/api-keys?hl=vi'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      AppToast.show(
        context,
        'Không mở được trang lấy API key.',
        tone: AppToastTone.error,
      );
    }
  }
}
