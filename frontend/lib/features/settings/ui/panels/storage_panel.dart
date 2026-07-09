import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/model/byte_format.dart';
import '../../../../core/platform/app_relaunch.dart';
import '../../../../core/platform/factory_reset.dart';
import '../../../../core/runtime.dart';
import '../../../../core/settings/settings_prefs.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/settings_repository.dart';

/// ⑨ 存储与日志 (WRK-062 §3, S5): the backend-resolved data directory (read-only + reveal), the
/// sandbox disk figure, the logs folder, copy-diagnostics, the local-preferences reset (declared
/// set only — never workspace data), and the FACTORY RESET (拍板 #12: type-to-confirm double gate →
/// stop sidecar → delete the data tree → relaunch; frontend-orchestrated).
///
/// 存储与日志:数据目录(只读+访达)/沙箱磁盘/日志文件夹/诊断复制/重置本地偏好(声明集,绝不碰工作区
/// 数据)/**出厂重置**(拍板 #12:输名双闸→停 sidecar→删数据树→重启,前端编排)。
class StoragePanel extends ConsumerWidget {
  const StoragePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final dir = ref.watch(dataDirProvider).value ?? '…';
    final disk = ref.watch(sandboxDiskProvider).value;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnSection(
        label: t.settings.panels.storage,
        variant: AnSectionVariant.quiet,
        children: [
          AnRow(
            leadless: true,
            label: t.settings.storage.dataDir,
            mono: true,
            meta: dir,
            passive: true,
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnButton(
                label: t.settings.storage.revealFinder,
                size: AnButtonSize.sm,
                onPressed: dir == '…' ? null : () => _reveal(dir),
              ),
              const SizedBox(width: AnSpace.s8),
              AnButton(
                label: t.settings.storage.openLogs,
                size: AnButtonSize.sm,
                onPressed: dir == '…' ? null : () => _reveal('$dir/logs'),
              ),
            ]),
          ),
          const SizedBox(height: AnSpace.s12),
          AnSettingRow(
            label: t.settings.storage.diskUsage,
            desc:
                '${t.settings.storage.diskSandbox} · ${t.settings.storage.diskMore}',
            child: SizedBox(
              width: 240,
              child: AnMeter(
                ratio: null,
                label: disk == null ? '…' : formatBytes(disk),
              ),
            ),
          ),
          const SizedBox(height: AnSpace.s8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AnButton(
              label: t.settings.about.copyDiagnostics,
              size: AnButtonSize.sm,
              onPressed: () => _copyDiagnostics(context, ref, dir),
            ),
          ),
        ],
      ),
      const SizedBox(height: AnSpace.s24),
      AnSettingRow(
        label: t.settings.storage.resetPrefs,
        desc: t.settings.storage.resetPrefsDesc,
        child: AnButton(
          label: t.settings.storage.resetPrefs,
          size: AnButtonSize.sm,
          variant: AnButtonVariant.danger,
          onPressed: () => _resetPrefs(context, ref),
        ),
      ),
      const SizedBox(height: AnSpace.s32),
      _FactoryZone(dataDir: dir),
    ]);
  }

  void _reveal(String path) {
    if (Platform.isMacOS) Process.run('open', [path]);
  }

  Future<void> _copyDiagnostics(BuildContext context, WidgetRef ref, String dir) async {
    final t = Translations.of(context);
    final app = (await PackageInfo.fromPlatform()).version;
    String engine = '';
    try {
      engine = await ref.read(settingsRepositoryProvider).backendVersion();
    } catch (_) {}
    final backend = ref.read(backendStartupProvider);
    final text = 'Anselm $app · engine $engine · ${Platform.operatingSystem} '
        '${Platform.operatingSystemVersion} · data $dir · ${backend.baseUrl ?? 'backend down'}';
    await Clipboard.setData(ClipboardData(text: text));
    ref.read(overlayProvider.notifier).showToast(t.settings.about.copied, tone: AnToastTone.ok);
  }

  Future<void> _resetPrefs(BuildContext context, WidgetRef ref) async {
    final t = Translations.of(context);
    final ok = await ref.read(overlayProvider.notifier).confirm(
          title: t.settings.storage.resetPrefsTitle,
          message: t.settings.storage.resetPrefsDesc,
          confirmLabel: t.settings.storage.resetPrefs,
          cancelLabel: t.settings.keys.cancel,
          barrierLabel: t.settings.storage.resetPrefsTitle,
        );
    if (!ok) return;
    await ref.read(settingsPrefsProvider).resetAll();
    // Relaunch so every startup-applied derived value (theme / zoom / window geometry / shortcuts)
    // actually reverts — an in-place invalidate would leave those live values stale until restart, so
    // the reset would look like it did nothing. 重启使启动时应用的派生态(主题/缩放/窗口/快捷键)真回退。
    relaunchApp();
  }
}

class _FactoryZone extends ConsumerStatefulWidget {
  const _FactoryZone({required this.dataDir});

  final String dataDir;

  @override
  ConsumerState<_FactoryZone> createState() => _FactoryZoneState();
}

class _FactoryZoneState extends ConsumerState<_FactoryZone> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return AnTypeToConfirm(
      title: t.settings.storage.factoryTitle,
      warning: t.settings.storage.factoryWarn,
      expected: 'Anselm',
      inputHint: t.settings.storage.factoryHint,
      confirmLabel: t.settings.storage.factoryConfirm,
      busy: _busy || widget.dataDir == '…',
      onConfirm: () async {
        setState(() => _busy = true);
        // No return: stops the sidecar, deletes the tree, relaunches. 不归路:停引擎删树重启。
        await ref.read(factoryResetProvider).run(dataDir: widget.dataDir);
      },
    );
  }
}

/// Backend-resolved data root. 后端解析数据根。
final dataDirProvider =
    FutureProvider<String>((ref) => ref.watch(settingsRepositoryProvider).dataDir());

/// Machine-wide sandbox usage — refetched each panel open. 全机沙箱占用;每次打开重取。
final sandboxDiskProvider = FutureProvider.autoDispose<int>(
    (ref) => ref.watch(settingsRepositoryProvider).sandboxDiskUsage());
