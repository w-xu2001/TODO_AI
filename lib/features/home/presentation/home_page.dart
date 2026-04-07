import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/app_settings_repository.dart';
import '../../settings/presentation/settings_page.dart';
import '../../todo/application/todo_controller.dart';
import '../../todo/domain/todo_item.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  DateTime _selectedDate = _dateOnly(DateTime.now());
  Timer? _ticker;
  bool? _lastLandscape;

  @override
  void initState() {
    super.initState();
    _restoreSystemUi();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _restoreSystemUi();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todoControllerProvider);

    ref.listen<TodoViewState>(todoControllerProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        messenger.showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
      if (next.infoMessage != null &&
          next.infoMessage != previous?.infoMessage) {
        messenger.showSnackBar(SnackBar(content: Text(next.infoMessage!)));
      }
    });

    final upcomingTodos = _upcomingTodos(state.todos, _selectedDate);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTaskSheet,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            _scheduleSystemUiSync(isLandscape);
            return Container(
              color: const Color(0xFFF2F4F7),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: isLandscape
                  ? Row(
                      children: <Widget>[
                        SizedBox(
                          width: 280,
                          child: _LeftPanel(
                            selectedDate: _selectedDate,
                            isLandscape: true,
                            onOpenSettings: _openSettings,
                            onJumpDate: _openDateJumpSheet,
                            onSelectDate: (date) {
                              setState(() {
                                _selectedDate = _dateOnly(date);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RightPanel(
                            todos: upcomingTodos,
                            onLongPressAction: (todo) {
                              ref
                                  .read(todoControllerProvider.notifier)
                                  .longPressTogglePendingDelete(todo);
                            },
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: <Widget>[
                        _LeftPanel(
                          selectedDate: _selectedDate,
                          isLandscape: false,
                          onOpenSettings: _openSettings,
                          onJumpDate: _openDateJumpSheet,
                          onSelectDate: (date) {
                            setState(() {
                              _selectedDate = _dateOnly(date);
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _RightPanel(
                            todos: upcomingTodos,
                            onLongPressAction: (todo) {
                              ref
                                  .read(todoControllerProvider.notifier)
                                  .longPressTogglePendingDelete(todo);
                            },
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  void _scheduleSystemUiSync(bool isLandscape) {
    if (_lastLandscape == isLandscape) {
      return;
    }
    _lastLandscape = isLandscape;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (isLandscape) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        _restoreSystemUi();
      }
    });
  }

  void _restoreSystemUi() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  List<TodoItem> _upcomingTodos(List<TodoItem> allTodos, DateTime fromDay) {
    final start = DateTime(fromDay.year, fromDay.month, fromDay.day);
    final list =
        allTodos.where((todo) {
          final visible = !todo.isDone || todo.isPendingDeletion;
          return visible && !todo.dueAt.isBefore(start);
        }).toList()..sort((a, b) {
          final byDue = a.dueAt.compareTo(b.dueAt);
          if (byDue != 0) {
            return byDue;
          }
          return a.createdAt.compareTo(b.createdAt);
        });
    return list;
  }

  Future<void> _openAddTaskSheet() async {
    var taskColors = AppSettings.defaultTaskColors;
    try {
      final settings = await ref.read(appSettingsRepositoryProvider).load();
      taskColors = settings.normalizedTaskColors;
    } catch (_) {
      taskColors = AppSettings.defaultTaskColors;
    }

    if (!mounted) {
      return;
    }

    final draft = await showModalBottomSheet<_AddTaskDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddTaskSheet(),
    );

    if (draft == null || !mounted) {
      return;
    }

    final notifier = ref.read(todoControllerProvider.notifier);
    final autoColor = _pickRandomHarmonicColor(taskColors);

    await notifier.submitTextInput(
      source: draft.source,
      forceText: draft.text,
      colorValue: autoColor,
    );
  }

  int _pickRandomHarmonicColor(List<int> colors) {
    final palette = colors.isEmpty ? AppSettings.defaultTaskColors : colors;
    final base = Color(palette.first);
    final random = Random(DateTime.now().microsecondsSinceEpoch);
    final lighten = random.nextBool();
    final amount = lighten
        ? 0.10 + random.nextDouble() * 0.22
        : 0.05 + random.nextDouble() * 0.14;
    final mixed =
        Color.lerp(base, lighten ? Colors.white : Colors.black, amount) ?? base;
    return mixed.toARGB32();
  }

  Future<void> _openDateJumpSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.today_rounded),
                title: const Text('回到今天'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    final now = DateTime.now();
                    _selectedDate = _dateOnly(now);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_rounded),
                title: const Text('月视图选日期（快速跳天）'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365 * 2),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (picked != null && mounted) {
                    setState(() {
                      _selectedDate = _dateOnly(picked);
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.view_week_rounded),
                title: const Text('按周跳转（选中该周周一）'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365 * 2),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (picked != null && mounted) {
                    final monday = _startOfWeek(_dateOnly(picked));
                    setState(() {
                      _selectedDate = monday;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _startOfWeek(DateTime value) {
    return value.subtract(Duration(days: value.weekday - 1));
  }
}

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({
    required this.selectedDate,
    required this.isLandscape,
    required this.onOpenSettings,
    required this.onJumpDate,
    required this.onSelectDate,
  });

  final DateTime selectedDate;
  final bool isLandscape;
  final VoidCallback onOpenSettings;
  final VoidCallback onJumpDate;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: '设置',
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_rounded),
                ),
                Expanded(
                  child: Text(
                    DateFormat('yyyy/MM').format(selectedDate),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onJumpDate,
                  icon: const Icon(
                    Icons.calendar_today_rounded,
                    color: Color(0xFF7D899B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _CollapsibleCalendar(
              selectedDate: selectedDate,
              onSelectDate: onSelectDate,
              isLandscape: isLandscape,
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsibleCalendar extends StatefulWidget {
  const _CollapsibleCalendar({
    required this.selectedDate,
    required this.onSelectDate,
    required this.isLandscape,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final bool isLandscape;

  @override
  State<_CollapsibleCalendar> createState() => _CollapsibleCalendarState();
}

class _CollapsibleCalendarState extends State<_CollapsibleCalendar> {
  bool _expanded = false;
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    final forceExpanded = widget.isLandscape;
    final effectiveExpanded = forceExpanded || _expanded;

    return Column(
      children: <Widget>[
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: effectiveExpanded
              ? _MonthGridCalendar(
                  selectedDate: widget.selectedDate,
                  onSelectDate: widget.onSelectDate,
                  isLandscape: widget.isLandscape,
                )
              : _WeekStripCalendar(
                  selectedDate: widget.selectedDate,
                  onSelectDate: widget.onSelectDate,
                ),
        ),
        if (!forceExpanded) ...<Widget>[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            onVerticalDragUpdate: (details) {
              _dragDistance += details.delta.dy;
            },
            onVerticalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (_dragDistance > 16 || velocity > 200) {
                setState(() {
                  _expanded = true;
                });
              } else if (_dragDistance < -16 || velocity < -200) {
                setState(() {
                  _expanded = false;
                });
              }
              _dragDistance = 0;
            },
            child: Container(
              width: 42,
              height: 24,
              alignment: Alignment.center,
              child: Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFFA5ACB6),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MonthGridCalendar extends StatelessWidget {
  const _MonthGridCalendar({
    required this.selectedDate,
    required this.onSelectDate,
    required this.isLandscape,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final bool isLandscape;

  @override
  Widget build(BuildContext context) {
    final displayMonth = DateTime(selectedDate.year, selectedDate.month);
    final firstDay = DateTime(displayMonth.year, displayMonth.month, 1);
    final firstWeekdayOffset = firstDay.weekday - 1;
    final daysInMonth = DateTime(
      displayMonth.year,
      displayMonth.month + 1,
      0,
    ).day;

    final cells = List<DateTime?>.filled(42, null);
    for (int day = 1; day <= daysInMonth; day++) {
      final index = firstWeekdayOffset + day - 1;
      cells[index] = DateTime(displayMonth.year, displayMonth.month, day);
    }

    return Column(
      children: <Widget>[
        const Row(
          children: <Widget>[
            _WeekdayMiniCell('一'),
            _WeekdayMiniCell('二'),
            _WeekdayMiniCell('三'),
            _WeekdayMiniCell('四'),
            _WeekdayMiniCell('五'),
            _WeekdayMiniCell('六'),
            _WeekdayMiniCell('日'),
          ],
        ),
        const SizedBox(height: 4),
        ...List<Widget>.generate(6, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: List<Widget>.generate(7, (col) {
                final date = cells[row * 7 + col];
                if (date == null) {
                  return const Expanded(child: SizedBox(height: 42));
                }

                final isSelected =
                    date.year == selectedDate.year &&
                    date.month == selectedDate.month &&
                    date.day == selectedDate.day;

                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSelectDate(date),
                    child: Container(
                      height: isLandscape ? 38 : 44,
                      alignment: Alignment.center,
                      child: isSelected
                          ? Container(
                              width: isLandscape ? 30 : 36,
                              height: isLandscape ? 30 : 36,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF5A2A),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${date.day}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : Text(
                              '${date.day}',
                              style: const TextStyle(
                                color: Color(0xFF1E242F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }
}

class _WeekdayMiniCell extends StatelessWidget {
  const _WeekdayMiniCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5F6B7F),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _WeekStripCalendar extends StatefulWidget {
  const _WeekStripCalendar({
    required this.selectedDate,
    required this.onSelectDate,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  @override
  State<_WeekStripCalendar> createState() => _WeekStripCalendarState();
}

class _WeekStripCalendarState extends State<_WeekStripCalendar> {
  static const int _basePage = 5000;
  late final PageController _pageController;
  late DateTime _anchorWeekStart;
  late int _weekdayIndex;

  @override
  void initState() {
    super.initState();
    _anchorWeekStart = _startOfWeek(_dateOnly(widget.selectedDate));
    _weekdayIndex = widget.selectedDate.weekday - 1;
    _pageController = PageController(initialPage: _basePage);
  }

  @override
  void didUpdateWidget(covariant _WeekStripCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _weekdayIndex = widget.selectedDate.weekday - 1;
    final newWeekStart = _startOfWeek(_dateOnly(widget.selectedDate));
    final diffWeeks = newWeekStart.difference(_anchorWeekStart).inDays ~/ 7;
    final targetPage = _basePage + diffWeeks;
    if (_pageController.hasClients) {
      final currentPage = (_pageController.page ?? _basePage.toDouble())
          .round();
      if (currentPage != targetPage) {
        _pageController.jumpToPage(targetPage);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          final weekStart = _weekStartForPage(index);
          final nextDate = weekStart.add(Duration(days: _weekdayIndex));
          if (!_isSameDay(nextDate, widget.selectedDate)) {
            widget.onSelectDate(nextDate);
          }
        },
        itemBuilder: (context, index) {
          final weekStart = _weekStartForPage(index);
          return Row(
            children: List<Widget>.generate(7, (dayOffset) {
              final date = weekStart.add(Duration(days: dayOffset));
              final isSelected = _isSameDay(date, widget.selectedDate);

              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    widget.onSelectDate(date);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF5A2A)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          DateFormat('E').format(date),
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF738197),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 16,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF1D2738),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  DateTime _weekStartForPage(int page) {
    final offsetWeek = page - _basePage;
    return _anchorWeekStart.add(Duration(days: offsetWeek * 7));
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _startOfWeek(DateTime value) {
    return value.subtract(Duration(days: value.weekday - 1));
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.todos, required this.onLongPressAction});

  final List<TodoItem> todos;
  final ValueChanged<TodoItem> onLongPressAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Tasks',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: todos.isEmpty
              ? Center(
                  child: Text(
                    '暂无任务，点击右下角 + 添加。\n点击卡片有涟漪，长按可完成并延迟删除。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF8390A3),
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  itemCount: todos.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final todo = todos[index];
                    return _MissionCard(
                      todo: todo,
                      onLongPressAction: () => onLongPressAction(todo),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.todo, required this.onLongPressAction});

  final TodoItem todo;
  final VoidCallback onLongPressAction;

  @override
  Widget build(BuildContext context) {
    final startAt = todo.createdAt;
    final endAt = todo.dueAt.isAfter(startAt)
        ? todo.dueAt
        : startAt.add(const Duration(minutes: 1));
    final now = DateTime.now();
    final isOverdue = !todo.dueAt.isAfter(now);
    final dueLabel = DateFormat('MM-dd HH:mm').format(todo.dueAt);
    final remainingLabel = _remainingText(todo.dueAt, now);

    final baseColor = isOverdue
      ? const Color(0xFFF2994A)
      : Color(todo.colorValue);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        _mixColor(
          baseColor,
          Colors.white,
          todo.isPendingDeletion ? 0.52 : 0.20,
        ),
        _mixColor(
          baseColor,
          Colors.black,
          todo.isPendingDeletion ? 0.36 : 0.10,
        ),
      ],
    );
    final progress = _autoProgress(
      isDone: todo.isDone,
      startAt: startAt,
      endAt: endAt,
      now: now,
    );
    final progressValue = progress / 100;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              blurRadius: 8,
              offset: Offset(0, 3),
              color: Color(0x29176BB8),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withValues(alpha: 0.45),
          highlightColor: Colors.white.withValues(alpha: 0.10),
          onTap: () {
            // Tap only plays ripple feedback to keep interactions lightweight.
          },
          onLongPress: onLongPressAction,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        todo.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          decoration: todo.isPendingDeletion
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: Colors.white.withValues(alpha: 0.90),
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      remainingLabel,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFFEAF5FF),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '截至: $dueLabel',
                  style: const TextStyle(
                    color: Color(0xFFEAF5FF),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                if (todo.isPendingDeletion &&
                    todo.deleteAt != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '将于 ${_pendingDeleteText(todo.deleteAt!, now)} 后删除（再次长按可恢复）',
                    style: const TextStyle(
                      color: Color(0xFFFFF3C9),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Text(
                      '进度',
                      style: TextStyle(
                        color: Color(0xFFEAF5FF),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$progress%',
                      style: const TextStyle(
                        color: Color(0xFFEAF5FF),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: progressValue,
                    backgroundColor: Colors.white.withValues(alpha: 0.28),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _remainingText(DateTime dueAt, DateTime now) {
    if (!dueAt.isAfter(now)) {
      return '已截至';
    }

    final diff = dueAt.difference(now);
    if (diff == Duration.zero) {
      return '已截至';
    }

    final days = diff.inDays;
    final hours = diff.inHours.remainder(24);
    final minutes = diff.inMinutes.remainder(60);

    if (days > 0) {
      return hours > 0 ? '$days天$hours小时' : '$days天';
    }
    if (diff.inHours > 0) {
      return minutes > 0 ? '${diff.inHours}小时$minutes分钟' : '${diff.inHours}小时';
    }
    return '${max(1, diff.inMinutes)}分钟';
  }

  String _pendingDeleteText(DateTime deleteAt, DateTime now) {
    final diff = deleteAt.isAfter(now)
        ? deleteAt.difference(now)
        : Duration.zero;
    final totalSeconds = diff.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes分${seconds.toString().padLeft(2, '0')}秒';
  }

  Color _mixColor(Color base, Color overlay, double amount) {
    final clamped = amount.clamp(0.0, 1.0);
    return Color.lerp(base, overlay, clamped) ?? base;
  }

  int _autoProgress({
    required bool isDone,
    required DateTime startAt,
    required DateTime endAt,
    required DateTime now,
  }) {
    if (isDone) {
      return 100;
    }
    if (!endAt.isAfter(startAt)) {
      return now.isAfter(endAt) ? 100 : 0;
    }
    if (now.isBefore(startAt)) {
      return 0;
    }
    if (!now.isBefore(endAt)) {
      return 100;
    }

    final totalMs = endAt.difference(startAt).inMilliseconds;
    final elapsedMs = now.difference(startAt).inMilliseconds;
    final ratio = elapsedMs / totalMs;
    return (ratio * 100).round().clamp(0, 100);
  }
}

class _AddTaskDraft {
  const _AddTaskDraft({required this.text, required this.source});

  final String text;
  final String source;
}

class _AddTaskSheet extends ConsumerStatefulWidget {
  const _AddTaskSheet();

  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '添加任务',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _textController,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '输入任务内容',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFFF0F2F5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('确认添加'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先输入内容。')));
      return;
    }

    if (mounted) {
      Navigator.of(context).pop(_AddTaskDraft(text: text, source: 'text'));
    }
  }
}
