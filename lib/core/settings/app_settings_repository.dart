import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository();
});

class AppSettingsRepository {
  static const String _keyApiBaseUrl = 'settings.api_base_url';
  static const String _keyParsePath = 'settings.parse_path';
  static const String _keyApiKey = 'settings.api_key';
  static const String _keyModelName = 'settings.model_name';
  static const String _keyMaxTokens = 'settings.max_tokens';
  static const String _keyTemperature = 'settings.temperature';
  static const String _keyStream = 'settings.stream';
  static const String _keyTaskColors = 'settings.task_colors';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = AppSettings.defaults();

    return AppSettings(
      apiBaseUrl: _readNonEmptyStringOrDefault(prefs, _keyApiBaseUrl, defaults.apiBaseUrl),
      parsePath: _readNonEmptyStringOrDefault(prefs, _keyParsePath, defaults.parsePath),
      apiKey: _readNonEmptyStringOrDefault(prefs, _keyApiKey, defaults.apiKey),
      modelName: _readNonEmptyStringOrDefault(prefs, _keyModelName, defaults.modelName),
      maxTokens: prefs.getInt(_keyMaxTokens) ?? defaults.maxTokens,
      temperature: prefs.getDouble(_keyTemperature) ?? defaults.temperature,
      stream: prefs.getBool(_keyStream) ?? defaults.stream,
      taskColors: _loadColors(prefs) ?? defaults.taskColors,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiBaseUrl, settings.normalizedBaseUrl);
    await prefs.setString(_keyParsePath, settings.normalizedParsePath);
    await prefs.setString(_keyApiKey, settings.apiKey.trim());
    await prefs.setString(_keyModelName, settings.normalizedModelName);
    await prefs.setInt(_keyMaxTokens, settings.normalizedMaxTokens);
    await prefs.setDouble(_keyTemperature, settings.normalizedTemperature);
    await prefs.setBool(_keyStream, settings.stream);
    await prefs.setStringList(
      _keyTaskColors,
      settings.normalizedTaskColors.map((color) => color.toRadixString(16)).toList(),
    );
  }

  Future<void> resetToDefaults() async {
    final defaults = AppSettings.defaults();
    await save(defaults);
  }

  List<int>? _loadColors(SharedPreferences prefs) {
    final list = prefs.getStringList(_keyTaskColors);
    if (list == null || list.isEmpty) {
      return null;
    }

    final parsed = <int>[];
    for (final value in list) {
      final color = int.tryParse(value, radix: 16);
      if (color != null) {
        parsed.add(color | 0xFF000000);
      }
    }

    return parsed.isEmpty ? null : parsed;
  }

  String _readNonEmptyStringOrDefault(
    SharedPreferences prefs,
    String key,
    String defaultValue,
  ) {
    final value = prefs.getString(key);
    if (value == null || value.trim().isEmpty) {
      return defaultValue;
    }
    return value;
  }
}
