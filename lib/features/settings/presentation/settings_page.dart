import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/app_settings_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _parsePathController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelNameController;
  late final TextEditingController _maxTokensController;
  late final TextEditingController _temperatureController;

  bool _seeded = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _parsePathController = TextEditingController();
    _apiKeyController = TextEditingController();
    _modelNameController = TextEditingController();
    _maxTokensController = TextEditingController();
    _temperatureController = TextEditingController();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _parsePathController.dispose();
    _apiKeyController.dispose();
    _modelNameController.dispose();
    _maxTokensController.dispose();
    _temperatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appSettingsControllerProvider);

    ref.listen<AppSettingsState>(appSettingsControllerProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        messenger.showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
      if (next.infoMessage != null && next.infoMessage != previous?.infoMessage) {
        messenger.showSnackBar(SnackBar(content: Text(next.infoMessage!)));
      }
    });

    if (!_seeded && !state.isLoading) {
      _baseUrlController.text = state.settings.normalizedBaseUrl;
      _parsePathController.text = state.settings.normalizedParsePath;
      _apiKeyController.text = state.settings.apiKey;
      _modelNameController.text = state.settings.normalizedModelName;
      _maxTokensController.text = state.settings.normalizedMaxTokens.toString();
      _temperatureController.text = state.settings.normalizedTemperature.toString();
      _seeded = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('应用设置')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: <Widget>[
                  Text(
                    '在这里配置接口与大模型参数，保存后立即生效。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black.withValues(alpha: 0.66),
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _baseUrlController,
                    onChanged: (value) {
                      ref.read(appSettingsControllerProvider.notifier).setBaseUrl(value);
                    },
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'API Base URL',
                      hintText: 'https://api.gpt.ge',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _parsePathController,
                    onChanged: (value) {
                      ref.read(appSettingsControllerProvider.notifier).setParsePath(value);
                    },
                    decoration: const InputDecoration(
                      labelText: '请求路径',
                      hintText: '/v1/chat/completions',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyController,
                    onChanged: (value) {
                      ref.read(appSettingsControllerProvider.notifier).setApiKey(value);
                    },
                    obscureText: _obscureApiKey,
                    decoration: InputDecoration(
                      labelText: 'API Key（可选）',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscureApiKey = !_obscureApiKey;
                          });
                        },
                        icon: Icon(
                          _obscureApiKey ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '模型参数',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _modelNameController,
                    onChanged: (value) {
                      ref.read(appSettingsControllerProvider.notifier).setModelName(value);
                    },
                    decoration: const InputDecoration(
                      labelText: '模型名称',
                      hintText: 'gpt-5.4-nano-2026-03-17',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _maxTokensController,
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      ref.read(appSettingsControllerProvider.notifier).setMaxTokens(value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'max_tokens',
                      hintText: '3000',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _temperatureController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      ref.read(appSettingsControllerProvider.notifier).setTemperature(value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'temperature',
                      hintText: '0.5',
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('stream 返回'),
                    value: state.settings.stream,
                    onChanged: (value) {
                      ref.read(appSettingsControllerProvider.notifier).setStream(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: state.isSaving
                              ? null
                              : () async {
                                  final success =
                                      await ref.read(appSettingsControllerProvider.notifier).save();
                                  if (success && context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          icon: state.isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(state.isSaving ? '保存中...' : '保存设置'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (state.isSaving || state.isTesting)
                              ? null
                              : () async {
                                  await ref
                                      .read(appSettingsControllerProvider.notifier)
                                      .testConnectivity();
                                },
                          icon: state.isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.network_check_rounded),
                          label: Text(state.isTesting ? '测试中...' : '测试连通性'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: state.isSaving
                        ? null
                        : () async {
                            await ref.read(appSettingsControllerProvider.notifier).resetToDefaults();
                            _seeded = false;
                            if (mounted) {
                              setState(() {});
                            }
                          },
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('恢复默认参数'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '提示：API Key 当前保存在本地偏好设置中，适合开发环境。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                  ),
                ],
              ),
            ),
    );
  }
}
