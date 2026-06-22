import 'package:flutter/widgets.dart';

import '../app/window_setup.dart';
import '../i18n/strings.g.dart';
import 'gallery/gallery_app.dart';

/// Entry for `make gallery` — the component catalog in the real desktop window. Dev-only: no
/// backend, no ProviderScope; just the kit on display for fidelity review against the demo.
/// `make gallery` 入口——真桌面窗里的组件目录。dev-only:无后端、无 ProviderScope,纯套件陈列。
Future<void> main() async {
  // Binding FIRST — useDeviceLocaleSync() reads WidgetsBinding.instance.platformDispatcher, so it
  // throws (→ white window) if called before init. 必须先初始化 binding,否则 useDeviceLocaleSync 抛→白屏。
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocaleSync();
  await initWindow(title: 'Anselm · Gallery');
  runApp(TranslationProvider(child: const GalleryApp()));
}
