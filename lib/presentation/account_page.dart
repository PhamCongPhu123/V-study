import 'package:flutter/material.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'account_editor_page.dart';
import 'account_widgets.dart';
import 'design_system.dart';
import 'quiz_ai_launcher.dart';
import 'widgets.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.useCases,
    required this.onNavigate,
    this.preview = false,
    this.onPreviewSignOut,
  });
  final VstudyUseCases useCases;
  final ValueChanged<int> onNavigate;
  final bool preview;
  final VoidCallback? onPreviewSignOut;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountActivity {
  const _AccountActivity(this.statistics, this.subjects);
  final StudyStatistics statistics;
  final List<Subject> subjects;
}

class _AccountPageState extends State<AccountPage> {
  late Future<Profile> _profile;
  late Future<_AccountActivity> _activity;
  bool _busy = false;
  bool _pending = false;
  String? _error;
  bool get _locked => _busy || _pending;
  String get _email =>
      widget.useCases.auth.currentUser?.email ??
      (widget.preview ? 'tom@vstudy.demo' : 'Chưa có email');

  @override
  void initState() {
    super.initState();
    _profile = widget.useCases.study.getProfile();
    _activity = _startActivity();
  }

  Future<_AccountActivity> _loadActivity() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day - 29);
    final values = await Future.wait<Object>([
      widget.useCases.study.getStatistics(from, now, now),
      widget.useCases.study.listSubjects(),
    ]);
    return _AccountActivity(
      values[0] as StudyStatistics,
      values[1] as List<Subject>,
    );
  }

  Future<_AccountActivity> _startActivity() {
    final future = _loadActivity();
    // The profile may fail before its activity section is built. Keep the
    // error available for Retry without leaving a Future error unobserved.
    future.ignore();
    return future;
  }

  void _refresh() => setState(() {
    _profile = widget.useCases.study.getProfile();
    _activity = _startActivity();
  });

  Future<void> _edit(Profile profile) async {
    if (_locked) {
      return;
    }
    setState(() => _pending = true);
    try {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AccountEditorPage(
            useCases: widget.useCases,
            profile: profile,
            email: _email,
          ),
        ),
      );
      if (mounted && saved == true) {
        _refresh();
      }
    } finally {
      if (mounted) {
        setState(() => _pending = false);
      }
    }
  }

  Future<void> _preferences(Profile profile, AccountPreferences next) async {
    if (_locked) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.useCases.saveAccountPreferences(next);
      if (mounted) {
        setState(
          () => _profile = Future.value(profile.copyWith(preferences: next)),
        );
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

  Future<void> _signOut() async {
    if (_locked) {
      return;
    }
    setState(() => _pending = true);
    final confirmed = await showAccountConfirmation(
      context,
      title: 'Đăng xuất',
      message: widget.preview
          ? 'Bạn có muốn thoát bản xem thử giao diện?'
          : 'Bạn có muốn đăng xuất tài khoản này?',
      confirm: 'Đăng xuất',
      destructive: true,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _pending = false;
    });
    if (!confirmed) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.preview) {
        final leave = widget.onPreviewSignOut;
        if (leave != null) {
          leave();
        } else {
          Navigator.of(context).pop();
        }
      } else {
        await widget.useCases.auth.signOut();
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

  Widget _panel(Profile profile, Widget child) => Container(
    decoration: BoxDecoration(
      color: profile.preferences.darkProfile
          ? const Color(0xFF2A3850)
          : Colors.white.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(15),
    ),
    child: child,
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
    ),
  );

  Widget _link(
    Profile profile, {
    required String keyName,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = VstudyColors.gold,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: _panel(
      profile,
      ListTile(
        key: ValueKey(keyName),
        enabled: !_locked,
        onTap: _locked ? null : onTap,
        leading: CircleAvatar(
          radius: 17,
          backgroundColor: color.withValues(alpha: .18),
          child: Icon(icon, size: 19, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    ),
  );

  Widget _activitySection(Profile profile) => AsyncContent<_AccountActivity>(
    future: _activity,
    onRetry: () => setState(() => _activity = _startActivity()),
    builder: (data) {
      final stats = data.statistics;
      Widget counter(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panel(
            profile,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  counter(
                    '${stats.totalMinutes ~/ 60}h ${stats.totalMinutes % 60}p',
                    'Giờ học · 30 ngày',
                  ),
                  counter('${stats.quizAttempts}', 'Bài quiz · 30 ngày'),
                  counter(
                    stats.quizAttempts == 0
                        ? '—'
                        : '${stats.averageQuizPercent.round()}%',
                    'Điểm trung bình',
                  ),
                ],
              ),
            ),
          ),
          _section('Môn học của tôi'),
          if (data.subjects.isEmpty)
            const Text(
              'Chưa có môn học. Bạn có thể thêm môn trong Quiz.',
              style: TextStyle(fontSize: 12),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final subject in data.subjects)
                  Chip(
                    label: Text(
                      subject.name,
                      style: const TextStyle(fontSize: 11),
                    ),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: profile.preferences.darkProfile
                        ? const Color(0xFF34435C)
                        : VstudyColors.paleGold,
                  ),
              ],
            ),
        ],
      );
    },
  );

  Widget _content(Profile profile) => RefreshIndicator(
    onRefresh: () async {
      if (_locked) {
        return;
      }
      _refresh();
      try {
        await Future.wait<Object>([_profile, _activity]);
      } catch (_) {
        /* Retry UI displays the error. */
      }
    },
    child: ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 84),
      children: [
        Center(
          child: AccountAvatar(
            avatarKey: profile.avatarKey,
            onTap: _locked ? null : () => _edit(profile),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          profile.displayName.trim().isEmpty ? 'Bạn học' : profile.displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          _email,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
        if (profile.className.isNotEmpty || profile.major.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [
                profile.className,
                profile.major,
              ].where((value) => value.isNotEmpty).join(' · '),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            key: const ValueKey('account-edit'),
            onPressed: _locked ? null : () => _edit(profile),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Chỉnh sửa thông tin'),
          ),
        ),
        if (widget.preview)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Hồ sơ và hoạt động minh họa',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11),
            ),
          ),
        _activitySection(profile),
        _section('Chức năng'),
        _link(
          profile,
          keyName: 'account-calendar',
          icon: Icons.calendar_month_outlined,
          title: 'Lịch cá nhân',
          subtitle: 'Sắp xếp việc học của bạn',
          onTap: () => widget.onNavigate(0),
        ),
        _link(
          profile,
          keyName: 'account-ai',
          icon: Icons.auto_awesome,
          title: 'Trợ lý học tập AI',
          subtitle: 'Hỏi đáp và ôn tập cùng V-study',
          onTap: () => QuizAiLauncher.open(context),
        ),
        _link(
          profile,
          keyName: 'account-documents',
          icon: Icons.folder_copy_outlined,
          title: 'Tài liệu đã lưu',
          subtitle: 'Không gian học liệu của bạn',
          onTap: () => widget.onNavigate(4),
          color: VstudyColors.green,
        ),
        _link(
          profile,
          keyName: 'account-statistics',
          icon: Icons.bar_chart_rounded,
          title: 'Thống kê và mục tiêu',
          subtitle: 'Theo dõi hành trình học tập',
          onTap: () => widget.onNavigate(3),
          color: const Color(0xFF6882BA),
        ),
        _section('Cài đặt'),
        _panel(
          profile,
          Column(
            children: [
              SwitchListTile.adaptive(
                key: const ValueKey('account-dark-mode'),
                secondary: const Icon(
                  Icons.dark_mode_outlined,
                  color: VstudyColors.gold,
                ),
                title: const Text(
                  'Chế độ tối',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Giao diện trang tài khoản',
                  style: TextStyle(fontSize: 10),
                ),
                activeTrackColor: VstudyColors.gold,
                value: profile.preferences.darkProfile,
                onChanged: _locked
                    ? null
                    : (value) => _preferences(
                        profile,
                        AccountPreferences(
                          darkProfile: value,
                          studyReminders: profile.preferences.studyReminders,
                        ),
                      ),
              ),
              SwitchListTile.adaptive(
                key: const ValueKey('account-study-reminders'),
                secondary: const Icon(
                  Icons.notifications_none,
                  color: VstudyColors.gold,
                ),
                title: const Text(
                  'Nhắc học',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Lưu lựa chọn; chưa gửi thông báo thiết bị',
                  style: TextStyle(fontSize: 10),
                ),
                activeTrackColor: VstudyColors.gold,
                value: profile.preferences.studyReminders,
                onChanged: _locked
                    ? null
                    : (value) => _preferences(
                        profile,
                        AccountPreferences(
                          darkProfile: profile.preferences.darkProfile,
                          studyReminders: value,
                        ),
                      ),
              ),
              const ListTile(
                leading: Icon(Icons.language, color: VstudyColors.muted),
                title: Text('Ngôn ngữ', style: TextStyle(fontSize: 13)),
                trailing: Text('Tiếng Việt', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _link(
          profile,
          keyName: 'account-help',
          icon: Icons.help_outline,
          title: 'Trợ giúp',
          subtitle: 'Hướng dẫn sử dụng V-study',
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  _AccountHelpPage(dark: profile.preferences.darkProfile),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                key: const ValueKey('account-error'),
                style: const TextStyle(color: VstudyColors.red),
              ),
            ),
          ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: 16),
        _panel(
          profile,
          TextButton(
            key: const ValueKey('account-logout'),
            onPressed: _locked ? null : _signOut,
            style: TextButton.styleFrom(
              foregroundColor: VstudyColors.red,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text(
              'Đăng xuất',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<Profile>(
    future: _profile,
    builder: (context, snapshot) => AccountFrame(
      title: 'Thông tin tài khoản',
      dark: snapshot.data?.preferences.darkProfile ?? false,
      body: AsyncContent<Profile>(
        future: _profile,
        onRetry: _refresh,
        builder: _content,
      ),
    ),
  );
}

class _AccountHelpPage extends StatelessWidget {
  const _AccountHelpPage({required this.dark});
  final bool dark;
  @override
  Widget build(BuildContext context) => AccountFrame(
    title: 'Trợ giúp',
    dark: dark,
    body: ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 80),
      children: const [
        ExpansionTile(
          title: Text('Lưu thông tin cá nhân'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Chọn Chỉnh sửa thông tin, cập nhật hồ sơ và bấm Lưu thay đổi. Email đăng nhập được quản lý bởi dịch vụ xác thực và không thay đổi khi sửa hồ sơ.',
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: Text('Bản xem thử và dữ liệu thật'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Bản xem thử dùng dữ liệu minh họa, thay đổi chỉ giữ trong phiên chạy. Khi dùng tài khoản thật, hồ sơ và dữ liệu học được lưu riêng cho tài khoản của bạn.',
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: Text('Nhắc học và thông báo'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Bạn có thể lưu lựa chọn nhắc học và thời gian nhắc trong lịch. Phiên bản hiện tại chưa gửi thông báo trên thiết bị.',
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: Text('Đăng xuất có xóa dữ liệu không?'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Đăng xuất đóng phiên đăng nhập trên thiết bị. Hồ sơ và dữ liệu học đã lưu trên máy chủ vẫn được giữ.',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
