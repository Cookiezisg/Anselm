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
import 'mcp_forms.dart';

/// ⑤ MCP 服务器 (WRK-062 §3, S4b): the roster (five-state dot + stats bar + three CTAs), and the
/// pushed-in faces: server detail (status card + tools / call-history / stderr tabs — no config
/// tab, S-2: config is encrypted write-only), manual add, import, marketplace + install form
/// (:plan-driven, 工单⑨). The list never trusts frame payloads (300ms-coalesced refetch).
///
/// MCP 面板(S4b):名册(五态点+统计条+三 CTA)+推入面:详情(状态卡+工具/调用/stderr 三 tab——无配置
/// tab,S-2:配置加密只写)/手动添加/导入/市场+安装表单(:plan 驱动)。列表绝不信帧内容(300ms 去抖重取)。
class McpPanel extends ConsumerWidget {
  const McpPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(settingsDetailProvider);
    return switch (detail?.kind) {
      'mcpServer' => McpServerDetail(name: detail!.id!, key: ValueKey(detail.id)),
      'mcpAdd' => const McpManualForm(),
      'mcpImport' => const McpImportForm(),
      'mcpMarket' => const McpMarket(),
      'mcpInstall' => McpInstallForm(fullName: detail!.id!, key: ValueKey(detail.id)),
      _ => const _Roster(),
    };
  }
}

/// status → dot. 五态映射。
AnStatus? mcpDot(String status) => switch (status) {
      'ready' => AnStatus.done,
      'failed' => AnStatus.err,
      'degraded' => AnStatus.wait,
      'connecting' => AnStatus.run,
      _ => null, // disconnected 未连接
    };

class _Roster extends ConsumerWidget {
  const _Roster();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final c = context.colors;
    final rows = ref.watch(mcpServersProvider).value ?? const <McpServerStatus>[];
    final ready = rows.where((s) => s.status == 'ready').length;
    final failed = rows.where((s) => s.status == 'failed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Text(
              t.settings.mcp.statBar(n: rows.length, ready: ready, failed: failed),
              style: AnText.label.copyWith(color: c.inkMuted),
            ),
          ),
          AnButton(
            label: t.settings.mcp.browse,
            variant: AnButtonVariant.primary,
            size: AnButtonSize.sm,
            onPressed: () => ref.read(settingsDetailProvider.notifier).push('mcpMarket'),
          ),
          const SizedBox(width: AnSpace.s8),
          AnButton(
            label: t.settings.mcp.manualAdd,
            size: AnButtonSize.sm,
            onPressed: () => ref.read(settingsDetailProvider.notifier).push('mcpAdd'),
          ),
          const SizedBox(width: AnSpace.s8),
          AnButton(
            label: t.settings.mcp.importJson,
            size: AnButtonSize.sm,
            onPressed: () => ref.read(settingsDetailProvider.notifier).push('mcpImport'),
          ),
        ]),
        const SizedBox(height: AnSpace.s16),
        if (rows.isEmpty)
          AnState(
            kind: AnStateKind.empty,
            title: t.settings.mcp.empty,
            hint: t.settings.mcp.emptyHint,
            size: AnStateSize.inset,
          )
        else
          for (final s in rows) _ServerRow(s: s),
      ],
    );
  }
}

class _ServerRow extends ConsumerWidget {
  const _ServerRow({required this.s});

  final McpServerStatus s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    return AnRow(
      dot: mcpDot(s.status),
      leadless: mcpDot(s.status) == null,
      label: s.name,
      mono: true,
      meta:
          '${statusLabel(t, s.status)} · ${t.settings.mcp.tools(n: s.tools.length)} · ${t.settings.mcp.calls(n: s.totalCalls)}',
      onSelect: () =>
          ref.read(settingsDetailProvider.notifier).push('mcpServer', id: s.name),
      actions: [
        AnButton(
          label: t.settings.mcp.reconnect,
          size: AnButtonSize.sm,
          onPressed: () async {
            try {
              await ref.read(mcpServersProvider.notifier).reconnect(s.name);
            } on ApiException catch (e) {
              ref
                  .read(overlayProvider.notifier)
                  .showToast(e.message, tone: AnTone.danger);
            }
          },
        ),
        AnButton(
          label: t.settings.mcp.deleteServer,
          size: AnButtonSize.sm,
          variant: AnButtonVariant.danger,
          onPressed: () => deleteMcpServer(context, ref, s.name),
        ),
      ],
    );
  }
}

String statusLabel(Translations t, String status) => switch (status) {
      'ready' => t.settings.mcp.statusReady,
      'failed' => t.settings.mcp.statusFailed,
      'degraded' => t.settings.mcp.statusDegraded,
      'connecting' => t.settings.mcp.statusConnecting,
      _ => t.settings.mcp.statusDisconnected,
    };

Future<void> deleteMcpServer(BuildContext context, WidgetRef ref, String name) async {
  final t = Translations.of(context);
  final ok = await ref.read(overlayProvider.notifier).confirm(
        title: t.settings.mcp.deleteTitle,
        message: t.settings.mcp.deleteBody(name: name),
        confirmLabel: t.settings.mcp.confirmDelete,
        cancelLabel: t.settings.keys.cancel,
        barrierLabel: t.settings.mcp.deleteTitle,
      );
  if (!ok) return;
  try {
    await ref.read(mcpServersProvider.notifier).remove(name);
    ref.read(settingsDetailProvider.notifier).pop();
  } on ApiException catch (e) {
    ref.read(overlayProvider.notifier).showToast(e.message, tone: AnTone.danger);
  }
}

