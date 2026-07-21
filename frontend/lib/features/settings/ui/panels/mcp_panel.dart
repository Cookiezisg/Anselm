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
      'mcpServer' => McpServerDetail(
        name: detail!.id!,
        key: ValueKey(detail.id),
      ),
      'mcpAdd' => const McpManualForm(),
      'mcpImport' => const McpImportForm(),
      'mcpMarket' => const McpMarket(),
      'mcpInstall' => McpInstallForm(
        fullName: detail!.id!,
        key: ValueKey(detail.id),
      ),
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
    final rows =
        ref.watch(mcpServersProvider).value ?? const <McpServerStatus>[];
    final ready = rows.where((s) => s.status == 'ready').length;
    final failed = rows.where((s) => s.status == 'failed').length;
    // Zero counts are noise, not information — each segment renders only when n>0 (0719 P1-3);
    // with no servers at all, the empty state below IS the answer. 零计数是噪声:分段 n>0 才显;
    // 一台都没有时,下方空态即答案。
    final statParts = [
      if (rows.isNotEmpty) t.settings.mcp.statCount(n: rows.length),
      if (ready > 0) t.settings.mcp.statReady(n: ready),
      if (failed > 0) t.settings.mcp.statFailed(n: failed),
    ];

    final empty = rows.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: statParts.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      statParts.join(' · '),
                      style: AnText.label.copyWith(color: c.inkMuted),
                    ),
            ),
            // With nothing installed the marketplace IS the body below — the «浏览市场» button would only
            // push the same list as a detail, so it retires until there's an installed roster to sit above.
            // 空态市场即下方主体,浏览钮冗余 → 装了第一个后再现。
            if (!empty) ...[
              AnButton(
                label: t.settings.mcp.browse,
                variant: AnButtonVariant.primary,
                size: AnButtonSize.sm,
                onPressed: () =>
                    ref.read(settingsDetailProvider.notifier).push('mcpMarket'),
              ),
              const SizedBox(width: AnSpace.s8),
            ],
            AnButton(
              label: t.settings.mcp.manualAdd,
              size: AnButtonSize.sm,
              outline: true,
              onPressed: () =>
                  ref.read(settingsDetailProvider.notifier).push('mcpAdd'),
            ),
            const SizedBox(width: AnSpace.s8),
            AnButton(
              label: t.settings.mcp.importJson,
              size: AnButtonSize.sm,
              outline: true,
              onPressed: () =>
                  ref.read(settingsDetailProvider.notifier).push('mcpImport'),
            ),
          ],
        ),
        const SizedBox(height: AnSpace.s16),
        if (empty) ...[
          // Zero MCP → the marketplace takes over the panel body (empty-state-as-target-shape): a quiet
          // one-line lead, then the FULL market (search + hover-install cards) top under the panel head.
          // The «Installed» section — its group head included — simply does not render (零计数律); it grows
          // in once the first server lands and the market retreats behind 浏览市场 (the branch above).
          // 零 MCP → 市场承接面板主体(空态穿目标形态律):一句安静引导 + 全列市场;「已安装」区含组头整个不渲
          // (零计数律),装了第一个才长出、市场退居浏览钮之后。
          Text(
            t.settings.mcp.marketEmptyLead,
            style: AnText.label.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: AnSpace.s12),
          const McpMarket(),
        ] else
          // Installed = two-column brand cards (0719 重造): identity + status at the head, the
          // stats line under it, the honest error line when failed, ⋯ for the verbs. 已装=双列
          // 品牌卡:头行身份+状态点,下行统计,失败时诚实错误句,动词收 ⋯。
          AnAutoGrid(
            minColWidth: AnSize.block,
            children: [for (final s in rows) _ServerCard(s: s)],
          ),
      ],
    );
  }
}

class _ServerCard extends ConsumerWidget {
  const _ServerCard({required this.s});

