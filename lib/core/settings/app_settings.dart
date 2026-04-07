import '../config/app_config.dart';

class AppSettings {
  const AppSettings({
    required this.apiBaseUrl,
    required this.parsePath,
    required this.apiKey,
    required this.modelName,
    required this.maxTokens,
    required this.temperature,
    required this.stream,
    required this.taskColors,
  });

  final String apiBaseUrl;
  final String parsePath;
  final String apiKey;
  final String modelName;
  final int maxTokens;
  final double temperature;
  final bool stream;
  final List<int> taskColors;

  static const List<int> defaultTaskColors = <int>[
    0xFF1D6FBA,
    0xFF2F92EE,
    0xFF00A896,
    0xFF4CAF50,
    0xFFF4A261,
    0xFFE76F51,
    0xFF8E5BD9,
    0xFFEF476F,
    0xFF06D6A0,
    0xFF118AB2,
  ];

  factory AppSettings.defaults() {
    return AppSettings(
      apiBaseUrl: AppConfig.apiBaseUrl,
      parsePath: AppConfig.parsePath,
      apiKey: AppConfig.apiKey,
      modelName: AppConfig.defaultModelName,
      maxTokens: AppConfig.defaultMaxTokens,
      temperature: AppConfig.defaultTemperature,
      stream: AppConfig.defaultStream,
      taskColors: defaultTaskColors,
    );
  }

  AppSettings copyWith({
    String? apiBaseUrl,
    String? parsePath,
    String? apiKey,
    String? modelName,
    int? maxTokens,
    double? temperature,
    bool? stream,
    List<int>? taskColors,
  }) {
    return AppSettings(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      parsePath: parsePath ?? this.parsePath,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      stream: stream ?? this.stream,
      taskColors: taskColors ?? this.taskColors,
    );
  }

  bool get hasBaseUrl {
    return apiBaseUrl.trim().isNotEmpty;
  }

  bool get hasParsePath {
    return parsePath.trim().isNotEmpty;
  }

  String get normalizedBaseUrl {
    return apiBaseUrl.trim();
  }

  String get normalizedParsePath {
    final value = parsePath.trim();
    if (value.isEmpty) {
      return value;
    }
    return value.startsWith('/') ? value : '/$value';
  }

  String get parseEndpoint {
    return Uri.parse(normalizedBaseUrl).resolve(normalizedParsePath).toString();
  }

  String get normalizedModelName {
    final value = modelName.trim();
    return value.isEmpty ? AppConfig.defaultModelName : value;
  }

  int get normalizedMaxTokens {
    final value = maxTokens <= 0 ? AppConfig.defaultMaxTokens : maxTokens;
    return value.clamp(1, 8192);
  }

  double get normalizedTemperature {
    final value = temperature;
    return value.clamp(0.0, 2.0);
  }

  List<int> get normalizedTaskColors {
    final seen = <int>{};
    final colors = <int>[];
    for (final color in taskColors) {
      final value = color | 0xFF000000;
      if (seen.add(value)) {
        colors.add(value);
      }
    }
    if (colors.isEmpty) {
      return defaultTaskColors;
    }
    return colors;
  }
}
