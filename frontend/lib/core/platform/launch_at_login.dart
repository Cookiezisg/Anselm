import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'host_platform.dart';

/// Launch-at-login (拍板 #15) — the OS registration seam over `launch_at_startup` (macOS
/// SMAppService / Windows registry / Linux autostart; 原则 #8 成熟包). [initLaunchAtLogin] runs once
/// at startup (needs the package name); [applyLaunchAtLogin] flips registration best-effort — the
/// preference key stays the source of truth for the UI, the OS registry for the OS.
/// 开机自启:launch_at_startup 成熟包之上的注册缝。启动时 init 一次;applyLaunchAtLogin best-effort
/// 翻注册——UI 事实源=偏好键,OS 侧事实源=系统注册表。
Future<void> initLaunchAtLogin() async {
  if (!HostPlatform.isDesktop) return;
  try {
    final info = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: info.appName,
      appPath: HostPlatform.executablePath,
    );
  } catch (_) {
    /* best-effort — the switch will no-op 尽力而为 */
  }
}

Future<void> applyLaunchAtLogin(bool enabled) async {
  try {
    enabled ? await launchAtStartup.enable() : await launchAtStartup.disable();
  } catch (_) {
    /* best-effort */
  }
}
