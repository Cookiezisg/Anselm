import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design/theme.dart';
import '../core/platform/window_zoom.dart';
import '../core/ui/an_shell.dart';

/// The root widget — wires the theme onto a MaterialApp whose home is the three-island shell.
/// App-wide UI zoom shortcuts (Cmd +/-/0) are bound here via [CallbackShortcuts]; an autofocused
/// [Focus] makes them live from launch (they keep working once any descendant — e.g. a text
/// field — holds focus, since CallbackShortcuts is its ancestor). Kept deliberately thin:
/// assembly (DI overrides, routing, sidecar lifecycle) accretes here as features land.
///
/// 根 widget——主题接到 MaterialApp,home=三岛 shell。应内缩放快捷键(Cmd +/-/0)在此经 CallbackShortcuts
/// 绑定;autofocus 的 Focus 让其开机即生效(后续子节点取焦也照常,因 CallbackShortcuts 是其祖先)。刻意薄。
class AnApp extends StatelessWidget {
  const AnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anselm',
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.equal, meta: true): WindowZoom.zoomIn,
          const SingleActivator(LogicalKeyboardKey.equal, meta: true, shift: true): WindowZoom.zoomIn,
          const SingleActivator(LogicalKeyboardKey.minus, meta: true): WindowZoom.zoomOut,
          const SingleActivator(LogicalKeyboardKey.digit0, meta: true): WindowZoom.reset,
        },
        child: const Focus(autofocus: true, child: AnShell()),
      ),
    );
  }
}
