import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'ai_page.dart';
import 'calendar_page.dart';
import 'home_page.dart';
import 'quiz_page.dart';
import 'statistics_page.dart';
import 'widgets.dart';

class VstudyApp extends StatelessWidget {
  const VstudyApp({super.key, required this.useCases});
  final VstudyUseCases useCases;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vstudy',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFC9A227),
        primary: const Color(0xFF1F2A44),
        secondary: const Color(0xFFC9A227),
        surface: const Color(0xFFF9F7F2),
      ),
      scaffoldBackgroundColor: const Color(0xFFF9F7F2),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: _AuthGate(useCases: useCases),
  );
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.useCases});
  final VstudyUseCases useCases;
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late AppUser? _user;
  StreamSubscription<AppUser?>? _authSubscription;
  StreamSubscription<bool>? _recoverySubscription;
  bool _recovery = false;

  @override
  void initState() {
    super.initState();
    _user = widget.useCases.auth.currentUser;
    _authSubscription = widget.useCases.auth.userChanges.listen((user) {
      if (!mounted) {
        return;
      }
      final accountChanged = _user?.id != user?.id;
      setState(() {
        _user = user;
        if (user == null) {
          _recovery = false;
        }
      });
      if (accountChanged) {
        _resetRoutes();
      }
    }, onError: _handleAuthError);
    _recoverySubscription = widget.useCases.auth.passwordRecovery.listen((
      recovery,
    ) {
      if (mounted && recovery) {
        setState(() => _recovery = true);
        _resetRoutes();
      }
    }, onError: _handleAuthError);
  }

  void _resetRoutes() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  void _handleAuthError(Object error, StackTrace stackTrace) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể cập nhật phiên đăng nhập. Hãy thử đăng nhập lại hoặc yêu cầu liên kết mới.',
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _recoverySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_recovery) {
      return PasswordRecoveryPage(
        useCases: widget.useCases,
        onCompleted: () => setState(() => _recovery = false),
      );
    }
    if (_user == null) {
      return AuthPage(useCases: widget.useCases);
    }
    return _MainShell(key: ValueKey(_user!.id), useCases: widget.useCases);
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.useCases});
  final VstudyUseCases useCases;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _register = false;
  bool _accepted = false;
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        setState(() => _notice = errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submit() => _run(() async {
    FocusScope.of(context).unfocus();
    if (_register) {
      final result = await widget.useCases.signUp(
        _name.text,
        _email.text,
        _password.text,
        _confirm.text,
        _accepted,
      );
      if (mounted && result.needsEmailConfirmation) {
        setState(() {
          _notice =
              'Đã đăng ký. Hãy kiểm tra email để xác nhận tài khoản rồi đăng nhập.';
          _register = false;
          _password.clear();
          _confirm.clear();
        });
      }
    } else {
      await widget.useCases.signIn(_email.text, _password.text);
    }
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: Color(0xFFC9A227),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Vstudy',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const Text('HỌC TẬP THÔNG MINH', textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  Text(
                    _register ? 'Tạo tài khoản' : 'Đăng nhập',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _register
                        ? 'Bắt đầu xây dựng lịch học của riêng bạn.'
                        : 'Tiếp tục hành trình học tập của bạn.',
                  ),
                  const SizedBox(height: 20),
                  if (_register) ...[
                    TextField(
                      controller: _name,
                      enabled: !_busy,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(labelText: 'Họ và tên'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    autofillHints: [
                      _register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: const InputDecoration(labelText: 'Mật khẩu'),
                    onSubmitted: (_) {
                      if (!_register) {
                        _submit();
                      }
                    },
                  ),
                  if (_register) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirm,
                      enabled: !_busy,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nhập lại mật khẩu',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _accepted,
                      onChanged: _busy
                          ? null
                          : (value) =>
                                setState(() => _accepted = value ?? false),
                      title: const Text(
                        'Tôi đồng ý với Điều khoản và Chính sách bảo mật.',
                      ),
                    ),
                  ] else
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                await widget.useCases.resetPassword(
                                  _email.text,
                                );
                                if (mounted) {
                                  setState(
                                    () => _notice =
                                        'Nếu email đã đăng ký, bạn sẽ nhận được hướng dẫn đặt lại mật khẩu.',
                                  );
                                }
                              }),
                        child: const Text('Quên mật khẩu?'),
                      ),
                    ),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(liveRegion: true, child: Text(_notice!)),
                    ),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Đang xử lý…'
                          : _register
                          ? 'Đăng ký'
                          : 'Đăng nhập',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(widget.useCases.auth.signInWithGoogle),
                    icon: const Icon(Icons.login),
                    label: const Text('Tiếp tục với Google'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _register = !_register;
                            _notice = null;
                          }),
                    child: Text(
                      _register
                          ? 'Đã có tài khoản? Đăng nhập'
                          : 'Chưa có tài khoản? Đăng ký',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({
    super.key,
    required this.useCases,
    required this.onCompleted,
  });
  final VstudyUseCases useCases;
  final VoidCallback onCompleted;
  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.useCases.updatePassword(_password.text, _confirm.text);
      if (mounted) {
        widget.onCompleted();
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đặt lại mật khẩu')),
    body: PageBody(
      children: [
        TextField(
          controller: _password,
          enabled: !_busy,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          enabled: !_busy,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu mới'),
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Đang lưu…' : 'Lưu mật khẩu'),
        ),
      ],
    ),
  );
}

class _MainShell extends StatefulWidget {
  const _MainShell({super.key, required this.useCases});
  final VstudyUseCases useCases;
  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;
  bool _signingOut = false;
  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await widget.useCases.auth.signOut();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _signingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.useCases;
    // Recreate a tab when selected so home/statistics reflect newly recorded data.
    final body = switch (_index) {
      0 => HomePage(
        useCases: u,
        onNavigate: (index) => setState(() => _index = index),
      ),
      1 => CalendarPage(useCases: u),
      2 => QuizPage(useCases: u),
      3 => AiPage(useCases: u),
      _ => StatisticsPage(useCases: u),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(
          [
            'Trang chủ',
            'Lịch học',
            'Quiz',
            'Trợ lý Vstudy',
            'Thống kê',
          ][_index],
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _signingOut ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Lịch',
          ),
          NavigationDestination(icon: Icon(Icons.quiz_outlined), label: 'Quiz'),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Thống kê',
          ),
        ],
      ),
    );
  }
}
