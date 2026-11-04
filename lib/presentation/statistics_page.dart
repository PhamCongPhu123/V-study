import 'package:flutter/material.dart';

import '../core/app_exception.dart';
import '../domain/analytics.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'design_system.dart';
import 'statistics_detail_pages.dart';
import 'statistics_extra_pages.dart';
import 'statistics_widgets.dart';
import 'widgets.dart';

/// The shell owns the persistent navigation and the assistant button.
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key, required this.useCases});
  final VstudyUseCases useCases;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 96),
        children: [
          const StatsHeader(
            title: 'Thống kê',
            subtitle: 'Hiểu hành trình học, tiến bộ mỗi ngày.',
          ),
          const SizedBox(height: 22),
          _destination(
            context,
            id: 'learning',
            title: 'Thống kê học tập',
            subtitle: 'Thời gian theo tuần, tháng và học kỳ',
            icon: Icons.query_stats_rounded,
            page: StudyTimeStatisticsPage(useCases: useCases),
          ),
          _destination(
            context,
            id: 'focus',
            title: 'Thống kê tập trung',
            subtitle: 'Thời gian và các phiên tập trung',
            icon: Icons.timer_outlined,
            page: FocusStatisticsPage(useCases: useCases),
          ),
          _destination(
            context,
            id: 'quiz',
            title: 'Thống kê quiz',
            subtitle: 'Kết quả và mức độ nắm vững',
            icon: Icons.fact_check_outlined,
            page: QuizStatisticsPage(useCases: useCases),
          ),
          _destination(
            context,
            id: 'subjects',
            title: 'Theo môn học',
            subtitle: 'Theo dõi tiến bộ từng môn',
            icon: Icons.menu_book_outlined,
            page: SubjectStatisticsPage(useCases: useCases),
          ),
          _destination(
            context,
            id: 'goals',
            title: 'Mục tiêu và chuỗi học',
            subtitle: 'Mục tiêu và thói quen mỗi ngày',
            icon: Icons.local_fire_department_outlined,
            page: GoalsStatisticsPage(useCases: useCases),
          ),
          _destination(
            context,
            id: 'weekly-report',
            title: 'Báo cáo tuần',
            subtitle: 'Nhìn lại hành trình học trong tuần',
            icon: Icons.calendar_view_week_outlined,
            page: WeeklyReportPage(useCases: useCases),
          ),
          _destination(
            context,
            id: 'flashcards',
            title: 'Thống kê flashcard',
            subtitle: 'Các lượt ôn thẻ đã ghi nhận',
            icon: Icons.style_outlined,
            page: FlashcardStatisticsPage(useCases: useCases),
          ),
        ],
      ),
    ),
  );

  Widget _destination(
    BuildContext context, {
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget page,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        key: ValueKey('stats-$id'),
        borderRadius: BorderRadius.circular(15),
        onTap: () => Navigator.of(
          context,
        ).push<void>(MaterialPageRoute(builder: (_) => page)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 37,
                height: 37,
                decoration: BoxDecoration(
                  color: VstudyColors.paleGold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 21, color: VstudyColors.navy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: VstudyColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        color: VstudyColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: VstudyColors.navy,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class StudyTimeStatisticsPage extends StatefulWidget {
  const StudyTimeStatisticsPage({super.key, required this.useCases});
  final VstudyUseCases useCases;
  @override
  State<StudyTimeStatisticsPage> createState() =>
      _StudyTimeStatisticsPageState();
}

class _StudyTimeStatisticsPageState extends State<StudyTimeStatisticsPage> {
  late Future<AnalyticsSnapshot> _future;
  AnalyticsPeriod _period = AnalyticsPeriod.week;
  DateTime? _anchor;
  DateTime? _selectedDay;

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

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    // AsyncContent renders failures and keeps its retry action available.
    await next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      title: const Text(
        'Thống kê học tập',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          onPressed: _refresh,
          tooltip: 'Tải lại thống kê',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: AsyncContent<AnalyticsSnapshot>(
      future: _future,
      onRetry: _refresh,
      builder: (snapshot) {
        final report = buildAnalyticsReport(snapshot, _period, anchor: _anchor);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
                children: [
                  StatsPeriodSelector(
                    selected: _period,
                    onChanged: (value) => setState(() {
                      _period = value;
                      _selectedDay = null;
                    }),
                  ),
                  const SizedBox(height: 9),
                  _dateNavigation(snapshot, report),
                  const SizedBox(height: 8),
                  switch (_period) {
                    AnalyticsPeriod.week => _week(snapshot, report),
                    AnalyticsPeriod.month => _month(snapshot, report),
                    AnalyticsPeriod.semester => _semester(snapshot, report),
                  },
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _dateNavigation(AnalyticsSnapshot snapshot, AnalyticsReport report) {
    final start = report.window.from;
    final last = _dayBefore(report.window.to);
    final label = switch (_period) {
      AnalyticsPeriod.week => '${shortDate(start)} – ${shortDate(last)}',
      AnalyticsPeriod.month => 'Tháng ${start.month}, ${start.year}',
      AnalyticsPeriod.semester =>
        'Học kỳ ${shortDate(start)} – ${shortDate(last)}',
    };
    if (_period == AnalyticsPeriod.semester) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: VstudyColors.muted),
        ),
      );
    }
    final canNext = !report.window.to.isAfter(_localDate(snapshot.now));
    return Row(
      children: [
        IconButton(
          key: const ValueKey('stats-previous-period'),
          tooltip: _period == AnalyticsPeriod.week
              ? 'Tuần trước'
              : 'Tháng trước',
          icon: const Icon(Icons.chevron_left_rounded, size: 21),
          onPressed: () => _movePeriod(snapshot, -1),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          key: const ValueKey('stats-next-period'),
          tooltip: _period == AnalyticsPeriod.week ? 'Tuần sau' : 'Tháng sau',
          icon: const Icon(Icons.chevron_right_rounded, size: 21),
          onPressed: canNext ? () => _movePeriod(snapshot, 1) : null,
        ),
      ],
    );
  }

  void _movePeriod(AnalyticsSnapshot snapshot, int delta) {
    final current = _anchor ?? snapshot.now;
    setState(() {
      _anchor = _period == AnalyticsPeriod.month
          ? DateTime(current.year, current.month + delta)
          : DateTime(current.year, current.month, current.day + delta * 7);
      _selectedDay = null;
    });
  }

  Widget _week(AnalyticsSnapshot snapshot, AnalyticsReport report) {
    final today = _localDate(snapshot.now);
    final days = report.study.dailyMinutes;
    final todayIndex = days.indexWhere((day) => day.date == today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _total(report),
              const SizedBox(height: 16),
              const Text(
                'Thời lượng học theo ngày (phút)',
                style: TextStyle(fontSize: 10, color: VstudyColors.muted),
              ),
              const SizedBox(height: 16),
              StatsBarChart(
                values: days.map((day) => day.minutes.toDouble()).toList(),
                labels: days
                    .map(
                      (day) =>
                          '${statsDateLabel(day.date)}\n${_weekday(day.date)}',
                    )
                    .toList(),
                highlightIndex: todayIndex < 0 ? null : todayIndex,
              ),
              if (report.study.totalMinutes == 0) ...[
                const SizedBox(height: 10),
                const Text(
                  'Chưa có buổi học được ghi nhận trong tuần này.',
                  style: TextStyle(
                    fontSize: 11,
                    color: VstudyColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _metrics(report),
        const SizedBox(height: 12),
        _weeklyGoal(snapshot, report),
      ],
    );
  }

  Widget _total(AnalyticsReport report) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 10,
        runSpacing: 9,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            formatStudyMinutes(report.study.totalMinutes),
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: VstudyColors.navy,
            ),
          ),
          _changeBadge(report.changePercent),
        ],
      ),
      const SizedBox(height: 5),
      const Text(
        'Thời gian từ các buổi học đã ghi nhận',
        style: TextStyle(fontSize: 10, color: VstudyColors.muted),
      ),
    ],
  );

  Widget _changeBadge(double? percent) {
    final color = percent == null
        ? VstudyColors.muted
        : percent < 0
        ? VstudyColors.red
        : VstudyColors.green;
    final periodName = switch (_period) {
      AnalyticsPeriod.week => 'tuần trước',
      AnalyticsPeriod.month => 'tháng trước',
      AnalyticsPeriod.semester => 'kỳ trước',
    };
    return Tooltip(
      message: percent == null
          ? 'Chưa có thời gian học ở kỳ trước để tính tỷ lệ.'
          : 'So với toàn bộ $periodName; kỳ hiện tại có thể chưa kết thúc.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          percent == null
              ? 'Chưa có kỳ so sánh'
              : '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(0)}% so $periodName',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _metrics(AnalyticsReport report) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: StatsMetric(
          label: 'Chuỗi học hiện tại',
          value: '${report.study.currentStreakDays} ngày',
          subtitle: 'Dựa trên các buổi học đã ghi nhận',
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: StatsMetric(
          label: 'Tỷ lệ tập trung',
          value: report.focusPercent == null
              ? 'Chưa ghi nhận'
              : '${report.focusPercent!.toStringAsFixed(0)}%',
          subtitle: 'Theo các phiên tập trung trong kỳ',
        ),
      ),
    ],
  );

  Widget _weeklyGoal(AnalyticsSnapshot snapshot, AnalyticsReport report) {
    final goal = snapshot.goals.weeklyMinutes;
    final progress = goal <= 0
        ? 0.0
        : (report.study.totalMinutes / goal).clamp(0.0, 1.0).toDouble();
    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mục tiêu ${formatStudyMinutes(goal)} / tuần',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(fontSize: 11, color: VstudyColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: VstudyColors.navy,
              backgroundColor: VstudyColors.divider,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Đã học ${formatStudyMinutes(report.study.totalMinutes)} · ${report.activeDays} ngày có hoạt động học',
            style: const TextStyle(
              fontSize: 10,
              height: 1.5,
              color: VstudyColors.muted,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _openGoals,
              child: const Text(
                'Điều chỉnh mục tiêu',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGoals() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GoalsStatisticsPage(useCases: widget.useCases),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  Widget _month(AnalyticsSnapshot snapshot, AnalyticsReport report) {
    final first = report.window.from;
    final today = _localDate(snapshot.now);
    final minutes = {
      for (final day in report.study.dailyMinutes) day.date: day.minutes,
    };
    final selected =
        _selectedDay ??
        (today.year == first.year && today.month == first.month
            ? today
            : report.bestDay?.date ?? first);
    final leading = first.weekday - 1;
    final numberOfDays = DateTime(first.year, first.month + 1, 0).day;
    final cellCount = ((leading + numberOfDays) / 7).ceil() * 7;
    final maximum = minutes.values.fold<int>(
      1,
      (max, value) => value > max ? value : max,
    );
    final best = report.bestDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _total(report),
              const SizedBox(height: 17),
              Row(
                children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                    .map(
                      (label) => Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: VstudyColors.muted,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final side = constraints.maxWidth / 7;
                  return Wrap(
                    children: List.generate(cellCount, (index) {
                      final number = index - leading + 1;
                      if (number < 1 || number > numberOfDays) {
                        return SizedBox(width: side, height: side);
                      }
                      final date = DateTime(first.year, first.month, number);
                      final count = minutes[date] ?? 0;
                      final active = date == selected;
                      final future = date.isAfter(today);
                      final shade = count == 0
                          ? Colors.transparent
                          : VstudyColors.navy.withValues(
                              alpha: .18 + .82 * count / maximum,
                            );
                      final key =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      return SizedBox(
                        width: side,
                        height: side,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Semantics(
                            label:
                                '${shortDate(date)}, ${future ? 'chưa đến ngày' : '$count phút học'}',
                            selected: active,
                            child: Material(
                              color: active ? VstudyColors.gold : shade,
                              borderRadius: BorderRadius.circular(7),
                              child: InkWell(
                                key: ValueKey('stats-month-day-$key'),
                                borderRadius: BorderRadius.circular(7),
                                onTap: future
                                    ? null
                                    : () => setState(() => _selectedDay = date),
                                child: Center(
                                  child: Text(
                                    '$number',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: active
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: active
                                          ? VstudyColors.navy
                                          : future
                                          ? VstudyColors.divider
                                          : count > maximum * .4
                                          ? Colors.white
                                          : VstudyColors.navy,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                '${shortDate(selected)} · ${formatStudyMinutes(minutes[selected] ?? 0)}',
                key: const ValueKey('stats-selected-day-minutes'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Chạm vào ngày để xem thời lượng học. Ô đậm hơn là ngày học nhiều hơn.',
                style: TextStyle(
                  fontSize: 10,
                  color: VstudyColors.muted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatsMetric(
                label: 'Chuỗi học hiện tại',
                value: '${report.study.currentStreakDays} ngày',
                subtitle: '${report.activeDays} ngày học trong tháng',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatsMetric(
                label: 'Ngày học nhiều nhất',
                value: best == null
                    ? 'Chưa có dữ liệu'
                    : statsDateLabel(best.date),
                subtitle: best == null
                    ? 'Ghi nhận buổi học để bắt đầu'
                    : formatStudyMinutes(best.minutes),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _semester(AnalyticsSnapshot snapshot, AnalyticsReport report) {
    final weekly = report.weeklyMinutes
        .where(
          (day) =>
              !report.window.from.isAfter(snapshot.now) &&
              !day.date.isAfter(_localDate(snapshot.now)),
        )
        .toList();
    DailyMinutes? bestWeek;
    for (final week in weekly) {
      if (week.minutes > 0 &&
          (bestWeek == null || week.minutes > bestWeek.minutes)) {
        bestWeek = week;
      }
    }
    final subjects =
        report.study.minutesBySubject.entries
            .where((entry) => entry.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final names = {
      for (final subject in snapshot.subjects) subject.id: subject.name,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _total(report),
              const SizedBox(height: 19),
              const Text(
                'Thời gian học theo tuần (phút)',
                style: TextStyle(fontSize: 10, color: VstudyColors.muted),
              ),
              const SizedBox(height: 12),
              StatsLineChart(
                values: weekly.map((week) => week.minutes.toDouble()).toList(),
              ),
              if (weekly.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:
                      [
                            Text(statsDateLabel(weekly.first.date)),
                            Text(statsDateLabel(weekly.last.date)),
                          ]
                          .map(
                            (text) => DefaultTextStyle(
                              style: const TextStyle(
                                fontSize: 10,
                                color: VstudyColors.muted,
                              ),
                              child: text,
                            ),
                          )
                          .toList(),
                ),
              if (report.study.totalMinutes == 0) ...[
                const SizedBox(height: 10),
                const Text(
                  'Chưa có buổi học trong học kỳ đã chọn.',
                  style: TextStyle(fontSize: 11, color: VstudyColors.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Mốc nổi bật',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _highlight(
          Icons.show_chart_rounded,
          'Tuần học nhiều nhất',
          bestWeek == null
              ? 'Chưa có dữ liệu học trong học kỳ'
              : '${statsDateLabel(bestWeek.date)} · ${formatStudyMinutes(bestWeek.minutes)}',
        ),
        const SizedBox(height: 10),
        _highlight(
          Icons.menu_book_outlined,
          'Môn dành nhiều thời gian nhất',
          subjects.isEmpty
              ? 'Chưa có dữ liệu môn học'
              : '${subjects.first.key == 'unassigned' ? 'Chưa gắn môn học' : names[subjects.first.key] ?? 'Môn học đã xóa'} · ${formatStudyMinutes(subjects.first.value)}',
        ),
        const SizedBox(height: 12),
        _metrics(report),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _openGoals,
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text(
              'Đổi thời gian học kỳ',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _highlight(IconData icon, String title, String subtitle) => StatsCard(
    padding: const EdgeInsets.all(13),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: VstudyColors.paleGold,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 20, color: VstudyColors.navy),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: VstudyColors.muted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

DateTime _localDate(DateTime value) {
  final date = value.toLocal();
  return DateTime(date.year, date.month, date.day);
}

DateTime _dayBefore(DateTime value) =>
    DateTime(value.year, value.month, value.day - 1);

String _weekday(DateTime value) =>
    value.weekday == DateTime.sunday ? 'CN' : 'T${value.weekday + 1}';
