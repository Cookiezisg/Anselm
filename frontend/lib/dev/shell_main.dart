import 'package:flutter/material.dart';

import '../core/design/theme.dart';
import 'shell_demo.dart';

/// Standalone entry for the three-island shell mock — zero backend:
///   cd frontend && flutter run -t lib/dev/shell_main.dart -d macos
/// 三岛 shell mock 的独立入口——零后端。
void main() => runApp(const _ShellApp());

class _ShellApp extends StatelessWidget {
  const _ShellApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Anselm · Shell',
      theme: AnTheme.light(),
      darkTheme: AnTheme.dark(),
      themeMode: ThemeMode.light,
      home: const ShellDemo(),
    );
  }
}
