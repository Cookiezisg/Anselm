import 'package:flutter/services.dart';

import 'host_platform.dart';

/// The one macOS-only bridge for native accessibility facts Flutter's desktop embedder drops.
/// 仅补 macOS Flutter embedder 丢失的原生 AX 字段名,不承载输入或业务状态。
abstract final class NativeAccessibility {
  static const _channel = MethodChannel('app/accessibility');

  static Future<void> setFocusedTextFieldLabel(String? label) async {
    if (!HostPlatform.isMacOS) return;
    try {
      await _channel.invokeMethod<void>(
        'setFocusedTextFieldLabel',
        <String, Object?>{'label': label},
      );
    } on MissingPluginException {
      // Widget tests and non-Runner hosts have no native half; the Flutter semantics tree remains intact.
    } on PlatformException {
      // Native accessibility supplements the named affordance and transition announcement.
    }
  }
}
