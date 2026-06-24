import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/window_setup.dart';
import '../i18n/strings.g.dart';
import 'gallery/gallery_app.dart';

/// Entry for `make gallery` — the component catalog in the real desktop window. Dev-only: no backend.
/// Wrapped in a [ProviderScope] (G6 onward) so the overlay specimens can `ref.read(overlayProvider)` to
/// fire toasts / confirm dialogs, mirroring the real app root (main.dart). 入口:真桌面窗组件目录。dev-only、无后端;
/// G6 起裹 ProviderScope(浮层 specimen 经 ref.read(overlayProvider) 弹 toast/dialog,与真 app 根一致)。
Future<void> main() async {
  // Binding FIRST — useDeviceLocaleSync() reads WidgetsBinding.instance.platformDispatcher, so it
  // throws (→ white window) if called before init. 必须先初始化 binding,否则 useDeviceLocaleSync 抛→白屏。
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocaleSync();
  await initWindow(title: 'Anselm · Gallery');
  runApp(TranslationProvider(child: const ProviderScope(child: GalleryApp())));
}
