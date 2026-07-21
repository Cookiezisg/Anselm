import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/model/status_state.dart';
import '../../../core/notice/notice_center.dart';
import '../../../core/settings/app_prefs_providers.dart';
import '../../../core/settings/settings_prefs.dart';
import '../../../i18n/strings.g.dart';
import '../state/update_check_provider.dart';

/// The launch-time update check (拍板 #7): once per app start, only when the General-panel switch is
/// on. Fire-and-forget — an available release surfaces as ONE neutral toast (download lives in
/// About); every failure stays silent (an unreachable GitHub must never nag at launch).
///
/// 启动时更新检查(拍板 #7):每次启动一次、仅当通用面板开关开着。fire-and-forget——有新版=一条中性
/// toast(下载入口在关于页);一切失败保持沉默(GitHub 不可达绝不在启动时烦人)。
class StartupUpdateCheck extends ConsumerStatefulWidget {
  const StartupUpdateCheck({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<StartupUpdateCheck> createState() => _StartupUpdateCheckState();
}

class _StartupUpdateCheckState extends ConsumerState<StartupUpdateCheck> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          !ref.read(boolSettingProvider(SettingsKeys.updateCheck))) {
        return;
      }
      final s = await ref.read(updateCheckProvider.notifier).check();
      if (!mounted || s.outcome != UpdateOutcome.available) return;
      ref
          .read(noticeCenterProvider.notifier)
          .show(
            t.settings.about.updateAvailable(v: s.latest),
            tone: AnTone.none,
          );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
