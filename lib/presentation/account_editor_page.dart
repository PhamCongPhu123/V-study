import 'dart:convert';
import 'package:flutter/material.dart';
import '../domain/entities.dart';
import '../domain/use_cases.dart';
import 'account_widgets.dart';
import 'design_system.dart';
import 'draft_exit_scope.dart';
import 'widgets.dart';

class AccountEditorPage extends StatefulWidget {
  const AccountEditorPage({
    super.key,
    required this.useCases,
    required this.profile,
    required this.email,
  });
  final VstudyUseCases useCases;
  final Profile profile;
  final String email;
  @override
  State<AccountEditorPage> createState() => _AccountEditorPageState();
}

class _AccountEditorPageState extends State<AccountEditorPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _className;
  late final TextEditingController _major;
  late final TextEditingController _goal;
  late String _avatar;
  DateTime? _birthDate;
  late final String _initial;
  bool _busy = false;
  bool _pending = false;
  bool _exiting = false;
  String? _error;
  DraftExitScope? _scope;
  VoidCallback? _detach;
  bool get _locked => _busy || _pending || _exiting;
  bool get _dirty => _snapshot() != _initial;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _name = TextEditingController(text: profile.displayName);
    _className = TextEditingController(text: profile.className);
    _major = TextEditingController(text: profile.major);
    _goal = TextEditingController(text: '${profile.dailyGoalMinutes}');
    _avatar = profile.avatarKey;
    _birthDate = profile.birthDate;
    _initial = _snapshot();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = DraftExitScope.maybeOf(context);
    if (_scope != scope) {
      _detach?.call();
      _scope = scope;
      _detach = scope?.attach(_requestExit);
    }
  }

  @override
  void dispose() {
    _detach?.call();
    for (final input in [_name, _className, _major, _goal]) {
      input.dispose();
    }
    super.dispose();
  }

  String _snapshot() => jsonEncode([
    _name.text.trim(),
    _className.text.trim(),
    _major.text.trim(),
    _goal.text.trim(),
    _avatar,
    _birthDate?.toIso8601String(),
  ]);

  Future<bool> _requestExit() async {
    if (_locked) {
      return false;
    }
    if (_dirty) {
      setState(() => _pending = true);
      final discard = await showAccountConfirmation(
        context,
        title: 'Bỏ thay đổi?',
        message: 'Thông tin bạn vừa chỉnh sửa chưa được lưu.',
        confirm: 'Bỏ thay đổi',
        destructive: true,
      );
      if (!mounted) {
        return false;
      }
      setState(() => _pending = false);
      if (!discard) {
        return false;
      }
    }
    _exiting = true;
    Navigator.of(context).pop(false);
    return true;
  }

  Future<void> _pickAvatar() async {
    if (_locked) {
      return;
    }
    setState(() => _pending = true);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chọn ảnh đại diện',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 14,
                children: [
                  for (final key in accountAvatarKeys)
                    SizedBox(
                      width: 76,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            key: ValueKey('account-avatar-$key'),
                            onTap: () {
                              if (ModalRoute.of(sheetContext)?.isCurrent ==
                                  true) {
                                Navigator.pop(sheetContext, key);
                              }
                            },
                            customBorder: const CircleBorder(),
                            child: AccountAvatar(avatarKey: key, size: 62),
                          ),
                          const SizedBox(height: 6),
                          Text(switch (key) {
                            'book' => 'Mọt sách',
                            'rocket' => 'Khám phá',
                            'flower' => 'Sáng tạo',
                            _ => 'Bạn học',
                          }, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _pending = false;
      if (selected != null) {
        _avatar = selected;
      }
    });
  }

  Future<void> _pickBirthDate() async {
    if (_locked) {
      return;
    }
    setState(() => _pending = true);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final earliest = DateTime(1900);
    var initial = _birthDate ?? DateTime(now.year - 20, now.month, now.day);
    if (initial.isBefore(earliest)) {
      initial = earliest;
    }
    if (initial.isAfter(today)) {
      initial = today;
    }
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: earliest,
      lastDate: today,
      helpText: 'Chọn ngày sinh',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _pending = false;
      if (selected != null) {
        _birthDate = selected;
      }
    });
  }

  Future<void> _save() async {
    if (_locked || !(_form.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_dirty) {
      await _requestExit();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.useCases.saveAccount(
        AccountDraft(
          displayName: _name.text,
          dailyGoalMinutes: int.tryParse(_goal.text.trim()) ?? 0,
          className: _className.text,
          major: _major.text,
          birthDate: _birthDate,
          avatarKey: _avatar,
        ),
      );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('account-save-success'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Color(0xFF1EAB44), size: 56),
              SizedBox(height: 16),
              Text(
                'Cập nhật thành công!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: VstudyColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              key: const ValueKey('account-success-done'),
              onPressed: () {
                if (ModalRoute.of(dialogContext)?.isCurrent == true) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text(
                'Hoàn tất',
                style: TextStyle(color: VstudyColors.navy),
              ),
            ),
          ],
        ),
      );
      if (!mounted) {
        return;
      }
      _exiting = true;
      Navigator.of(context).pop(true);
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

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: widget.profile.preferences.darkProfile
        ? const Color(0xFF2A3851)
        : Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        _requestExit();
      }
    },
    child: AccountFrame(
      title: 'Chỉnh sửa thông tin',
      dark: widget.profile.preferences.darkProfile,
      onClose: _requestExit,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: AccountAvatar(
                        key: const ValueKey('account-change-avatar'),
                        avatarKey: _avatar,
                        size: 90,
                        onTap: _locked ? null : _pickAvatar,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      key: const ValueKey('account-name'),
                      controller: _name,
                      enabled: !_locked,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration('Họ và tên'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập họ và tên.'
                          : value.trim().length > 100
                          ? 'Họ và tên tối đa 100 ký tự.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const ValueKey('account-email'),
                      initialValue: widget.email,
                      readOnly: true,
                      decoration: _decoration('Email').copyWith(
                        suffixIcon: const Icon(Icons.lock_outline, size: 18),
                        helperText:
                            'Email đăng nhập được quản lý riêng trong xác thực.',
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const ValueKey('account-class'),
                      controller: _className,
                      enabled: !_locked,
                      decoration: _decoration('Lớp'),
                      validator: (value) => (value?.trim().length ?? 0) > 80
                          ? 'Tên lớp tối đa 80 ký tự.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const ValueKey('account-major'),
                      controller: _major,
                      enabled: !_locked,
                      decoration: _decoration('Ngành học'),
                      validator: (value) => (value?.trim().length ?? 0) > 120
                          ? 'Ngành học tối đa 120 ký tự.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('account-birth-date'),
                            onPressed: _locked ? null : _pickBirthDate,
                            icon: const Icon(
                              Icons.calendar_month_outlined,
                              size: 20,
                            ),
                            label: Text(
                              _birthDate == null
                                  ? 'Chọn ngày sinh'
                                  : 'Ngày sinh: ${shortDate(_birthDate!)}',
                            ),
                          ),
                        ),
                        if (_birthDate != null)
                          IconButton(
                            key: const ValueKey('account-clear-birth-date'),
                            tooltip: 'Xóa ngày sinh',
                            onPressed: _locked
                                ? null
                                : () => setState(() => _birthDate = null),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      title: const Text(
                        'Mục tiêu học mỗi ngày',
                        style: TextStyle(fontSize: 14),
                      ),
                      tilePadding: EdgeInsets.zero,
                      children: [
                        TextFormField(
                          key: const ValueKey('account-daily-goal'),
                          controller: _goal,
                          enabled: !_locked,
                          keyboardType: TextInputType.number,
                          decoration: _decoration('Số phút mỗi ngày'),
                          validator: (value) {
                            final minutes = int.tryParse(value?.trim() ?? '');
                            return minutes == null ||
                                    minutes < 1 ||
                                    minutes > 1440
                                ? 'Nhập từ 1 đến 1440 phút.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 62, 16),
              child: Row(
                children: [
                  TextButton(
                    key: const ValueKey('account-edit-cancel'),
                    onPressed: _locked ? null : _requestExit,
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('account-save'),
                      onPressed: _locked ? null : _save,
                      child: Text(_busy ? 'Đang lưu…' : 'Lưu thay đổi'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
