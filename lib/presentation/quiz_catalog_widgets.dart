import 'package:flutter/material.dart';
import '../domain/entities.dart';
import 'design_system.dart';

class QuizCourseHero extends StatelessWidget {
  const QuizCourseHero({
    super.key,
    required this.subject,
    required this.questionCount,
    required this.quizCount,
    required this.progress,
  });
  final Subject subject;
  final int questionCount;
  final int quizCount;
  final double progress;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: VstudyColors.navy,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33202B48),
          blurRadius: 10,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: const Color(0xFFA83D30),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            color: Color(0xFFFFF2CB),
            size: 36,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$questionCount câu hỏi • $quizCount bộ đề',
                style: const TextStyle(color: Color(0xFFD8DCE9), fontSize: 11),
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0).toDouble(),
                  minHeight: 4,
                  color: VstudyColors.gold,
                  backgroundColor: const Color(0xFF4E5871),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 7),
        const Icon(Icons.auto_awesome, color: VstudyColors.gold, size: 20),
      ],
    ),
  );
}

class QuizPill extends StatelessWidget {
  const QuizPill(this.text, {super.key, this.color = VstudyColors.gold});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}

String quizDifficultyLabel(String difficulty) => switch (difficulty) {
  'easy' => 'Dễ',
  'hard' => 'Khó',
  _ => 'Trung bình',
};
Color quizDifficultyColor(String difficulty) => switch (difficulty) {
  'easy' => VstudyColors.green,
  'hard' => VstudyColors.red,
  _ => VstudyColors.gold,
};

class QuizEmptyCard extends StatelessWidget {
  const QuizEmptyCard(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: VstudyColors.paper,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: VstudyColors.muted, fontSize: 13),
    ),
  );
}
