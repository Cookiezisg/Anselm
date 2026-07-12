import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/an_json_tree.dart';
import '../../../core/ui/an_window.dart';
import '../../../core/ui/an_live_tail.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_catalog.dart';
import 'tool_card_skins.dart';

// F01 mount skins (B4 F01.5) — the per-agent DYNAMIC mount tools (an agent's equipped functions /
// handler methods / MCP tools appear as synthesized tools with structured names). Routed by NAME (safe,
// no shape guessing): `mcp__<server>__<tool>` → MCP skin; `<handler>__<method>` → handler-method skin.
// A bare function-mount name shares run_function's ExecutionResult shape → handled by F08 (B5).
// mount 三式:按名字路由(mcp__ / handler__ / 裸函数名);函数 mount 的 ExecutionResult 对陈随 F08 落。

/// Parse `mcp__<server>__<tool>` (leftmost split after the `mcp__` prefix). MCP 名解析(最左劈)。
({String server, String tool})? parseMcpName(String name) {
  if (!name.startsWith('mcp__')) return null;
  final rest = name.substring(5);
  final i = rest.indexOf('__');
  return i < 0 ? (server: rest, tool: '') : (server: rest.substring(0, i), tool: rest.substring(i + 2));
}

/// Parse `<handler>__<method>` (rightmost split; the method is the last segment). handler 名解析(最右劈)。
({String handler, String method})? parseHandlerName(String name) {
  final i = name.lastIndexOf('__');
  return i <= 0 ? null : (handler: name.substring(0, i), method: name.substring(i + 2));
}

/// Resolve a mount spec for a structured tool name, or null (not a mount). 解析 mount 规格。
ToolCardSpec? mountSpecFor(String toolName) {
  if (parseMcpName(toolName) != null) return _mcpToolSpec(toolName);
  // A handler-method mount uses `__` but is NOT an mcp__ name (checked above). handler__method。
  if (parseHandlerName(toolName) != null) return _handlerToolSpec(toolName);
  return null;
}

// ── MCP tool skin ──
final RegExp _mcpErr = RegExp(r'MCP_SERVER_NOT_FOUND|MCP_TOOL_NOT_FOUND|is not connected|MCP_SERVER_NOT_CONNECTED');

ToolCardSpec _mcpToolSpec(String toolName) {
  final p = parseMcpName(toolName)!;
  return ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.mcpCalling : t.chat.tool.mcpCalled,
    target: (s) => '${p.server}/${p.tool}',
    // An MCP resolution error is a danger receipt (auto-expand). MCP 解析错→红回执自动展开。
    receipt: (t, s) => _mcpErr.hasMatch(s.resultText) ? (text: t.chat.tool.mcpError, tone: ToolReceiptTone.danger) : null,
    body: _mcpToolBody,
  );
}

/// MCP tool body — LIVE: the progress stream as a rolling mono tail (the server's only live
/// signal; the result window is withheld — an empty mono shell mid-call says nothing, WRK-065).
/// SETTLED: the progress record (if any) over the result — the server's RAW string (no JSON wrapper,
/// unbounded size) in a capped mono window, NEVER rendered as markdown (opaque server output); an
/// error string → red. MCP 体:活=progress 滚动尾(结果窗留落定——空壳窗什么都没说);落定=progress
/// 记录 + 结果纯 mono 封顶(绝不当 markdown;错误红)。
Widget _mcpToolBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final live = toolLive(state);
  if (live) {
    // Empty-shell guard is built into the family head (whitespace-only renders nothing). 守卫内建。
    return AnLiveTail(state.progressText, style: AnLiveTailStyle.mono, tailLines: 12);
  }
  final result = state.resultText;
  final isErr = _mcpErr.hasMatch(result);
  final over = result.length > AnCap.window;
  final shown = over ? result.substring(0, AnCap.window) : result;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    // The streamed progress survives the settle as the call's record (above the result). 进度记录留档。
    if (state.progressText.trim().isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(bottom: AnSpace.s6),
        child: AnWindow(child: Text(state.progressText.trimRight(), style: AnText.code.copyWith(color: c.inkFaint), maxLines: 40, overflow: TextOverflow.ellipsis)),
      ),
    // The truncation note rides the window's footer slot (codex 族一 规则④,批4 复审). 注记进 footer 槽。
    AnWindow(
      footer: over ? Text(Translations.of(context).chat.tool.contentTruncated) : null,
      child: Text(shown, style: AnText.code.copyWith(color: isErr ? c.danger : c.inkMuted), maxLines: 200, overflow: TextOverflow.ellipsis),
    ),
  ]);
}

// ── handler-method tool skin ──
ToolCardSpec _handlerToolSpec(String toolName) {
  final p = parseHandlerName(toolName)!;
  return ToolCardSpec(
    verb: (t, {required bool live}) => live ? t.chat.tool.hdCalling : t.chat.tool.hdCalled,
    target: (s) => '${p.handler}.${p.method}()',
    body: _handlerToolBody,
  );
}

/// Handler-method body — LIVE: the streamed yields as a rolling mono tail (the result section is
/// withheld — a labelled empty «结果» window mid-call would lie, WRK-065). SETTLED: the yields record
/// + the result JSON `{result: <any>}`. handler 方法体:活=yield 滚动尾(结果段留落定——带标签的空窗
/// =撒谎);落定=yield 记录 + {result}。
Widget _handlerToolBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final live = toolLive(state);
  if (live) {
    return AnLiveTail(state.progressText, style: AnLiveTailStyle.mono, tailLines: 12);
  }
  Object? result;
  try {
    final d = jsonDecode(state.resultText);
    if (d is Map && d.containsKey('result')) result = d['result'];
  } catch (_) {}
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    // The streamed yields (if any) are the progress log. yield 流(如有)。
    if (state.progressText.isNotEmpty)
      Padding(padding: const EdgeInsets.only(bottom: AnSpace.s6), child: AnWindow(child: Text(state.progressText, style: AnText.code.copyWith(color: c.inkMuted), maxLines: 40, overflow: TextOverflow.ellipsis))),
    Text(t.chat.tool.hdResult, style: AnText.meta.copyWith(color: c.inkFaint)),
    const SizedBox(height: AnSpace.s2),
    AnWindow(
      child: result == null
          ? Text(state.resultText, style: AnText.code.copyWith(color: c.inkMuted), maxLines: 40, overflow: TextOverflow.ellipsis)
          : SizedBox(height: AnSize.jsonViewport, child: AnJsonTree(data: result, showRoot: false)),
    ),
  ]);
}
