class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'TODO_AI_BASE_URL',
    defaultValue: 'https://api.gpt.ge',
  );

  static const String parsePath = String.fromEnvironment(
    'TODO_AI_PARSE_PATH',
    defaultValue: '/v1/chat/completions',
  );

  static const String apiKey = String.fromEnvironment(
    'TODO_AI_API_KEY',
    defaultValue: 'sk-xxxxx',
  );

  static const String defaultModelName = String.fromEnvironment(
    'TODO_AI_MODEL',
    defaultValue: 'gpt-5.4-nano-2026-03-17',
  );

  static const int defaultMaxTokens = int.fromEnvironment(
    'TODO_AI_MAX_TOKENS',
    defaultValue: 2000,
  );

  static const String _defaultTemperatureRaw = String.fromEnvironment(
    'TODO_AI_TEMPERATURE',
    defaultValue: '0.5',
  );

  static double get defaultTemperature {
    return double.tryParse(_defaultTemperatureRaw) ?? 0.5;
  }

  static const bool defaultStream = bool.fromEnvironment(
    'TODO_AI_STREAM',
    defaultValue: false,
  );

  static const int requestTimeoutSeconds = 12;

  static String get parseEndpoint {
    return Uri.parse(apiBaseUrl).resolve(parsePath).toString();
  }
}
