import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/window_setup.dart';
import '../i18n/strings.g.dart';
import 'gallery/gallery_app.dart';

/// Entry for `make gallery` — the component catalog in the real desktop window. Dev-only: no backend.
/// Wrapped in a [ProviderScope] so top-band message / dialog specimens use the same command services
/// as the real app root. 入口:真桌面窗组件目录;顶带消息/确认框 specimen 与真 app 根共用命令服务。
Future<void> main() async {
  // Binding FIRST — useDeviceLocaleSync() reads WidgetsBinding.instance.platformDispatcher, so it
  // throws (→ white window) if called before init. 必须先初始化 binding,否则 useDeviceLocaleSync 抛→白屏。
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocaleSync();
  await initWindow(title: 'Anselm · Gallery');
  // Dev drive-by seams: --dart-define=GALLERY_CAT=<index> opens a category directly (real-machine perf
  // verification navigates without UI scripting). 开发直达缝:GALLERY_CAT 直开类目(真机验证免 UI 脚本)。
  const cat = int.fromEnvironment('GALLERY_CAT');
  runApp(TranslationProvider(child: const ProviderScope(child: GalleryApp(initialCategory: cat))));
}
