import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/auth_validation.dart';
import '../domain/use_cases.dart';
import 'auth_widgets.dart';
import 'design_system.dart';
import 'widgets.dart';

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({
    super.key,
    required this.useCases,
    required this.onCompleted,
    this.onCancel,
  });
  final VstudyUseCases useCases;
  final VoidCallback onCompleted;
  final Future<void> Function()? onCancel;
  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _visible = false;
  bool _confirmVisible = false;
  bool _busy = false;
  bool _success = false;
  bool _completed = false;
  String? _error;
  bool get _valid =>
      AuthValidation.password(_password.text, newPassword: true) == null &&
      AuthValidation.confirmation(_confirm.text, _password.text) == null;
  @override
  void initState() {
    super.initState();
    _password.addListener(_changed);
    _confirm.addListener(_changed);
  }

  void _changed() {
    if (mounted) {
      setState(() {
        if (!_busy) {
          _error = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _success || !(_form.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.useCases.updatePassword(_password.text, _confirm.text);
      if (!mounted) {
        return;
      }
      TextInput.finishAutofillContext(shouldSave: true);
      _password.clear();
      _confirm.clear();
      setState(() => _success = true);
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

  Future<void> _cancel() async {
    if (_busy) {
      return;
    }
    if (_success) {
      _done();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.onCancel != null) {
        await widget.onCancel!();
      } else {
        await widget.useCases.auth.signOut();
        if (mounted) {
          widget.onCompleted();
        }
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

  void _done() {
    if (_completed || _busy) {
      return;
    }
    _completed = true;
    widget.onCompleted();
  }

  Widget _field(bool confirmation) => AuthFieldLabel(
    label: confirmation ? 'Nhập lại mật khẩu mới' : 'Mật khẩu mới',
    child: TextFormField(
      key: ValueKey(confirmation ? 'recovery-confirm' : 'recovery-password'),
      controller: confirmation ? _confirm : _password,
      enabled: !_busy,
      obscureText: !(confirmation ? _confirmVisible : _visible),
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.newPassword],
      keyboardType: TextInputType.visiblePassword,
      textInputAction: confirmation
          ? TextInputAction.done
          : TextInputAction.next,
      validator: (value) => confirmation
          ? AuthValidation.confirmation(value, _password.text)
          : AuthValidation.password(value, newPassword: true),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration:
          authInputDecoration(
            confirmation ? 'Nhập lại mật khẩu mới' : 'Từ 8 đến 128 ký tự',
            Icons.lock_outline,
          ).copyWith(
            suffixIcon: IconButton(
              key: ValueKey(
                confirmation
                    ? 'recovery-toggle-confirm'
                    : 'recovery-toggle-password',
              ),
              tooltip: (confirmation ? _confirmVisible : _visible)
                  ? 'Ẩn mật khẩu'
                  : 'Hiện mật khẩu',
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      if (confirmation) {
                        _confirmVisible = !_confirmVisible;
                      } else {
                        _visible = !_visible;
                      }
                    }),
              icon: Icon(
                (confirmation ? _confirmVisible : _visible)
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
              ),
            ),
          ),
      onFieldSubmitted: (_) {
        if (confirmation) {
          _save();
        } else {
          FocusScope.of(context).nextFocus();
        }
      },
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        _cancel();
      }
    },
    child: AuthFrame(
      onBack: _busy ? null : _cancel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _success ? 'Mật khẩu đã cập nhật' : 'Đặt lại mật khẩu',
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            _success
                ? 'Bạn có thể tiếp tục hành trình học tập.'
                : 'Chọn mật khẩu mới để bảo vệ tài khoản của bạn.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.6,
              color: VstudyColors.muted,
            ),
          ),
          const SizedBox(height: 22),
          AuthCard(
            child: _success
                ? Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: VstudyColors.green,
                        size: 60,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Đã lưu mật khẩu mới.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 20),
                      AuthSubmitButton(
                        key: const ValueKey('recovery-done'),
                        label: 'Tiếp tục học tập',
                        onPressed: _done,
                      ),
                    ],
                  )
                : AutofillGroup(
                    onDisposeAction: AutofillContextAction.cancel,
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget
                                  .useCases
                                  .auth
                                  .currentUser
                                  ?.email
                                  .isNotEmpty ==
                              true)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Text(
                                widget.useCases.auth.currentUser!.email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          _field(false),
                          _field(true),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  _error!,
                                  key: const ValueKey('recovery-error'),
                                  style: const TextStyle(
                                    color: VstudyColors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          AuthSubmitButton(
                            key: const ValueKey('recovery-save'),
                            label: _busy ? 'Đang lưu…' : 'Lưu mật khẩu mới',
                            busy: _busy,
                            onPressed: _busy || !_valid ? null : _save,
                          ),
                          TextButton(
                            key: const ValueKey('recovery-cancel'),
                            onPressed: _busy ? null : _cancel,
                            child: const Text(
                              'Quay về đăng nhập',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