  final McpServerStatus s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final c = context.colors;
    // Zero counts are noise (P1-3) — stat segments render only when n>0. 零计数不显。
    final statParts = [
      statusLabel(t, s.status),
      if (s.tools.isNotEmpty) t.settings.mcp.tools(n: s.tools.length),
      if (s.totalCalls > 0) t.settings.mcp.calls(n: s.totalCalls),
    ];
    return AnCard(
      selectable: true,
      onSelect: () => ref
          .read(settingsDetailProvider.notifier)
          .push('mcpServer', id: s.name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              brandIconOr(
                mcpBrandFor(s.name),
                fallbackLabel: s.name,
                size: AnBrandSize.sm,
              ),
              const SizedBox(width: AnSpace.s8),
              Expanded(
                child: Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.mono.copyWith(color: c.ink),
                ),
              ),
              if (mcpDot(s.status) != null) AnStatusDot(mcpDot(s.status)!),
              const SizedBox(width: AnSpace.s6),
              AnMenu(
                entries: [
                  AnMenuItem(
                    label: t.settings.mcp.reconnect,
                    icon: AnIcons.undo,
                    onTap: () async {
                      try {
                        await ref
                            .read(mcpServersProvider.notifier)
                            .reconnect(s.name);
                      } on ApiException catch (e) {
                        ref
                            .read(noticeCenterProvider.notifier)
                            .show(e.message, tone: AnTone.danger);
                      }
                    },
                  ),
                  AnMenuItem(
                    label: t.settings.mcp.deleteServer,
                    danger: true,
                    onTap: () => deleteMcpServer(context, ref, s.name),
                  ),
                ],
                anchorBuilder: (context, toggle, isOpen) => AnButton.iconOnly(
                  AnIcons.more,
                  size: AnButtonSize.sm,
                  onPressed: toggle,
                  semanticLabel: t.settings.mcp.cardMenu,
                ),
              ),
            ],
          ),
          const SizedBox(height: AnSpace.s6),
          Text(
            statParts.join(' · '),
            style: AnText.meta.copyWith(color: c.inkMuted),
          ),
          if ((s.lastError ?? '').isNotEmpty) ...[
            const SizedBox(height: AnSpace.s4),
            Text(
              s.lastError!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AnText.meta.copyWith(color: c.danger),
            ),
          ],
        ],
      ),
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

Future<void> deleteMcpServer(
  BuildContext context,
  WidgetRef ref,
  String name,
) async {
  final t = Translations.of(context);
  final ok = await ref
      .read(overlayProvider.notifier)
      .confirm(
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
    ref
        .read(noticeCenterProvider.notifier)
        .show(e.message, tone: AnTone.danger);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AnStatusDot(mcpDot(s.status) ?? AnStatus.idle),
            const SizedBox(width: AnSpace.s8),
            Text(s.name, style: AnText.mono.copyWith(color: c.ink)),
            const SizedBox(width: AnSpace.s8),
            AnChip(
              statusLabel(t, s.status),
              tone: s.status == 'ready'
                  ? AnTone.ok
                  : s.status == 'failed'
                  ? AnTone.danger
                  : AnTone.none,
            ),
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
                  ref
                      .read(noticeCenterProvider.notifier)
                      .show(e.message, tone: AnTone.danger);
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
          ],
        ),
        if (s.lastError != null && s.lastError!.isNotEmpty) ...[
          const SizedBox(height: AnSpace.s8),
          Text(
            '${t.settings.mcp.lastError} · ${s.lastError}',
            style: AnText.label.copyWith(color: c.danger),
          ),
          if (s.consecutiveFailures > 0)
            Text(
              '${t.settings.mcp.consecutiveFailures} · ${s.consecutiveFailures}',
              style: AnText.label.copyWith(color: c.inkFaint),
            ),
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
                pane: _ToolsPane(tools: s.tools),
              ),
              AnTabsItem(
                key: 'calls',
                label: t.settings.mcp.tabCalls,
                pane: _CallsPane(name: s.name),
              ),
              AnTabsItem(
                key: 'stderr',
                label: t.settings.mcp.tabStderr,
                pane: _StderrPane(name: s.name),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolsPane extends StatelessWidget {
  const _ToolsPane({required this.tools});

  final List<McpToolDef> tools;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    if (tools.isEmpty) {
      return AnState(
        kind: AnStateKind.empty,
        size: AnStateSize.inset,
        title: t.settings.mcp.noTools,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AnSpace.s8),
        for (final tool in tools)
          AnRow(
            leadless: true,
            label: tool.name,
            mono: true,
            hint: tool.description,
            passive: true,
          ),
      ],
    );
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
      return AnState(
        kind: AnStateKind.empty,
        size: AnStateSize.inset,
        title: t.settings.mcp.noCalls,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AnSpace.s8),
        Text(
          t.settings.mcp.callsAgg(ok: page.okCount, failed: page.failedCount),
          style: AnText.label.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: AnSpace.s8),
        for (final call in page.calls)
          AnRow(
            dot: call.status == 'ok' ? AnStatus.done : AnStatus.err,
            label: call.tool,
            mono: true,
            meta: '${call.triggeredBy} · ${call.elapsedMs}ms',
            passive: true,
          ),
      ],
    );
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
      return AnState(
        kind: AnStateKind.empty,
        size: AnStateSize.inset,
        title: t.settings.mcp.noStderr,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s8),
      child: AnTermViewport(text: text),
    );
  }
}
