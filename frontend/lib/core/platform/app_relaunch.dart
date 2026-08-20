import 'dart:io';

/// Relaunch the app process — the only guaranteed-complete way to make a full preference/data reset
/// take effect, since live derived state (theme/zoom/window geometry/shortcuts) is applied at startup
/// and would otherwise linger until the next launch. macOS starts the current bundle executable
/// detached so dev-attach variables such as ANSELM_BACKEND_URL survive the restart; an explicit
/// debug-only ANSELM_RELAUNCH_LOG also keeps the replacement process observable. Elsewhere we exit
/// and the user reopens. Shared by factory reset and «reset local preferences».
///
/// 重启进程——让整套偏好/数据重置彻底生效的唯一可靠手段(缩放/窗口几何/主题/快捷键等派生态在启动时应用,
/// 否则残留到下次启动)。macOS 直接分离启动当前 bundle executable,保留开发接入环境变量;其他平台退出待用户
/// 重开。显式 debug-only 的 `ANSELM_RELAUNCH_LOG` 也让新进程继续可观测。出厂重置与「重置本地偏好」共用。
String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";
Future<void> relaunchApp() async {
  if (Platform.isMacOS) {
    // LaunchServices drops the process environment, which breaks the dev attach path after a reset.
    // The resolved executable is the same bundle binary that launched this process and preserves the
    // environment needed by both the bundled sidecar and ANSELM_BACKEND_URL.
    final executable = Platform.resolvedExecutable;
    final environment = Platform.environment;
    final logPath = environment['ANSELM_RELAUNCH_LOG'];
    if (logPath != null && logPath.isNotEmpty) {
      // Detached children otherwise lose the old process's console sink after the parent exits.
      await Process.start(
        '/bin/sh',
        [
          '-c',
          'exec ${_shellQuote(executable)} >> ${_shellQuote(logPath)} 2>&1',
        ],
        environment: environment,
        mode: ProcessStartMode.detached,
      );
    } else {
      await Process.start(
        executable,
        const [],
        environment: environment,
        mode: ProcessStartMode.detached,
      );
    }
  }
  exit(0);
}
