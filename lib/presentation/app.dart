import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/entities.dart';
import '../domain/use_cases.dart';
import '../domain/repositories.dart';
import '../core/app_exception.dart';
import 'auth_page.dart';
import 'password_recovery_page.dart';
import 'design_system.dart';
import 'shell.dart';

export 'auth_page.dart';
export 'password_recovery_page.dart';

AuthFlowRepository? _authFlow(AuthRepository auth) =>
    auth is AuthFlowRepository ? auth as AuthFlowRepository : null;

class VstudyApp extends StatelessWidget {
  const VstudyApp({
    super.key,
    required this.useCases,
    this.preview = false,
    this.showAuthPreview = false,
  });
  final VstudyUseCases useCases;
  final bool preview;
  final bool showAuthPreview;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vstudy',
    debugShowCheckedModeBanner: false,
    theme: vstudyTheme(),
    home: preview
        ? _PreviewGate(useCases: useCases, showAuth: showAuthPreview)
        : _AuthGate(useCases: useCases),
  );
}

class _PreviewGate extends StatefulWidget {
  const _PreviewGate({required this.useCases, required this.showAuth});
  final VstudyUseCases useCases;
  final bool showAuth;
  @override
  State<_PreviewGate> createState() => _PreviewGateState();
}

class _PreviewGateState extends State<_PreviewGate> {
  bool _ended = false;
  late bool _showAuth;
  @override
  void initState() {
    super.initState();
    _showAuth = widget.showAuth;
  }

  @override
  Widget build(BuildContext context) => _showAuth
      ? AuthPage(
          useCases: widget.useCases,
          preview: true,
          onPreviewEnter: () => setState(() {
            _showAuth = false;
            _ended = false;
          }),
        )
      : _ended
      ? Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.waving_hand_outlined,
                      size: 56,
                      color: VstudyColors.gold,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Đã thoát bản xem thử',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bạn có thể tiếp tục xem giao diện mà không cần đăng nhập.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey('account-preview-continue'),
                      onPressed: () => setState(() => _ended = false),
                      child: const Text('Tiếp tục xem giao diện'),
                    ),
                    TextButton(
                      key: const ValueKey('account-preview-auth'),
                      onPressed: () => setState(() {
                        _showAuth = true;
                        _ended = false;
                      }),
                      child: const Text('Xem đăng nhập / đăng ký'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
      : VstudyShell(
          useCases: widget.useCases,
          preview: true,
          onPreviewSignOut: () => setState(() => _ended = true),
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
    final initialFlow = _authFlow(widget.useCases.auth);
    if (initialFlow != null) {
      _recovery = initialFlow.isPasswordRecovery;
      final notice = initialFlow.takePendingAuthNotice();
      if (notice != null) {
        _handleAuthError(AppException(notice), StackTrace.empty);
      }
    }
    _authSubscription = widget.useCases.auth.userChanges.listen((user) {
      if (!mounted) {
        return;
      }
      final accountChanged = _user?.id != user?.id;
      setState(() {
        _user = user;
        final flow = _authFlow(widget.useCases.auth);
        if (flow != null) {
          _recovery = flow.isPasswordRecovery;
        }
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
        SnackBar(
          content: Text(
            error is AppException
                ? error.message
                : 'Không thể cập nhật phiên đăng nhập. Hãy thử đăng nhập lại hoặc yêu cầu liên kết mới.',
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
        onCompleted: () {
          final flow = _authFlow(widget.useCases.auth);
          if (flow != null) {
            flow.completePasswordRecovery();
          }
          setState(() {
            _recovery = false;
            _user = widget.useCases.auth.currentUser;
          });
          _resetRoutes();
        },
        onCancel: () async {
          await widget.useCases.auth.signOut();
          if (mounted) {
            final flow = _authFlow(widget.useCases.auth);
            if (flow != null) {
              flow.completePasswordRecovery();
            }
            setState(() {
              _recovery = false;
              _user = widget.useCases.auth.currentUser;
            });
            _resetRoutes();
          }
        },
      );
    }
    if (_user == null) {
      return AuthPage(useCases: widget.useCases);
    }
    return VstudyShell(key: ValueKey(_user!.id), useCases: widget.useCases);
  }
}
