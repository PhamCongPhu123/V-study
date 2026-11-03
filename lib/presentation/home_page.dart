import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'design_system.dart';
import 'quiz_page.dart';
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

  Future<void> _openQuizzes() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: VstudyColors.cream,
          appBar: AppBar(title: const Text('Quiz ôn tập')),
          body: QuizPage(useCases: widget.useCases),
        ),
      ),
    );
    if (mounted) {
      _refresh();
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    return hour < 12
        ? 'Buổi sáng tốt lành!'
        : hour < 18
        ? 'Buổi chiều tốt lành!'
        : 'Buổi tối tốt lành!';
  }

  Widget _heading(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: VstudyColors.ink,
    ),
  );

  @override
  Widget build(BuildContext context) => AsyncContent<HomeDashboard>(
    future: _future,
    onRetry: _refresh,
    builder: (data) => RefreshIndicator(
      onRefresh: () async {
        final next = _load();
        setState(() => _future = next);
        await next;
      },
      color: VstudyColors.gold,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            key: const PageStorageKey('home-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
            children: [
              _header(data.profile),
              const SizedBox(height: 22),
              _goalCard(data),
              const SizedBox(height: 26),
              _heading('Truy cập nhanh'),
              const SizedBox(height: 12),
              _quickAccess(data),
              const SizedBox(height: 18),
              _suggestion(data),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _heading('Tuần này')),
                  TextButton(
                    onPressed: () => widget.onNavigate(3),
                    style: TextButton.styleFrom(
                      foregroundColor: VstudyColors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: const Text(
                      'Chi tiết',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _WeeklyChart(days: data.week),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _heading('Sắp đến')),
                  TextButton(
                    onPressed: () => widget.onNavigate(0),
                    child: const Text(
                      'Xem lịch',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              if (data.upcomingEvents.isEmpty)
                const EmptyView(
                  'Chưa có lịch sắp đến. Thêm một buổi học để bắt đầu nhé!',
                )
              else
                ...data.upcomingEvents.take(3).map(_upcomingCard),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _header(Profile profile) {
    final name = profile.displayName.trim().isEmpty
        ? 'bạn'
        : profile.displayName.trim();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: const TextStyle(fontSize: 11, color: VstudyColors.muted),
              ),
              const SizedBox(height: 3),
              Text(
                'Xin chào, $name!',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.2,
                  color: VstudyColors.ink,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: 'Hồ sơ và mục tiêu',
          child: InkWell(
            onTap: () => _editProfile(profile),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF1E3C4),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .8),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.face_rounded,
                color: VstudyColors.navy,
                size: 31,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _goalCard(HomeDashboard data) {
    final ratio = data.profile.dailyGoalMinutes <= 0
        ? 0.0
        : (data.todayMinutes / data.profile.dailyGoalMinutes)
              .clamp(0.0, 1.0)
              .toDouble();
    final remaining = math.max(
      0,
      data.profile.dailyGoalMinutes - data.todayMinutes,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 335;
        final ring = compact ? 82.0 : 100.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Stack(
            children: [
              Positioned.fill(
                top: 9,
                left: 4,
                right: 4,
                bottom: 0,
                child: Transform.rotate(
                  angle: -.035,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFB9C6E9),
                      borderRadius: BorderRadius.circular(21),
                    ),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(compact ? 18 : 22),
                decoration: BoxDecoration(
                  color: VstudyColors.navy,
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mục tiêu hôm nay',
                            style: TextStyle(
                              color: Color(0xFFD5D9E5),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${data.todayMinutes}/${data.profile.dailyGoalMinutes} phút',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 18 : 22,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            remaining == 0
                                ? 'Bạn đã hoàn thành mục tiêu!'
                                : 'Cố lên! Còn $remaining phút nữa là hoàn thành.',
                            style: const TextStyle(
                              color: Color(0xFFF7E8A9),
                              fontSize: 10,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _logSession,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: VstudyColors.navy,
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Ghi nhận buổi học'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      label:
                          'Đã hoàn thành ${(ratio * 100).round()} phần trăm mục tiêu',
                      child: SizedBox(
                        width: ring,
                        height: ring,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: ratio,
                                strokeWidth: compact ? 10 : 12,
                                strokeCap: StrokeCap.round,
                                backgroundColor: const Color(0xFF46506B),
                                color: VstudyColors.gold,
                              ),
                            ),
                            Text(
                              '${(ratio * 100).toStringAsFixed(1).replaceAll('.', ',')}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _quickAccess(HomeDashboard data) {
    final quizName = data.recentQuizzes.isEmpty
        ? 'Tạo quiz ôn tập'
        : data.recentQuizzes.first.title;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _QuickCard(
            key: const ValueKey('home-quiz'),
            label: 'Quiz',
            title: quizName,
            subtitle: 'Kiểm tra kiến thức của bạn',
            icon: Icons.wb_sunny_rounded,
            accent: VstudyColors.gold,
            tint: const Color(0xFFFFF0AE),
            onTap: _openQuizzes,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickCard(
            key: const ValueKey('home-documents'),
            label: 'Tài liệu',
            title: 'Kho tài liệu học tập',
            subtitle: 'Đọc lại và ghi nhớ kiến thức',
            icon: Icons.auto_stories_rounded,
            accent: const Color(0xFF8C9DCB),
            tint: const Color(0xFFE6EBF8),
            onTap: () => widget.onNavigate(4),
          ),
        ),
      ],
    );
  }

  Widget _suggestion(HomeDashboard data) {
    final next = data.upcomingEvents.isEmpty ? null : data.upcomingEvents.first;
    final text = next == null
        ? 'Chia nhỏ nội dung, nghỉ giữa giờ và tự kiểm tra bằng quiz để nhớ lâu hơn.'
        : 'Dành 25 phút chuẩn bị cho “${next.title}”, sau đó tự kiểm tra lại kiến thức.';
    return Material(
      color: const Color(0xFFF9EDC2),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => widget.onNavigate(1),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9D58D)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12BC941C),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: VstudyColors.gold,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 23,
                  color: VstudyColors.navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gợi ý từ Vstudy',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: VstudyColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.5,
                        color: Color(0xFF73705E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: VstudyColors.navy,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upcomingCard(StudyEvent event) {
    final deadline = event.kind == EventKind.deadline;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: VstudyColors.paper,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: () => widget.onNavigate(0),
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 44,
                  decoration: BoxDecoration(
                    color: deadline
                        ? VstudyColors.red
                        : const Color(0xFF9FACCA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: VstudyColors.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${shortDate(event.startsAt)} · ${shortTime(event.startsAt)} – ${shortTime(event.endsAt)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: VstudyColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  deadline ? Icons.flag_outlined : Icons.school_outlined,
                  size: 21,
                  color: deadline ? VstudyColors.red : VstudyColors.navy,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    super.key,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.tint,
    required this.onTap,
  });
  final String label;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color tint;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: VstudyColors.paper,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: VstudyColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(icon, color: accent, size: 24),
              ],
            ),
            const SizedBox(height: 17),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w800,
                color: VstudyColors.ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                height: 1.4,
                color: VstudyColors.muted,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 14, color: accent),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.days});
  final List<DailyMinutes> days;
  @override
  Widget build(BuildContext context) {
    final highest = days.fold<int>(
      0,
      (value, day) => math.max(value, day.minutes),
    );
    final maxHours = math.max(4, (highest / 60).ceil());
    final today = DateTime.now();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
      decoration: BoxDecoration(
        color: VstudyColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E8D6)),
      ),
      child: Semantics(
        label: 'Biểu đồ thời gian học từng ngày trong tuần',
        child: SizedBox(
          height: 172,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 150,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 4; i >= 0; i--)
                      Text(
                        '${(maxHours * i / 4).round()}h',
                        style: const TextStyle(
                          color: Color(0xFFBEA357),
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Stack(
                  children: [
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 150,
                      child: CustomPaint(painter: _ChartGridPainter()),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final day in days)
                          Expanded(
                            child: Tooltip(
                              message:
                                  '${shortDate(day.date)}: ${day.minutes} phút',
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 150,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: FractionallySizedBox(
                                        widthFactor: .38,
                                        heightFactor:
                                            (day.minutes / (maxHours * 60))
                                                .clamp(0.0, 1.0)
                                                .toDouble(),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color:
                                                day.date.year == today.year &&
                                                    day.date.month ==
                                                        today.month &&
                                                    day.date.day == today.day
                                                ? VstudyColors.gold
                                                : const Color(0xFFF2E5AF),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(5),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    day.date.weekday == DateTime.sunday
                                        ? 'CN'
                                        : 'T${day.date.weekday + 1}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFFBFA45C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartGridPainter extends CustomPainter {
  const _ChartGridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5D9B4)
      ..strokeWidth = .7;
    for (var row = 0; row <= 4; row++) {
      final y = size.height * row / 4;
      for (var x = 0.0; x < size.width; x += 5) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 1.5, size.width), y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ChartGridPainter oldDelegate) => false;
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
