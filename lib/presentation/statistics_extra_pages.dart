import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_exception.dart';
import '../domain/analytics.dart';
import '../domain/entities.dart';
import '../domain/study_metrics.dart';
import '../domain/use_cases.dart';
import 'design_system.dart';
import 'statistics_widgets.dart';
import 'widgets.dart';

class FocusStatisticsPage extends StatelessWidget {
  const FocusStatisticsPage({super.key, required this.useCases});
  final VstudyUseCases useCases;
  @override
  Widget build(BuildContext context) =>
      _ExtraStatisticsPage(useCases: useCases, kind: _ExtraKind.focus);
}

class FlashcardStatisticsPage extends StatelessWidget {
  const FlashcardStatisticsPage({super.key, required this.useCases});
  final VstudyUseCases useCases;
  @override
  Widget build(BuildContext context) =>
      _ExtraStatisticsPage(useCases: useCases, kind: _ExtraKind.flashcards);
}

class WeeklyReportPage extends StatelessWidget {
  const WeeklyReportPage({super.key, required this.useCases});
  final VstudyUseCases useCases;
  @override
  Widget build(BuildContext context) =>
      _ExtraStatisticsPage(useCases: useCases, kind: _ExtraKind.weekly);
}

enum _ExtraKind { focus, flashcards, weekly }

class _ExtraStatisticsPage extends StatefulWidget {
  const _ExtraStatisticsPage({required this.useCases, required this.kind});
  final VstudyUseCases useCases;
  final _ExtraKind kind;
  @override
  State<_ExtraStatisticsPage> createState() => _ExtraStatisticsPageState();
}

class _ExtraStatisticsPageState extends State<_ExtraStatisticsPage> {
  late Future<AnalyticsSnapshot> _future;
  AnalyticsPeriod _period = AnalyticsPeriod.week;
  DateTime _anchor = DateTime.now();
  String get _title => switch (widget.kind) {
    _ExtraKind.focus => 'Thống kê tập trung',
    _ExtraKind.flashcards => 'Thống kê flashcard',
    _ExtraKind.weekly => 'Báo cáo tuần',
  };
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AnalyticsSnapshot> _load() async {
    final repository = widget.useCases.analytics;
    if (repository == null) {
      throw const AppException('Thống kê chưa được cấu hình.');
    }
    return repository.loadSnapshot(now: DateTime.now());
  }

  void _refresh() => setState(() => _future = _load());
  String _windowLabel(AnalyticsReport report) {
    final first = report.window.from;
    final last = DateTime(
      report.window.to.year,
      report.window.to.month,
      report.window.to.day - 1,
    );
    return '${statsDateLabel(first)}/${first.year} – ${statsDateLabel(last)}/${last.year}';
  }

