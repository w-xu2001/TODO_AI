import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/app_settings_repository.dart';

final appSettingsControllerProvider =
    StateNotifierProvider.autoDispose<AppSettingsController, AppSettingsState>(
  (ref) {
    final controller =
        AppSettingsController(repository: ref.watch(appSettingsRepositoryProvider));
    controller.load();
    return controller;
  },
);

class AppSettingsState {
  const AppSettingsState({
    required this.settings,
    this.isLoading = false,
    this.isSaving = false,
    this.isTesting = false,
    this.errorMessage,
    this.infoMessage,
  });

  final AppSettings settings;
  final bool isLoading;
  final bool isSaving;
  final bool isTesting;
  final String? errorMessage;
  final String? infoMessage;

  factory AppSettingsState.initial() {
    return AppSettingsState(settings: AppSettings.defaults(), isLoading: true);
  }

  AppSettingsState copyWith({
    AppSettings? settings,
    bool? isLoading,
    bool? isSaving,
    bool? isTesting,
    String? errorMessage,
    String? infoMessage,
    bool clearError = false,
    bool clearInfo = false,
  }) {
    return AppSettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isTesting: isTesting ?? this.isTesting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
    );
  }
}

class AppSettingsController extends StateNotifier<AppSettingsState> {
  AppSettingsController({required AppSettingsRepository repository})
      : _repository = repository,
        super(AppSettingsState.initial());

  final AppSettingsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      final settings = await _repository.load();
      state = state.copyWith(settings: settings, isLoading: false);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '读取设置失败: $error',
      );
    }
  }

  void setBaseUrl(String value) {
    state = state.copyWith(
      settings: state.settings.copyWith(apiBaseUrl: value),
      clearError: true,
      clearInfo: true,
    );
  }

  void setParsePath(String value) {
    state = state.copyWith(
      settings: state.settings.copyWith(parsePath: value),
      clearError: true,
      clearInfo: true,
    );
  }

  void setApiKey(String value) {
    state = state.copyWith(
      settings: state.settings.copyWith(apiKey: value),
      clearError: true,
      clearInfo: true,
    );
  }

  void setModelName(String value) {
    state = state.copyWith(
      settings: state.settings.copyWith(modelName: value),
      clearError: true,
      clearInfo: true,
    );
  }

  void setMaxTokens(String value) {
    final parsed = int.tryParse(value.trim());
    state = state.copyWith(
      settings: state.settings.copyWith(maxTokens: parsed ?? state.settings.maxTokens),
      clearError: true,
      clearInfo: true,
    );
  }

  void setTemperature(String value) {
    final parsed = double.tryParse(value.trim());
    state = state.copyWith(
      settings: state.settings.copyWith(temperature: parsed ?? state.settings.temperature),
      clearError: true,
      clearInfo: true,
    );
  }

  void setStream(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(stream: value),
      clearError: true,
      clearInfo: true,
    );
  }

  void addTaskColor(int colorValue) {
    final normalized = colorValue | 0xFF000000;
    final current = state.settings.normalizedTaskColors;
    if (current.contains(normalized)) {
      state = state.copyWith(errorMessage: '该颜色已存在。');
      return;
    }

    state = state.copyWith(
      settings: state.settings.copyWith(taskColors: <int>[...current, normalized]),
      clearError: true,
      clearInfo: true,
    );
  }

  void removeTaskColor(int colorValue) {
    final current = state.settings.normalizedTaskColors;
    if (current.length <= 1) {
      state = state.copyWith(errorMessage: '至少保留一种任务颜色。');
      return;
    }

    final updated = current.where((value) => value != colorValue).toList();
    state = state.copyWith(
      settings: state.settings.copyWith(taskColors: updated),
      clearError: true,
      clearInfo: true,
    );
  }

  Future<bool> save() async {
    if (state.isSaving) {
      return false;
    }

    final baseUrl = state.settings.normalizedBaseUrl;
    final parsePath = state.settings.normalizedParsePath;

    if (baseUrl.isEmpty || parsePath.isEmpty) {
      state = state.copyWith(errorMessage: 'API 地址和解析路径不能为空。');
      return false;
    }

    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      state = state.copyWith(errorMessage: 'API 地址格式不正确，请填写完整 URL。');
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true, clearInfo: true);
    try {
      final normalized = state.settings.copyWith(
        apiBaseUrl: baseUrl,
        parsePath: parsePath,
        apiKey: state.settings.apiKey.trim(),
        modelName: state.settings.normalizedModelName,
        maxTokens: state.settings.normalizedMaxTokens,
        temperature: state.settings.normalizedTemperature,
      );
      await _repository.save(normalized);
      state = state.copyWith(
        settings: normalized,
        isSaving: false,
        infoMessage: '设置已保存。',
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: '保存失败: $error',
      );
      return false;
    }
  }

  Future<void> testConnectivity() async {
    if (state.isSaving || state.isTesting) {
      return;
    }

    final endpoint = state.settings.parseEndpoint;
    final endpointUri = Uri.tryParse(endpoint);
    if (endpointUri == null || !endpointUri.hasScheme || endpointUri.host.isEmpty) {
      state = state.copyWith(errorMessage: '当前 endpoint 格式无效，请检查 Base URL 和路径。');
      return;
    }

    state = state.copyWith(isTesting: true, clearError: true, clearInfo: true);

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        validateStatus: (_) => true,
      ),
    );

    try {
      final response = await dio.request<Object?>(
        endpoint,
        data: const <String, Object?>{},
        options: Options(
          method: 'POST',
          headers: const <String, String>{'Content-Type': 'application/json'},
        ),
      );

      final code = response.statusCode ?? 0;
      if (code == 0) {
        state = state.copyWith(
          isTesting: false,
          errorMessage: '连通性测试失败：未获取到有效状态码。',
        );
        return;
      }

      if (code >= 500) {
        state = state.copyWith(
          isTesting: false,
          errorMessage: '服务可达，但服务端异常（HTTP $code）。请稍后重试。',
        );
        return;
      }

      state = state.copyWith(
        isTesting: false,
        infoMessage: '连通性测试通过（HTTP $code）。域名与网络可达。',
      );
    } on DioException catch (error) {
      final raw = error.message ?? error.error?.toString() ?? 'unknown';
      final lower = raw.toLowerCase();
      final host = endpointUri.host;
      final isDnsIssue = lower.contains('failed host lookup') ||
          lower.contains('name or service not known') ||
          lower.contains('nodename nor servname provided');

      final message = isDnsIssue
          ? '域名解析失败：$host。请检查 DNS 或在设置中更换 API Base URL。'
          : '连通性测试失败：$raw';

      state = state.copyWith(
        isTesting: false,
        errorMessage: message,
      );
    } catch (error) {
      state = state.copyWith(
        isTesting: false,
        errorMessage: '连通性测试失败：$error',
      );
    } finally {
      dio.close(force: true);
    }
  }

  Future<void> resetToDefaults() async {
    state = state.copyWith(isSaving: true, clearError: true, clearInfo: true);
    try {
      await _repository.resetToDefaults();
      final settings = await _repository.load();
      state = state.copyWith(
        settings: settings,
        isSaving: false,
        infoMessage: '已恢复默认配置。',
      );
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: '恢复默认失败: $error',
      );
    }
  }
}
