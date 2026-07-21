import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/api_error.dart';
import '../../../../core/contract/mcp.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/mcp_providers.dart';
import '../../state/settings_detail_provider.dart';

/// The MCP write faces (S4b): manual add (transport-conditional fields; an unreachable server still
/// lands as failed — honest), the mcp.json import dialog, and the marketplace (client-side search →
/// :plan-driven env form → install; OAuth entries block on the browser consent up to 120s).
/// MCP 写入面:手动添加(transport 条件字段;连不上也落 failed 诚实)/导入对话框/市场(:plan 驱动 env 表单)。
class McpManualForm extends ConsumerStatefulWidget {
  const McpManualForm({super.key});

  @override
  ConsumerState<McpManualForm> createState() => _McpManualFormState();
}

class _McpManualFormState extends ConsumerState<McpManualForm> {
  final _name = TextEditingController();
  final _command = TextEditingController();
  final _args = TextEditingController();
  final _url = TextEditingController();
  final _env = TextEditingController();
  final _headers = TextEditingController();
  String _transport = 'stdio';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _command, _args, _url, _env, _headers]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _kv(String text) => {
    for (final line in text.split('\n'))
      if (line.contains('='))
        line.substring(0, line.indexOf('=')).trim(): line
            .substring(line.indexOf('=') + 1)
            .trim(),
  };

  Future<void> _submit() async {
    if (_saving || _name.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final config = <String, dynamic>{
      if (_transport == 'stdio') ...{
        'command': _command.text.trim(),
        'args': [
          for (final a in _args.text.split('\n'))
            if (a.trim().isNotEmpty) a.trim(),
        ],
        'env': _kv(_env.text),
      } else ...{
        'url': _url.text.trim(),
        'transport': _transport,
        'headers': _kv(_headers.text),
      },
    };
    try {
      await ref
          .read(mcpServersProvider.notifier)
          .put(_name.text.trim(), config);
      if (mounted) ref.read(settingsDetailProvider.notifier).pop();
    } on ApiException catch (e) {
      // MCP_INSTALL_FAILED etc — the row may STILL have landed (honest failed face); refresh showed it.
      // 装环境失败等——行可能已落盘(failed 诚实态)。
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final stdio = _transport == 'stdio';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnSize.formMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The ONE form block (批6c A-059 — the private «label above» dies; the quiet 13 label
          // steps up to the family face). 唯一表单字段块(私排退役,字面升族脸)。
          AnFormField(
            label: t.settings.mcp.name,
            child: AnInput(
              controller: _name,
              mono: true,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: AnSpace.s12),
          AnFormField(
            label: t.settings.mcp.transport,
            child: SizedBox(
              width: AnSize.ctlSlotXl,
              child: AnSegmented<String>(
                options: const [
                  AnSegmentedOption(value: 'stdio', label: 'stdio'),
                  AnSegmentedOption(value: 'sse', label: 'sse'),
                  AnSegmentedOption(
                    value: 'streamable-http',
                    label: 'streamable-http',
                  ),
                ],
                value: _transport,
                onChanged: (v) => setState(() => _transport = v),
              ),
            ),
          ),
          const SizedBox(height: AnSpace.s12),
          if (stdio) ...[
            AnFormField(
              label: t.settings.mcp.command,
              child: AnInput(
                controller: _command,
                mono: true,
                placeholder: 'npx / uvx / docker …',
              ),
            ),
            const SizedBox(height: AnSpace.s12),
            AnFormField(
              label: t.settings.mcp.args,
              child: AnInput(controller: _args, mono: true, multiline: true),
            ),
            const SizedBox(height: AnSpace.s12),
            AnFormField(
              label: t.settings.mcp.envKv,
              child: AnInput(controller: _env, mono: true, multiline: true),
            ),
          ] else ...[
            AnFormField(
              label: t.settings.mcp.url,
              child: AnInput(
                controller: _url,
                mono: true,
                placeholder: 'https://…',
              ),
            ),
            const SizedBox(height: AnSpace.s12),
            AnFormField(
              label: t.settings.mcp.headersKv,
              child: AnInput(controller: _headers, mono: true, multiline: true),
            ),
          ],
          const SizedBox(height: AnSpace.s8),
          Text(
            t.settings.mcp.addFailedHonest,
            style: AnText.label.copyWith(color: c.inkFaint),
          ),
          if (_error != null) ...[
            const SizedBox(height: AnSpace.s8),
            Text(_error!, style: AnText.label.copyWith(color: c.danger)),
          ],
          const SizedBox(height: AnSpace.s16),
          Row(
            children: [
              AnButton(
                label: t.settings.mcp.add,
                variant: AnButtonVariant.primary,
                onPressed: _saving || _name.text.trim().isEmpty
                    ? null
                    : _submit,
              ),
              const SizedBox(width: AnSpace.s8),
              AnButton(
                label: t.settings.keys.cancel,
                onPressed: () =>
                    ref.read(settingsDetailProvider.notifier).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The import face — a mono paste box + overwrite switch → «imported N · skipped M» toast.
/// 导入面:mono 粘贴框+覆盖开关。
class McpImportForm extends ConsumerStatefulWidget {
  const McpImportForm({super.key});

  @override
  ConsumerState<McpImportForm> createState() => _McpImportFormState();
}

class _McpImportFormState extends ConsumerState<McpImportForm> {
  final _json = TextEditingController();
  bool _overwrite = false;
  bool _busy = false;

  @override
  void dispose() {
    _json.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_busy || _json.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final t = Translations.of(context);
    final notices = ref.read(noticeCenterProvider.notifier);
    try {
      final r = await ref
          .read(mcpServersProvider.notifier)
          .importJson(_json.text, overwrite: _overwrite);
      notices.show(
        t.settings.mcp.importResult(n: r.imported.length, m: r.skipped.length),
        tone: AnTone.ok,
      );
      if (mounted) ref.read(settingsDetailProvider.notifier).pop();
    } on FormatException {
      notices.show(t.settings.mcp.importInvalid, tone: AnTone.danger);
    } on ApiException catch (e) {
      notices.show(e.message, tone: AnTone.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnSize.formMaxWidthWide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnInput(
            controller: _json,
            multiline: true,
            mono: true,
            placeholder: t.settings.mcp.importHint,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AnSpace.s8),
          Row(
            children: [
              AnSwitch(
                value: _overwrite,
                onChanged: (v) => setState(() => _overwrite = v),
              ),
              const SizedBox(width: AnSpace.s8),
              Text(
                t.settings.mcp.overwrite,
                style: AnText.label.copyWith(color: c.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: AnSpace.s16),
          Row(
            children: [
              AnButton(
                label: t.settings.mcp.doImport,
                variant: AnButtonVariant.primary,
                onPressed: _busy || _json.text.trim().isEmpty ? null : _import,
              ),
              const SizedBox(width: AnSpace.s8),
              AnButton(
                label: t.settings.keys.cancel,
                onPressed: () =>
                    ref.read(settingsDetailProvider.notifier).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The marketplace — the WHOLE curated registry listed by default (browse first; search is a
/// filter, never a gate), as two-column brand cards: logo + short name + installed mark +
/// description + prerequisite badge; click = the `:plan`-driven install form. 市场:默认全列
/// (先浏览,搜索只是过滤、不是门),双列品牌卡(logo+短名+已装标+描述+前置徽);点卡进 :plan 安装表单。
class McpMarket extends ConsumerStatefulWidget {
  const McpMarket({super.key});

  @override
  ConsumerState<McpMarket> createState() => _McpMarketState();
}

class _McpMarketState extends ConsumerState<McpMarket> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final entries =
        ref.watch(mcpRegistryProvider).value ?? const <McpRegistryEntry>[];
    final installed = {
      for (final s
          in ref.watch(mcpServersProvider).value ?? const <McpServerStatus>[])
        s.name,
    };
    final q = _query.toLowerCase();
    final rows = entries
        .where(
          (e) =>
              q.isEmpty ||
              e.name.toLowerCase().contains(q) ||
              e.description.toLowerCase().contains(q),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnInput(
          placeholder: t.settings.mcp.searchMarket,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
        const SizedBox(height: AnSpace.s12),
        AnAutoGrid(
          minColWidth: AnSize.block,
          children: [
            for (final e in rows)
              _MarketCard(
                key: ValueKey(e.name),
                entry: e,
                installed: installed.contains(e.name.split('/').last),
              ),
          ],
        ),
        if (rows.isEmpty)
          AnState(
            kind: AnStateKind.empty,
            size: AnStateSize.inset,
            title: t.settings.mcp.empty,
          ),
      ],
    );
  }
}

/// One marketplace card (App-Store grammar). The whole card taps into the `:plan` install form (env
/// collection / OAuth preserved — 既有能力不破坏); hover OR keyboard-focus reveals a primary «安装» CTA
/// that installs IN PLACE with empty env (the one-click path). The install lifecycle rides on the card:
/// [AnSpinner] while installing → the «已安装» chip once the roster refetch lands the row (no cross-list
/// move needed) → an honest red line if it threw. An entry that needs keys lands as the backend's honest
/// failed face — the whole-card tap then opens the form to collect them.
///
/// The CTA is always laid out + focusable (keyboard-reachable, AnInteractive/FocusRing 先例) but hidden
/// by an INSTANT opacity swap when idle (kit grammar: reveals don't animate) and made inert so a rest
/// click falls through to «open form»; hover/focus tracked via [AnHoverRegion] (scroll-freeze correct) +
/// a non-focusable [Focus] wrapper reporting subtree focus (card OR CTA).
///
/// 市场卡(App Store 文法):整卡点进 :plan 安装表单(env/OAuth 表单保持);hover 或键盘 focus 揭示「安装」主
/// CTA 就地空 env 装(一键径)。安装态链在卡上:转圈→名册重取落行后渲「已安装」→抛错则红句诚实。需密钥的
/// 条目落后端 failed 诚实态,整卡点击再开表单填。CTA 常驻可聚焦、闲时即时 opacity 隐+惰化(点击透传给开表单)。
class _MarketCard extends ConsumerStatefulWidget {
  const _MarketCard({required this.entry, required this.installed, super.key});

  final McpRegistryEntry entry;
  final bool installed;

  @override
  ConsumerState<_MarketCard> createState() => _MarketCardState();
}

class _MarketCardState extends ConsumerState<_MarketCard> {
  bool _hovered = false;
  bool _focusWithin = false;
  bool _installing = false;
  String? _error;

  String get _short => widget.entry.name.split('/').last;

  void _openForm() => ref
      .read(settingsDetailProvider.notifier)
      .push('mcpInstall', id: widget.entry.name);

  Future<void> _quickInstall() async {
    if (_installing) return;
    setState(() {
      _installing = true;
      _error = null;
    });
    try {
      // Empty env = the one-click path. On success the roster refetches → `installed` flips true → this
      // card rebuilds into the «已安装» face. 空 env 一键装;成功后名册重取→installed 翻真→本卡自渲已装态。
      await ref
          .read(mcpServersProvider.notifier)
          .install(widget.entry.name, const {});
    } on ApiException catch (e) {
      // MCP_INSTALL_FAILED etc — the honest red line on the card (the row may still have landed failed).
      // 安装失败:卡上红句诚实(行可能已落 failed)。
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final e = widget.entry;
    final reveal = _hovered || _focusWithin;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (has) => setState(() => _focusWithin = has),
      child: AnHoverRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnCard(
          selectable: true,
          onSelect: _openForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  brandIconOr(
                    mcpBrandFor(e.name),
                    fallbackLabel: _short,
                    size: AnBrandSize.sm,
                  ),
                  const SizedBox(width: AnSpace.s8),
                  Expanded(
                    child: Text(
                      _short,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AnText.mono.copyWith(color: c.ink),
                    ),
                  ),
                  const SizedBox(width: AnSpace.s8),
                  _trailing(t, reveal),
                ],
              ),
              if (e.description.isNotEmpty) ...[
                const SizedBox(height: AnSpace.s6),
                Text(
                  e.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.meta.copyWith(color: c.inkMuted),
                ),
              ],
              if (e.prerequisite.isNotEmpty) ...[
                const SizedBox(height: AnSpace.s6),
                AnChip(
                  t.settings.mcp.prerequisite,
                  tone: AnTone.warn,
                  tooltip: e.prerequisite,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AnSpace.s6),
                Text(
                  _error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.meta.copyWith(color: c.danger),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _trailing(Translations t, bool reveal) {
    if (widget.installed) {
      return AnChip(t.settings.mcp.installed, tone: AnTone.ok);
    }
    if (_installing) return AnSpinner(semanticLabel: t.settings.mcp.installing);
    // Reveal-gated «安装» CTA — always laid out (no reflow) + focusable, INSTANT opacity, inert when
    // hidden so a rest click falls through to the whole-card open-form. 揭示门控的安装钮:常驻不重排+可聚焦。
    return IgnorePointer(
      ignoring: !reveal,
      child: Opacity(
        opacity: reveal ? 1 : 0,
        child: AnButton(
          label: t.settings.mcp.install,
          variant: AnButtonVariant.primary,
          size: AnButtonSize.sm,
          semanticLabel: t.settings.mcp.installNamed(name: _short),
          onPressed: _quickInstall,
        ),
      ),
    );
  }
}

/// The install form — :plan-driven (工单⑨): the backend says which env vars to collect (isSecret →
/// masked, required → starred) and whether this is an OAuth entry (button becomes «connect &
/// authorize», waits on the browser). 安装表单::plan 驱动;OAuth 条目=「连接并授权」等浏览器。
class McpInstallForm extends ConsumerStatefulWidget {
  const McpInstallForm({required this.fullName, super.key});

  final String fullName;

  @override
  ConsumerState<McpInstallForm> createState() => _McpInstallFormState();
}

class _McpInstallFormState extends ConsumerState<McpInstallForm> {
  final Map<String, TextEditingController> _env = {};
  bool _installing = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _env.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctl(String name) =>
      _env.putIfAbsent(name, TextEditingController.new);

  Future<void> _install(McpRegistryPlan plan) async {
    if (_installing) return;
    setState(() {
      _installing = true;
      _error = null;
    });
    try {
      await ref.read(mcpServersProvider.notifier).install(widget.fullName, {
        for (final e in _env.entries)
          if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
      });
      if (mounted) ref.read(settingsDetailProvider.notifier).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final planAsync = ref.watch(mcpPlanProvider(widget.fullName));
    final plan = planAsync.value;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnSize.formMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.fullName, style: AnText.mono.copyWith(color: c.ink)),
          const SizedBox(height: AnSpace.s8),
          if (planAsync.hasError)
            // An honest error face — a dead :plan must never look like eternal loading. 诚实错误面。
            Text(
              planAsync.error is ApiException
                  ? (planAsync.error as ApiException).message
                  : '${planAsync.error}',
              style: AnText.label.copyWith(color: c.danger),
            )
          else if (plan == null)
            // :plan resolving = the deferred-skeleton idiom, not a prose sentinel. 取回中走骨架。
            const AnDeferredLoading(child: AnSkeleton.lines(3))
          else ...[
            Row(
              children: [
                AnChip(plan.transport),
                if (plan.runtime.isNotEmpty) ...[
                  const SizedBox(width: AnSpace.s8),
                  AnChip(plan.runtime),
                ],
              ],
            ),
            if (plan.prerequisite.isNotEmpty) ...[
              const SizedBox(height: AnSpace.s8),
              Text(
                '${t.settings.mcp.prerequisite} · ${plan.prerequisite}',
                style: AnText.label.copyWith(color: c.warn),
              ),
            ],
            const SizedBox(height: AnSpace.s12),
            // The env-var group is the ONE form block too (批6 复审 — monoLabel 的声明用途在此,
            // A-059 关账落到实处): mono env name + required mark on the label baseline + description
            // as the desc sub-line. env 组同走唯一表单字段块:mono 名+required 骑基线+描述走 desc。
            for (final v in plan.envVars) ...[
              AnFormField(
                label: v.name,
                monoLabel: true,
                labelTrailing: v.required
                    ? Text(
                        '* ${t.settings.mcp.requiredMark}',
                        style: AnText.label.copyWith(color: c.danger),
                      )
                    : null,
                desc: v.description.isEmpty ? null : v.description,
                child: v.isSecret
                    ? AnSecretField(controller: _ctl(v.name))
                    : AnInput(controller: _ctl(v.name), mono: true),
              ),
              const SizedBox(height: AnSpace.s12),
            ],
            if (_installing && plan.oauth)
              Text(
                t.settings.mcp.oauthWaiting,
                style: AnText.label.copyWith(color: c.inkMuted),
              ),
            if (_error != null) ...[
              Text(_error!, style: AnText.label.copyWith(color: c.danger)),
              const SizedBox(height: AnSpace.s8),
            ],
            Row(
              children: [
                AnButton(
                  label: _installing
                      ? t.settings.mcp.installing
                      : plan.oauth
                      ? t.settings.mcp.oauthConnect
                      : t.settings.mcp.install,
                  variant: AnButtonVariant.primary,
                  onPressed: _installing ? null : () => _install(plan),
                ),
                const SizedBox(width: AnSpace.s8),
                AnButton(
                  label: t.settings.keys.cancel,
                  onPressed: () =>
                      ref.read(settingsDetailProvider.notifier).pop(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
