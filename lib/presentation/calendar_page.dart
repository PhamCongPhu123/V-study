import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'design_system.dart';
import 'widgets.dart' show errorMessage;

/// Real local calendar dates; data adapters handle UTC serialization.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.useCases});
  final VstudyUseCases useCases;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

enum _CalendarRange { day, week, month }

class _CalendarPageState extends State<CalendarPage> {
  DateTime _selected = DateTime.now();
  _CalendarRange _range = _CalendarRange.day;
  late Future<List<StudyEvent>> _events;
  final _timelineScroll = ScrollController();
  bool _mutating = false;

  @override
  void initState() {
    super.initState();
    _events = _load();
  }

  @override
  void dispose() {
    _timelineScroll.dispose();
    super.dispose();
  }

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
  DateTime _nextDay(DateTime value) =>
      DateTime(value.year, value.month, value.day + 1);
  DateTime get _weekStart => DateTime(
    _selected.year,
    _selected.month,
    _selected.day - _selected.weekday + 1,
  );

  (DateTime, DateTime) get _bounds {
    if (_range == _CalendarRange.month) {
      final first = DateTime(_selected.year, _selected.month);
      final start = DateTime(
        first.year,
        first.month,
        first.day - first.weekday + 1,
      );
      return (start, DateTime(start.year, start.month, start.day + 42));
    }
    // The full week also supplies markers in the day selector.
    final start = _weekStart;
    return (start, DateTime(start.year, start.month, start.day + 7));
  }

  Future<List<StudyEvent>> _load() =>
      widget.useCases.study.listEvents(_bounds.$1, _bounds.$2);
  void _refresh() => setState(() => _events = _load());

  void _selectDate(DateTime value) {
    setState(() {
      _selected = _day(value);
      _events = _load();
    });
  }

  void _move(int delta) {
    if (_range == _CalendarRange.month) {
      final lastDay = DateTime(
        _selected.year,
        _selected.month + delta + 1,
        0,
      ).day;
      _selectDate(
        DateTime(
          _selected.year,
          _selected.month + delta,
          math.min(_selected.day, lastDay),
        ),
      );
    } else {
      _selectDate(
        DateTime(
          _selected.year,
          _selected.month,
          _selected.day + delta * (_range == _CalendarRange.week ? 7 : 1),
        ),
      );
    }
  }

