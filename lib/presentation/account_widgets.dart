import 'package:flutter/material.dart';
import 'design_system.dart';

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.avatarKey,
    this.size = 86,
    this.onTap,
  });
  final String avatarKey;
  final double size;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final icon = switch (avatarKey) {
      'book' => Icons.auto_stories_rounded,
      'rocket' => Icons.rocket_launch_rounded,
      'flower' => Icons.local_florist_rounded,
      _ => Icons.face_rounded,
    };
    final avatar = Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF4E5C7),
            border: Border.all(color: VstudyColors.gold, width: 2.5),
          ),
          child: Icon(icon, size: size * .57, color: VstudyColors.navy),
        ),
        if (onTap != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: VstudyColors.gold,
              ),
              child: const Icon(
                Icons.edit_outlined,
                size: 14,
                color: VstudyColors.navy,
              ),
            ),
          ),
      ],
    );
    if (onTap == null) {
      return avatar;
    }
    return Semantics(
      button: true,
      label: 'Chọn ảnh đại diện',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: avatar,
      ),
    );
  }
}

class AccountFrame extends StatelessWidget {
  const AccountFrame({
    super.key,
    required this.title,
    required this.body,
    this.dark = false,
    this.onClose,
    this.actions,
  });
  final String title;
  final Widget body;
  final bool dark;
  final VoidCallback? onClose;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = dark
        ? ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: VstudyColors.gold,
              secondary: VstudyColors.gold,
              surface: Color(0xFF26334C),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: VstudyColors.gold,
                foregroundColor: VstudyColors.navy,
              ),
            ),
          )
        : vstudyTheme();
    return Theme(
      data: theme,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: dark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF182033), Color(0xFF26344C)],
                )
              : VstudyColors.background,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            foregroundColor: dark ? Colors.white : VstudyColors.navy,
            leading: IconButton(
              key: const ValueKey('account-back'),
              tooltip: 'Quay lại',
              onPressed: onClose ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            ),
            title: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            actions: actions,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> showAccountConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  bool destructive = false,
}) async {
  var closed = false;
  void close(BuildContext dialogContext, bool value) {
    if (closed || ModalRoute.of(dialogContext)?.isCurrent != true) {
      return;
    }
    closed = true;
    Navigator.of(dialogContext).pop(value);
  }

  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VstudyColors.navy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: VstudyColors.muted, height: 1.5),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              key: const ValueKey('account-dialog-cancel'),
              onPressed: () => close(dialogContext, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: VstudyColors.navy,
              ),
              child: const Text('Hủy'),
            ),
            FilledButton(
              key: const ValueKey('account-dialog-confirm'),
              onPressed: () => close(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: destructive
                    ? VstudyColors.red
                    : VstudyColors.navy,
                foregroundColor: Colors.white,
              ),
              child: Text(confirm),
            ),
          ],
        ),
      ) ==
      true;
}
