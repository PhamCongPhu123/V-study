import 'package:flutter/material.dart';

import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.useCases, required this.onNavigate});
  final VstudyUseCases useCases;
  final ValueChanged<int> onNavigate;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<HomeDashboard> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<HomeDashboard> _load() =>
      widget.useCases.study.getDashboard(DateTime.now());
  void _refresh() => setState(() => _future = _load());
  Future<void> _logSession() async {
    try {
      final subjects = await widget.useCases.study.listSubjects();
      if (!mounted) {
        return;
      }
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) =>
            _SessionDialog(useCases: widget.useCases, subjects: subjects),
      );
      if (mounted && saved == true) {
        _refresh();
      }
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _editProfile(Profile profile) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _GoalDialog(useCases: widget.useCases, profile: profile),
    );
    if (mounted && saved == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) => AsyncContent<HomeDashboard>(
    future: _future,
    onRetry: _refresh,
    builder: (data) => PageBody(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Xin chào, ${data.profile.displayName}!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              onPressed: _refresh,
              tooltip: 'Tải lại',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text('Tiếp tục hành trình học tập của bạn.'),
        SectionTitle(
          'Mục tiêu hôm nay',
          action: IconButton(
            tooltip: 'Sửa hồ sơ và mục tiêu',
            onPressed: () => _editProfile(data.profile),
            icon: const Icon(Icons.edit_outlined),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${data.todayMinutes}/${data.profile.dailyGoalMinutes} phút',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: data.profile.dailyGoalMinutes > 0
                      ? (data.todayMinutes / data.profile.dailyGoalMinutes)
                            .clamp(0.0, 1.0)
                            .toDouble()
                      : 0.0,
                ),
                const SizedBox(height: 12),
                Text(
                  data.todayMinutes >= data.profile.dailyGoalMinutes
                      ? 'Bạn đã hoàn thành mục tiêu hôm nay!'
                      : 'Còn ${data.profile.dailyGoalMinutes - data.todayMinutes} phút đến mục tiêu.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _logSession,
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Ghi nhận thời gian đã học'),
                ),
              ],
            ),
          ),
        ),
        const SectionTitle('Truy cập nhanh'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.calendar_month),
              label: const Text('Thời gian biểu'),
              onPressed: () => widget.onNavigate(1),
            ),
            ActionChip(
              avatar: const Icon(Icons.quiz),
              label: const Text('Làm Quiz'),
              onPressed: () => widget.onNavigate(2),
            ),
            ActionChip(
              avatar: const Icon(Icons.auto_awesome),
              label: const Text('Hỏi AI'),
              onPressed: () => widget.onNavigate(3),
            ),
          ],
        ),
        const SectionTitle('Sắp đến'),
        if (data.upcomingEvents.isEmpty)
          const EmptyView('Chưa có lịch học hoặc deadline sắp đến.'),
        ...data.upcomingEvents.map(
          (event) => Card(
            child: ListTile(
              leading: Icon(
                event.kind == EventKind.deadline
                    ? Icons.flag_outlined
                    : Icons.event_outlined,
              ),
              title: Text(event.title),
              subtitle: Text(
                '${eventKindLabel(event.kind)} · ${shortDate(event.startsAt)} '
                '${shortTime(event.startsAt)}–${shortTime(event.endsAt)}'
                '${event.location.isEmpty ? '' : '\n${event.location}'}',
              ),
              onTap: () => widget.onNavigate(1),
            ),
          ),
        ),
        SectionTitle(
          'Tuần này',
          action: TextButton(
            onPressed: () => widget.onNavigate(4),
            child: const Text('Chi tiết'),
          ),
        ),
        ...data.week.map(
          (day) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text('${day.date.day}/${day.date.month}'),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: data.profile.dailyGoalMinutes > 0
                        ? (day.minutes / data.profile.dailyGoalMinutes)
                              .clamp(0.0, 1.0)
                              .toDouble()
                        : 0.0,
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text('${day.minutes} phút', textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
        ),
        const SectionTitle('Quiz gần đây'),
        if (data.recentQuizzes.isEmpty)
          const EmptyView(
            'Chưa có quiz. Tạo quiz theo chủ đề hoặc tài liệu của bạn.',
          ),
        ...data.recentQuizzes.map(
          (quiz) => ListTile(
            title: Text(quiz.title),
            subtitle: Text(quiz.topic),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.onNavigate(2),
          ),
        ),
        const SectionTitle('AI chat gần đây'),
        if (data.recentThreads.isEmpty)
          const EmptyView('Hỏi AI để bắt đầu cuộc trò chuyện đầu tiên.'),
        ...data.recentThreads.map(
          (thread) => ListTile(
            title: Text(thread.title),
            subtitle: Text(aiModeLabel(thread.mode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.onNavigate(3),
          ),
        ),
      ],
    ),
  );
}

class _SessionDialog extends StatefulWidget {
  const _SessionDialog({required this.useCases, required this.subjects});
  final VstudyUseCases useCases;
  final List<Subject> subjects;
  @override
  State<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<_SessionDialog> {
  final _minutes = TextEditingController(text: '30');
  String? _subjectId;
  late DateTime _startedAt;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now().subtract(const Duration(minutes: 30));
  }

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _startedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (day == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startedAt),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(
      () => _startedAt = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.useCases.logSession(
        startedAt: _startedAt,
        durationMinutes: int.tryParse(_minutes.text) ?? 0,
        subjectId: _subjectId,
      );
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ghi nhận buổi học'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chỉ ghi thời gian bạn đã học xong. Lịch dự kiến không được tính vào thống kê.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _subjectId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Môn học'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Tự học chung'),
                ),
                ...widget.subjects.map(
                  (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _subjectId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _minutes,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Thời lượng (phút)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _pickStart,
              child: Text(
                'Bắt đầu: ${shortDate(_startedAt)} ${shortTime(_startedAt)}',
              ),
            ),
            if (_error != null) Text(_error!),
          ],
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
        child: Text(_busy ? 'Đang lưu…' : 'Lưu'),
      ),
    ],
  );
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.useCases, required this.profile});
  final VstudyUseCases useCases;
  final Profile profile;
  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final TextEditingController _name;
  late final TextEditingController _goal;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.displayName);
    _goal = TextEditingController(text: '${widget.profile.dailyGoalMinutes}');
  }

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.useCases.updateProfile(
        displayName: _name.text,
        dailyGoalMinutes: int.tryParse(_goal.text) ?? 0,
      );
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Hồ sơ và mục tiêu'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Họ và tên'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _goal,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mục tiêu mỗi ngày (phút)',
              ),
            ),
            if (_error != null) Text(_error!),
          ],
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
        child: Text(_busy ? 'Đang lưu…' : 'Lưu'),
      ),
    ],
  );
}
