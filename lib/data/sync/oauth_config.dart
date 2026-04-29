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
///   Services discovers it via the package + signature.
/// - **Web**: a "Web application" OAuth client. Authorized JavaScript
///   origins must include `http://localhost:5000` (dev) and the eventual
///   production origin.
///
/// Client IDs are public identifiers and safe to commit. Client *secrets*
/// (only used by the Desktop OAuth flow, which Catchline does not use)
/// must never be committed.
class OAuthConfig {
  const OAuthConfig._();

  /// iOS / macOS OAuth client ID. Bundle: `com.gnarhard.catchline`.
  static const String iosClientId =
      '332621785030-s0lsa46na2vhe9st88b05nkmmnjm6eo2.apps.googleusercontent.com';

  /// Web OAuth client ID. Used in the browser and in `web/index.html`'s
  /// `google-signin-client_id` meta tag.
  static const String webClientId =
      '332621785030-ts1k5v02kt84fts9jjc7akdk854m0dmc.apps.googleusercontent.com';

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
