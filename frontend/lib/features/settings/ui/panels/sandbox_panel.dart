import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/api_error.dart';
import '../../../../core/contract/sandbox.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/model/byte_format.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/settings_repository.dart';
import '../../state/sandbox_providers.dart';
import '../../state/settings_detail_provider.dart';
import '../panels/storage_panel.dart' show sandboxDiskProvider;

/// ⑦ 沙箱 (WRK-062 §3, S5): the bootstrap health gate, the machine-wide runtime list (install /
/// delete, 409-in-use honest), the per-owner env tabs (five owner kinds), the disk figure and GC.
/// Everything is a resting row with hover actions — no config hidden behind chrome.
///
/// 沙箱面板:引导健康门+全机运行时(装/删,409 引用诚实)+五 owner 环境 tab+磁盘+GC。
class SandboxPanel extends ConsumerWidget {
  const SandboxPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(settingsDetailProvider)?.kind == 'sandboxInstall') {
      return const _InstallForm();
    }
    final t = Translations.of(context);
    final boot = ref.watch(sandboxBootstrapProvider).value;
    final runtimes = ref.watch(sandboxRuntimesProvider).value ?? const <SandboxRuntime>[];
    final disk = ref.watch(sandboxDiskProvider).value;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (boot != null && !boot.ok)
        // The failure banner is the callout family's job (WRK-066 A-084) — no hand-rolled shell.
        // 失败横幅归 callout 族(A-084),不手搓壳。
        AnCallout(
          '${t.settings.sandbox.bootstrapFail} · ${boot.error ?? ''}',
          severity: AnCalloutSeverity.danger,
          actions: [
            AnButton(
              label: t.settings.sandbox.retry,
              size: AnButtonSize.sm,
              onPressed: () async {
                await ref.read(settingsRepositoryProvider).retrySandboxBootstrap();
                ref.invalidate(sandboxBootstrapProvider);
              },
            ),
          ],
        ),
      // Disk. 磁盘。
      AnSettingRow(
        label: t.settings.sandbox.disk,
        child: SizedBox(
          width: 240,
          child: AnMeter(ratio: null, label: disk == null ? '…' : formatBytes(disk)),
        ),
      ),
      const SizedBox(height: AnSpace.s16),
      // Runtimes. 运行时。
      AnSection(
        label: t.settings.sandbox.runtimes,
        variant: AnSectionVariant.quiet,
        actions: [
          const AnScopeBadge(AnSettingScope.machine),
          const SizedBox(width: AnSpace.s8),
          AnButton(
            label: t.settings.sandbox.install,
            icon: AnIcons.plus,
            size: AnButtonSize.sm,
            onPressed: () => ref.read(settingsDetailProvider.notifier).push('sandboxInstall'),
          ),
        ],
        children: [
          if (runtimes.isEmpty)
            AnState(
              kind: AnStateKind.empty,
              title: t.settings.sandbox.noRuntimes,
              hint: t.settings.sandbox.noRuntimesHint,
              size: AnStateSize.inset,
            )
          else
            for (final r in runtimes)
              AnRow(
                leadless: true,
                label: '${r.kind} ${r.version}',
                mono: true,
                meta: formatBytes(r.sizeBytes),
                actions: [
                  AnButton(
                    label: t.settings.sandbox.delete,
                    size: AnButtonSize.sm,
                    variant: AnButtonVariant.danger,
                    onPressed: () => _deleteRuntime(context, ref, r),
                  ),
                ],
              ),
        ],
      ),
      // Envs — five owner tabs; the section rhythm belongs to AnSection like every other section
      // on this panel (批6 A-064 — the lone hand-rolled readingH3 head + s24 spacers retire; the
      // 360 magic stays on the B-track ledger). 环境五 owner tab;节律归 AnSection(孤例手搓头+手排
      // spacer 退役;360 魔数留 B 轨)。
      AnSection(
          label: t.settings.sandbox.envs,
          variant: AnSectionVariant.quiet,
          children: [SizedBox(height: 360, child: _EnvTabs())]),
      _GcZone(),
    ]);
  }

  Future<void> _deleteRuntime(BuildContext context, WidgetRef ref, SandboxRuntime r) async {
    final t = Translations.of(context);
    final ok = await ref.read(overlayProvider.notifier).confirm(
          title: t.settings.sandbox.deleteRtTitle,
          message: t.settings.sandbox.deleteRtBody(kind: r.kind, version: r.version),
          confirmLabel: t.settings.sandbox.confirmDelete,
          cancelLabel: t.settings.keys.cancel,
          barrierLabel: t.settings.sandbox.deleteRtTitle,
        );
    if (!ok) return;
    try {
      await ref.read(sandboxRuntimesProvider.notifier).remove(r.id);
    } on ApiException catch (e) {
      final msg = e.code == 'SANDBOX_ENV_IN_USE' ? t.settings.sandbox.inUse : e.message;
      ref.read(overlayProvider.notifier).showToast(msg, tone: AnToastTone.danger);
    }
  }
}

