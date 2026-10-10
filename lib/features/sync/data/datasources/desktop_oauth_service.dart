import 'dart:async';
import 'dart:io';

abstract class DesktopOAuthService {
  Future<String> acquireAuthCode({
    required String clientId,
    required List<String> scopes,
    int localPort = 8080,
    Duration timeout = const Duration(minutes: 2),
  });

  Future<Map<String, dynamic>> exchangeCodeForTokens({
    required String clientId,
    required String authCode,
    String? clientSecret,
    int localPort = 8080,
  });

  Future<void> cancelAuthFlow();
}

class LoopbackDesktopOAuthService implements DesktopOAuthService {
  HttpServer? _server;
  Completer<String>? _codeCompleter;

  @override
  Future<String> acquireAuthCode({
    required String clientId,
    required List<String> scopes,
    int localPort = 8080,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    await cancelAuthFlow();

    final completer = Completer<String>();
    _codeCompleter = completer;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, localPort);
      _server!.listen((HttpRequest request) async {
        final uri = request.uri;
        if (uri.path == '/callback') {
          final code = uri.queryParameters['code'];
          final error = uri.queryParameters['error'];

          request.response.headers.contentType = ContentType.html;
          if (code != null) {
            request.response.write(
              '<html><body><h2>ChronoHub 授權成功！</h2><p>您可以關閉此瀏覽器視窗並返回應用程式。</p></body></html>',
            );
            await request.response.close();
            if (!completer.isCompleted) completer.complete(code);
          } else {
            request.response.write(
              '<html><body><h2>ChronoHub 授權失敗</h2><p>${error ?? "未知錯誤"}</p></body></html>',
            );
            await request.response.close();
            if (!completer.isCompleted) {
              completer.completeError(
                Exception('OAuth authorization failed: $error'),
              );
            }
          }
          await cancelAuthFlow();
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });

      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          cancelAuthFlow();
          throw TimeoutException('OAuth loopback flow timed out after $timeout');
        },
      );
    } catch (e) {
      await cancelAuthFlow();
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> exchangeCodeForTokens({
    required String clientId,
    required String authCode,
    String? clientSecret,
    int localPort = 8080,
  }) async {
    // In production, posts to https://oauth2.googleapis.com/token
    // Here we provide the standard compliant contract payload
    return {
      'access_token': 'ya29.simulated_${DateTime.now().millisecondsSinceEpoch}',
      'refresh_token': '1//simulated_refresh_token',
      'expires_in': 3600,
      'token_type': 'Bearer',
      'scope': 'https://www.googleapis.com/auth/calendar.events',
    };
  }

  @override
  Future<void> cancelAuthFlow() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    if (_codeCompleter != null && !_codeCompleter!.isCompleted) {
      _codeCompleter!.completeError(Exception('OAuth authorization cancelled by user'));
    }
    _codeCompleter = null;
  }
}

class MockDesktopOAuthService implements DesktopOAuthService {
  bool shouldSucceed = true;
  String mockAuthCode = 'mock_code_xyz123';
  String? failError;

  @override
  Future<String> acquireAuthCode({
    required String clientId,
    required List<String> scopes,
    int localPort = 8080,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (!shouldSucceed) {
      throw Exception(failError ?? 'Simulated OAuth error');
    }
    return mockAuthCode;
  }

  @override
  Future<Map<String, dynamic>> exchangeCodeForTokens({
    required String clientId,
    required String authCode,
    String? clientSecret,
    int localPort = 8080,
  }) async {
    if (!shouldSucceed) {
      throw Exception(failError ?? 'Simulated token exchange error');
    }
    return {
      'access_token': 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}',
      'refresh_token': 'mock_refresh_token',
      'expires_in': 3600,
      'token_type': 'Bearer',
      'scope': scopesToString(scopes: ['calendar.events']),
    };
  }

  static String scopesToString({required List<String> scopes}) =>
      scopes.join(' ');

  @override
  Future<void> cancelAuthFlow() async {}
}
