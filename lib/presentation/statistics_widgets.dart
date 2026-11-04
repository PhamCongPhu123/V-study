import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/analytics.dart';
import 'design_system.dart';

String formatStudyMinutes(int minutes) {
  if (minutes < 60) {
    return '$minutes phút';
  }
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0
      ? '${hours}h'
      : '${hours}h ${remainder.toString().padLeft(2, '0')}p';
}

String statsDateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';

class StatsCard extends StatelessWidget {
  const StatsCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

class StatsHeader extends StatelessWidget {
  const StatsHeader({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: VstudyColors.navy,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 5),
        Text(
          subtitle!,
          style: const TextStyle(
            fontSize: 11,
            color: VstudyColors.muted,
            height: 1.5,
          ),
        ),
      ],
    ],
  );
}

class StatsPeriodSelector extends StatelessWidget {
  const StatsPeriodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final AnalyticsPeriod selected;
  final ValueChanged<AnalyticsPeriod> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFE5E0D4),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: AnalyticsPeriod.values.map((period) {
        final active = selected == period;
        return Expanded(
          child: Semantics(
            button: true,
            selected: active,
            child: InkWell(
              key: ValueKey('stats-period-${period.name}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => onChanged(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? VstudyColors.navy : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  switch (period) {
                    AnalyticsPeriod.week => 'Tuần',
                    AnalyticsPeriod.month => 'Tháng',
                    AnalyticsPeriod.semester => 'Học kỳ',
                  },
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : VstudyColors.muted,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class StatsMetric extends StatelessWidget {
  const StatsMetric({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
  });
  final String label;
  final String value;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => StatsCard(
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: VstudyColors.muted),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: VstudyColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 10,
              color: VstudyColors.muted,
              height: 1.45,
            ),
          ),
        ],
      ],
    ),
  );
}

class StatsBarChart extends StatelessWidget {
  const StatsBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.highlightIndex,
  });
  final List<double> values;
  final List<String> labels;
  final int? highlightIndex;
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox(
        height: 130,
        child: Center(
          child: Text(
            'Chưa có dữ liệu',
            style: TextStyle(color: VstudyColors.muted, fontSize: 12),
          ),
        ),
      );
    }
    final maximum = values.fold<double>(
      1,
      (value, next) => next.isFinite ? math.max(value, next) : value,
    );
    return Semantics(
      label: List.generate(
        values.length,
        (i) =>
            '${i < labels.length ? labels[i] : '${i + 1}'}: ${values[i].isFinite ? values[i].toStringAsFixed(0) : '0'}',
      ).join(', '),
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(values.length, (index) {
            final value = values[index].isFinite
                ? math.max(0.0, values[index])
                : 0.0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: value == 0
                            ? const SizedBox(
                                height: 1,
                                width: double.infinity,
                                child: ColoredBox(color: VstudyColors.divider),
                              )
                            : FractionallySizedBox(
                                widthFactor: .94,
                                heightFactor: (value / maximum)
                                    .clamp(.02, 1.0)
                                    .toDouble(),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: index == highlightIndex
                                        ? VstudyColors.gold
                                        : VstudyColors.navy,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(5),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 26,
                      child: Text(
                        index < labels.length ? labels[index] : '${index + 1}',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          color: VstudyColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class StatsLineChart extends StatelessWidget {
  const StatsLineChart({super.key, required this.values});
  final List<double> values;
  @override
  Widget build(BuildContext context) => Semantics(
    label: values.isEmpty
        ? 'Chưa có dữ liệu theo tuần'
        : 'Biểu đồ theo tuần: ${values.map((v) => v.isFinite ? v.toStringAsFixed(0) : '0').join(', ')}',
    child: SizedBox(
      height: 150,
      width: double.infinity,
      child: CustomPaint(painter: _StatsLinePainter(values)),
    ),
  );
}

class _StatsLinePainter extends CustomPainter {
  const _StatsLinePainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    final safe = values
        .map((v) => v.isFinite ? math.max(0.0, v) : 0.0)
        .toList();
    final grid = Paint()
      ..color = VstudyColors.blue.withValues(alpha: .45)
      ..strokeWidth = .7;
    for (var i = 0; i < 4; i++) {
      final y = 12 + (size.height - 24) * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (safe.isEmpty) {
      return;
    }
    final maxValue = safe.fold<double>(1, math.max);
    final points = List.generate(
      safe.length,
      (i) => Offset(
        safe.length == 1 ? size.width / 2 : i * size.width / (safe.length - 1),
        size.height - 12 - safe[i] / maxValue * (size.height - 28),
      ),
    );
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = VstudyColors.navy
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    final dot = Paint()..color = VstudyColors.navy;
    for (final point in points) {
      canvas.drawCircle(point, 2.5, dot);
    }
    canvas.drawCircle(points.last, 3.5, Paint()..color = VstudyColors.gold);
  }

  @override
  bool shouldRepaint(_StatsLinePainter oldDelegate) =>
      oldDelegate.values != values;
}
