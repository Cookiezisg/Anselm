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
import '../panels/storage_panel.dart'
    show SandboxDiskUsageValue, sandboxDiskProvider;

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
    final runtimeSnapshot = ref.watch(sandboxRuntimesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BootstrapHealth(),
        // Disk — one shared projection with explicit loading/error states. 磁盘共用同一投影,保留加载/错误态。
        AnSettingRow(
          label: t.settings.sandbox.disk,
          child: const SandboxDiskUsageValue(),
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
              outline: true,
              onPressed: () => ref
                  .read(settingsDetailProvider.notifier)
                  .push('sandboxInstall'),
            ),
          ],
          children: [
            AnLastGood<List<SandboxRuntime>>(
              value: runtimeSnapshot,
              placeholder: const AnSkeleton.lines(2),
              errorBuilder: (context, _, _) => AnState(
                kind: AnStateKind.error,
                title: t.settings.sandbox.runtimesLoadFailed,
                size: AnStateSize.inset,
                action: AnButton(
                  label: t.settings.sandbox.retry,
                  outline: true,
                  onPressed: () => ref.invalidate(sandboxRuntimesProvider),
                ),
              ),
              builder: (context, runtimes) {
                if (runtimes.isEmpty) {
                  // Only a settled empty response may say there are no runtimes. 仅服务端落定空数组才能进入空态。
                  return AnState(
                    kind: AnStateKind.empty,
                    title: t.settings.sandbox.noRuntimes,
                    size: AnStateSize.inset,
                  );
                }
                return Column(
                  children: [
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
                );
              },
            ),
          ],
        ),
        // Envs — five owner tabs; the section rhythm belongs to AnSection like every other section
        // on this panel (批6 A-064 — the lone hand-rolled readingH3 head + s24 spacers retire).
        // 环境五 owner tab;节律归 AnSection(孤例手搓头+手排 spacer 退役)。
        AnSection(
          label: t.settings.sandbox.envs,
          variant: AnSectionVariant.quiet,
          children: [SizedBox(height: AnSize.tabPane, child: _EnvTabs())],
        ),
        _GcZone(),
      ],
    );
  }

  Future<void> _deleteRuntime(
    BuildContext context,
    WidgetRef ref,
    SandboxRuntime r,
  ) async {
    final t = Translations.of(context);
    final ok = await ref
        .read(overlayProvider.notifier)
        .confirm(
          title: t.settings.sandbox.deleteRtTitle,
          message: t.settings.sandbox.deleteRtBody(
            kind: r.kind,
            version: r.version,
          ),
          confirmLabel: t.settings.sandbox.confirmDelete,
          cancelLabel: t.settings.keys.cancel,
          barrierLabel: t.settings.sandbox.deleteRtTitle,
        );
    if (!ok) return;
    try {
      await ref.read(sandboxRuntimesProvider.notifier).remove(r.id);
      // Deleting a runtime changes the same machine-wide total shown above. 删除运行时会改变上方全机总量。
      ref.invalidate(sandboxDiskProvider);
    } on ApiException catch (e) {
      final msg = e.code == 'SANDBOX_ENV_IN_USE'
          ? t.settings.sandbox.inUse
          : e.message;
      ref.read(noticeCenterProvider.notifier).show(msg, tone: AnTone.danger);
    }
  }
}

/// The bootstrap status is a health signal, not a raw error console. Keep all async states visible,
/// and never put filesystem paths or wrapped Go errors into the product surface.
///
/// bootstrap 状态是健康信号，不是原始错误控制台。所有异步状态都要可见，绝不把文件路径或 Go 包装错误
/// 放进产品界面。
class _BootstrapHealth extends ConsumerStatefulWidget {
  const _BootstrapHealth();

  @override
  ConsumerState<_BootstrapHealth> createState() => _BootstrapHealthState();
}

