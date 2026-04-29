import 'package:flutter/material.dart';

import 'features/home/home_shell.dart';
import 'theme/app_theme.dart';

class CatchlineApp extends StatelessWidget {
  const CatchlineApp({super.key});

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
