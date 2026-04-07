import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/settings/app_settings.dart';

class ParsedTodoDraft {
  const ParsedTodoDraft({
    required this.title,
    required this.note,
    required this.dueAt,
  });

  final String title;
  final String note;
  final DateTime dueAt;
}

class AiTodoParserApi {
  AiTodoParserApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: AppConfig.requestTimeoutSeconds),
                receiveTimeout: const Duration(seconds: AppConfig.requestTimeoutSeconds),
              ),
            );

  final Dio _dio;

  Future<ParsedTodoDraft> parseText(
    String text, {
    required AppSettings settings,
  }) async {
    final endpoint = settings.parseEndpoint;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: _buildChatCompletionsPayload(text, settings),
        options: Options(headers: _headers(settings.apiKey.trim())),
      );

      final body = _normalizeBody(response.data);
      final draft = _parseDraft(body, fallbackTitle: text);
      return draft;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final message = error.response?.data?.toString() ?? error.message ?? 'Unknown error';
      final hint = _connectionHint(
        error.type,
        message: message,
        endpoint: endpoint,
      );
      throw Exception('AI 接口调用失败($status): $message${hint.isEmpty ? '' : '；$hint'}；endpoint=$endpoint');
    } on FormatException catch (error) {
      throw Exception('AI 返回格式不正确: ${error.message}');
    }
  }

  String _connectionHint(
    DioExceptionType type, {
    required String message,
    required String endpoint,
  }) {
    if (type != DioExceptionType.connectionError && type != DioExceptionType.connectionTimeout) {
      return '';
    }

    final lowered = message.toLowerCase();
    final isDnsIssue = lowered.contains('failed host lookup') ||
        lowered.contains('name or service not known') ||
        lowered.contains('nodename nor servname provided');

    final host = Uri.tryParse(endpoint)?.host ?? '';

    if (isDnsIssue) {
      return host.isEmpty
          ? 'DNS 解析失败，请检查域名与网络，或在“应用设置”中修改 API Base URL'
          : 'DNS 解析失败（$host），请检查 DNS 或在“应用设置”中修改 API Base URL';
    }

    if (kIsWeb) {
      return 'Web 网络层错误，常见原因：CORS 未放行、证书/HTTPS 问题、域名不可达';
    }

    return '网络连接失败，请检查设备联网、DNS 与目标服务可达性；可在“应用设置”中先做连通性测试';
  }

  Map<String, dynamic> _buildChatCompletionsPayload(
    String text,
    AppSettings settings,
  ) {
    final now = DateTime.now().toIso8601String();
    return <String, dynamic>{
      'model': settings.normalizedModelName,
      'messages': <Map<String, String>>[
        <String, String>{
          'role': 'system',
          'content':
              '你是待办事项提取器。请从用户输入中提取任务信息，并且只返回一个 JSON 对象，不要输出解释文字或 Markdown。'
                  'JSON 必须包含字段 title、note、due_at。'
                  'due_at 必须是 ISO8601 时间字符串（例如 2026-04-08T09:00:00+08:00）。'
                  '当用户只给出相对时间（如明早、下周一）时，按当前时间和 Asia/Shanghai 时区换算为具体时间。'
                  '若无法识别时间，则设置为当前时间后 1 小时。',
        },
        <String, String>{
          'role': 'user',
          'content': '当前时间是 $now。用户输入：$text',
        },
      ],
      'max_tokens': settings.normalizedMaxTokens,
      'temperature': settings.normalizedTemperature,
      // Structured extraction depends on one complete JSON payload.
      'stream': false,
    };
  }

  Map<String, String> _headers(String apiKey) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  Map<String, dynamic> _normalizeBody(Map<String, dynamic>? data) {
    if (data == null) {
      throw const FormatException('空响应');
    }

    if (data['choices'] is List) {
      final choices = data['choices'] as List<dynamic>;
      if (choices.isNotEmpty && choices.first is Map<String, dynamic>) {
        final first = choices.first as Map<String, dynamic>;
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          final decoded = _decodeFromMessageObject(message);
          if (decoded != null) {
            return decoded;
          }
        }

        final text = first['text'];
        if (text is String) {
          final decoded = _decodeFromMessageContent(text);
          if (decoded != null) {
            return decoded;
          }
        }
      }

      throw FormatException('模型返回中未找到可解析的 JSON：${_preview(data)}');
    }

    if (data['todo'] is Map<String, dynamic>) {
      return data['todo'] as Map<String, dynamic>;
    }

    if (data['data'] is Map<String, dynamic>) {
      final wrapped = data['data'] as Map<String, dynamic>;
      if (wrapped['todo'] is Map<String, dynamic>) {
        return wrapped['todo'] as Map<String, dynamic>;
      }
      return wrapped;
    }

    if (_looksLikeTodoMap(data)) {
      return data;
    }

    throw FormatException('未找到待办字段：${_preview(data)}');
  }

  ParsedTodoDraft _parseDraft(
    Map<String, dynamic> json, {
    required String fallbackTitle,
  }) {
    final title = (_asString(json['title']) ?? _asString(json['task']) ?? fallbackTitle).trim();

    final note = _asString(json['note']) ?? _asString(json['description']) ?? '';
    final dueAt = _parseDate(
        json['due_at'] ??
          json['dueAt'] ??
          json['datetime'] ??
          json['remind_at'] ??
          json['due_time'] ??
          json['deadline'] ??
          json['time'],
      ) ??
        DateTime.now().add(const Duration(hours: 1));

    final adjustedDueAt = dueAt.isBefore(DateTime.now())
        ? DateTime.now().add(const Duration(minutes: 5))
        : dueAt;

    return ParsedTodoDraft(
      title: title,
      note: note.trim(),
      dueAt: adjustedDueAt,
    );
  }

  Map<String, dynamic>? _decodeFromMessageObject(Map<String, dynamic> message) {
    final contentDecoded = _decodeFromMessageContentObject(message['content']);
    if (contentDecoded != null) {
      return contentDecoded;
    }

    final functionCall = message['function_call'];
    if (functionCall is Map<String, dynamic>) {
      final arguments = functionCall['arguments'];
      if (arguments is String) {
        final decoded = _decodeFromMessageContent(arguments);
        if (decoded != null) {
          return decoded;
        }
      }
    }

    final toolCalls = message['tool_calls'];
    if (toolCalls is List) {
      for (final call in toolCalls) {
        if (call is! Map<String, dynamic>) {
          continue;
        }
        final function = call['function'];
        if (function is! Map<String, dynamic>) {
          continue;
        }
        final arguments = function['arguments'];
        if (arguments is! String) {
          continue;
        }
        final decoded = _decodeFromMessageContent(arguments);
        if (decoded != null) {
          return decoded;
        }
      }
    }

    return null;
  }

  Map<String, dynamic>? _decodeFromMessageContentObject(Object? content) {
    if (content == null) {
      return null;
    }

    if (content is String) {
      return _decodeFromMessageContent(content);
    }

    if (content is Map<String, dynamic>) {
      if (_looksLikeTodoMap(content)) {
        return content;
      }

      final text = content['text'];
      if (text is String) {
        final decoded = _decodeFromMessageContent(text);
        if (decoded != null) {
          return decoded;
        }
      }

      final value = content['value'];
      if (value is String) {
        final decoded = _decodeFromMessageContent(value);
        if (decoded != null) {
          return decoded;
        }
      }

      final jsonValue = content['json'];
      if (jsonValue is Map<String, dynamic>) {
        return jsonValue;
      }

      return null;
    }

    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is String) {
          buffer.writeln(item);
          continue;
        }

        if (item is! Map<String, dynamic>) {
          continue;
        }

        final jsonValue = item['json'];
        if (jsonValue is Map<String, dynamic>) {
          return jsonValue;
        }

        final text = item['text'];
        if (text is String) {
          buffer.writeln(text);
        } else if (text is Map<String, dynamic>) {
          final value = text['value'];
          if (value is String) {
            buffer.writeln(value);
          }
        }
      }

      final merged = buffer.toString().trim();
      if (merged.isEmpty) {
        return null;
      }
      return _decodeFromMessageContent(merged);
    }

    return null;
  }

  Map<String, dynamic>? _decodeFromMessageContent(String content) {
    final cleaned = content.trim();
    if (cleaned.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Try extracting JSON object from markdown wrappers or explanation text.
    }

    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final jsonText = cleaned.substring(start, end + 1);
      try {
        final decoded = jsonDecode(jsonText);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      final ms = value > 1000000000000 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }

    if (value is String) {
      final direct = DateTime.tryParse(value);
      if (direct != null) {
        return direct.toLocal();
      }

      final numeric = int.tryParse(value);
      if (numeric != null) {
        final ms = numeric > 1000000000000 ? numeric : numeric * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }

    return null;
  }

  bool _looksLikeTodoMap(Map<String, dynamic> json) {
    return json.containsKey('title') ||
        json.containsKey('task') ||
        json.containsKey('due_at') ||
        json.containsKey('dueAt') ||
        json.containsKey('datetime') ||
        json.containsKey('deadline');
  }

  String _preview(Object value) {
    final text = value.toString().replaceAll('\n', ' ');
    if (text.length <= 220) {
      return text;
    }
    return '${text.substring(0, 220)}...';
  }

  String? _asString(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      return value;
    }

    if (value is Map || value is List) {
      return jsonEncode(value);
    }

    return value.toString();
  }
}
