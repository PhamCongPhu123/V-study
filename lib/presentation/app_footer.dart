import 'package:flutter/material.dart';
import 'design_system.dart';

/// The order is shared by every page and matches the submitted design.
enum VstudyTab { calendar, qa, home, statistics, documents }

class VstudyFooter extends StatelessWidget {
  const VstudyFooter({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const labels = [
    'Lịch',
    'Hỏi đáp',
    'Trang chủ',
    'Thống kê',
    'Tài liệu',
  ];
  static const ids = ['calendar', 'qa', 'home', 'statistics', 'documents'];
  static const icons = [
    Icons.calendar_month_outlined,
    Icons.forum_outlined,
    Icons.home_outlined,
    Icons.bar_chart_rounded,
    Icons.menu_book_outlined,
  ];

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: VstudyColors.footer,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 68,
        child: Row(
          children: List.generate(icons.length, (index) {
            final selected = index == selectedIndex;
            return Expanded(
              child: Semantics(
                selected: selected,
                button: true,
                label: labels[index],
                child: Tooltip(
                  message: labels[index],
                  excludeFromSemantics: true,
                  child: InkResponse(
                    key: ValueKey('footer-${ids[index]}'),
                    onTap: () => onSelected(index),
                    radius: 28,
                    child: SizedBox(
                      height: 68,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 48,
                          height: 48,
                          transform: Matrix4.translationValues(
                            0,
                            selected ? -14 : 0,
                            0,
                          ),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? VstudyColors.navy
                                : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF9DAED1)
                                  : Colors.transparent,
                              width: 4,
                            ),
                            boxShadow: selected
                                ? [
                                    const BoxShadow(
                                      color: Color(0x33202B48),
                                      blurRadius: 10,
                                      offset: Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            icons[index],
                            size: selected ? 24 : 22,
                            color: selected ? Colors.white : VstudyColors.navy,
                            semanticLabel: null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}
