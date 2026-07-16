import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/contract/api_error.dart';
import '../../../../core/contract/retention.dart';
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
    // null = not resolved yet — the TYPE carries availability (buttons/factory gate key off it);
    // no '…' sentinel string doubling as a logic value. null=未解析,可用性由类型承载、不设哨兵串。
    final String? dir = ref.watch(dataDirProvider).value;
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
            meta: dir ?? '',
            passive: true,
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnButton(
                label: t.settings.storage.revealFinder,
                size: AnButtonSize.sm,
                onPressed: dir == null ? null : () => _reveal(dir),
              ),
              const SizedBox(width: AnSpace.s8),
              AnButton(
                label: t.settings.storage.openLogs,
                size: AnButtonSize.sm,
                onPressed: dir == null ? null : () => _reveal('$dir/logs'),
              ),
            ]),
          ),
          const SizedBox(height: AnSpace.s12),
          AnSettingRow(
            label: t.settings.storage.diskUsage,
            desc:
                '${t.settings.storage.diskSandbox} · ${t.settings.storage.diskMore}',
            child: SizedBox(
              width: AnSize.ctlSlot,
              child: AnMeter(
                ratio: null,
                // ratio:null already shows indeterminate — no '…' sentinel. 不定态示能已在,免哨兵。
                label: disk == null ? '' : formatBytes(disk),
              ),
            ),
          ),
          const SizedBox(height: AnSpace.s8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AnButton(
              label: t.settings.about.copyDiagnostics,
              size: AnButtonSize.sm,
              onPressed: () => _copyDiagnostics(context, ref, dir ?? ''),
            ),
          ),
        ],
      ),
      const SizedBox(height: AnSpace.s24),
      // ── Run 历史保留 (scheduler 判决④/工单⑬) ──
      // A SECTION-level scope badge, not a page-level one: this panel is MIXED-scope (the data dir is
      // machine-wide, «reset local preferences» is device-local), and S-16 states a page-head badge on
      // a mixed page necessarily lies. 节级域徽而非页级:本面板是**混域**页(数据目录=全机、重置本地偏好=
      // 本机),S-16 明写混域页的页头徽必撒谎。
      AnSection(
        label: t.settings.storage.retention,
        variant: AnSectionVariant.quiet,
        actions: const [AnScopeBadge(AnSettingScope.machine)],
        children: [_RetentionRow()],
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
    ref.read(overlayProvider.notifier).showToast(t.settings.about.copied, tone: AnTone.ok);
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

/// «Run history retention» (scheduler 判决④/工单⑬) — the machine-level line after which settled runs
/// are physically cleared. Four affordances: 30d / 90d / 180d / forever (`0`).
///
/// Two rules this row exists to honour:
///   • **Never hardcode the default.** The wire always answers a concrete number (a fresh install
///     reads back the server-held default), so until it resolves this renders a DISABLED dropdown with
///     no value — never a speculative «90» that a slow read would turn into a lie the user then saves.
///     That is also why there is no `modified`/`onReset` affordance: «is this modified?» needs a
///     client-side default to compare against, and there is no `/retention/schema` to ask.
///   • **Commit on pick, and write back what the server merged.** PATCH is a partial merge returning
///     the merged whole; re-reading through the provider keeps the storage panel and the scheduler's
///     tombstone on one truth.
///
/// 「Run 历史保留」(判决④/⑬):机器级保留线,越线的终态 run 被物理清理。四档 30/90/180/永久(0)。两条规则:
/// ①**永不硬编默认**——线缆恒返具体值(全新安装读回服务端自持的默认),故在读回之前渲**禁用且无值**的下拉,
/// 绝不渲一个会被慢读变成谎、又被用户顺手存下的臆测「90」;这也是本行**没有** modified/onReset 的原因:
/// 「是否已修改」需要一个客户端默认来比对,而 `/retention/schema` 并不存在,无处可问。
/// ②**选中即提交、并拿服务端合并后的值回写**——PATCH 是部分合并返全量;经 provider 重读使存储面板与
/// scheduler 大表墓碑同一份真相。
class _RetentionRow extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RetentionRow> createState() => _RetentionRowState();
}

class _RetentionRowState extends ConsumerState<_RetentionRow> {
  bool _saving = false;

  Future<void> _set(int days) async {
    if (_saving) return;
    setState(() => _saving = true);
    final t = Translations.of(context);
    try {
      await ref.read(settingsRepositoryProvider).patchRetention(days);
      ref.invalidate(retentionConfigProvider);
      ref.read(overlayProvider.notifier).showToast(t.settings.storage.retentionSaved, tone: AnTone.ok);
    } on ApiException catch (e) {
      ref.read(overlayProvider.notifier).showToast(e.message, tone: AnTone.danger);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final cfg = ref.watch(retentionConfigProvider).value;
    return AnSettingRow(
      label: t.settings.storage.retention,
      desc: t.settings.storage.retentionDesc,
      child: SizedBox(
        width: AnSize.ctlSlot,
        child: AnDropdown<int>(
          options: [
            AnDropdownOption(value: 30, label: t.settings.storage.retention30),
            AnDropdownOption(value: 90, label: t.settings.storage.retention90),
            AnDropdownOption(value: 180, label: t.settings.storage.retention180),
            // 0 = keep forever — the sweeper never runs. 0=永久:清理绝不跑。
            AnDropdownOption(value: 0, label: t.settings.storage.retentionForever),
          ],
          // null until the wire answers — the dropdown shows its placeholder rather than a guess.
          // 读回之前为 null——下拉显示占位符,而不是一个猜测。
          value: cfg?.runRetentionDays,
          enabled: cfg != null && !_saving,
          onChanged: _set,
        ),
      ),
    );
  }
}

class _FactoryZone extends ConsumerStatefulWidget {
  const _FactoryZone({required this.dataDir});

  /// null until the backend resolves the data root — the DANGER action's availability rides the
  /// type, never a sentinel string. 后端未解析前为 null:危险动作可用性由类型兜底,绝不判哨兵串。
  final String? dataDir;

  @override
  ConsumerState<_FactoryZone> createState() => _FactoryZoneState();
}

class _FactoryZoneState extends ConsumerState<_FactoryZone> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final dataDir = widget.dataDir;
    return AnTypeToConfirm(
      title: t.settings.storage.factoryTitle,
      warning: t.settings.storage.factoryWarn,
      expected: 'Anselm',
      inputHint: t.settings.storage.factoryHint,
      confirmLabel: t.settings.storage.factoryConfirm,
      busy: _busy || dataDir == null,
      onConfirm: () async {
        if (dataDir == null) return;
        setState(() => _busy = true);
        // No return: stops the sidecar, deletes the tree, relaunches. 不归路:停引擎删树重启。
        await ref.read(factoryResetProvider).run(dataDir: dataDir);
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

/// The machine-level run-history retention line (scheduler 工单⑬). 机器级 run 保留线(⑬)。
final retentionConfigProvider =
    FutureProvider<RetentionConfig>((ref) => ref.watch(settingsRepositoryProvider).getRetention());