  Future<void> _log(AnalyticsSnapshot snapshot) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RecordSessionDialog(
        useCases: widget.useCases,
        subjects: snapshot.subjects,
        focus: widget.kind == _ExtraKind.focus,
      ),
    );
    if (mounted && saved == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      title: Text(
        _title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: AsyncContent<AnalyticsSnapshot>(
      future: _future,
      onRetry: _refresh,
      builder: (snapshot) {
        final report = buildAnalyticsReport(snapshot, _period, anchor: _anchor);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 94),
          children: [
            if (widget.kind != _ExtraKind.weekly) ...[
              StatsPeriodSelector(
                selected: _period,
                onChanged: (period) => setState(() => _period = period),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                if (_period != AnalyticsPeriod.semester)
                  IconButton(
                    tooltip: 'Kỳ trước',
                    onPressed: () => _move(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                Expanded(
                  child: Text(
                    _windowLabel(report),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: VstudyColors.muted,
                    ),
                  ),
                ),
                if (_period != AnalyticsPeriod.semester)
                  IconButton(
                    tooltip: 'Kỳ sau',
                    onPressed: () => _move(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...switch (widget.kind) {
              _ExtraKind.focus => _focus(snapshot, report),
              _ExtraKind.flashcards => _flashcards(snapshot, report),
              _ExtraKind.weekly => _weekly(snapshot, report),
            },
          ],
        );
      },
    ),
  );

  void _move(int delta) => setState(() {
    _anchor = _period == AnalyticsPeriod.month
        ? DateTime(_anchor.year, _anchor.month + delta, 1)
        : DateTime(_anchor.year, _anchor.month, _anchor.day + 7 * delta);
  });

  List<DateTime> _buckets(AnalyticsReport report, DateTime now) =>
      report.study.dailyMinutes.length > 14
      ? report.weeklyMinutes
            .where((d) => !d.date.isAfter(localDay(now)))
            .map((d) => d.date)
            .toList()
      : report.study.dailyMinutes.map((d) => d.date).toList();
  bool _inBucket(DateTime timestamp, DateTime bucket, bool weekly) {
    final date = localDay(timestamp);
    return !date.isBefore(bucket) &&
        date.isBefore(
          DateTime(bucket.year, bucket.month, bucket.day + (weekly ? 7 : 1)),
        );
  }

  List<Widget> _focus(AnalyticsSnapshot snapshot, AnalyticsReport report) {
    final sessions = report.focusSessions.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final focused = sessions.fold<int>(0, (v, s) => v + s.focusedMinutes);
    final planned = sessions.fold<int>(0, (v, s) => v + s.plannedMinutes);
    final interruptions = sessions.fold<int>(0, (v, s) => v + s.interruptions);
    final buckets = _buckets(report, snapshot.now);
    final weekly = report.study.dailyMinutes.length > 14;
    return [
      StatsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatStudyMinutes(focused),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const Text(
              'Thời gian tập trung đã ghi nhận',
              style: TextStyle(fontSize: 11, color: VstudyColors.muted),
            ),
            const SizedBox(height: 22),
            if (sessions.isEmpty)
              const _NoMeasurement('Chưa ghi nhận phiên tập trung')
            else
              StatsBarChart(
                values: buckets
                    .map(
                      (date) => sessions
                          .where((s) => _inBucket(s.startedAt, date, weekly))
                          .fold<double>(0, (v, s) => v + s.focusedMinutes),
                    )
                    .toList(),
                labels: buckets.map(statsDateLabel).toList(),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: StatsMetric(
              label: 'Tỷ lệ tập trung',
              value: report.focusPercent == null
                  ? '—'
                  : '${report.focusPercent!.toStringAsFixed(0)}%',
              subtitle: planned == 0
                  ? 'Chưa có phiên để tính'
                  : 'Trên ${formatStudyMinutes(planned)} dự kiến',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatsMetric(
              label: 'Số lần gián đoạn',
              value: '$interruptions',
              subtitle: '${sessions.length} phiên đã ghi nhận',
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      const Text(
        'Phiên tập trung được ghi nhận riêng; không tự cộng thêm vào thời gian học để tránh đếm trùng.',
        style: TextStyle(fontSize: 11, color: VstudyColors.muted, height: 1.5),
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        key: const ValueKey('stats-log-focus'),
        onPressed: () => _log(snapshot),
        icon: const Icon(Icons.add),
        label: const Text('Ghi nhận phiên tập trung'),
      ),
      const SizedBox(height: 14),
      for (final session in sessions.take(12))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: StatsCard(
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: VstudyColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${statsDateLabel(session.startedAt)} · ${_subject(snapshot, session.subjectId)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${session.focusedMinutes}/${session.plannedMinutes} phút · ${session.interruptions} lần gián đoạn',
                        style: const TextStyle(
                          fontSize: 11,
                          color: VstudyColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _flashcards(AnalyticsSnapshot snapshot, AnalyticsReport report) {
    final buckets = _buckets(report, snapshot.now);
    final weekly = report.study.dailyMinutes.length > 14;
    final sessions = report.flashcardSessions.toList()
      ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
    return [
      StatsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${report.flashcardReviewed} lượt ôn thẻ',
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tính theo các lượt ôn đã ghi nhận, không phải số thẻ duy nhất.',
              style: TextStyle(fontSize: 11, color: VstudyColors.muted),
            ),
            const SizedBox(height: 20),
            if (sessions.isEmpty)
              const _NoMeasurement('Chưa ghi nhận lượt ôn flashcard')
            else
              StatsBarChart(
                values: buckets
                    .map(
                      (date) => sessions
                          .where((s) => _inBucket(s.reviewedAt, date, weekly))
                          .fold<double>(0, (v, s) => v + s.reviewedCards),
                    )
                    .toList(),
                labels: buckets.map(statsDateLabel).toList(),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: StatsMetric(
              label: 'Mức ghi nhớ',
              value: report.rememberPercent == null
                  ? '—'
                  : '${report.rememberPercent!.toStringAsFixed(0)}%',
              subtitle: '${report.flashcardRemembered} lượt trả lời nhớ được',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatsMetric(
              label: 'Mục tiêu mỗi ngày',
              value: '${snapshot.goals.flashcardsPerDay} lượt ôn',
              subtitle: 'Có thể chỉnh ở Mục tiêu',
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        key: const ValueKey('stats-log-flashcards'),
        onPressed: () => _log(snapshot),
        icon: const Icon(Icons.add),
        label: const Text('Ghi nhận lượt ôn'),
      ),
      const SizedBox(height: 14),
      for (final session in sessions.take(12))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: StatsCard(
            child: Row(
              children: [
                const Icon(Icons.style_outlined, color: VstudyColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${statsDateLabel(session.reviewedAt)} · ${_subject(snapshot, session.subjectId)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${session.rememberedCards}/${session.reviewedCards} lượt nhớ đúng',
                        style: const TextStyle(
                          fontSize: 11,
                          color: VstudyColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  String _subject(AnalyticsSnapshot snapshot, String? id) {
    for (final subject in snapshot.subjects) {
      if (subject.id == id) {
        return subject.name;
      }
    }
    return 'Tự học';
  }

  String _reportText(AnalyticsSnapshot snapshot, AnalyticsReport report) =>
      'BÁO CÁO TUẦN VSTUDY\n${_windowLabel(report)}\n'
      'Thời gian học: ${formatStudyMinutes(report.study.totalMinutes)}\n'
      'Ngày có học: ${report.activeDays}/7\n'
      'Chuỗi học hiện tại: ${report.study.currentStreakDays} ngày\n'
      'Quiz đã nộp: ${report.quizAttempts.length}\n'
      'Điểm quiz trung bình: ${report.quizAttempts.isEmpty ? 'Chưa có bài nộp' : '${report.study.averageQuizPercent.toStringAsFixed(1)}%'}\n'
      'Flashcard: ${report.flashcardReviewed} lượt ôn\n'
      'Mục tiêu tuần: ${formatStudyMinutes(snapshot.goals.weeklyMinutes)}';

  List<Widget> _weekly(AnalyticsSnapshot snapshot, AnalyticsReport report) => [
    StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tuần học của bạn',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            formatStudyMinutes(report.study.totalMinutes),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          Text(
            report.changePercent == null
                ? 'Chưa có kỳ trước để so sánh'
                : '${report.changePercent! >= 0 ? 'Tăng' : 'Giảm'} ${report.changePercent!.abs().toStringAsFixed(0)}% so với tuần trước',
            style: const TextStyle(fontSize: 11, color: VstudyColors.muted),
          ),
          const SizedBox(height: 20),
          StatsBarChart(
            values: report.study.dailyMinutes
                .map((d) => d.minutes.toDouble())
                .toList(),
            labels: report.study.dailyMinutes
                .map(
                  (d) => d.date.weekday == 7 ? 'CN' : 'T${d.date.weekday + 1}',
                )
                .toList(),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: StatsMetric(
            label: 'Ngày có học',
            value: '${report.activeDays}/7',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatsMetric(
            label: 'Quiz đã nộp',
            value: '${report.quizAttempts.length}',
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Điểm nổi bật',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            report.bestDay == null
                ? 'Chưa có buổi học trong tuần. Ghi nhận buổi học từ Trang chủ để bắt đầu.'
                : 'Ngày ${statsDateLabel(report.bestDay!.date)} học nhiều nhất: ${formatStudyMinutes(report.bestDay!.minutes)}.',
            style: const TextStyle(fontSize: 12, height: 1.6),
          ),
          Text(
            'Đã hoàn thành ${report.tasksCompleted}/${report.tasksTotal} việc học và ${report.flashcardReviewed} lượt ôn thẻ.',
            style: const TextStyle(fontSize: 12, height: 1.6),
          ),
        ],
      ),
    ),
    const SizedBox(height: 18),
    Padding(
      padding: const EdgeInsets.only(right: 48),
      child: FilledButton.icon(
        key: const ValueKey('stats-copy-report'),
        onPressed: () async {
          try {
            await Clipboard.setData(
              ClipboardData(text: _reportText(snapshot, report)),
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã sao chép báo cáo tuần.')),
              );
            }
          } catch (error) {
            if (mounted) {
              showError(context, error);
            }
          }
        },
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Sao chép báo cáo'),
      ),
    ),
  ];
}

class _NoMeasurement extends StatelessWidget {
  const _NoMeasurement(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 25),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: VstudyColors.muted, fontSize: 12),
      ),
    ),
  );
}

class _RecordSessionDialog extends StatefulWidget {
  const _RecordSessionDialog({
    required this.useCases,
    required this.subjects,
    required this.focus,
  });
  final VstudyUseCases useCases;
  final List<Subject> subjects;
  final bool focus;
  @override
  State<_RecordSessionDialog> createState() => _RecordSessionDialogState();
}

class _RecordSessionDialogState extends State<_RecordSessionDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  final _interruptions = TextEditingController(text: '0');
  late DateTime _date;
  String? _subjectId;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _first.text = widget.focus ? '25' : '20';
    _second.text = widget.focus ? '20' : '16';
    _date = DateTime.now().subtract(Duration(minutes: widget.focus ? 60 : 1));
  }

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    _interruptions.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time != null && mounted) {
      setState(
        () => _date = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final first = int.tryParse(_first.text.trim()) ?? -1;
      final second = int.tryParse(_second.text.trim()) ?? -1;
      if (widget.focus) {
        await widget.useCases.logFocusSession(
          startedAt: _date,
          plannedMinutes: first,
          focusedMinutes: second,
          interruptions: int.tryParse(_interruptions.text.trim()) ?? -1,
          subjectId: _subjectId,
        );
      } else {
        await widget.useCases.logFlashcardSession(
          reviewedAt: _date,
          reviewedCards: first,
          rememberedCards: second,
          subjectId: _subjectId,
        );
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
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(
        widget.focus
            ? 'Ghi nhận phiên tập trung'
            : 'Ghi nhận lượt ôn flashcard',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _subjectId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Môn học (tùy chọn)',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tự học')),
                  ...widget.subjects.map(
                    (s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (id) => setState(() => _subjectId = id),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('stats-log-first'),
                controller: _first,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: widget.focus
                      ? 'Thời gian dự kiến (phút)'
                      : 'Số lượt ôn thẻ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('stats-log-second'),
                controller: _second,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: widget.focus
                      ? 'Tập trung thực tế (phút)'
                      : 'Số lượt nhớ đúng',
                ),
              ),
              if (widget.focus) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _interruptions,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số lần gián đoạn',
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _busy ? null : _chooseDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  '${statsDateLabel(_date)} ${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}',
                ),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: VstudyColors.red)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: ValueKey(
            widget.focus ? 'stats-save-focus' : 'stats-save-flashcards',
          ),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Đang lưu…' : 'Lưu'),
        ),
      ],
    ),
  );
}
