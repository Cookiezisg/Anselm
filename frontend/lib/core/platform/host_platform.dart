import 'dart:io' as io;

/// A thin seam over the host-OS check, so UI primitives and tests express platform intent
/// through one vocabulary instead of reaching into `dart:io` everywhere. Funnelling it through
/// one place also keeps the desktop/test split trivial to stub.
///
/// 宿主 OS 判定的薄缝:UI 与测试经此统一表达平台意图,不再到处 import dart:io;单点收口便于 stub。
abstract final class HostPlatform {
  static bool get isMacOS => io.Platform.isMacOS;
  static bool get isWindows => io.Platform.isWindows;
  static bool get isLinux => io.Platform.isLinux;
  static bool get isDesktop => isMacOS || isWindows || isLinux;

  /// The running executable's path (launch-at-login registration). 可执行文件路径(自启注册用)。
  static String get executablePath => io.Platform.resolvedExecutable;
}
