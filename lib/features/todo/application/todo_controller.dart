import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/settings/app_settings_repository.dart';
import '../../reminder/reminder_service.dart';
import '../data/ai_todo_parser_api.dart';
import '../data/todo_local_datasource.dart';
import '../data/todo_repository.dart';
import '../domain/todo_item.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: AppConfig.requestTimeoutSeconds),
      receiveTimeout: const Duration(seconds: AppConfig.requestTimeoutSeconds),
    ),
  );
});

final todoLocalDataSourceProvider = Provider<TodoLocalDataSource>((ref) {
  final dataSource = TodoLocalDataSource();
  ref.onDispose(dataSource.close);
  return dataSource;
});

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService();
});

final aiTodoParserApiProvider = Provider<AiTodoParserApi>((ref) {
  return AiTodoParserApi(dio: ref.watch(dioProvider));
});

final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepository(
    local: ref.watch(todoLocalDataSourceProvider),
    parser: ref.watch(aiTodoParserApiProvider),
    reminder: ref.watch(reminderServiceProvider),
    settingsRepository: ref.watch(appSettingsRepositoryProvider),
  );
});

final todoControllerProvider =
    StateNotifierProvider<TodoController, TodoViewState>((ref) {
      final controller = TodoController(
        repository: ref.watch(todoRepositoryProvider),
      );
      controller.bootstrap();
      return controller;
    });

class TodoViewState {
  const TodoViewState({
    this.todos = const <TodoItem>[],
    this.isLoading = false,
    this.isSubmitting = false,
    this.draftText = '',
    this.errorMessage,
    this.infoMessage,
  });

  final List<TodoItem> todos;
  final bool isLoading;
  final bool isSubmitting;
  final String draftText;
  final String? errorMessage;
  final String? infoMessage;

  TodoViewState copyWith({
    List<TodoItem>? todos,
    bool? isLoading,
    bool? isSubmitting,
    String? draftText,
    String? errorMessage,
    String? infoMessage,
    bool clearError = false,
    bool clearInfo = false,
  }) {
    return TodoViewState(
      todos: todos ?? this.todos,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      draftText: draftText ?? this.draftText,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
    );
  }
}

class TodoController extends StateNotifier<TodoViewState> {
  TodoController({required TodoRepository repository})
    : _repository = repository,
      super(const TodoViewState());

  final TodoRepository _repository;

  bool _isBootstrapped = false;
  Timer? _cleanupTicker;
  bool _isCleaningExpired = false;

  Future<void> bootstrap() async {
    if (_isBootstrapped) {
      return;
    }
    _isBootstrapped = true;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.initialize();
      await _repository.deleteExpiredPendingTodos(DateTime.now());
      await _repository.reschedulePendingTodos();
      await refreshTodos();
      _startCleanupTicker();
    } on MissingPluginException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            '初始化失败: 插件未注册($error)。请完全重启 App；若在 Web 端运行，请改用 Android/iOS/桌面端。',
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: '初始化失败: $error');
    }
  }

  void _startCleanupTicker() {
    _cleanupTicker?.cancel();
    _cleanupTicker = Timer.periodic(const Duration(seconds: 10), (_) {
      _cleanupExpiredPendingDeletes();
    });
  }

  Future<void> _cleanupExpiredPendingDeletes() async {
    if (_isCleaningExpired) {
      return;
    }

    _isCleaningExpired = true;
    try {
      final deletedCount = await _repository.deleteExpiredPendingTodos(
        DateTime.now(),
      );
      if (deletedCount > 0) {
        await refreshTodos();
      }
    } finally {
      _isCleaningExpired = false;
    }
  }

  Future<void> refreshTodos() async {
    final todos = await _repository.loadTodos();
    state = state.copyWith(todos: todos, isLoading: false);
  }

  void setDraftText(String value) {
    state = state.copyWith(draftText: value, clearError: true, clearInfo: true);
  }

  Future<void> submitTextInput({
    String source = 'text',
    int colorValue = 0xFF1D6FBA,
    String? forceText,
  }) async {
    if (state.isSubmitting) {
      return;
    }

    final raw = (forceText ?? state.draftText).trim();
    if (raw.isEmpty) {
      state = state.copyWith(errorMessage: '先输入一句话，比如“明早9点开组会”。');
      return;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearInfo: true,
    );

    try {
      final created = await _repository.createTodoFromInput(
        text: raw,
        source: source,
        colorValue: colorValue,
      );

      await refreshTodos();
      state = state.copyWith(
        isSubmitting: false,
        draftText: '',
        infoMessage: '已添加待办：${created.title}',
      );
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> toggleTodo(TodoItem todo) async {
    await _repository.toggleTodo(todo);
    await refreshTodos();
  }

  Future<void> deleteTodo(TodoItem todo) async {
    await _repository.deleteTodo(todo);
    await refreshTodos();
  }

  Future<void> editTodo({
    required TodoItem todo,
    required String title,
    required DateTime dueAt,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(errorMessage: '任务名称不能为空', clearInfo: true);
      return;
    }

    await _repository.editTodo(todo: todo, title: trimmed, dueAt: dueAt);
    await refreshTodos();
    state = state.copyWith(
      infoMessage: '已更新任务：$trimmed',
      clearError: true,
    );
  }

  Future<void> longPressTogglePendingDelete(TodoItem todo) async {
    if (todo.isPendingDeletion) {
      await _repository.restoreFromPendingDelete(todo);
      await refreshTodos();
      state = state.copyWith(
        infoMessage: '已恢复任务：${todo.title}',
        clearError: true,
      );
      return;
    }

    await _repository.markDoneAndScheduleDelete(todo);
    await refreshTodos();
    state = state.copyWith(
      infoMessage: '已标记完成，将在 1 分钟后删除（再次长按可恢复）',
      clearError: true,
    );
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearInfo: true);
  }

  @override
  void dispose() {
    _cleanupTicker?.cancel();
    super.dispose();
  }
}
