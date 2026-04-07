import '../../../core/settings/app_settings_repository.dart';
import '../../reminder/reminder_service.dart';
import '../domain/todo_item.dart';
import 'ai_todo_parser_api.dart';
import 'todo_local_datasource.dart';

class TodoRepository {
  TodoRepository({
    required TodoLocalDataSource local,
    required AiTodoParserApi parser,
    required ReminderService reminder,
    required AppSettingsRepository settingsRepository,
  }) : _local = local,
       _parser = parser,
       _reminder = reminder,
       _settingsRepository = settingsRepository;

  final TodoLocalDataSource _local;
  final AiTodoParserApi _parser;
  final ReminderService _reminder;
  final AppSettingsRepository _settingsRepository;

  Future<void> initialize() async {
    await _reminder.initialize();
  }

  Future<List<TodoItem>> loadTodos() {
    return _local.getTodos();
  }

  Future<TodoItem> createTodoFromInput({
    required String text,
    required String source,
    required int colorValue,
  }) async {
    final settings = await _settingsRepository.load();
    if (!settings.hasBaseUrl || !settings.hasParsePath) {
      throw Exception('请先在设置中填写 AI API 地址和解析路径。');
    }

    final uri = Uri.tryParse(settings.normalizedBaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw Exception('AI API 地址格式不正确，请在设置页修正。');
    }

    final parsed = await _parser.parseText(text, settings: settings);

    final todo = TodoItem(
      title: parsed.title,
      note: parsed.note,
      dueAt: parsed.dueAt,
      isDone: false,
      source: source,
      colorValue: colorValue,
      progress: 0,
      createdAt: DateTime.now(),
    );

    final created = await _local.insertTodo(todo);
    await _attemptSchedule(created);
    return created;
  }

  Future<TodoItem> toggleTodo(TodoItem todo) async {
    final updated = todo.isDone
        ? todo.copyWith(isDone: false, clearDeleteAt: true)
        : todo.copyWith(isDone: true);
    await _local.updateTodo(updated);
    if (updated.id != null) {
      if (updated.isDone) {
        await _reminder.cancelTodoReminder(updated.id!);
      } else {
        await _attemptSchedule(updated);
      }
    }
    return updated;
  }

  Future<void> deleteTodo(TodoItem todo) async {
    final id = todo.id;
    if (id != null) {
      await _reminder.cancelTodoReminder(id);
      await _local.deleteTodo(id);
    }
  }

  Future<void> reschedulePendingTodos() async {
    final todos = await _local.getTodos();
    for (final todo in todos.where(
      (item) => !item.isDone && !item.isPendingDeletion,
    )) {
      await _attemptSchedule(todo);
    }
  }

  Future<TodoItem> markDoneAndScheduleDelete(
    TodoItem todo, {
    Duration delay = const Duration(minutes: 1),
  }) async {
    final updated = todo.copyWith(
      isDone: true,
      deleteAt: DateTime.now().add(delay),
    );

    await _local.updateTodo(updated);
    if (updated.id != null) {
      await _reminder.cancelTodoReminder(updated.id!);
    }

    return updated;
  }

  Future<TodoItem> restoreFromPendingDelete(TodoItem todo) async {
    final updated = todo.copyWith(isDone: false, clearDeleteAt: true);

    await _local.updateTodo(updated);
    await _attemptSchedule(updated);
    return updated;
  }

  Future<int> deleteExpiredPendingTodos(DateTime now) async {
    final pendingTodos = await _local.getPendingDeletionTodos();
    final expired = pendingTodos.where((todo) {
      if (todo.id == null || todo.deleteAt == null) {
        return false;
      }
      return !todo.deleteAt!.isAfter(now);
    }).toList();

    if (expired.isEmpty) {
      return 0;
    }

    final ids = <int>[];
    for (final todo in expired) {
      final id = todo.id;
      if (id == null) {
        continue;
      }
      ids.add(id);
      await _reminder.cancelTodoReminder(id);
    }

    await _local.deleteTodosByIds(ids);
    return ids.length;
  }

  Future<void> _attemptSchedule(TodoItem todo) async {
    try {
      await _reminder.scheduleTodoReminder(todo);
    } catch (_) {
      // Avoid blocking todo creation due to vendor-specific alarm policies.
    }
  }
}
