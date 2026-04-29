import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/boxes.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final boxes = await openBoxes();
  runApp(
    ProviderScope(
      overrides: [boxesProvider.overrideWithValue(boxes)],
      child: const CatchlineApp(),
    ),
  );
}
