import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_shell.dart';
import 'state/providers.dart';
import 'state/sync_providers.dart';
import 'theme/app_theme.dart';

class CatchlineApp extends ConsumerStatefulWidget {
  const CatchlineApp({super.key});

  @override
  ConsumerState<CatchlineApp> createState() => _CatchlineAppState();
}

class _CatchlineAppState extends ConsumerState<CatchlineApp> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<dynamic>? _itemsBoxSub;
  Timer? _webDebounce;

  @override
  void initState() {
    super.initState();

    _lifecycle = AppLifecycleListener(onResume: _onResume, onPause: _onPause);

    // Init Google sign-in and try silent restore. After a successful restore
    // the account stream emits and any signed-in path runs an initial sync.
    // Swallow errors here: in unit tests there's no platform plugin, and a
    // malformed OAuth config should not block the rest of the app.
    Future<void>.microtask(() async {
      try {
        await ref.read(googleAuthProvider).initialize();
      } catch (e, st) {
        debugPrint('Google sign-in init failed: $e\n$st');
        return;
      }
      if (!mounted) return;
      if (ref.read(googleAuthProvider).currentAccount != null) {
        ref.read(syncServiceProvider).syncNow();
      }
    });

    if (kIsWeb) {
      // Browsers may kill the page before pause-time async work flushes.
      // Mirror the close-sync via a debounced post-write sync so changes
      // reach Drive within a couple seconds of the last edit.
      _itemsBoxSub = ref.read(boxesProvider).items.watch().listen((_) {
        _webDebounce?.cancel();
        _webDebounce = Timer(const Duration(seconds: 2), () {
          if (ref.read(googleAuthProvider).currentAccount == null) return;
          ref.read(syncServiceProvider).syncNow();
        });
      });
    }
  }

  void _onResume() {
    if (ref.read(googleAuthProvider).currentAccount == null) return;
    ref.read(syncServiceProvider).syncNow();
  }

  void _onPause() {
    if (kIsWeb) return; // web uses the debounced post-write sync instead.
    if (ref.read(googleAuthProvider).currentAccount == null) return;
    ref.read(syncServiceProvider).syncNow();
  }

  @override
  void dispose() {
    _webDebounce?.cancel();
    _itemsBoxSub?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catchline',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: const HomeShell(),
    );
  }
}
