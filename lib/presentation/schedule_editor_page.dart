import 'dart:convert';

import 'package:flutter/material.dart';

import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'design_system.dart';
import 'schedule_confirmation.dart';
import 'draft_exit_scope.dart';
import 'widgets.dart';

/// A route inside the calendar tab. The shell keeps its footer and AI shortcut.
class ScheduleEditorPage extends StatefulWidget {
  const ScheduleEditorPage({
    super.key,
    required this.useCases,
    required this.subjects,
    required this.selectedDay,
    this.existing,
    this.onSaved,
  });

  final VstudyUseCases useCases;
  final List<Subject> subjects;
  final DateTime selectedDay;
  final StudyEvent? existing;
  final ValueChanged<DateTime>? onSaved;

  @override
  State<ScheduleEditorPage> createState() => _ScheduleEditorPageState();
}

class _ScheduleEditorPageState extends State<ScheduleEditorPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  late final TextEditingController _tasks;
  final _repeatWeeks = TextEditingController(text: '1');
  late final List<Subject> _subjects;
  late DateTime _start;
  late DateTime _end;
  late EventKind _kind;
  late EventKind _courseKind;
  String? _subjectId;
  int? _reminder;
  bool _multiDay = false;
  bool _weekly = false;
  bool _busy = false;
  bool _dialogPending = false;
  bool _exiting = false;
  String? _error;
  late final String _initialSnapshot;
  VoidCallback? _unregisterExit;
  DraftExitScope? _exitScope;

  bool get _editing => widget.existing != null;
  bool get _locked => _busy || _dialogPending || _exiting;
  bool get _dirty => _snapshot() != _initialSnapshot;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final day = widget.selectedDay.toLocal();
    _start =
        existing?.startsAt.toLocal() ??
        DateTime(day.year, day.month, day.day, 8);
    _end =
        existing?.endsAt.toLocal() ?? DateTime(day.year, day.month, day.day, 9);
    _multiDay = !DateUtils.isSameDay(_start, _end);
    _kind = existing?.kind ?? EventKind.classSession;
    _courseKind = _kind == EventKind.deadline ? EventKind.classSession : _kind;
    _title = TextEditingController(text: existing?.title ?? '');
    _location = TextEditingController(text: existing?.location ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _tasks = TextEditingController(
      text: existing?.tasks.map((task) => task.title).join('\n') ?? '',
    );
    _subjects = List.of(widget.subjects);
    _subjectId = existing?.subjectId;
    _reminder = existing?.reminderMinutes;
    _initialSnapshot = _snapshot();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = DraftExitScope.maybeOf(context);
    if (_exitScope != scope) {
      _unregisterExit?.call();
      _exitScope = scope;
      _unregisterExit = scope?.attach(_requestExit);
    }
  }

  @override
  void dispose() {
    _unregisterExit?.call();
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    _tasks.dispose();
    _repeatWeeks.dispose();
    super.dispose();
  }

  List<String> get _taskTitles => _editing
      ? widget.existing!.tasks.map((task) => task.title).toList()
      : _tasks.text
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();

  String _snapshot() => jsonEncode([
    _title.text.trim(),
    _kind.name,
    _subjectId,
    _start.microsecondsSinceEpoch,
    _end.microsecondsSinceEpoch,
    _location.text.trim(),
    _notes.text.trim(),
    _reminder,
    _weekly ? _repeatWeeks.text.trim() : '0',
    _taskTitles,
  ]);

  Future<bool> _requestExit() async {
    if (_locked) {
      return false;
    }
    if (_dirty) {
      setState(() => _dialogPending = true);
      final discard = await showScheduleConfirmation(
        context,
        kind: ScheduleConfirmationKind.discard,
      );
      if (!mounted) {
        return false;
      }
      setState(() => _dialogPending = false);
      if (!discard) {
        return false;
      }
    }
    _exiting = true;
    Navigator.of(context).pop(false);
    return true;
  }

  EventDraft? _validatedDraft() {
    final validFields = _form.currentState?.validate() ?? false;
    String? error;
    if (!_end.isAfter(_start)) {
      error =
          'Giờ kết thúc phải sau giờ bắt đầu. '
          'Nếu lịch qua nửa đêm, hãy chọn ngày kết thúc khác.';
    } else if (_end.difference(_start) > const Duration(days: 7)) {
      error = 'Một lịch trình không được kéo dài quá 7 ngày.';
    }
    final repeats = _weekly ? int.tryParse(_repeatWeeks.text.trim()) : 0;
    if (_weekly && (repeats == null || repeats < 1 || repeats > 52)) {
      error ??= 'Số tuần lặp thêm cần từ 1 đến 52.';
    }
    final tasks = _taskTitles;
    if (tasks.length > 30 || tasks.any((task) => task.length > 300)) {
      error ??= 'Tối đa 30 việc cần chuẩn bị, mỗi việc không quá 300 ký tự.';
    }
    setState(() {
      _error =
          error ??
          (validFields ? null : 'Vui lòng kiểm tra các ô được đánh dấu.');
    });
    if (!validFields || error != null) {
      return null;
    }
    return EventDraft(
      title: _title.text.trim(),
      kind: _kind,
      startsAt: _start,
      endsAt: _end,
      subjectId: _subjectId,
      location: _location.text.trim(),
      notes: _notes.text.trim(),
      reminderMinutes: _reminder,
      taskTitles: tasks,
      repeatWeeks: _editing ? 0 : repeats!,
    );
  }

  Future<void> _save() async {
    if (_locked) {
      return;
    }
    FocusScope.of(context).unfocus();
    final draft = _validatedDraft();
    if (draft == null) {
      return;
    }
    if (_editing && !_dirty) {
      await _requestExit();
      return;
    }
    setState(() => _dialogPending = true);
    final confirmed = await showScheduleConfirmation(
      context,
      kind: _editing
          ? ScheduleConfirmationKind.update
          : ScheduleConfirmationKind.create,
      title: draft.title,
      details:
          '${shortDate(_start)} · ${shortTime(_start)} – '
          '${DateUtils.isSameDay(_start, _end) ? '' : '${shortDate(_end)} · '}'
          '${shortTime(_end)}'
          '${_weekly ? '\nLặp thêm ${draft.repeatWeeks} tuần.' : ''}'
          '${widget.existing?.seriesId != null ? '\nChỉ cập nhật buổi này trong lịch lặp.' : ''}',
    );
    if (!mounted) {
      return;
    }
    if (!confirmed) {
      setState(() => _dialogPending = false);
      return;
    }
    setState(() {
      _dialogPending = false;
      _busy = true;
      _error = null;
    });
    try {
      if (_editing) {
        await widget.useCases.updateEvent(widget.existing!.id, draft);
      } else {
        await widget.useCases.createEvent(draft);
      }
      if (!mounted) {
        return;
      }
      widget.onSaved?.call(draft.startsAt);
      _exiting = true;
      Navigator.of(context).pop(true);
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

  Future<void> _delete() async {
    if (_locked || !_editing) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _dialogPending = true);
    final confirmed = await showScheduleConfirmation(
      context,
      kind: ScheduleConfirmationKind.delete,
      title: widget.existing!.title,
      details: widget.existing!.seriesId == null
          ? 'Lịch trình và danh sách việc chuẩn bị của buổi này sẽ bị xóa.'
          : 'Chỉ xóa buổi này; những buổi khác trong lịch lặp vẫn được giữ.',
    );
    if (!mounted) {
      return;
    }
    if (!confirmed) {
      setState(() => _dialogPending = false);
      return;
    }
    setState(() {
      _dialogPending = false;
      _busy = true;
      _error = null;
    });
    try {
      await widget.useCases.study.deleteEvent(widget.existing!.id);
      if (!mounted) {
        return;
      }
      _exiting = true;
      Navigator.of(context).pop(true);
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

  Future<void> _pickDate({bool end = false}) async {
    if (_locked) {
      return;
    }
    setState(() => _dialogPending = true);
    final value = await showDatePicker(
      context: context,
      initialDate: end ? _end : _start,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: end ? 'Chọn ngày kết thúc' : 'Chọn ngày bắt đầu',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _dialogPending = false;
      if (value == null) {
        return;
      }
      if (end) {
        _end = DateTime(
          value.year,
          value.month,
          value.day,
          _end.hour,
          _end.minute,
        );
        _multiDay = !DateUtils.isSameDay(_start, _end);
      } else {
        // Move the calendar dates together, preserving both clock times and
        // the explicit number of calendar days between them.
        final dayOffset = DateTime.utc(_end.year, _end.month, _end.day)
            .difference(DateTime.utc(_start.year, _start.month, _start.day))
            .inDays;
        _start = DateTime(
          value.year,
          value.month,
          value.day,
          _start.hour,
          _start.minute,
        );
        _end = DateTime(
          value.year,
          value.month,
          value.day + dayOffset,
          _end.hour,
          _end.minute,
        );
      }
      _error = null;
    });
  }

  Future<void> _pickTime({required bool end}) async {
    if (_locked) {
      return;
    }
    setState(() => _dialogPending = true);
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(end ? _end : _start),
      helpText: end ? 'Giờ kết thúc' : 'Giờ bắt đầu',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _dialogPending = false;
      if (value == null) {
        return;
      }
      final day = end ? _end : _start;
      final time = DateTime(
        day.year,
        day.month,
        day.day,
        value.hour,
        value.minute,
      );
      if (end) {
        _end = time;
      } else {
        _start = time;
      }
      // Never shift the other time to make an invalid range appear valid.
      _error = null;
    });
  }

  Future<void> _addSubject() async {
    if (_locked) {
      return;
    }
    setState(() => _dialogPending = true);
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _NewScheduleSubjectDialog(),
    );
    if (!mounted) {
      return;
    }
    if (name == null) {
      setState(() => _dialogPending = false);
      return;
    }
    setState(() {
      _dialogPending = false;
      _busy = true;
      _error = null;
    });
    try {
      final subject = await widget.useCases.createSubject(name);
      if (!mounted) {
        return;
      }
      setState(() {
        if (!_subjects.any((item) => item.id == subject.id)) {
          _subjects.add(subject);
        }
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

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: VstudyColors.muted, fontSize: 12),
    filled: true,
    fillColor: const Color(0xFFE0E0DE),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: Color(0xFFB6B8BE)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: Color(0xFFB6B8BE)),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 17, bottom: 7),
    child: Text(
      text,
      style: const TextStyle(
        color: VstudyColors.ink,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _pill({
    required String keyName,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool enabled = true,
  }) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Semantics(
        selected: selected,
        child: FilledButton(
          key: ValueKey(keyName),
          onPressed: _locked || !enabled ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: selected
                ? VstudyColors.navy
                : const Color(0xFFDADAD8),
            foregroundColor: selected ? Colors.white : VstudyColors.navy,
            disabledBackgroundColor: const Color(0xFFE6E4DE),
            disabledForegroundColor: VstudyColors.muted,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(label),
        ),
      ),
    ),
  );

  Widget _dateButton({required bool end}) => OutlinedButton(
    key: ValueKey(end ? 'schedule-end-date' : 'schedule-date'),
    onPressed: _locked ? null : () => _pickDate(end: end),
    style: OutlinedButton.styleFrom(
      backgroundColor: const Color(0xFFE0E0DE),
      foregroundColor: VstudyColors.navy,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      side: const BorderSide(color: Color(0xFFB6B8BE)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(shortDate(end ? _end : _start)),
        const Icon(Icons.calendar_month_outlined, size: 20),
      ],
    ),
  );

  Widget _timeButton({required bool end}) => Expanded(
    child: OutlinedButton(
      key: ValueKey(end ? 'schedule-end-time' : 'schedule-start-time'),
      onPressed: _locked ? null : () => _pickTime(end: end),
      style: OutlinedButton.styleFrom(
        foregroundColor: VstudyColors.navy,
        backgroundColor: const Color(0xFFDADAD8),
        side: BorderSide.none,
        minimumSize: const Size(0, 38),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      child: Text(shortTime(end ? _end : _start)),
    ),
  );

  Widget _repeatAndReminder() {
    final options = <int>{0, 5, 15, 30, 60, 120, 1440};
    if (_reminder != null) {
      options.add(_reminder!);
    }
    final reminderOptions = options.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Lặp lại'),
        if (_editing)
          Text(
            widget.existing!.seriesId == null
                ? 'Không lặp lại. Lặp hằng tuần được thiết lập khi tạo lịch mới.'
                : 'Lịch hằng tuần · Chỉnh sửa chỉ áp dụng cho buổi này.',
            style: const TextStyle(fontSize: 12, color: VstudyColors.muted),
          )
        else
          DropdownButtonFormField<bool>(
            key: const ValueKey('schedule-repeat'),
            initialValue: _weekly,
            decoration: _decoration('Không lặp lại'),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: false, child: Text('Không lặp lại')),
              DropdownMenuItem(value: true, child: Text('Hằng tuần')),
            ],
            onChanged: _locked
                ? null
                : (value) => setState(() => _weekly = value!),
          ),
        if (_weekly && !_editing) ...[
          _label('Số tuần lặp thêm (1–52)'),
          TextFormField(
            key: const ValueKey('schedule-repeat-weeks'),
            controller: _repeatWeeks,
            enabled: !_locked,
            keyboardType: TextInputType.number,
            decoration: _decoration('Ví dụ: 12'),
            validator: (value) {
              final count = int.tryParse(value?.trim() ?? '');
              return count == null || count < 1 || count > 52
                  ? 'Nhập số tuần từ 1 đến 52.'
                  : null;
            },
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Bao gồm buổi hiện tại và các buổi lặp thêm cùng giờ mỗi tuần.',
              style: TextStyle(fontSize: 11, color: VstudyColors.muted),
            ),
          ),
        ],
        _label('Nhắc trước'),
        DropdownButtonFormField<int>(
          key: const ValueKey('schedule-reminder'),
          initialValue: _reminder ?? -1,
          decoration: _decoration('Không nhắc'),
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: -1, child: Text('Không nhắc')),
            for (final minutes in reminderOptions)
              DropdownMenuItem(
                value: minutes,
                child: Text(
                  minutes == 0
                      ? 'Đúng giờ'
                      : minutes == 1440
                      ? 'Trước 1 ngày'
                      : 'Trước $minutes phút',
                ),
              ),
          ],
          onChanged: _locked
              ? null
              : (value) =>
                    setState(() => _reminder = value == -1 ? null : value),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Chỉ lưu thời gian nhắc; thông báo trên thiết bị chưa được kích hoạt.',
            style: TextStyle(fontSize: 11, color: VstudyColors.muted),
          ),
        ),
      ],
    );
  }

  Widget _extraFields() => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const ValueKey('schedule-extra'),
        tilePadding: EdgeInsets.zero,
        title: const Text(
          'Môn học và việc cần chuẩn bị',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey('schedule-subject-${_subjectId ?? 'none'}'),
            initialValue: _subjectId ?? '',
            isExpanded: true,
            decoration: _decoration('Không liên kết môn học'),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Không liên kết môn học'),
              ),
              for (final subject in _subjects)
                DropdownMenuItem(
                  value: subject.id,
                  child: Text(subject.name, overflow: TextOverflow.ellipsis),
                ),
              if (_subjectId != null &&
                  !_subjects.any((subject) => subject.id == _subjectId))
                DropdownMenuItem(
                  value: _subjectId,
                  child: const Text('Môn học đã liên kết'),
                ),
            ],
            onChanged: _locked
                ? null
                : (value) =>
                      setState(() => _subjectId = value == '' ? null : value),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('schedule-add-subject'),
              onPressed: _locked ? null : _addSubject,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm môn học'),
            ),
          ),
          if (_editing) ...[
            for (final task in widget.existing!.tasks)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: task.isCompleted,
                onChanged: null,
                title: Text(task.title),
              ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Danh sách chuẩn bị và trạng thái hoàn thành được giữ nguyên. '
                'Đánh dấu hoàn thành tại trang lịch.',
                style: TextStyle(fontSize: 11, color: VstudyColors.muted),
              ),
            ),
          ] else
            TextFormField(
              key: const ValueKey('schedule-tasks'),
              controller: _tasks,
              enabled: !_locked,
              minLines: 2,
              maxLines: 5,
              decoration: _decoration('Việc cần chuẩn bị (mỗi dòng một việc)'),
              validator: (_) {
                if (_taskTitles.length > 30) {
                  return 'Tối đa 30 việc cần chuẩn bị.';
                }
                if (_taskTitles.any((title) => title.length > 300)) {
                  return 'Mỗi việc không quá 300 ký tự.';
                }
                return null;
              },
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        _requestExit();
      }
    },
    child: DecoratedBox(
      decoration: const BoxDecoration(gradient: VstudyColors.background),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: VstudyColors.navy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            key: const ValueKey('schedule-close'),
            tooltip: 'Đóng',
            onPressed: _locked ? null : _requestExit,
            icon: const Icon(Icons.close, size: 21),
          ),
          titleSpacing: 0,
          title: Text(
            _editing ? 'Sửa lịch trình' : 'Thêm lịch trình mới',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Tên môn học / Deadline'),
                      TextFormField(
                        key: const ValueKey('schedule-title'),
                        controller: _title,
                        enabled: !_locked,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _decoration(
                          'Nhập tên môn học hoặc deadline',
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Vui lòng nhập tên lịch trình.';
                          }
                          if (text.length > 200) {
                            return 'Tên không quá 200 ký tự.';
                          }
                          return null;
                        },
                      ),
                      _label('Phân loại'),
                      Row(
                        children: [
                          _pill(
                            keyName: 'schedule-type-course',
                            label: 'Môn học',
                            selected: _kind != EventKind.deadline,
                            onTap: () => setState(() => _kind = _courseKind),
                          ),
                          const SizedBox(width: 20),
                          _pill(
                            keyName: 'schedule-type-deadline',
                            label: 'Deadline',
                            selected: _kind == EventKind.deadline,
                            onTap: () =>
                                setState(() => _kind = EventKind.deadline),
                          ),
                        ],
                      ),
                      _label('Hình thức'),
                      Row(
                        children: [
                          _pill(
                            keyName: 'schedule-subtype-class',
                            label: 'Trên lớp',
                            selected: _kind == EventKind.classSession,
                            enabled: _kind != EventKind.deadline,
                            onTap: () => setState(() {
                              _courseKind = EventKind.classSession;
                              _kind = _courseKind;
                            }),
                          ),
                          const SizedBox(width: 20),
                          _pill(
                            keyName: 'schedule-subtype-self-study',
                            label: 'Tự học',
                            selected: _kind == EventKind.selfStudy,
                            enabled: _kind != EventKind.deadline,
                            onTap: () => setState(() {
                              _courseKind = EventKind.selfStudy;
                              _kind = _courseKind;
                            }),
                          ),
                        ],
                      ),
                      _label('Ngày'),
                      _dateButton(end: false),
                      _label('Thời gian'),
                      Row(
                        children: [
                          _timeButton(end: false),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              '–',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          _timeButton(end: true),
                        ],
                      ),
                      CheckboxListTile(
                        key: const ValueKey('schedule-multi-day'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'Kết thúc vào ngày khác',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _multiDay,
                        onChanged: _locked
                            ? null
                            : (value) => setState(() {
                                _multiDay = value!;
                                _end = DateTime(
                                  _start.year,
                                  _start.month,
                                  _start.day + (_multiDay ? 1 : 0),
                                  _end.hour,
                                  _end.minute,
                                );
                                _error = null;
                              }),
                      ),
                      if (_multiDay) ...[
                        _label('Ngày kết thúc (tối đa 7 ngày)'),
                        _dateButton(end: true),
                      ],
                      _label('Phòng học / Địa điểm'),
                      TextFormField(
                        key: const ValueKey('schedule-location'),
                        controller: _location,
                        enabled: !_locked,
                        decoration: _decoration('Thêm địa điểm nếu cần'),
                        validator: (value) => (value?.trim().length ?? 0) > 300
                            ? 'Địa điểm không quá 300 ký tự.'
                            : null,
                      ),
                      _label('Ghi chú'),
                      TextFormField(
                        key: const ValueKey('schedule-notes'),
                        controller: _notes,
                        enabled: !_locked,
                        minLines: 2,
                        maxLines: 5,
                        decoration: _decoration('Thêm ghi chú cho lịch trình'),
                        validator: (value) => (value?.trim().length ?? 0) > 5000
                            ? 'Ghi chú không quá 5000 ký tự.'
                            : null,
                      ),
                      _repeatAndReminder(),
                      _extraFields(),
                    ],
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                key: const ValueKey('schedule-error'),
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: VstudyColors.red),
                  ),
                ),
              ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            SafeArea(
              top: false,
              child: Padding(
                // Keep clear of the shell's floating AI shortcut.
                padding: const EdgeInsets.fromLTRB(24, 12, 62, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_editing)
                      TextButton.icon(
                        key: const ValueKey('schedule-delete'),
                        onPressed: _locked ? null : _delete,
                        style: TextButton.styleFrom(
                          foregroundColor: VstudyColors.red,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Xóa lịch trình'),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            key: const ValueKey('schedule-cancel'),
                            onPressed: _locked ? null : _requestExit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFDADAD8),
                              foregroundColor: VstudyColors.navy,
                            ),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            key: const ValueKey('schedule-confirm'),
                            onPressed: _locked ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: VstudyColors.navy,
                            ),
                            child: Text(
                              _busy
                                  ? 'Đang lưu…'
                                  : _editing
                                  ? 'Lưu thay đổi'
                                  : 'Xác nhận',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NewScheduleSubjectDialog extends StatefulWidget {
  const _NewScheduleSubjectDialog();

  @override
  State<_NewScheduleSubjectDialog> createState() =>
      _NewScheduleSubjectDialogState();
}

class _NewScheduleSubjectDialogState extends State<_NewScheduleSubjectDialog> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Thêm môn học'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _name,
        autofocus: true,
        maxLength: 100,
        decoration: const InputDecoration(labelText: 'Tên môn học'),
        validator: (value) => (value?.trim().isEmpty ?? true)
            ? 'Vui lòng nhập tên môn học.'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.of(context).pop(_name.text.trim());
          }
        },
        child: const Text('Thêm'),
      ),
    ],
  );
}