/// The pushed-in runtime install form — kind dropdown + version (pinned→dropdown, else free input).
/// 推入安装表单:类型下拉+版本(pinned 下拉/否则自由输入)。
class _InstallForm extends ConsumerStatefulWidget {
  const _InstallForm();

  @override
  ConsumerState<_InstallForm> createState() => _InstallFormState();
}

class _InstallFormState extends ConsumerState<_InstallForm> {
  String? _kind;
  String _version = '';
  final _freeVersion = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _freeVersion.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _kind == null || _version.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sandboxRuntimesProvider.notifier).install(kind: _kind!, version: _version);
      if (mounted) ref.read(settingsDetailProvider.notifier).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final avail = ref.watch(sandboxAvailableProvider).value ?? const <RuntimeAvailability>[];
    if (avail.isEmpty) {
      return Text('…', style: AnText.label.copyWith(color: c.inkFaint));
    }
    _kind ??= avail.first.kind;
    final sel = avail.firstWhere((a) => a.kind == _kind, orElse: () => avail.first);
    if (_version.isEmpty) _version = sel.defaultVersion;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnFormField(label: t.settings.sandbox.kind, child: AnDropdown<String>(
          value: _kind,
          options: [for (final a in avail) AnDropdownOption(value: a.kind, label: a.kind)],
          onChanged: (v) => setState(() {
            _kind = v;
            _version = avail.firstWhere((a) => a.kind == v).defaultVersion;
          }),
        )),
        const SizedBox(height: AnSpace.s12),
        // The conditional subtrees (pinned dropdown ↔ free input) stay structurally identical to
        // today — same shell both branches (scout 风险注记). 条件子树两分支同壳。
        AnFormField(
          label: t.settings.sandbox.version,
          child: sel.pinned
              ? AnDropdown<String>(
                  value: sel.versions.contains(_version) ? _version : sel.versions.firstOrNull,
                  options: [for (final v in sel.versions) AnDropdownOption(value: v, label: v)],
                  onChanged: (v) => setState(() => _version = v),
                )
              : AnInput(
                  controller: _freeVersion..text = _freeVersion.text.isEmpty ? _version : _freeVersion.text,
                  placeholder: t.settings.sandbox.versionHint,
                  onChanged: (v) => _version = v.trim(),
                ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AnSpace.s8),
          Text(_error!, style: AnText.label.copyWith(color: c.danger)),
        ],
        const SizedBox(height: AnSpace.s16),
        Row(children: [
          AnButton(
            label: _busy ? t.settings.sandbox.installing : t.settings.sandbox.add,
            variant: AnButtonVariant.primary,
            onPressed: _busy ? null : _submit,
          ),
          const SizedBox(width: AnSpace.s8),
          AnButton(
            label: t.settings.keys.cancel,
            onPressed: () => ref.read(settingsDetailProvider.notifier).pop(),
          ),
        ]),
      ]),
    );
  }
}

class _EnvTabs extends ConsumerStatefulWidget {
  @override
  ConsumerState<_EnvTabs> createState() => _EnvTabsState();
}

