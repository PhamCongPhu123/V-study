import 'analytics.dart';

abstract interface class AnalyticsRepository {
  Future<AnalyticsSnapshot> loadSnapshot({required DateTime now});
  Future<void> saveGoals(LearningGoals goals);
  Future<void> logFocusSession({
    required DateTime startedAt,
    required int plannedMinutes,
    required int focusedMinutes,
    required int interruptions,
    String? subjectId,
  });
  Future<void> logFlashcardSession({
    required DateTime reviewedAt,
    required int reviewedCards,
    required int rememberedCards,
    String? subjectId,
  });
}
