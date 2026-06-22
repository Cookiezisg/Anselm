import 'package:flutter/material.dart';

import '../app/window_setup.dart';
import '../core/design/theme.dart';
import 'gallery_page.dart';

/// Standalone entrypoint for the design gallery — bypasses the sidecar/backend health gate
/// so the visual language can be reviewed with ZERO backend running:
///   cd frontend && flutter run -t lib/dev/gallery_main.dart -d macos
/// 设计画廊的独立入口——绕过 sidecar/后端健康门控,零后端即可验收视觉语言。
Future<void> main() async {
  await initWindow(title: 'Anselm · Gallery');
  runApp(const _GalleryApp());
}

class _GalleryApp extends StatelessWidget {
  const _GalleryApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Anselm · Gallery',
      theme: AnTheme.light(),
      darkTheme: AnTheme.dark(),
      themeMode: ThemeMode.light,
      home: const GalleryPage(),
    );
  }
}