/// The pushed-in server detail: status card + tools / calls / stderr tabs (S-2: NO config tab).
/// 详情:状态卡+三 tab(无配置 tab)。
class McpServerDetail extends ConsumerStatefulWidget {
  const McpServerDetail({required this.name, super.key});

  final String name;

  @override
  ConsumerState<McpServerDetail> createState() => _McpServerDetailState();
}

class _McpServerDetailState extends ConsumerState<McpServerDetail> {
  String _tab = 'tools';

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final s = (ref.watch(mcpServersProvider).value ?? const <McpServerStatus>[])
        .where((r) => r.name == widget.name)
        .firstOrNull;
    if (s == null) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        AnStatusDot(mcpDot(s.status) ?? AnStatus.idle),
        const SizedBox(width: AnSpace.s8),
        Text(s.name, style: AnText.mono.copyWith(color: c.ink)),
        const SizedBox(width: AnSpace.s8),
        AnChip(statusLabel(t, s.status),
            tone: s.status == 'ready'
                ? AnTone.ok
                : s.status == 'failed'
                    ? AnTone.danger
                    : AnTone.none),
        const Spacer(),
        AnButton(
          label: t.settings.mcp.reconnect,
          size: AnButtonSize.sm,
          // Error-handle like the roster row — a throwing reconnect must toast, not escape unhandled.
          // 与名册行同款兜错:reconnect 抛错须 toast、不裸逃。
          onPressed: () async {
            try {
              await ref.read(mcpServersProvider.notifier).reconnect(s.name);
            } on ApiException catch (e) {
              ref.read(overlayProvider.notifier).showToast(e.message, tone: AnTone.danger);
            }
          },
        ),
        const SizedBox(width: AnSpace.s8),
        AnButton(
          label: t.settings.mcp.deleteServer,
          size: AnButtonSize.sm,
          variant: AnButtonVariant.danger,
          onPressed: () => deleteMcpServer(context, ref, s.name),
        ),
      ]),
      if (s.lastError != null && s.lastError!.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s8),
        Text('${t.settings.mcp.lastError} · ${s.lastError}',
            style: AnText.label.copyWith(color: c.danger)),
        if (s.consecutiveFailures > 0)
          Text('${t.settings.mcp.consecutiveFailures} · ${s.consecutiveFailures}',
              style: AnText.label.copyWith(color: c.inkFaint)),
      ],
      const SizedBox(height: AnSpace.s16),
      // AnTabs' pane stack needs a bounded height inside the document flow. tab 区在文档流中定高。
      SizedBox(
          height: AnSize.tabPane,
          child: AnTabs(
        value: _tab,
        onSelect: (k) => setState(() => _tab = k),
        items: [
          AnTabsItem(
              key: 'tools',
              label: t.settings.mcp.tabTools,
              count: '${s.tools.length}',
              pane: _ToolsPane(tools: s.tools)),
          AnTabsItem(
              key: 'calls',
              label: t.settings.mcp.tabCalls,
              pane: _CallsPane(name: s.name)),
          AnTabsItem(
              key: 'stderr',
              label: t.settings.mcp.tabStderr,
              pane: _StderrPane(name: s.name)),
        ],
      )),
    ]);
  }
}

class _ToolsPane extends StatelessWidget {
  const _ToolsPane({required this.tools});

  final List<McpToolDef> tools;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    if (tools.isEmpty) {
      return AnState(kind: AnStateKind.empty, size: AnStateSize.inset, title: t.settings.mcp.noTools);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: AnSpace.s8),
      for (final tool in tools)
        AnRow(
          leadless: true,
          label: tool.name,
          mono: true,
          hint: tool.description,
          passive: true,
        ),
    ]);
  }
}

class _CallsPane extends ConsumerWidget {
  const _CallsPane({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final c = context.colors;
    final page = ref.watch(mcpCallsProvider(name)).value;
    if (page == null || page.calls.isEmpty) {
      return AnState(kind: AnStateKind.empty, size: AnStateSize.inset, title: t.settings.mcp.noCalls);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: AnSpace.s8),
      Text(t.settings.mcp.callsAgg(ok: page.okCount, failed: page.failedCount),
          style: AnText.label.copyWith(color: c.inkMuted)),
      const SizedBox(height: AnSpace.s8),
      for (final call in page.calls)
        AnRow(
          dot: call.status == 'ok' ? AnStatus.done : AnStatus.err,
          label: call.tool,
          mono: true,
          meta: '${call.triggeredBy} · ${call.elapsedMs}ms',
          passive: true,
        ),
    ]);
  }
}

class _StderrPane extends ConsumerWidget {
  const _StderrPane({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final text = ref.watch(mcpStderrProvider(name)).value ?? '';
    if (text.isEmpty) {
      return AnState(kind: AnStateKind.empty, size: AnStateSize.inset, title: t.settings.mcp.noStderr);
    }
    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s8),
      child: AnTermViewport(text: text),
    );
  }
}
