import 'dart:io';

/// Relaunch the app process — the only guaranteed-complete way to make a full preference/data reset
/// take effect, since live derived state (theme/zoom/window geometry/shortcuts) is applied at startup
/// and would otherwise linger until the next launch. macOS asks LaunchServices for a new bundle
/// instance; elsewhere we exit and the user reopens. Shared by factory reset and «reset local
/// preferences».
///
/// 重启进程——让整套偏好/数据重置彻底生效的唯一可靠手段(缩放/窗口几何/主题/快捷键等派生态在启动时应用,
/// 否则残留到下次启动)。macOS 交给 LaunchServices 新开 bundle 实例;其他平台退出待用户重开。
/// 出厂重置与「重置本地偏好」共用。
Future<void> relaunchApp() async {
  if (Platform.isMacOS) {
    // LaunchServices owns macOS app-instance semantics. Starting the executable directly from the
    // exiting process is not equivalent: AppKit may treat it as a duplicate and terminate both.
    final executable = Platform.resolvedExecutable;
    final bundle = File(executable).parent.parent.parent.path;
    if (bundle.endsWith('.app')) {
      await Process.start('open', [
        '-n',
        bundle,
      ], mode: ProcessStartMode.detached);
    }
  }
  exit(0);
}
