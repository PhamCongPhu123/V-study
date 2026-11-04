import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/auth_repository.dart';
import 'data/auth_callback_coordinator.dart';
import 'data/study_repository.dart';
import 'data/document_repository.dart';
import 'data/quiz_repository.dart';
import 'data/assistant_repository.dart';
import 'data/preview_repository.dart';
import 'data/analytics_repository.dart';
import 'data/account_repository.dart';
import 'data/ai_workspace_repository.dart';
import 'domain/use_cases.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const liveBackend = bool.fromEnvironment('LIVE_BACKEND', defaultValue: false);
  if (!liveBackend) {
    final preview = PreviewRepository();
    const skipAuthPreview = bool.fromEnvironment(
      'SKIP_AUTH_PREVIEW',
      defaultValue: false,
    );
    runApp(
      VstudyApp(
        useCases: preview.useCases,
        preview: true,
        showAuthPreview: !skipAuthPreview,
      ),
    );
    return;
  }
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  const redirect = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'io.vstudy.app://login-callback/',
  );
  final uri = Uri.tryParse(url);
  final callback = Uri.tryParse(redirect);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      !['https', 'http'].contains(uri.scheme) ||
      callback == null ||
      !callback.hasScheme ||
      !callback.hasAuthority ||
      callback.host.isEmpty ||
      callback.userInfo.isNotEmpty ||
      callback.hasQuery ||
      callback.hasFragment ||
      key.isEmpty) {
    runApp(const _ConfigurationApp());
    return;
  }
  try {
    await Supabase.initialize(
      url: url,
      anonKey: key,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        detectSessionInUri: false,
      ),
    );
    final client = Supabase.instance.client;
    final auth = SupabaseAuthRepository(client, redirectUrl: redirect);
    final callbacks = AuthCallbackCoordinator(
      auth: auth,
      redirectUrl: redirect,
    );
    runApp(
      _AuthRuntime(
        auth: auth,
        callbacks: callbacks,
        child: VstudyApp(
          useCases: VstudyUseCases(
            auth: auth,
            study: SupabaseStudyRepository(client),
            documents: SupabaseDocumentRepository(client),
            quizzes: SupabaseQuizRepository(client),
            assistant: SupabaseAssistantRepository(client),
            analytics: SupabaseAnalyticsRepository(client),
            account: SupabaseAccountRepository(client),
            aiWorkspace: SupabaseAiWorkspaceRepository(client),
          ),
        ),
      ),
    );
  } catch (_) {
    runApp(const _ConfigurationApp(failed: true));
  }
}

class _AuthRuntime extends StatefulWidget {
  const _AuthRuntime({
    required this.auth,
    required this.callbacks,
    required this.child,
  });
  final SupabaseAuthRepository auth;
  final AuthCallbackCoordinator callbacks;
  final Widget child;
  @override
  State<_AuthRuntime> createState() => _AuthRuntimeState();
}

class _AuthRuntimeState extends State<_AuthRuntime> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.callbacks.start());
  }

  @override
  void dispose() {
    unawaited(widget.callbacks.dispose());
    unawaited(widget.auth.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
