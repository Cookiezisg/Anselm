import 'dart:io' as io;

/// A thin seam over the host-OS check, so UI primitives and tests express platform intent
/// through one vocabulary instead of reaching into `dart:io` everywhere. Keeping the import
/// in a single place also means the desktop/test split is trivial to stub if we ever need to.
///
/// 宿主 OS 判定的薄缝:UI 原语与测试经此统一表达平台意图,不再到处直接 import dart:io;
/// 单点收口也让将来要 stub 桌面/测试分支变得轻而易举。
abstract final class HostPlatform {
  static bool get isMacOS => io.Platform.isMacOS;
  static bool get isWindows => io.Platform.isWindows;
  static bool get isLinux => io.Platform.isLinux;
}
