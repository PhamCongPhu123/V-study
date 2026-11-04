import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'design_system.dart';

class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.child,
    required this.onBack,
    this.preview = false,
  });
  final Widget child;
  final VoidCallback? onBack;
  final bool preview;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: VstudyColors.background),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            key: const ValueKey('auth-scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton.filled(
                            key: const ValueKey('auth-back'),
                            tooltip: 'Quay lại',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: VstudyColors.navy,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back, size: 19),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'HỌC TẬP THÔNG MINH',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: VstudyColors.navy,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    if (preview)
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text(
                          'Bản xem thử · Chưa kết nối xác thực',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: VstudyColors.muted,
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),
                    child,
                    SizedBox(height: math.max(0.0, bounds.maxHeight * .10)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D202B48),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel({super.key, required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        child,
      ],
    ),
  );
}

InputDecoration authInputDecoration(String hint, IconData icon) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF979DAA)),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      prefixIcon: Icon(icon, size: 18, color: VstudyColors.navy),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 42),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFFE1E4EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFFE1E4EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: VstudyColors.navy),
      ),
      errorMaxLines: 3,
    );

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      backgroundColor: VstudyColors.navy,
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFFDEE3F0),
      disabledForegroundColor: const Color(0xFF969EB2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    ),
    child: Row(
      children: [
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        if (busy)
          const SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          const Icon(Icons.arrow_forward, size: 19),
      ],
    ),
  );
}

class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CustomPaint(painter: _GoogleMarkPainter()),
  );
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    for (final arc in [
      (45.0, 90.0, const Color(0xFF34A853)),
      (135.0, 65.0, const Color(0xFFFBBC05)),
      (200.0, 105.0, const Color(0xFFEA4335)),
      (-3.0, 48.0, const Color(0xFF4285F4)),
    ]) {
      paint.color = arc.$3;
      canvas.drawArc(
        rect,
        arc.$1 * math.pi / 180,
        arc.$2 * math.pi / 180,
        false,
        paint,
      );
    }
    paint
      ..color = const Color(0xFF4285F4)
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(size.width * .52, size.height * .50),
      Offset(size.width * .90, size.height * .50),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) => false;
}
