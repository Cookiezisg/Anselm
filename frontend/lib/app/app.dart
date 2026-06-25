import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design/theme.dart';
import '../core/overlay/an_overlay.dart';
import '../core/platform/window_zoom.dart';
import '../core/ui/an_shell.dart';
import '../i18n/strings.g.dart';
import 'app_startup_gate.dart';

/// The root widget — wires the theme onto a MaterialApp whose `home` is the three-island shell and
/// whose `builder` wraps the navigator in an [AnOverlayHost] (the assembly-root layer that holds the
/// toast stack + registers the root navigator so [AnOverlayController.confirm] can push dialogs). The
/// host needs a stable `GlobalKey<NavigatorState>` (shared with `MaterialApp.navigatorKey`), so this is
/// a StatefulWidget. App-wide UI zoom shortcuts (Cmd +/-/0) bind via [CallbackShortcuts]; an autofocused
/// [Focus] makes them live from launch. Kept deliberately thin: assembly (DI overrides, routing,
/// sidecar lifecycle) accretes here as features land.
///
/// 根 widget——主题接到 MaterialApp,home=三岛 shell,builder 把 navigator 包进 AnOverlayHost(装配根浮层层:托 toast
/// 栈 + 注册 root navigator 供 confirm push)。host 需稳定的 `GlobalKey<NavigatorState>`(与 MaterialApp.navigatorKey 共用),
/// 故 StatefulWidget。应内缩放快捷键经 CallbackShortcuts 绑定,autofocus Focus 开机即生效。刻意薄。
class AnApp extends StatefulWidget {
  const AnApp({super.key});

  @override
  State<AnApp> createState() => _AnAppState();
}

class _AnAppState extends State<AnApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: context.t.appName,
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      navigatorKey: _navigatorKey,
      // The startup gate sits BETWEEN the navigator's home and the shell: while the sidecar backend
      // connects it shows a connecting/crashed screen; once ready it reveals the shell. The zoom
      // shortcuts + autofocus stay wrapped inside (live once the shell shows). 启动门控在 home 与壳之间。
      home: AppStartupGate(
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.equal, meta: true): WindowZoom.zoomIn,
            const SingleActivator(LogicalKeyboardKey.equal, meta: true, shift: true): WindowZoom.zoomIn,
            const SingleActivator(LogicalKeyboardKey.minus, meta: true): WindowZoom.zoomOut,
            const SingleActivator(LogicalKeyboardKey.digit0, meta: true): WindowZoom.reset,
          },
          child: const Focus(autofocus: true, child: AnShell()),
        ),
      ),
      builder: (context, child) => AnOverlayHost(navigatorKey: _navigatorKey, child: child!),
    );
  }
}
