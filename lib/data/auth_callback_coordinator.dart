import 'dart:async';
import 'package:app_links/app_links.dart';
import 'auth_repository.dart';

/// Owns PKCE callbacks so initial and foreground links follow the same path.
/// Never logs or persists the callback URI, OAuth code or token.
class AuthCallbackCoordinator {
  AuthCallbackCoordinator({
    required this.auth,
    required String redirectUrl,
    Stream<Uri>? links,
    Future<Uri?> Function()? initialLink,
  }) : _redirect = Uri.parse(redirectUrl),
       _links = links,
       _initialLink = initialLink;
  final SupabaseAuthRepository auth;
  final Uri _redirect;
  final Stream<Uri>? _links;
  final Future<Uri?> Function()? _initialLink;
  StreamSubscription<Uri>? _subscription;
  final _handled = <String>{};
  Future<void> _queue = Future.value();
  bool _disposed = false;
  bool _started = false;
  String _path(Uri uri) => uri.path.replaceAll(RegExp(r'/+$'), '');

  bool accepts(Uri uri) {
    if (uri.toString().length > 8192 ||
        uri.scheme.toLowerCase() != _redirect.scheme.toLowerCase() ||
        uri.host.toLowerCase() != _redirect.host.toLowerCase() ||
        uri.port != _redirect.port ||
        uri.userInfo.isNotEmpty ||
        _path(uri) != _path(_redirect)) {
      return false;
    }
    try {
      final params = {
        ...uri.queryParameters,
        if (uri.fragment.isNotEmpty) ...Uri.splitQueryString(uri.fragment),
      };
      return params.containsKey('code') ||
          params.containsKey('error_description') ||
          params.containsKey('error');
    } on FormatException {
      return false;
    }
  }

  void _receive(Uri uri) {
    if (_disposed || !accepts(uri) || !_handled.add(uri.toString())) {
      return;
    }
    if (_handled.length > 8) {
      _handled.remove(_handled.first);
    }
    _queue = _queue.then((_) async {
      if (!_disposed) {
        await auth.handleCallback(uri);
      }
    });
  }

  Future<void> start() async {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    try {
      final appLinks = _links == null || _initialLink == null
          ? AppLinks()
          : null;
      _subscription = (_links ?? appLinks!.uriLinkStream).listen(
        _receive,
        onError: (Object error, StackTrace stack) =>
            auth.reportCallbackFailure(),
      );
      final uri = await (_initialLink?.call() ?? appLinks!.getInitialLink());
      if (uri != null) {
        _receive(uri);
      }
    } catch (_) {
      auth.reportCallbackFailure();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _handled.clear();
  }
}
