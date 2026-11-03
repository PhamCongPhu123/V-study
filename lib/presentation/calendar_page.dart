import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'widgets.dart' show errorMessage;

/// Calendar uses local day boundaries; the data adapter serializes UTC for SQL.
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
  bool _mutating = false;

  @override
  void initState() {
    super.initState();
    _events = _load();
  }

  (DateTime, DateTime) get _bounds {
    final day = DateTime(_selected.year, _selected.month, _selected.day);
    switch (_range) {
      case _CalendarRange.day:
        return (day, DateTime(day.year, day.month, day.day + 1));
      case _CalendarRange.week:
        final from = DateTime(day.year, day.month, day.day - day.weekday + 1);
        return (from, DateTime(from.year, from.month, from.day + 7));
      case _CalendarRange.month:
        return (
          DateTime(day.year, day.month),
          DateTime(day.year, day.month + 1),
        );
    }
  }

  Future<List<StudyEvent>> _load() {
    final (from, to) = _bounds;
    return widget.useCases.study.listEvents(from, to);
  }

  void _refresh() {
    setState(() => _events = _load());
  }

  void _move(int delta) {
    setState(() {
      _selected = switch (_range) {
        _CalendarRange.day => DateTime(
          _selected.year,
          _selected.month,
          _selected.day + delta,
        ),
        _CalendarRange.week => DateTime(
          _selected.year,
          _selected.month,
          _selected.day + 7 * delta,
        ),
        _CalendarRange.month => DateTime(
          _selected.year,
          _selected.month + delta,
        ),
      };
      _events = _load();
    });
  }

  Future<void> _chooseDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (chosen == null || !mounted) {
      return;
    }
    setState(() {
      _selected = chosen;
      _events = _load();
    });
  }

  Future<void> _edit([StudyEvent? existing]) async {
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
          existing: existing,
          subjects: subjects,
          selectedDay: _selected,
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
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errorMessage(error))));
  }

  Future<void> _delete(StudyEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa buổi học?'),
        content: Text(
          'Xóa “${event.title}” và checklist của buổi này? '
          'Các buổi lặp lại khác vẫn được giữ.',
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
    if (confirmed != true || !mounted) {
      return;
    }
    await _runMutation(() => widget.useCases.study.deleteEvent(event.id));
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

  @override
  Widget build(BuildContext context) {
    final label = switch (_range) {
      _CalendarRange.day => DateFormat('dd/MM/yyyy').format(_selected),
      _CalendarRange.week =>
        '${DateFormat('dd/MM').format(_bounds.$1)} – '
            '${DateFormat('dd/MM/yyyy').format(_bounds.$2.subtract(const Duration(days: 1)))}',
      _CalendarRange.month => DateFormat('MM/yyyy').format(_selected),
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Thời gian biểu',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            FilledButton.icon(
              onPressed: _mutating ? null : _edit,
              icon: const Icon(Icons.add),
              label: const Text('Thêm lịch'),
            ),
            IconButton(
              tooltip: 'Tải lại',
              onPressed: _mutating ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<_CalendarRange>(
          segments: const [
            ButtonSegment(value: _CalendarRange.day, label: Text('Ngày')),
            ButtonSegment(value: _CalendarRange.week, label: Text('Tuần')),
            ButtonSegment(value: _CalendarRange.month, label: Text('Tháng')),
          ],
          selected: {_range},
          onSelectionChanged: (selection) {
            setState(() {
              _range = selection.first;
              _events = _load();
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Trước',
              onPressed: () => _move(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Flexible(
              child: TextButton(onPressed: _chooseDate, child: Text(label)),
            ),
            IconButton(
              tooltip: 'Sau',
              onPressed: () => _move(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (_mutating) const LinearProgressIndicator(),
        FutureBuilder<List<StudyEvent>>(
          future: _events,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  Text(errorMessage(snapshot.error!)),
                  TextButton(onPressed: _refresh, child: const Text('Thử lại')),
                ],
              );
            }
            final events = snapshot.data ?? const [];
            if (events.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Chưa có lịch trong khoảng này. Hãy thêm buổi học hoặc deadline.',
                ),
              );
            }
            return Column(children: events.map(_eventCard).toList());
          },
        ),
      ],
    );
  }

  Widget _eventCard(StudyEvent event) {
    final starts = event.startsAt.toLocal();
    final ends = event.endsAt.toLocal();
    final dateFormat = DateFormat('dd/MM HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(switch (event.kind) {
                  EventKind.classSession => Icons.school_outlined,
                  EventKind.selfStudy => Icons.menu_book_outlined,
                  EventKind.deadline => Icons.flag_outlined,
                }),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Sửa buổi này',
                  onPressed: _mutating ? null : () => _edit(event),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Xóa buổi này',
                  onPressed: _mutating ? null : () => _delete(event),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text(_kindLabel(event.kind)),
            const SizedBox(height: 4),
            Text('${dateFormat.format(starts)} – ${dateFormat.format(ends)}'),
            if (event.location.isNotEmpty) Text('Địa điểm: ${event.location}'),
            if (event.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(event.notes),
              ),
            if (event.seriesId != null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Thuộc chuỗi lịch hằng tuần'),
              ),
            if (event.reminderMinutes != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Nhắc trước: ${event.reminderMinutes} phút (chỉ lưu cài đặt)',
                ),
              ),
            if (event.tasks.isNotEmpty) ...[
              const Divider(),
              const Text('Việc cần chuẩn bị'),
              ...event.tasks.map(
                (task) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(task.title),
                  value: task.isCompleted,
                  onChanged: _mutating
                      ? null
                      : (checked) => _runMutation(
                          () => widget.useCases.study.setTaskCompleted(
                            task.id,
                            checked ?? false,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
