import 'package:flutter/material.dart';

import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'widgets.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key, required this.useCases});
  final VstudyUseCases useCases;
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsData {
  const _StatisticsData(this.statistics, this.subjectNames);
  final StudyStatistics statistics;
  final Map<String, String> subjectNames;
}

class _StatisticsPageState extends State<StatisticsPage> {
  int _days = 7;
  late Future<_StatisticsData> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StatisticsData> _load() async {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day + 1);
    final start = DateTime(now.year, now.month, now.day - _days + 1);
    final results = await Future.wait<Object>([
      widget.useCases.study.getStatistics(start, end, now),
      widget.useCases.study.listSubjects(),
    ]);
    return _StatisticsData(results[0] as StudyStatistics, {
      for (final subject in results[1] as List<Subject>)
        subject.id: subject.name,
    });
  }

  void _refresh() => setState(() => _future = _load());
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            const Expanded(child: Text('Khoảng thời gian')),
            DropdownButton<int>(
              value: _days,
              items: [7, 30, 90]
                  .map(
                    (d) => DropdownMenuItem(value: d, child: Text('$d ngày')),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _days = value;
                    _future = _load();
                  });
                }
              },
            ),
            IconButton(
              onPressed: _refresh,
              tooltip: 'Tải lại',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      Expanded(
        child: AsyncContent<_StatisticsData>(
          future: _future,
          onRetry: _refresh,
          builder: (result) {
            final data = result.statistics;
            return PageBody(
              children: [
                const Text(
                  'Thống kê từ các buổi học đã ghi nhận và bài quiz đã nộp.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Metric(
                      'Thời gian học',
                      '${data.totalMinutes} phút',
                      Icons.timer_outlined,
                    ),
                    _Metric(
                      'Bài quiz đã nộp',
                      '${data.quizAttempts}',
                      Icons.quiz_outlined,
                    ),
                    _Metric(
                      'Điểm quiz trung bình',
                      '${data.averageQuizPercent.toStringAsFixed(1)}%',
                      Icons.school_outlined,
                    ),
                    _Metric(
                      'Chuỗi học hiện tại',
                      '${data.currentStreakDays} ngày',
                      Icons.local_fire_department_outlined,
                    ),
                  ],
                ),
                const SectionTitle('Thời gian học theo ngày'),
                if (data.totalMinutes == 0)
                  const EmptyView(
                    'Chưa có thời gian học trong khoảng này. Ghi nhận buổi học từ trang chủ.',
                  ),
                ...data.dailyMinutes.map((day) {
                  final maxMinutes = data.dailyMinutes.fold<int>(
                    1,
                    (m, d) => d.minutes > m ? d.minutes : m,
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 54,
                          child: Text('${day.date.day}/${day.date.month}'),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: day.minutes / maxMinutes,
                          ),
                        ),
                        SizedBox(
                          width: 76,
                          child: Text(
                            '${day.minutes} phút',
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SectionTitle('Theo môn học'),
                if (data.minutesBySubject.isEmpty)
                  const EmptyView('Chưa có dữ liệu môn học.'),
                ...data.minutesBySubject.entries.map(
                  (entry) => ListTile(
                    title: Text(
                      entry.key == 'unassigned'
                          ? 'Chưa gắn môn học'
                          : result.subjectNames[entry.key] ?? 'Môn học đã xóa',
                    ),
                    trailing: Text('${entry.value} phút'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(label),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    ),
  );
}
