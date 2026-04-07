class TodoItem {
  const TodoItem({
    this.id,
    required this.title,
    required this.note,
    required this.dueAt,
    required this.isDone,
    required this.source,
    required this.colorValue,
    required this.progress,
    required this.createdAt,
    this.deleteAt,
  });

  final int? id;
  final String title;
  final String note;
  final DateTime dueAt;
  final bool isDone;
  final String source;
  final int colorValue;
  final int progress;
  final DateTime createdAt;
  final DateTime? deleteAt;

  bool get isPendingDeletion {
    return deleteAt != null;
  }

  TodoItem copyWith({
    int? id,
    String? title,
    String? note,
    DateTime? dueAt,
    bool? isDone,
    String? source,
    int? colorValue,
    int? progress,
    DateTime? createdAt,
    DateTime? deleteAt,
    bool clearDeleteAt = false,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      dueAt: dueAt ?? this.dueAt,
      isDone: isDone ?? this.isDone,
      source: source ?? this.source,
      colorValue: colorValue ?? this.colorValue,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      deleteAt: clearDeleteAt ? null : (deleteAt ?? this.deleteAt),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'due_at': dueAt.toIso8601String(),
      'is_done': isDone ? 1 : 0,
      'source': source,
      'color_value': colorValue,
      'progress': progress,
      'created_at': createdAt.toIso8601String(),
      'delete_at': deleteAt?.toIso8601String(),
    };
  }

  factory TodoItem.fromMap(Map<String, Object?> map) {
    return TodoItem(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      note: map['note'] as String? ?? '',
      dueAt:
          DateTime.tryParse(map['due_at'] as String? ?? '') ?? DateTime.now(),
      isDone: (map['is_done'] as int? ?? 0) == 1,
      source: map['source'] as String? ?? 'text',
      colorValue: map['color_value'] as int? ?? 0xFF1D6FBA,
      progress: map['progress'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      deleteAt: DateTime.tryParse(map['delete_at'] as String? ?? ''),
    );
  }
}
