import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/auth_repository.dart';
import 'data/study_repository.dart';
import 'data/document_repository.dart';
import 'data/quiz_repository.dart';
import 'data/assistant_repository.dart';
import 'data/preview_repository.dart';
import 'data/analytics_repository.dart';
import 'domain/use_cases.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const liveBackend = bool.fromEnvironment('LIVE_BACKEND', defaultValue: false);
  if (!liveBackend) {
    final preview = PreviewRepository();
    runApp(VstudyApp(useCases: preview.useCases, preview: true));
    return;
  }
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  const redirect = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'io.vstudy.app://login-callback/',
  );
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !uri.hasAuthority ||
      !['https', 'http'].contains(uri.scheme) ||
      key.isEmpty) {
    runApp(const _ConfigurationApp());
    return;
  }
  try {
    await Supabase.initialize(url: url, anonKey: key);
    final client = Supabase.instance.client;
    runApp(
      VstudyApp(
        useCases: VstudyUseCases(
          auth: SupabaseAuthRepository(client, redirectUrl: redirect),
          study: SupabaseStudyRepository(client),
          documents: SupabaseDocumentRepository(client),
          quizzes: SupabaseQuizRepository(client),
          assistant: SupabaseAssistantRepository(client),
          analytics: SupabaseAnalyticsRepository(client),
        ),
      ),
    );
  } catch (_) {
    runApp(const _ConfigurationApp(failed: true));
  }
}

class _ConfigurationApp extends StatelessWidget {
  const _ConfigurationApp({this.failed = false});
  final bool failed;
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              failed
                  ? 'Không khởi tạo được kết nối Vstudy. Vui lòng kiểm tra cấu hình và khởi động lại.'
                  : 'Vstudy chưa được kết nối với máy chủ. Vui lòng liên hệ người quản trị ứng dụng.',
            ),
          ),
        ),
      ),
    ),
  );
}