  Future<void> _chooseDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (value != null && mounted) {
      _selectDate(value);
    }
  }

  Future<void> _edit([StudyEvent? event]) async {
    if (_mutating) {
      return;
    }
    setState(() => _mutating = true);
    try {
      final subjects = await widget.useCases.study.listSubjects();
      if (!mounted) {
        return;
      }
      final changed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EventEditor(
          useCases: widget.useCases,
          subjects: subjects,
          selectedDay: _selected,
          existing: event,
        ),
      );
      if (mounted && changed == true) {
        _refresh();
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _mutating = false);
      }
    }
  }

  void _showError(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage(error))));
    }
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    if (_mutating) {
      return;
    }
    setState(() => _mutating = true);
    try {
      await action();
      if (mounted) {
        _refresh();
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _mutating = false);
      }
    }
  }

  Future<void> _delete(StudyEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa buổi học?'),
        content: Text(
          'Xóa “${event.title}” và checklist của buổi này? Các buổi lặp lại khác vẫn được giữ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _runMutation(() => widget.useCases.study.deleteEvent(event.id));
    }
  }

  Future<void> _details(StudyEvent event) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: VstudyColors.paper,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chi tiết buổi học',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _eventColor(event),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_kindLabel(event.kind)),
                    Text(
                      '${DateFormat('dd/MM/yyyy HH:mm').format(event.startsAt.toLocal())} – ${DateFormat('dd/MM/yyyy HH:mm').format(event.endsAt.toLocal())}',
                    ),
                    if (event.location.isNotEmpty)
                      Text('Địa điểm: ${event.location}'),
                  ],
                ),
              ),
              if (event.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(event.notes),
                ),
              if (event.seriesId != null)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Thuộc chuỗi lịch hằng tuần'),
                ),
              if (event.reminderMinutes != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Nhắc trước ${event.reminderMinutes} phút · đã lưu cài đặt, chưa gửi thông báo thiết bị',
                  ),
                ),
              if (event.tasks.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Việc cần chuẩn bị',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                ...event.tasks.map(
                  (task) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(task.title),
                    value: task.isCompleted,
                    onChanged: _mutating
                        ? null
                        : (checked) {
                            Navigator.pop(sheetContext);
                            _runMutation(
                              () => widget.useCases.study.setTaskCompleted(
                                task.id,
                                checked ?? false,
                              ),
                            );
                          },
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, 'delete'),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Xóa buổi học'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, 'edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Sửa'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (action == 'edit') {
      await _edit(event);
    }
    if (action == 'delete') {
      await _delete(event);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tháng ${_selected.month}, ${_selected.year}',
              style: const TextStyle(fontSize: 11, color: VstudyColors.muted),
            ),
            const SizedBox(height: 3),
            LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  Expanded(
                    child: Text(
                      'Thời gian biểu',
                      style: TextStyle(
                        color: VstudyColors.navy,
                        fontSize: constraints.maxWidth < 330 ? 20 : 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (constraints.maxWidth >= 330)
                    IconButton(
                      tooltip: 'Tải lại lịch',
                      onPressed: _mutating ? null : _refresh,
                      icon: const Icon(Icons.refresh, size: 19),
                    ),
                  FilledButton.icon(
                    onPressed: _mutating ? null : _edit,
                    style: FilledButton.styleFrom(
                      backgroundColor: VstudyColors.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: const Size(82, 38),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('Thêm'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE1DFDA),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: _CalendarRange.values.map((range) {
                  final selected = _range == range;
                  final label = switch (range) {
                    _CalendarRange.day => 'Ngày',
                    _CalendarRange.week => 'Tuần',
                    _CalendarRange.month => 'Tháng',
                  };
                  return Expanded(
                    child: Semantics(
                      selected: selected,
                      button: true,
                      child: InkWell(
                        key: ValueKey('calendar-view-${range.name}'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() {
                          _range = range;
                          _events = _load();
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? VstudyColors.navy
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: selected
                                  ? Colors.white
                                  : VstudyColors.navy,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      if (_mutating) const LinearProgressIndicator(minHeight: 2),
      Expanded(
        child: FutureBuilder<List<StudyEvent>>(
          future: _events,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(errorMessage(snapshot.error!)),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final events = snapshot.data ?? const <StudyEvent>[];
            return _range == _CalendarRange.month
                ? _monthView(events)
                : _timeView(events);
          },
        ),
      ),
    ],
  );

  Widget _dateNavigation({bool month = false}) => Row(
    children: [
      IconButton(
        tooltip: month ? 'Tháng trước' : 'Khoảng trước',
        onPressed: () => _move(-1),
        icon: const Icon(Icons.chevron_left, size: 20),
      ),
      Expanded(
        child: TextButton(
          onPressed: _chooseDate,
          child: Text(
            month
                ? 'Tháng ${_selected.month}, ${_selected.year}'
                : _range == _CalendarRange.week
                ? '${DateFormat('dd/MM').format(_weekStart)} – ${DateFormat('dd/MM').format(DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 6))}'
                : '${_weekday(_selected)}, ${DateFormat('dd/MM').format(_selected)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: VstudyColors.navy,
            ),
          ),
        ),
      ),
      IconButton(
        tooltip: month ? 'Tháng sau' : 'Khoảng sau',
        onPressed: () => _move(1),
        icon: const Icon(Icons.chevron_right, size: 20),
      ),
    ],
  );

  Widget _weekStrip(List<StudyEvent> events) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: List.generate(7, (index) {
        final date = DateTime(
          _weekStart.year,
          _weekStart.month,
          _weekStart.day + index,
        );
        final selected = _day(date) == _day(_selected);
        final hasDeadline = _forDay(
          events,
          date,
        ).any((e) => e.kind == EventKind.deadline);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Semantics(
              label:
                  '${_weekday(date)}, ${DateFormat('dd/MM/yyyy').format(date)}',
              selected: selected,
              button: true,
              child: InkWell(
                onTap: () => _selectDate(date),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected
                        ? VstudyColors.navy
                        : const Color(0xFFE1E5EE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _weekdays[index],
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? Colors.white : VstudyColors.navy,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : VstudyColors.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasDeadline
                              ? VstudyColors.red
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );

  Widget _timeView(List<StudyEvent> events) {
    final days = _range == _CalendarRange.week
        ? List.generate(
            7,
            (i) =>
                DateTime(_weekStart.year, _weekStart.month, _weekStart.day + i),
          )
        : [_day(_selected)];
    final selectedEvents = _forDay(events, _selected);
    final remaining = selectedEvents
        .where(
          (e) =>
              e.kind == EventKind.selfStudy && e.endsAt.isAfter(DateTime.now()),
        )
        .length;
    return Column(
      children: [
        _weekStrip(events),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _dateNavigation(),
        ),
        if (_range == _CalendarRange.day)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Còn $remaining buổi tự học',
                style: const TextStyle(color: VstudyColors.muted, fontSize: 11),
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rowHeight = ((constraints.maxHeight - 16) / 24)
                  .clamp(24.0, 40.0)
                  .toDouble();
              const labelWidth = 42.0;
              final contentWidth = math.max(
                0.0,
                constraints.maxWidth - labelWidth - 30,
              );
              final columnWidth = contentWidth / days.length;
              return SingleChildScrollView(
                controller: _timelineScroll,
                padding: const EdgeInsets.fromLTRB(14, 6, 16, 18),
                child: SizedBox(
                  height: 24 * rowHeight + 16,
                  child: Stack(
                    children: [
                      for (var hour = 0; hour <= 24; hour++) ...[
                        Positioned(
                          top: hour * rowHeight,
                          left: 0,
                          width: labelWidth - 6,
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: const TextStyle(
                              fontSize: 9,
                              color: VstudyColors.muted,
                            ),
                          ),
                        ),
                        Positioned(
                          top: hour * rowHeight + 5,
                          left: labelWidth,
                          right: 0,
                          child: Container(
                            height: 1,
                            color: const Color(0xFFD7D5CF),
                          ),
                        ),
                      ],
                      if (days.length > 1)
                        for (var i = 1; i < days.length; i++)
                          Positioned(
                            left: labelWidth + i * columnWidth,
                            top: 5,
                            bottom: 12,
                            child: Container(
                              width: 1,
                              color: const Color(0xFFE6E3DB),
                            ),
                          ),
                      for (var column = 0; column < days.length; column++)
                        ..._timelineBlocks(
                          events,
                          days[column],
                          column,
                          columnWidth,
                          labelWidth,
                          rowHeight,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _legend(),
      ],
    );
  }

  List<Widget> _timelineBlocks(
    List<StudyEvent> events,
    DateTime date,
    int column,
    double columnWidth,
    double labelWidth,
    double rowHeight,
  ) {
    final dayEvents = _forDay(events, date)
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final placements = <_EventPlacement>[];
    var group = <_EventPlacement>[];
    var groupEnd = -1.0;
    var groupColumns = 1;
    void finishGroup() {
      for (final placement in group) placement.columns = groupColumns;
      group = [];
      groupColumns = 1;
      groupEnd = -1;
    }

    for (final event in dayEvents) {
      final start = _wallMinute(event.startsAt, date);
      final end = _wallMinute(event.endsAt, date);
      final visibleEnd = math.min(
        1440.0,
        math.max(end, start + (daysAreNarrow ? 28 : 60)),
      );
      if (start >= groupEnd) {
        finishGroup();
      }
      var lane = 0;
      while (group.any((item) => item.lane == lane && item.end > start)) lane++;
      groupColumns = math.max(groupColumns, lane + 1);
      final placement = _EventPlacement(event, start, visibleEnd, lane);
      group.add(placement);
      placements.add(placement);
      groupEnd = math.max(groupEnd, visibleEnd);
    }
    finishGroup();
    return placements.map((placement) {
      final width = math.max(1.0, columnWidth / placement.columns - 5);
      final height = math.max(
        10.0,
        (placement.end - placement.start) / 60 * rowHeight - 3,
      );
      final event = placement.event;
      return Positioned(
        top: placement.start / 60 * rowHeight + 5,
        left:
            labelWidth +
            column * columnWidth +
            placement.lane * columnWidth / placement.columns +
            2,
        width: width,
        height: height,
        child: Semantics(
          label:
              '${event.title}, ${_kindLabel(event.kind)}, ${DateFormat('HH:mm').format(event.startsAt.toLocal())}',
          button: true,
          child: Tooltip(
            message: event.title,
            child: Material(
              color: _eventColor(event),
              elevation: 1,
              shadowColor: VstudyColors.navy.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(daysAreNarrow ? 5 : 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(daysAreNarrow ? 5 : 14),
                onTap: _mutating ? null : () => _details(event),
                child: ClipRect(
                  child: Padding(
                    padding: EdgeInsets.all(daysAreNarrow ? 3 : 6),
                    child: width < 68 || height < 25
                        ? const SizedBox.shrink()
                        : SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    color: VstudyColors.navy,
                                  ),
                                ),
                                if (height >= 39) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${DateFormat('HH:mm').format(event.startsAt.toLocal())} – ${DateFormat('HH:mm').format(event.endsAt.toLocal())}'
                                    '${event.location.isEmpty ? '' : ' · ${event.location}'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      height: 1.15,
                                      color: VstudyColors.navy,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  bool get daysAreNarrow => _range == _CalendarRange.week;
  double _wallMinute(DateTime value, DateTime date) {
    final local = value.toLocal();
    if (local.isBefore(_day(date))) {
      return 0;
    }
    if (!local.isBefore(_nextDay(date))) {
      return 1440;
    }
    return (local.hour * 60 + local.minute).toDouble();
  }

  Widget _monthView(List<StudyEvent> events) {
    final monthFirst = DateTime(_selected.year, _selected.month);
    final gridStart = DateTime(
      monthFirst.year,
      monthFirst.month,
      2 - monthFirst.weekday,
    );
    final selectedEvents = _forDay(events, _selected);
    final selfStudy = selectedEvents
        .where((e) => e.kind == EventKind.selfStudy)
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        _dateNavigation(month: true),
        const SizedBox(height: 14),
        Row(
          children: _weekdays
              .map(
                (label) => Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: VstudyColors.navy,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = constraints.maxWidth / 7;
            return Wrap(
              children: List.generate(42, (index) {
                final date = DateTime(
                  gridStart.year,
                  gridStart.month,
                  gridStart.day + index,
                );
                final selected = _day(date) == _day(_selected);
                final today = _day(date) == _day(DateTime.now());
                final inMonth = date.month == _selected.month;
                final deadline = _forDay(
                  events,
                  date,
                ).any((e) => e.kind == EventKind.deadline);
                return SizedBox(
                  width: cellWidth,
                  height: 44,
                  child: Semantics(
                    label:
                        '${_weekday(date)}, ${DateFormat('dd/MM/yyyy').format(date)}',
                    selected: selected,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _selectDate(date),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 29,
                            height: 29,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? VstudyColors.navy
                                  : Colors.transparent,
                              border: today && !selected
                                  ? Border.all(color: VstudyColors.gold)
                                  : null,
                            ),
                            child: Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected || today
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : inMonth
                                    ? VstudyColors.navy
                                    : const Color(0xFFB8B6B0),
                              ),
                            ),
                          ),
                          Container(
                            width: 3,
                            height: 3,
                            margin: const EdgeInsets.only(top: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: deadline
                                  ? VstudyColors.red
                                  : Colors.transparent,
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
        const SizedBox(height: 14),
        Text(
          '${_weekday(_selected)}, ${DateFormat('dd/MM').format(_selected)}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: VstudyColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Còn $selfStudy buổi tự học',
          style: const TextStyle(fontSize: 11, color: VstudyColors.muted),
        ),
        const SizedBox(height: 12),
        if (selectedEvents.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: VstudyColors.paper,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Ngày này chưa có lịch. Chọn + Thêm để lên kế hoạch học tập.',
              style: TextStyle(fontSize: 12, color: VstudyColors.muted),
            ),
          ),
        ...selectedEvents.map(_agendaCard),
        const SizedBox(height: 12),
        _legend(),
      ],
    );
  }

  Widget _agendaCard(StudyEvent event) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: _eventColor(event),
      elevation: 1,
      shadowColor: VstudyColors.navy.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: () => _details(event),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: VstudyColors.navy,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('HH:mm').format(event.startsAt.toLocal())} – ${DateFormat('HH:mm').format(event.endsAt.toLocal())}'
                '${event.location.isEmpty ? '' : ' · ${event.location}'}',
                style: const TextStyle(fontSize: 10, color: VstudyColors.navy),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _legend() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    child: Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _legendItem(const Color(0xFFC7CFDF), 'Lịch học trên lớp'),
        _legendItem(const Color(0xFFF9EDB9), 'Lịch ôn tập tự học'),
        _legendItem(VstudyColors.red, 'Deadline dưới 2 ngày'),
        _legendItem(const Color(0xFF409D72), 'Deadline từ 2 ngày'),
      ],
    ),
  );
  Widget _legendItem(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: VstudyColors.navy.withValues(alpha: .2)),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 9, color: VstudyColors.muted),
      ),
    ],
  );

  Color _eventColor(StudyEvent event) => switch (event.kind) {
    EventKind.classSession => const Color(0xFFC7CFDF),
    EventKind.selfStudy => const Color(0xFFF9EDB9),
    EventKind.deadline =>
      event.startsAt.difference(DateTime.now()) < const Duration(days: 2)
          ? VstudyColors.red
          : const Color(0xFF409D72),
  };
  List<StudyEvent> _forDay(List<StudyEvent> events, DateTime date) =>
      events
          .where(
            (event) =>
                event.startsAt.isBefore(_nextDay(date)) &&
                event.endsAt.isAfter(_day(date)),
          )
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  String _weekday(DateTime date) =>
      date.weekday == 7 ? 'Chủ nhật' : 'Thứ ${date.weekday + 1}';
}

class _EventPlacement {
  _EventPlacement(this.event, this.start, this.end, this.lane);
  final StudyEvent event;
  final double start;
  final double end;
  final int lane;
  int columns = 1;
}

String _kindLabel(EventKind kind) => switch (kind) {
  EventKind.classSession => 'Lịch học trên lớp',
  EventKind.selfStudy => 'Lịch ôn tập tự học',
  EventKind.deadline => 'Deadline',
};

class _EventEditor extends StatefulWidget {
  const _EventEditor({
    required this.useCases,
    required this.subjects,
    required this.selectedDay,
    this.existing,
  });

  final VstudyUseCases useCases;
  final List<Subject> subjects;
  final DateTime selectedDay;
  final StudyEvent? existing;

  @override
  State<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<_EventEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  final _tasks = TextEditingController();
  final _repeat = TextEditingController(text: '0');
  late DateTime _starts;
  late DateTime _ends;
  late EventKind _kind;
  String? _subjectId;
  int? _reminder;
  late List<Subject> _subjects;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final event = widget.existing;
    _title = TextEditingController(text: event?.title ?? '');
    _location = TextEditingController(text: event?.location ?? '');
    _notes = TextEditingController(text: event?.notes ?? '');
    _subjects = [...widget.subjects];
    _subjectId = event?.subjectId;
    _kind = event?.kind ?? EventKind.selfStudy;
    _reminder = event?.reminderMinutes;
    _starts =
        event?.startsAt.toLocal() ??
        DateTime(
          widget.selectedDay.year,
          widget.selectedDay.month,
          widget.selectedDay.day,
          8,
        );
    _ends = event?.endsAt.toLocal() ?? _starts.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    _tasks.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final previous = start ? _starts : _ends;
    final date = await showDatePicker(
      context: context,
      initialDate: previous,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(previous),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (start) {
        final previousDuration = _ends.difference(_starts);
        _starts = value;
        _ends = value.add(
          previousDuration.isNegative || previousDuration == Duration.zero
              ? const Duration(hours: 1)
              : previousDuration,
        );
      } else {
        _ends = value;
      }
    });
  }

  Future<void> _addSubject() async {
    final input = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm môn học'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Tên môn học'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    // Dispose after the closing route has completed using the controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
    if (name == null || name.isEmpty || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final subject = await widget.useCases.createSubject(name);
      if (!mounted) {
        return;
      }
      setState(() {
        _subjects.add(subject);
        _subjectId = subject.id;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }
    if (!_ends.isAfter(_starts)) {
      setState(() => _error = 'Giờ kết thúc phải sau giờ bắt đầu.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final draft = EventDraft(
      title: _title.text.trim(),
      kind: _kind,
      startsAt: _starts,
      endsAt: _ends,
      subjectId: _subjectId,
      location: _location.text.trim(),
      notes: _notes.text.trim(),
      reminderMinutes: _reminder,
      repeatWeeks: widget.existing == null ? int.parse(_repeat.text) : 0,
      taskTitles:
          widget.existing?.tasks.map((task) => task.title).toList() ??
          _tasks.text
              .split('\n')
              .map((task) => task.trim())
              .where((task) => task.isNotEmpty)
              .toList(),
    );
    try {
      final existing = widget.existing;
      if (existing != null) {
        await widget.useCases.updateEvent(existing.id, draft);
      } else {
        await widget.useCases.createEvent(draft);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy HH:mm');
    final reminders = <int>{
      5,
      15,
      30,
      60,
      120,
      1440,
      if (_reminder != null) _reminder!,
    }.toList()..sort();
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(
          widget.existing == null ? 'Thêm lịch học / deadline' : 'Sửa buổi học',
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.existing?.seriesId != null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Thay đổi chỉ áp dụng cho buổi này trong chuỗi lịch.',
                      ),
                    ),
                  TextFormField(
                    controller: _title,
                    enabled: !_busy,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Tên buổi học / deadline',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nhập tên lịch.'
                        : null,
                  ),
                  DropdownButtonFormField<EventKind>(
                    initialValue: _kind,
                    decoration: const InputDecoration(labelText: 'Loại lịch'),
                    items: EventKind.values
                        .map(
                          (kind) => DropdownMenuItem(
                            value: kind,
                            child: Text(_kindLabel(kind)),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _kind = value!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('subject-$_subjectId-${_subjects.length}'),
                    initialValue: _subjectId,
                    decoration: const InputDecoration(labelText: 'Môn học'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Không chọn'),
                      ),
                      ..._subjects.map(
                        (subject) => DropdownMenuItem(
                          value: subject.id,
                          child: Text(subject.name),
                        ),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _subjectId = value),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _addSubject,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm môn học'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pickTime(true),
                    icon: const Icon(Icons.event),
                    label: Text('Bắt đầu: ${format.format(_starts)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pickTime(false),
                    icon: const Icon(Icons.schedule),
                    label: Text('Kết thúc: ${format.format(_ends)}'),
                  ),
                  TextFormField(
                    controller: _location,
                    enabled: !_busy,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'Địa điểm / phòng học',
                    ),
                  ),
                  TextFormField(
                    controller: _notes,
                    enabled: !_busy,
                    maxLines: 3,
                    maxLength: 5000,
                    decoration: const InputDecoration(labelText: 'Ghi chú'),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _reminder,
                    decoration: const InputDecoration(labelText: 'Nhắc trước'),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Không nhắc'),
                      ),
                      ...reminders.map(
                        (minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes phút'),
                        ),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _reminder = value),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Thời gian nhắc được lưu. Phiên bản này chưa gửi thông báo trên thiết bị.',
                    ),
                  ),
                  if (widget.existing == null) ...[
                    TextFormField(
                      controller: _repeat,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Số tuần lặp thêm (0 = không lặp)',
                        helperText:
                            'Tối đa 52 tuần; tạo lịch cùng giờ mỗi tuần.',
                      ),
                      validator: (value) {
                        final weeks = int.tryParse(value ?? '');
                        return weeks == null || weeks < 0 || weeks > 52
                            ? 'Nhập số tuần từ 0 đến 52.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tasks,
                      enabled: !_busy,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Việc cần chuẩn bị',
                        hintText: 'Mỗi dòng một việc',
                      ),
                    ),
                  ] else if (widget.existing!.tasks.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Checklist được giữ nguyên. Đánh dấu hoàn thành trong chi tiết lịch.',
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
