import '../core/app_exception.dart';
import '../domain/account_repository.dart';
import '../domain/entities.dart';
import 'data_support.dart';

class SupabaseAccountRepository extends SupabaseAccess
    implements AccountRepository {
  const SupabaseAccountRepository(super.client);

  Future<void> _update(Map<String, dynamic> values) => protect(() async {
    final changed = await client
        .from('profiles')
        .update(values)
        .eq('id', ownerId)
        .select('id');
    if (changed.isEmpty) {
      throw const AppException(
        'Không tìm thấy hồ sơ hoặc bạn không có quyền cập nhật. Vui lòng tải lại.',
      );
    }
  });

  @override
  Future<void> saveAccount(AccountDraft draft) {
    final birth = draft.birthDate;
    return _update({
      'display_name': draft.displayName.trim(),
      'daily_goal_minutes': draft.dailyGoalMinutes,
      'class_name': draft.className.trim(),
      'major': draft.major.trim(),
      'birth_date': birth == null
          ? null
          : '${birth.year.toString().padLeft(4, '0')}-${birth.month.toString().padLeft(2, '0')}-${birth.day.toString().padLeft(2, '0')}',
      'avatar_key': draft.avatarKey,
    });
  }

  @override
  Future<void> saveAccountPreferences(AccountPreferences preferences) =>
      _update({
        'dark_profile': preferences.darkProfile,
        'study_reminders': preferences.studyReminders,
      });
}
