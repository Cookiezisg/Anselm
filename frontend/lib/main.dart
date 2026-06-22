import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scaled_app/scaled_app.dart';

import 'app/app.dart';
import 'app/window_setup.dart';
import 'core/platform/window_zoom.dart';

/// Entry point. The scaled_app binding enables app-wide UI zoom (Cmd +/-): its scaleFactor reads
/// [WindowZoom.factor], so the whole tree reflows at the zoom level. Then configure the desktop
/// window, restore the persisted zoom before the first frame, and run under the assembly-root
/// [ProviderScope].
/// 入口:scaled_app binding 启用应内 UI 缩放(Cmd +/-);配窗口 → 首帧前恢复持久化缩放 → ProviderScope 起 app。
Future<void> main() async {
  ScaledWidgetsFlutterBinding.ensureInitialized(scaleFactor: WindowZoom.scaleFactorCallback);
  await initWindow();
  await WindowZoom.restore();
  runApp(const ProviderScope(child: AnApp()));
}
