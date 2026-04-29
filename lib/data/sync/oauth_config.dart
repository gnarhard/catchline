/// OAuth client identifiers for Google Sign-In.
///
/// These are issued in Google Cloud Console for the project that owns the
/// Drive `appdata` scope. Each platform needs its own client of the right
/// type:
///
/// - **iOS** / **macOS**: an "iOS" OAuth client. Bundle ID
///   `com.gnarhard.catchline`. The reversed client ID must also be added to
///   `ios/Runner/Info.plist` (`CFBundleURLTypes`) and
///   `macos/Runner/Info.plist`.
/// - **Android**: an "Android" OAuth client. Package name
///   `com.gnarhard.catchline` plus debug + release SHA-1 fingerprints. The
///   client ID is **not** referenced from code on Android — Google Play
///   Services discovers it via the package + signature, so leave the constant
///   below empty for Android.
/// - **Web**: a "Web application" OAuth client. Authorized JavaScript
///   origins must include `http://localhost:5000` (dev) and the eventual
///   production origin.
///
/// Until these are filled in, [requireConfigured] throws with a clear error
/// so a sync attempt fails loudly instead of silently producing 401s.
class OAuthConfig {
  const OAuthConfig._();

  // TODO(catchline): replace with the iOS/macOS OAuth client ID from Google
  // Cloud Console (looks like `<numeric>-<hash>.apps.googleusercontent.com`).
  static const String iosClientId = '';

  // TODO(catchline): replace with the Web OAuth client ID. Required for the
  // browser; ignored on native.
  static const String webClientId = '';

  /// Drive's "appdata" scope: a hidden, app-specific folder no other app or
  /// the Drive UI can see (visible only via the user's Drive "Manage apps").
  static const String driveAppdataScope =
      'https://www.googleapis.com/auth/drive.appdata';

  /// We also request `userinfo.email` so the signed-in account's email is
  /// available immediately for scoping `sync_meta` keys without a separate
  /// API call.
  static const String emailScope =
      'https://www.googleapis.com/auth/userinfo.email';

  static const List<String> requestedScopes = [driveAppdataScope, emailScope];
}

class OAuthConfigError extends StateError {
  OAuthConfigError(super.message);
}
