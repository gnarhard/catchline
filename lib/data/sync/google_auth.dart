import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'oauth_config.dart';

/// Wraps `google_sign_in` for Catchline's Drive sync.
///
/// Sign-in (identity) is separate from authorization (OAuth scopes) in
/// `google_sign_in` 7.x. This class exposes a single `connectDrive()` flow
/// that does both, and a `getAuthedClient()` that hands the sync engine an
/// `http.Client` with a fresh access token bound to it.
class GoogleAuth {
  GoogleAuth._();

  static final GoogleAuth instance = GoogleAuth._();

  bool _initialized = false;
  GoogleSignInAccount? _account;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _eventSub;
  final StreamController<GoogleSignInAccount?> _accountStream =
      StreamController<GoogleSignInAccount?>.broadcast();

  /// Stream of the current account (`null` when signed out). Always emits the
  /// latest known value to new subscribers.
  Stream<GoogleSignInAccount?> get accountStream => _accountStream.stream;

  GoogleSignInAccount? get currentAccount => _account;

  /// Initializes the underlying SDK exactly once. Must be awaited before any
  /// other method on this class. Safe to call repeatedly — extra calls are
  /// no-ops.
  Future<void> initialize() async {
    if (_initialized) return;

    final clientId = kIsWeb ? OAuthConfig.webClientId : OAuthConfig.iosClientId;
    // Android gets null — the platform plugin discovers credentials from the
    // package name + SHA-1.
    final initClientId = clientId.isEmpty ? null : clientId;

    await GoogleSignIn.instance.initialize(clientId: initClientId);

    _eventSub = GoogleSignIn.instance.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _setAccount(event.user);
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          _setAccount(null);
        }
      },
      onError: (_) {
        // Sign-in errors are surfaced to callers of `connectDrive`. The
        // ambient stream just stays at its previous value.
      },
    );

    _initialized = true;

    // Try a silent restore of a previous session. May be null on web.
    final lightweight = GoogleSignIn.instance
        .attemptLightweightAuthentication();
    if (lightweight != null) {
      try {
        final account = await lightweight;
        if (account != null) _setAccount(account);
      } catch (_) {
        // Lightweight failures are expected; ignore.
      }
    }
  }

  void _setAccount(GoogleSignInAccount? account) {
    _account = account;
    _accountStream.add(account);
  }

  /// Interactive sign-in + scope authorization. Must be called from a user
  /// gesture (e.g. a button tap) — required by the web platform.
  ///
  /// Returns the signed-in account on success; throws on cancellation or
  /// auth failure.
  Future<GoogleSignInAccount> connectDrive() async {
    await initialize();

    GoogleSignInAccount account =
        _account ??
        await GoogleSignIn.instance.authenticate(
          scopeHint: OAuthConfig.requestedScopes,
        );

    // Make sure the Drive scope is actually granted. `authenticate()` may
    // sign in without granting scopes; `authorizeScopes` will prompt.
    await account.authorizationClient.authorizeScopes(
      OAuthConfig.requestedScopes,
    );

    _setAccount(account);
    return account;
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    await GoogleSignIn.instance.signOut();
    _setAccount(null);
  }

  /// Returns an `http.Client` that injects a fresh access token on every
  /// request and retries once with a refreshed token on `401 Unauthorized`.
  ///
  /// Throws [OAuthConfigError] if the user has not connected Drive yet, or
  /// if scope authorization is unexpectedly missing.
  Future<http.Client> getAuthedClient() async {
    final account = _account;
    if (account == null) {
      throw OAuthConfigError(
        'Not signed in. Call connectDrive() before using Drive APIs.',
      );
    }
    return _BearerClient(
      inner: http.Client(),
      account: account,
      scopes: OAuthConfig.requestedScopes,
    );
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
    await _accountStream.close();
  }
}

/// Injects `Authorization: Bearer <token>` on every request and refreshes the
/// token on a 401 (once per request, replayable bodies only).
class _BearerClient extends http.BaseClient {
  _BearerClient({
    required http.Client inner,
    required this.account,
    required this.scopes,
  }) : _inner = inner;

  final http.Client _inner;
  final GoogleSignInAccount account;
  final List<String> scopes;

  String? _cachedToken;

  Future<String> _token({required bool forceRefresh}) async {
    if (!forceRefresh) {
      final cached = _cachedToken;
      if (cached != null) return cached;
    } else if (_cachedToken != null) {
      // Tell google_sign_in to drop the cached token so the next request gets
      // a fresh one.
      await account.authorizationClient.clearAuthorizationToken(
        accessToken: _cachedToken!,
      );
      _cachedToken = null;
    }

    final authz = await account.authorizationClient.authorizationForScopes(
      scopes,
    );
    if (authz == null) {
      throw OAuthConfigError(
        'Drive scope is no longer authorized for this account. '
        'Call connectDrive() to re-authorize.',
      );
    }
    return _cachedToken = authz.accessToken;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _token(forceRefresh: false);
    final attempt = await _inner.send(_authed(request, token));
    if (attempt.statusCode != 401) return attempt;
    if (!_isReplayable(request)) return attempt;

    // Drain the failed response so the connection can be reused.
    await attempt.stream.drain<void>();

    final fresh = await _token(forceRefresh: true);
    return _inner.send(_authed(_clone(request), fresh));
  }

  @override
  void close() {
    _inner.close();
  }

  http.BaseRequest _authed(http.BaseRequest request, String token) {
    request.headers['Authorization'] = 'Bearer $token';
    return request;
  }

  bool _isReplayable(http.BaseRequest request) {
    // `http.Request` keeps `bodyBytes` in memory and can be cloned. Streamed
    // / multipart bodies cannot be replayed without help from the caller; for
    // those, the 401 bubbles to the sync engine which retries the operation
    // from scratch.
    return request is http.Request;
  }

  http.BaseRequest _clone(http.BaseRequest request) {
    final original = request as http.Request;
    final copy = http.Request(original.method, original.url)
      ..headers.addAll(original.headers)
      ..bodyBytes = original.bodyBytes
      ..encoding = original.encoding
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection;
    return copy;
  }
}