class _EnvTabsState extends ConsumerState<_EnvTabs> {
  String _tab = 'function';

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return AnTabs(
      value: _tab,
      onSelect: (k) => setState(() => _tab = k),
      items: [
        AnTabsItem(key: 'function', label: t.settings.sandbox.ownerFunction, pane: _EnvList(ownerKind: 'function')),
        AnTabsItem(key: 'handler', label: t.settings.sandbox.ownerHandler, pane: _EnvList(ownerKind: 'handler')),
        AnTabsItem(key: 'mcp', label: t.settings.sandbox.ownerMcp, pane: _EnvList(ownerKind: 'mcp')),
        AnTabsItem(key: 'skill', label: t.settings.sandbox.ownerSkill, pane: _EnvList(ownerKind: 'skill')),
        AnTabsItem(
            key: 'conversation',
            label: t.settings.sandbox.ownerConversation,
            pane: _EnvList(ownerKind: 'conversation')),
      ],
    );
  }
}

class _EnvList extends ConsumerWidget {
  const _EnvList({required this.ownerKind});

  final String ownerKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final c = context.colors;
    final envs = ref.watch(sandboxEnvsProvider(ownerKind)).value;
    if (envs == null || envs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AnSpace.s16),
        child: Text(t.settings.sandbox.noEnvs, style: AnText.label.copyWith(color: c.inkFaint)),
      );
    }
    return ListView(
      children: [
        const SizedBox(height: AnSpace.s8),
        for (final e in envs)
          AnRow(
            dot: switch (e.status) {
              'ready' => AnStatus.done,
              'failed' => AnStatus.err,
              _ => AnStatus.run,
            },
            label: e.ownerName.isEmpty ? e.ownerId : e.ownerName,
            meta:
                '${e.deps.length} deps · ${formatBytes(e.sizeBytes)}${(e.runningPid ?? 0) > 0 ? ' · ${t.settings.sandbox.running}' : ''}',
            actions: [
              AnButton(
                label: t.settings.sandbox.delete,
                size: AnButtonSize.sm,
                variant: AnButtonVariant.danger,
                onPressed: () => _delete(context, ref, e),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SandboxEnv e) async {
    final t = Translations.of(context);
    final ok = await ref.read(overlayProvider.notifier).confirm(
          title: t.settings.sandbox.deleteEnvTitle,
          message: '${t.settings.sandbox.deleteEnvBody} ${t.settings.sandbox.envRebuild}',
          confirmLabel: t.settings.sandbox.confirmDelete,
          cancelLabel: t.settings.keys.cancel,
          barrierLabel: t.settings.sandbox.deleteEnvTitle,
        );
    if (!ok) return;
    try {
      await ref.read(settingsRepositoryProvider).deleteEnv(e.id);
      ref.invalidate(sandboxEnvsProvider(ownerKind));
    } on ApiException catch (err) {
      ref.read(overlayProvider.notifier).showToast(err.message, tone: AnToastTone.danger);
    }
  }
}

class _GcZone extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GcZone> createState() => _GcZoneState();
}

class _GcZoneState extends ConsumerState<_GcZone> {
  final _days = TextEditingController(text: '30');

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  Future<void> _gc(int days) async {
    final t = Translations.of(context);
    final n = await ref.read(settingsRepositoryProvider).sandboxGc(days);
    ref.invalidate(sandboxEnvsProvider);
    ref.read(overlayProvider.notifier).showToast(t.settings.sandbox.gcDone(n: n), tone: AnToastTone.ok);
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnSettingRow(
        label: t.settings.sandbox.gc,
        desc: t.settings.sandbox.gcDays,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 90, child: AnInput(controller: _days, mono: true)),
          const SizedBox(width: AnSpace.s8),
          AnButton(
            label: t.settings.sandbox.gcRun,
            size: AnButtonSize.sm,
            onPressed: () => _gc(int.tryParse(_days.text.trim()) ?? 30),
          ),
        ]),
      ),
      const SizedBox(height: AnSpace.s16),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: AnButton(
          label: t.settings.sandbox.gcAll,
          size: AnButtonSize.sm,
          variant: AnButtonVariant.danger,
          onPressed: () async {
            final ok = await ref.read(overlayProvider.notifier).confirm(
                  title: t.settings.sandbox.gcAllTitle,
                  confirmLabel: t.settings.sandbox.gcAll,
                  cancelLabel: t.settings.keys.cancel,
                  barrierLabel: t.settings.sandbox.gcAllTitle,
                );
            if (ok) await _gc(0);
          },
        ),
      ),
    ]);
  }
}
