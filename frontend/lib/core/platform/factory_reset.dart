import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../runtime.dart';
import '../settings/settings_prefs.dart';

/// The factory reset choreography (WRK-062 拍板 #12) — FRONTEND-orchestrated (a single-user local
/// app already holds the process + directory handles; no backend destruction endpoint): ① stop the
/// sidecar (its files must be closed before the tree goes), ② delete the data directory, ③ clear
/// the declared local preference set, ④ relaunch (macOS re-opens the bundle; elsewhere we just
/// exit and the user reopens). The double gate (AnTypeToConfirm) lives in the UI.
///
/// 出厂重置编排(拍板 #12)——前端编排(单用户本地 app 本就握有进程与目录权柄,不做后端毁灭端点):
/// ①停 sidecar(删树前文件必须先关)②删数据目录③清声明键集本地偏好④重启(macOS 重开 bundle;
/// 其他平台退出由用户重开)。双闸(输名解锁)在 UI 层。
class FactoryReset {
  FactoryReset(this._ref);

  final Ref _ref;

  Future<void> run({required String dataDir}) async {
    await _ref.read(backendControllerProvider).stop();
    if (dataDir.isNotEmpty) {
      final dir = Directory(dataDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
    await _ref.read(settingsPrefsProvider).resetAll();
    _relaunch();
  }

  void _relaunch() {
    if (Platform.isMacOS) {
      // resolvedExecutable = <bundle>.app/Contents/MacOS/<bin> — walk up to the bundle. 上溯到 bundle。
      final bundle =
          File(Platform.resolvedExecutable).parent.parent.parent.path;
      if (bundle.endsWith('.app')) {
        Process.start('open', ['-n', bundle], mode: ProcessStartMode.detached);
      }
    }
    exit(0);
  }
}

final factoryResetProvider = Provider<FactoryReset>(FactoryReset.new);
