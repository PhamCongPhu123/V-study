import 'entities.dart';

abstract interface class AccountRepository {
  Future<void> saveAccount(AccountDraft draft);
  Future<void> saveAccountPreferences(AccountPreferences preferences);
}