class _BootstrapHealthState extends ConsumerState<_BootstrapHealth> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await ref.read(settingsRepositoryProvider).retrySandboxBootstrap();
    } catch (_) {
      // The follow-up GET is the source of truth and will render a localized transport error.
      // 后续 GET 才是真相，会把网络失败渲成统一的本地化错误态。
    } finally {
      if (mounted) {
        setState(() => _retrying = false);
        ref.invalidate(sandboxBootstrapProvider);
      }
    }
  }

  Widget _callout({required String title, required String message}) {
    final t = context.t;
    return AnCallout(
      message,
      title: title,
      severity: AnCalloutSeverity.danger,
      actions: [
        AnButton(
          label: _retrying
              ? t.settings.sandbox.retrying
              : t.settings.sandbox.retry,
          size: AnButtonSize.sm,
          outline: true,
          onPressed: _retrying ? null : _retry,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(sandboxBootstrapProvider);
    final t = context.t;
    return AnLastGood<SandboxBootstrap>(
      value: snapshot,
      placeholder: const AnSkeleton.lines(
        1,
        key: Key('sandbox-bootstrap-loading'),
      ),
      errorBuilder: (context, _, _) => _callout(
        title: t.settings.sandbox.bootstrapStatusLoadFailed,
        message: t.settings.sandbox.bootstrapStatusLoadFailedHint,
      ),
      builder: (context, boot) {
        if (boot.ok) return const SizedBox.shrink();
        return _callout(
          title: t.settings.sandbox.bootstrapFail,
          message: t.settings.sandbox.bootstrapFailHint,
        );
      },
    );
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
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy || _kind == null || _version.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sandboxRuntimesProvider.notifier)
          .install(kind: _kind!, version: _version);
      // Runtime bytes are machine-wide truth too; refresh the figure before leaving the form.
      // runtime 字节也是全机真相;离开安装表单前同步重取磁盘数。
      ref.invalidate(sandboxDiskProvider);
      if (mounted) ref.read(settingsDetailProvider.notifier).pop();
    } on ApiException catch (e) {
      setState(() => _error = _installError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _installError(ApiException error) {
    final details = error.details is Map
        ? (error.details as Map).cast<Object?, Object?>()
        : const <Object?, Object?>{};
    final kind = details['kind']?.toString();
    final version = details['version']?.toString();
    if (kind != null && version != null) {
      if (error.code == AnselmErr.sandboxRuntimeVersionUnsupported) {
        final hint = details['hint']?.toString();
        if (hint != null && hint.isNotEmpty) {
          return context.t.settings.sandbox.versionUnsupported(
            kind: kind,
            version: version,
            hint: hint,
          );
        }
      }
      if (error.code == AnselmErr.sandboxRuntimeInstallFailed) {
        return context.t.settings.sandbox.installFailed(
          kind: kind,
          version: version,
        );
      }
    }
    return error.message;
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final availAsync = ref.watch(sandboxAvailableProvider);
    // A dead :available must not read as eternal loading (批7 复审 — 立法四:整面载入失败=AnState).
    // 取选项失败=诚实错误面,绝不永久骨架。
    if (availAsync.hasError) {
      return AnState(
        kind: AnStateKind.error,
        size: AnStateSize.inset,
        title: t.settings.sandbox.installTitle,
        action: AnButton(
          label: t.settings.sandbox.retry,
          size: AnButtonSize.sm,
          onPressed: () => ref.invalidate(sandboxAvailableProvider),
        ),
      );
    }
    final avail = availAsync.value ?? const <RuntimeAvailability>[];
    if (avail.isEmpty) {
      // Install-form options still loading = the deferred-skeleton idiom. 选项载入中走骨架。
      return const AnDeferredLoading(child: AnSkeleton.lines(2));
    }
    _kind ??= avail.first.kind;
    final sel = avail.firstWhere(
      (a) => a.kind == _kind,
      orElse: () => avail.first,
    );
    if (_version.isEmpty) _version = sel.defaultVersion;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnSize.formMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnFormField(
            label: t.settings.sandbox.kind,
            child: AnDropdown<String>(
              value: _kind,
              options: [
                for (final a in avail)
                  AnDropdownOption(value: a.kind, label: a.kind),
              ],
              onChanged: (v) => setState(() {
                _kind = v;
                final next = avail.firstWhere((a) => a.kind == v);
                _version = next.defaultVersion;
              }),
            ),
          ),
          const SizedBox(height: AnSpace.s12),
          // The conditional subtrees (pinned dropdown ↔ free input) stay structurally identical to
          // today — same shell both branches (scout 风险注记). 条件子树两分支同壳。
          AnFormField(
            label: t.settings.sandbox.version,
            child: sel.pinned
                ? AnDropdown<String>(
                    value: sel.versions.contains(_version)
                        ? _version
                        : sel.versions.firstOrNull,
                    options: [
                      for (final v in sel.versions)
                        AnDropdownOption(value: v, label: v),
                    ],
                    onChanged: (v) => setState(() => _version = v),
                  )
                : AnInput(
                    // A kind change must create a fresh field so an open runtime cannot inherit
                    // the previous kind's version text.  Runtime kind is the field's identity.
                    // 切 kind 必须换一只新输入框，开放 runtime 不得继承上一个 kind 的版本文字。
                    key: ValueKey('sandbox-version-${sel.kind}'),
                    initialValue: _version,
                    placeholder: t.settings.sandbox.versionHint,
                    onChanged: (v) => _version = v.trim(),
                  ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AnSpace.s8),
            Text(_error!, style: AnText.label.copyWith(color: c.danger)),
          ],
          const SizedBox(height: AnSpace.s16),
          Row(
            children: [
              AnButton(
                label: _busy
                    ? t.settings.sandbox.installing
                    : t.settings.sandbox.add,
                variant: AnButtonVariant.primary,
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(width: AnSpace.s8),
              AnButton(
                label: t.settings.keys.cancel,
                onPressed: _busy
                    ? null
                    : () => ref.read(settingsDetailProvider.notifier).pop(),
              ),
            ],
          ),
        ],
      ),
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
        AnTabsItem(
          key: 'function',
          label: t.settings.sandbox.ownerFunction,
          pane: _EnvList(ownerKind: 'function'),
        ),
        AnTabsItem(
          key: 'handler',
          label: t.settings.sandbox.ownerHandler,
          pane: _EnvList(ownerKind: 'handler'),
        ),
        AnTabsItem(
          key: 'mcp',
          label: t.settings.sandbox.ownerMcp,
          pane: _EnvList(ownerKind: 'mcp'),
        ),
        AnTabsItem(
          key: 'skill',
          label: t.settings.sandbox.ownerSkill,
          pane: _EnvList(ownerKind: 'skill'),
        ),
        AnTabsItem(
          key: 'conversation',
          label: t.settings.sandbox.ownerConversation,
          pane: _EnvList(ownerKind: 'conversation'),
        ),
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
    final snapshot = ref.watch(sandboxEnvsProvider(ownerKind));
    return AnLastGood<List<SandboxEnv>>(
      value: snapshot,
      resetKey: ownerKind,
      placeholder: const AnSkeleton.lines(2),
      errorBuilder: (context, _, _) => AnState(
        kind: AnStateKind.error,
        size: AnStateSize.inset,
        title: t.settings.sandbox.envsLoadFailed,
        action: AnButton(
          label: t.settings.sandbox.retry,
          outline: true,
          onPressed: () => ref.invalidate(sandboxEnvsProvider(ownerKind)),
        ),
      ),
      builder: (context, envs) {
        if (envs.isEmpty) {
          // Only a settled empty response may say there are no environments. 仅服务端落定空数组才能进入空态。
          return AnState(
            kind: AnStateKind.empty,
            size: AnStateSize.inset,
            title: t.settings.sandbox.noEnvs,
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
                // Conversation envs use the same localized fallback as the chat rail when a
                // thread has not been titled yet; opaque cv_* owner ids are implementation
                // details, not a useful product label.
                // 未命名对话沿用 chat rail 的本地化回落；cv_* 是实现细节，不应直接展示给用户。
                label: e.ownerName.isNotEmpty
                    ? e.ownerName
                    : e.ownerKind == 'conversation'
                    ? t.chat.kNew
                    : e.ownerId,
                hint: _errorHint(e),
                meta: [
                  '${e.deps.length} deps',
                  formatBytes(e.sizeBytes),
                  if (e.status == 'failed') t.settings.sandbox.statusFailed,
                  if (e.status == 'installing')
                    t.settings.sandbox.statusInstalling,
                  if ((e.runningPid ?? 0) > 0) t.settings.sandbox.running,
                ].join(' · '),
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
      },
    );
  }

  String? _errorHint(SandboxEnv e) {
    if (e.status != 'failed') return null;
    final message = (e.errorMsg ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (message.isEmpty) return null;
    return message.length > 160 ? '${message.substring(0, 160)}…' : message;
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SandboxEnv e,
  ) async {
    final t = Translations.of(context);
    final ok = await ref
        .read(overlayProvider.notifier)
        .confirm(
          title: t.settings.sandbox.deleteEnvTitle,
          message: t.settings.sandbox.deleteEnvBody,
          confirmLabel: t.settings.sandbox.confirmDelete,
          cancelLabel: t.settings.keys.cancel,
          barrierLabel: t.settings.sandbox.deleteEnvTitle,
        );
    if (!ok) return;
    try {
      await ref.read(settingsRepositoryProvider).deleteEnv(e.id);
      ref.invalidate(sandboxEnvsProvider(ownerKind));
      // Env deletion changes the same machine-wide total shown above. 删除环境会改变上方全机总量。
      ref.invalidate(sandboxDiskProvider);
    } on ApiException catch (err) {
      final msg = err.code == 'SANDBOX_ENV_IN_USE'
          ? t.settings.sandbox.envInUse
          : err.message;
      ref.read(noticeCenterProvider.notifier).show(msg, tone: AnTone.danger);
    }
  }
}

class _GcZone extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GcZone> createState() => _GcZoneState();
}

class _GcZoneState extends ConsumerState<_GcZone> {
  final _days = TextEditingController(text: '30');
  String? _daysError;
  bool _busy = false;

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  int? _parseDays() {
    final days = int.tryParse(_days.text.trim());
    if (days == null || days < 0) {
      setState(() => _daysError = context.t.settings.sandbox.gcInvalidDays);
      return null;
    }
    setState(() => _daysError = null);
    return days;
  }

  Future<void> _confirmAndGc(int days) async {
    if (_busy) return;
    final t = Translations.of(context);
    final ok = await ref
        .read(overlayProvider.notifier)
        .confirm(
          title: days == 0
              ? t.settings.sandbox.gcAllTitle
              : t.settings.sandbox.gcTitle,
          message: days == 0
              ? t.settings.sandbox.gcAllBody
              : t.settings.sandbox.gcBody(days: days),
          confirmLabel: days == 0
              ? t.settings.sandbox.gcAll
              : t.settings.sandbox.gcRun,
          cancelLabel: t.settings.keys.cancel,
          barrierLabel: t.settings.sandbox.gc,
        );
    if (ok && mounted) await _gc(days);
  }

  Future<void> _gc(int days) async {
    if (_busy) return;
    final t = Translations.of(context);
    setState(() {
      _busy = true;
      _daysError = null;
    });
    try {
      final n = await ref.read(settingsRepositoryProvider).sandboxGc(days);
      if (!mounted) return;
      // GC changes every machine-wide sandbox projection, not just the selected owner tab.
      // GC 会同时改变全机 runtime、disk 与所有 owner env 投影，不能只刷新当前 tab。
      ref.invalidate(sandboxRuntimesProvider);
      ref.invalidate(sandboxDiskProvider);
      ref.invalidate(sandboxEnvsProvider);
      ref
          .read(noticeCenterProvider.notifier)
          .show(t.settings.sandbox.gcDone(n: n), tone: AnTone.ok);
    } on ApiException {
      if (mounted) {
        ref
            .read(noticeCenterProvider.notifier)
            .show(t.settings.sandbox.gcFailed, tone: AnTone.danger);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnSettingRow(
          label: t.settings.sandbox.gc,
          desc: t.settings.sandbox.gcDays,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: AnSize.numField,
                    child: AnInput(
                      controller: _days,
                      mono: true,
                      enabled: !_busy,
                      onChanged: (_) {
                        if (_daysError != null) {
                          setState(() => _daysError = null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AnSpace.s8),
                  AnButton(
                    label: _busy
                        ? t.settings.sandbox.gcWorking
                        : t.settings.sandbox.gcRun,
                    size: AnButtonSize.sm,
                    outline: true,
                    onPressed: _busy
                        ? null
                        : () {
                            final days = _parseDays();
                            if (days != null) _confirmAndGc(days);
                          },
                  ),
                ],
              ),
              if (_daysError != null) ...[
                const SizedBox(height: AnSpace.s8),
                Text(
                  _daysError!,
                  style: AnText.meta.copyWith(color: context.colors.danger),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AnSpace.s16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AnButton(
            label: t.settings.sandbox.gcAll,
            size: AnButtonSize.sm,
            outline: true,
            variant: AnButtonVariant.danger,
            onPressed: _busy ? null : () => _confirmAndGc(0),
          ),
        ),
      ],
    );
  }
}
