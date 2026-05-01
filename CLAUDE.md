# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

Catchline is an **offline-first** Flutter app for capturing four kinds of personal notes: journal entries, poems, lyrics, and phrases. Each item has a title, a text body, and a list of multiple recorded audio clips. v1 ships on iOS, Android, macOS, and web. Phone is the **primary target** — UI is single-column, phone-sized, with a bottom NavigationBar; desktop and web simply scale the same layout up (with a max-width column on wide screens). The only network calls are user-opt-in: Google Drive sync (after sign-in) and Anthropic API calls for journal synopses + phrase rephrasing (after the user pastes their own API key in Settings). No analytics, no remote fonts, no telemetry.

## Architecture at a glance

- **State**: Riverpod 3.x. `boxesProvider` is overridden at app bootstrap with already-open boxes; `itemsRepoProvider` and `audioRepoProvider` derive from it. `ItemsNotifier` (single notifier holding all items) subscribes to `itemsBox.watch()`; per-kind lists are derived via a small `Provider.family<List<Item>, ItemKind>` filter.
- **Persistence (metadata)**: Hive CE (`hive_ce`, `hive_ce_flutter`, `hive_ce_generator`). One polymorphic `items` Box keyed by UUID. **Do not** use the legacy `hive` / `hive_flutter` packages — they are unmaintained.
- **Persistence (audio bytes)**: split by platform via conditional import in `lib/data/audio_repository.dart`:
  - Native (`audio_repository_io.dart`): clips written as files in `getApplicationDocumentsDirectory()/audio/<clipId>.<ext>`.
  - Web (`audio_repository_web.dart`): clips persisted as `Uint8List` in a `Box<Uint8List>` (IndexedDB); blob URLs are materialized on demand and cached.
- **Recording**: `record` (`AudioEncoder.aacLc`, `.m4a`). On web the browser may produce webm/opus — playback handles both since just_audio's web backend is HTML5 `<audio>`.
- **Playback**: `just_audio` with `setUrl(playableUri)`. URI is `file://...` on native, `blob:...` on web. **No `StreamAudioSource`** — playable URIs are sufficient.
- **Permissions**: `record.hasPermission()` requests at recording time. If denied, a dialog deep-links into settings via `permission_handler`'s `openAppSettings()`.
- **IDs**: UUID v4 strings (`lib/util/id.dart`).
- **Timestamps**: `int millisecondsSinceEpoch` (UTC). Never `DateTime` in Hive — Hive's DateTime serialization is local-time without TZ.

## Code layout

```
lib/
  main.dart                       # ProviderScope bootstrap, opens boxes
  app.dart                        # MaterialApp + theme + HomeShell
  hive_registrar.g.dart           # generated; Hive.registerAdapters() extension
  theme/app_theme.dart            # deepPurple Material 3 seed, light + dark
  data/
    models/{item,item_kind,audio_clip_meta}.dart    # @HiveType, with .g.dart adapters
    boxes.dart                    # openBoxes() — Hive.initFlutter + adapter registration
    items_repository.dart
    app_settings_repository.dart  # phrase styles list (Hive Box<dynamic>)
    secure_settings.dart          # Anthropic API key (flutter_secure_storage; Keychain/Keystore/DPAPI/libsecret)
    ai_service.dart               # Anthropic Messages API client (sonnet)
    audio_repository.dart         # abstract interface + factory
    audio_repository_io.dart      # native impl
    audio_repository_web.dart     # web impl
  state/
    providers.dart                # boxesProvider, itemsRepoProvider, audioRepoProvider
    items_notifier.dart           # ItemsNotifier + itemsByKindProvider family
  features/
    home/home_shell.dart          # NavigationBar with 4 destinations
    items/
      item_list_screen.dart
      item_edit_screen.dart       # title, body, audio clips; PopScope dirty guard
      widgets/{item_tile,empty_state,audio_recorder,audio_clip_tile}.dart
  util/{id,text_preview}.dart
```

Hive typeIds reserved: `0=ItemKind`, `1=AudioClipMeta`, `2=Item`, `3=AiFavorite`. Never reuse a removed `@HiveField` number — bump to a new one when evolving the schema.

## Critical native config

- Bundle ID: `com.gnarhard.catchline` (Android `applicationId` + `namespace`, iOS + macOS `PRODUCT_BUNDLE_IDENTIFIER`).
- iOS + macOS Info.plist both have `NSMicrophoneUsageDescription`.
- Android Manifest has `<uses-permission android:name="android.permission.RECORD_AUDIO" />`.
- macOS DebugProfile + Release entitlements both have `com.apple.security.device.audio-input`.

## Tooling: prefer the dart MCP server

Per the `dart` MCP server instructions, **prefer its tools over raw shell commands** for Dart/Flutter work:

- `mcp__dart__add_roots` — call once at the start of every session with this project's path.
- `mcp__dart__pub` — instead of `flutter pub get` / `flutter pub add`.
- `mcp__dart__analyze_files` — instead of `flutter analyze`.
- `mcp__dart__dart_format` / `mcp__dart__dart_fix` — instead of the shell equivalents.
- `mcp__dart__run_tests` — instead of `flutter test`.
- `mcp__dart__launch_app` / `list_devices` / `hot_reload` / `hot_restart` / `stop_app` — for running the app.
- `mcp__dart__get_app_logs` / `get_runtime_errors` — for inspecting a running app.
- `mcp__dart__pub_dev_search` — when evaluating a package.

Fall back to shell `flutter`/`dart` only if an MCP tool can't express what you need.

After model changes (`@HiveType`/`@HiveField`), regenerate adapters:

```
dart run build_runner build --delete-conflicting-outputs
```

(There's no MCP wrapper for build_runner; this one needs the shell.)

## Lints

`analysis_options.yaml` excludes `**/*.g.dart` and includes `package:flutter_lints/flutter.yaml`. Don't loosen the lint set — prefer per-line `// ignore:` if you must suppress.

## Testing

**Every feature must ship with unit tests.** Scope is unit tests only at this stage — no widget tests, no integration tests yet. Cover the feature's logic (repositories, notifiers, services, pure functions); skip pure UI wiring. Tests live under `test/` mirroring `lib/` (e.g. `lib/data/items_repository.dart` → `test/data/items_repository_test.dart`). Run via `mcp__dart__run_tests`. A feature is not done until its tests pass.

**Tests gate "done".** Before declaring any code change complete — feature, bug fix, or refactor — you must (1) update existing tests the change affects, (2) add new tests for any new logic, and (3) run the full suite via `mcp__dart__run_tests` and confirm it is green. Never report a task complete with failing or missing tests.

## Memory policy

Do not write to the persistent memory system for this project. CLAUDE.md is the single source of truth for project context, conventions, and behavioral rules. If something is worth remembering across sessions, propose adding it here instead of saving a memory file.

## Web dev

`getUserMedia` requires a secure context — use localhost (e.g., `flutter run -d chrome --web-port=5000`) or HTTPS. Pin the dev port so IndexedDB origin is stable across sessions and clips persist between runs.
