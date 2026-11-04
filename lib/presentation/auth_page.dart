import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_validation.dart';
import '../domain/use_cases.dart';
import 'auth_widgets.dart';
import 'design_system.dart';
import 'legal_information_page.dart';
import 'widgets.dart';

enum _AuthStep { signIn, signUp, confirmation, resetRequest, welcome }

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.useCases,
    this.preview = false,
    this.onPreviewEnter,
  });
  final VstudyUseCases useCases;
  final bool preview;
  final VoidCallback? onPreviewEnter;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _form = GlobalKey<FormState>();
  _AuthStep _step = _AuthStep.signIn;
  bool _accepted = false;
  bool _visible = false;
  bool _confirmVisible = false;
  bool _busy = false;
  bool _successNotice = false;
  bool _unconfirmed = false;
  bool _confirmationFromSignup = false;
  String? _notice;
  Timer? _timer;
  DateTime? _canSendAt;
  bool get _signup => _step == _AuthStep.signUp;
  bool get _valid =>
      AuthValidation.email(_email.text) == null &&
      (_step == _AuthStep.resetRequest ||
          (AuthValidation.password(_password.text, newPassword: _signup) ==
                  null &&
              (!_signup ||
                  (AuthValidation.name(_name.text) == null &&
                      AuthValidation.confirmation(
                            _confirm.text,
                            _password.text,
                          ) ==
                          null &&
                      _accepted))));
  int get _remaining {
    final ms = _canSendAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    for (final input in [_name, _email, _password, _confirm]) {
      input.addListener(_changed);
    }
  }

  void _changed() {
    if (!mounted) {
      return;
    }
    setState(() {
      if (!_busy) {
        _notice = null;
        _unconfirmed = false;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final input in [_name, _email, _password, _confirm]) {
      input.dispose();
    }
    super.dispose();
  }

  void _cooldown() {
    _timer?.cancel();
    _canSendAt = DateTime.now().add(const Duration(seconds: 60));
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _remaining == 0) {
        timer.cancel();
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _switch(_AuthStep step) {
    if (_busy) {
      return;
    }
    FocusScope.of(context).unfocus();
    TextInput.finishAutofillContext(shouldSave: false);
    _password.clear();
    _confirm.clear();
    setState(() {
      _step = step;
      _form = GlobalKey<FormState>();
      _visible = false;
      _confirmVisible = false;
      _notice = null;
      _unconfirmed = false;
      _accepted = false;
    });
  }

  void _back() {
    if (_busy) {
      return;
    }
    if (_step == _AuthStep.signIn) {
      _switch(_AuthStep.welcome);
    } else if (_step != _AuthStep.welcome) {
      _switch(_AuthStep.signIn);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy || widget.preview) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _notice = null;
      _unconfirmed = false;
      _successNotice = false;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _notice = errorMessage(error);
          _unconfirmed =
              error is AuthFailure &&
              error.reason == AuthFailureReason.unconfirmedEmail;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_busy || widget.preview) {
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    if (_signup && !_accepted) {
      setState(
        () => _notice = 'Vui lòng đồng ý với Điều khoản và Chính sách bảo mật.',
      );
      return;
    }
    await _perform(() async {
      if (_step == _AuthStep.resetRequest) {
        if (_remaining > 0) {
          return;
        }
        await widget.useCases.resetPassword(_email.text);
        if (!mounted) {
          return;
        }
        _cooldown();
        setState(() {
          _successNotice = true;
          _notice =
              'Nếu email đã được đăng ký, bạn sẽ nhận được liên kết đặt lại mật khẩu. Hãy kiểm tra cả thư rác.';
        });
      } else if (_signup) {
        final result = await widget.useCases.signUp(
          _name.text,
          _email.text,
          _password.text,
          _confirm.text,
          _accepted,
        );
        if (!mounted) {
          return;
        }
        if (result.needsEmailConfirmation) {
          TextInput.finishAutofillContext(shouldSave: false);
          _password.clear();
          _confirm.clear();
          _cooldown();
          setState(() {
            _step = _AuthStep.confirmation;
            _confirmationFromSignup = true;
            _accepted = false;
            _form = GlobalKey<FormState>();
          });
        } else {
          TextInput.finishAutofillContext(shouldSave: true);
          _password.clear();
          _confirm.clear();
          setState(() {
            _step = _AuthStep.signIn;
            _form = GlobalKey<FormState>();
            _accepted = false;
            _visible = false;
            _confirmVisible = false;
            _successNotice = true;
            _notice =
                'Tạo tài khoản thành công. Hãy đăng nhập để bắt đầu học tập.';
          });
        }
      } else {
        await widget.useCases.signIn(_email.text, _password.text);
        TextInput.finishAutofillContext(shouldSave: true);
      }
    });
  }

  Future<void> _google() => _perform(() async {
    await widget.useCases.auth.signInWithGoogle();
    if (mounted) {
      setState(() {
        _successNotice = true;
        _notice =
            'Hoàn tất đăng nhập Google trong trình duyệt để quay về Vstudy.';
      });
    }
  });
  Future<void> _resend() async {
    if (_remaining > 0 || AuthValidation.email(_email.text) != null) {
      return;
    }
    await _perform(() async {
      await widget.useCases.resendConfirmation(_email.text);
      if (!mounted) {
        return;
      }
      _cooldown();
      setState(() {
        _successNotice = true;
        _notice =
            'Nếu địa chỉ này có thể nhận email xác nhận, liên kết sẽ được gửi tới email của bạn. Hãy kiểm tra cả thư rác.';
      });
    });
  }

  void _showConfirmation() {
    _switch(_AuthStep.confirmation);
    _confirmationFromSignup = false;
  }

  Widget _heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 27,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: VstudyColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            height: 1.6,
            color: VstudyColors.muted,
          ),
        ),
      ],
    ),
  );
  Widget _message() => _notice == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _notice!,
              key: const ValueKey('auth-notice'),
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: _successNotice ? VstudyColors.green : VstudyColors.red,
              ),
            ),
          ),
        );
  Widget _emailField() => AuthFieldLabel(
    label: 'Email',
    child: TextFormField(
      key: const ValueKey('auth-email'),
      controller: _email,
      enabled: !_busy,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      autofillHints: const [AutofillHints.email],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: AuthValidation.email,
      decoration: authInputDecoration(
        'Nhập email của bạn',
        Icons.email_outlined,
      ),
      onFieldSubmitted: (_) {
        if (_step == _AuthStep.resetRequest) {
          _submit();
        } else {
          FocusScope.of(context).nextFocus();
        }
      },
    ),
  );
  Widget _passwordField({bool confirmation = false}) => AuthFieldLabel(
    label: confirmation ? 'Nhập lại mật khẩu' : 'Mật khẩu',
    child: TextFormField(
      key: ValueKey(confirmation ? 'auth-confirm-password' : 'auth-password'),
      controller: confirmation ? _confirm : _password,
      enabled: !_busy,
      obscureText: !(confirmation ? _confirmVisible : _visible),
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: [
        confirmation || _signup
            ? AutofillHints.newPassword
            : AutofillHints.password,
      ],
      textInputAction: _signup && !confirmation
          ? TextInputAction.next
          : TextInputAction.done,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) => confirmation
          ? AuthValidation.confirmation(value, _password.text)
          : AuthValidation.password(value, newPassword: _signup),
      decoration:
          authInputDecoration(
            confirmation ? 'Nhập lại mật khẩu' : 'Nhập mật khẩu',
            Icons.lock_outline,
          ).copyWith(
            helperText: _signup && !confirmation ? 'Từ 8 đến 128 ký tự.' : null,
            helperStyle: const TextStyle(fontSize: 10),
            suffixIcon: IconButton(
              key: ValueKey(
                confirmation ? 'auth-toggle-confirm' : 'auth-toggle-password',
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
        if (_signup && !confirmation) {
          FocusScope.of(context).nextFocus();
        } else {
          _submit();
        }
      },
    ),
  );
  void _legal(bool privacy) {
    if (_busy) {
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => LegalInformationPage(privacy: privacy)),
    );
  }

  Widget _terms() => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          height: 32,
          child: Checkbox(
            key: const ValueKey('auth-consent'),
            value: _accepted,
            visualDensity: VisualDensity.compact,
            onChanged: _busy
                ? null
                : (value) => setState(() => _accepted = value ?? false),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Tôi đồng ý với ',
                style: TextStyle(fontSize: 11, height: 2.2),
              ),
              TextButton(
                key: const ValueKey('auth-terms'),
                onPressed: _busy ? null : () => _legal(false),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Điều khoản',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              const Text(' và ', style: TextStyle(fontSize: 11)),
              TextButton(
                key: const ValueKey('auth-privacy'),
                onPressed: _busy ? null : () => _legal(true),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Chính sách bảo mật',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _formContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(
        _signup ? 'Tạo tài khoản' : 'Đăng nhập',
        _signup
            ? 'Bắt đầu xây dựng lịch học của riêng bạn.'
            : 'Tiếp tục hành trình học tập của bạn.',
      ),
      AuthCard(
        child: AutofillGroup(
          onDisposeAction: AutofillContextAction.cancel,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_signup)
                  AuthFieldLabel(
                    label: 'Họ và tên',
                    child: TextFormField(
                      key: const ValueKey('auth-name'),
                      controller: _name,
                      enabled: !_busy,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: AuthValidation.name,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: authInputDecoration(
                        'Nhập họ và tên',
                        Icons.person_outline,
                      ),
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                    ),
                  ),
                _emailField(),
                _passwordField(),
                if (_signup) ...[
                  _passwordField(confirmation: true),
                  _terms(),
                ] else
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey('auth-forgot'),
                      onPressed: _busy
                          ? null
                          : () => _switch(_AuthStep.resetRequest),
                      child: const Text(
                        'Quên mật khẩu?',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                _message(),
                if (_unconfirmed)
                  TextButton(
                    key: const ValueKey('auth-resend-link'),
                    onPressed: _busy ? null : _showConfirmation,
                    child: const Text(
                      'Gửi lại email xác nhận',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                AuthSubmitButton(
                  key: const ValueKey('auth-submit'),
                  label: _busy
                      ? 'Đang xử lý…'
                      : _signup
                      ? 'Tạo tài khoản'
                      : 'Đăng nhập',
                  busy: _busy,
                  onPressed: _busy || widget.preview || !_valid
                      ? null
                      : _submit,
                ),
                if (!_signup) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'hoặc',
                            style: TextStyle(
                              fontSize: 10,
                              color: VstudyColors.muted,
                            ),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    key: const ValueKey('auth-google'),
                    onPressed: _busy || widget.preview ? null : _google,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: VstudyColors.navy,
                      side: const BorderSide(color: Color(0xFFE1E4EC)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Row(
                      children: [
                        GoogleMark(),
                        Expanded(
                          child: Text(
                            'Tiếp tục với Google',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: 20),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      TextButton(
        key: ValueKey(_signup ? 'auth-switch-signin' : 'auth-switch-signup'),
        onPressed: _busy
            ? null
            : () => _switch(_signup ? _AuthStep.signIn : _AuthStep.signUp),
        child: Text.rich(
          TextSpan(
            text: _signup ? 'Đã có tài khoản?  ' : 'Chưa có tài khoản?  ',
            style: const TextStyle(fontSize: 11, color: VstudyColors.muted),
            children: [
              TextSpan(
                text: _signup ? 'Đăng nhập' : 'Đăng ký',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: VstudyColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Widget _confirmation() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(
        'Kiểm tra email của bạn',
        'Hoàn tất xác nhận email để đăng nhập vào Vstudy.',
      ),
      AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 60,
              color: VstudyColors.gold,
            ),
            const SizedBox(height: 18),
            Text(
              _email.text.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nếu địa chỉ này có thể đăng ký, hãy kiểm tra email và thư rác để mở liên kết xác nhận.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 18),
            _message(),
            AuthSubmitButton(
              key: const ValueKey('auth-resend'),
              label: _busy
                  ? 'Đang gửi…'
                  : _remaining > 0
                  ? 'Gửi lại sau ${_remaining}s'
                  : 'Gửi lại email xác nhận',
              busy: _busy,
              onPressed:
                  _busy ||
                      widget.preview ||
                      _remaining > 0 ||
                      AuthValidation.email(_email.text) != null
                  ? null
                  : _resend,
            ),
            TextButton(
              key: const ValueKey('auth-change-email'),
              onPressed: _busy
                  ? null
                  : () => _switch(
                      _confirmationFromSignup
                          ? _AuthStep.signUp
                          : _AuthStep.signIn,
                    ),
              child: const Text('Đổi email', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        key: const ValueKey('auth-confirm-signin'),
        onPressed: _busy ? null : () => _switch(_AuthStep.signIn),
        child: const Text(
          'Đã xác nhận? Đăng nhập',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
  Widget _resetRequest() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(
        'Quên mật khẩu?',
        'Nhập email để nhận liên kết đặt lại mật khẩu.',
      ),
      AuthCard(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _emailField(),
              _message(),
              AuthSubmitButton(
                key: const ValueKey('auth-send-reset'),
                label: _busy
                    ? 'Đang gửi…'
                    : _remaining > 0
                    ? 'Gửi lại sau ${_remaining}s'
                    : 'Gửi liên kết đặt lại',
                busy: _busy,
                onPressed: _busy || widget.preview || !_valid || _remaining > 0
                    ? null
                    : _submit,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: _busy ? null : () => _switch(_AuthStep.signIn),
        child: const Text('Quay về đăng nhập'),
      ),
    ],
  );
  Widget _welcome() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.school_outlined, size: 76, color: VstudyColors.gold),
      const SizedBox(height: 20),
      const Text(
        'Vstudy',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      const Text(
        'Cùng bạn học tập mỗi ngày.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: VstudyColors.muted),
      ),
      const SizedBox(height: 36),
      AuthSubmitButton(
        label: 'Đăng nhập',
        onPressed: () => _switch(_AuthStep.signIn),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () => _switch(_AuthStep.signUp),
        child: const Text('Tạo tài khoản'),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _step == _AuthStep.welcome && !_busy,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        _back();
      }
    },
    child: AuthFrame(
      preview: widget.preview,
      onBack: _busy || _step == _AuthStep.welcome ? null : _back,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switch (_step) {
            _AuthStep.signIn || _AuthStep.signUp => _formContent(),
            _AuthStep.confirmation => _confirmation(),
            _AuthStep.resetRequest => _resetRequest(),
            _AuthStep.welcome => _welcome(),
          },
          if (widget.preview && widget.onPreviewEnter != null) ...[
            const SizedBox(height: 18),
            const Text(
              'Xác thực tài khoản chưa được kết nối trong bản xem thử.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: VstudyColors.muted),
            ),
            TextButton(
              key: const ValueKey('auth-preview-enter'),
              onPressed: widget.onPreviewEnter,
              child: const Text(
                'Xem thử ứng dụng',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
