
import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_skins.dart';

/// A PROSE READING WINDOW (WRK-056 #11) — settled rendered content (AnMarkdown 15/1.6) inside the ONE
/// window shell ([AnWindow], WRK-066 族一 — the hand-rolled surface+hairline Container is retired),
/// fade-collapsed past [AnSize.proseViewport] so a long document/skill/approval body doesn't own an
/// unbounded wall. What the model authored, read as a TYPESET page (not a source wall).
/// 散文阅读窗:落定排版态住唯一窗壳(手搓白框退役,批4)+ 超高 FadeCollapse(长文不背无界墙);
/// 读成成品排版、非源码。
class ProseWindow extends StatelessWidget {
  const ProseWindow({required this.markdown, this.collapsedHeight = AnSize.proseViewport, super.key});

  final String markdown;
  final double collapsedHeight;

  @override
  Widget build(BuildContext context) {
    // Only clamp+fade when the prose is long enough to plausibly overflow the collapsed height —
    // AnFadeCollapse always reserves its full height + a toggle, so a SHORT answer (invoke_agent's
    // one-sentence result, a short doc) would otherwise sit in a tall empty box with a pointless
    // «展开全文». Length-based (allowed — it's a size decision, not markdown sniffing). 短稿内联、不装长盒。
    final long = markdown.length > AnCap.proseFoldChars || '\n'.allMatches(markdown).length > AnCap.proseFoldLines;
    return AnWindow(
      maxHeight: long ? collapsedHeight : null,
      collapsible: long,
      child: AnMarkdown(markdown),
    );
  }
}

// ── document (soft-fail family: the result is an English SENTENCE, not JSON) ──

const _docOkPrefixes = ['Created document', 'Updated document', 'Moved', 'Deleted document'];

bool _docSucceeded(String result) => _docOkPrefixes.any(result.trimLeft().startsWith);

/// The document collapsed-row receipt — parsed from the result SENTENCE (document ops fail SOFT: a
/// success reads `Created document "X" (id=…, path=…)`, a failure is a plain English prompt). Success →
/// the path's last segment; a soft failure → warn `未生效`. document 回执:成功句取 path 尾段,软失败→warn。
ToolReceipt? docSentenceReceipt(Translations t, ToolCardState state) {
  final r = state.resultText.trim();
  if (r.isEmpty) return null;
  if (!_docSucceeded(r)) return (text: t.chat.tool.docSoftFail, tone: ToolReceiptTone.warn);
  final m = RegExp(r'path=([^)]+)\)').firstMatch(r);
  if (m == null) return null;
  final tail = m.group(1)!.split('/').where((s) => s.isNotEmpty).lastOrNull;
  return tail == null ? null : (text: tail, tone: ToolReceiptTone.none);
}

/// document body: the authored content as a TYPESET prose window; a soft failure reframes the English
/// sentence as an amber note (never a code wall); an auto-rename (create's silent conflict handling) is
/// surfaced. document 落定体:排版态稿子;软失败→琥珀注记;自动改名必显。
Widget documentBody(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final c = context.colors;
  // LIVE face (WRK-066 族六): the prose streaming in as the LLM types it — the prose tail face
  // (bottom-pinned: the newest words stay visible; typesetting a half-written markdown would render
  // broken). The head slices its own O(tail) — the possibly-MB draft is safe to hand over (批1 复审:
  // caller-side contracts get forgotten). 活脸:稿子随打字流入——prose 尾脸(贴底=最新字恒可见;半截
  // markdown 排版会碎)。O(tail) 族头内建,全稿可直喂(批1 复审:调用侧契约必有人忘)。
  if (toolLive(state)) {
    final draft = state.argsSession.liveStringNamed('content');
    if (draft == null) return const SizedBox.shrink();
    return AnLiveTail(draft, style: AnLiveTailStyle.prose);
  }
  final result = state.resultText.trim();
  // Session read, closed-only: this settled body is CONSTRUCTED every frame while streaming (hidden
  // inside the collapsed reveal) — an O(bytes) argsText rescan per frame melts on MB-scale content.
  // 会话闭合值:settled 体在流入期每帧被隐形构造——O(字节) 重扫在 MB 级必炸。
  final content = state.argsSession.closedStringAt(['content']) ?? '';

  if (result.isNotEmpty && !_docSucceeded(result)) {
    // Soft failure — the backend's English prompt, framed calmly (not red): the one soft-fail face
    // (AnCallout warn, same as entity_get_bodies ×6). 软失败:后端英文提示,琥珀 callout 唯一脸。
    return AnCallout(result, severity: AnCalloutSeverity.warn);
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    toolIntent(context, state),
    if (content.isNotEmpty) ProseWindow(markdown: content),
    if (result.contains('auto-renamed'))
      Padding(
        padding: const EdgeInsets.only(top: AnSpace.s6),
        child: Text(t.chat.tool.docAutoRenamed, style: AnText.label.copyWith(color: c.warn)),
      ),
  ]);
}

// ── skill (hard-fail family: JSON {created|updated: name}; whole replace; no versions) ──

/// The skill collapsed-row receipt — the created/updated slug from the JSON result. skill 回执:slug。
ToolReceipt? skillReceipt(Translations t, ToolCardState state) {
  final d = state.resultObj; // C-028: memoized decode 记忆化解码
  if (d != null) {
    final name = d['created'] ?? d['updated'];
    if (name is String && name.isNotEmpty) return (text: name, tone: ToolReceiptTone.none);
  }
  return null;
}

/// skill body: the SKILL.md instructions as a typeset prose window + the frontmatter chips — context
/// (inline/fork) and, crucially, the **allowedTools in WARN tone** (activation pre-authorizes those
/// tools, skipping the danger gate — a permission grant the user must see at a glance) — plus, on edit,
/// the honest small print that a skill has NO version to revert to (whole overwrite).
/// skill 落定体:排版态指令 + frontmatter chips(context + **警示色 allowedTools**[激活免确认=权限让渡]);
/// edit 附小字「整份覆盖·无版本可回退」。
Widget skillBody(BuildContext context, ToolCardState state) {
  final t = Translations.of(context);
  final c = context.colors;
  // LIVE face (WRK-066 族六): the SKILL.md body streaming in — the prose tail face, same rationale
  // as document (the head owns O(tail)). 活脸:正文流入——prose 尾脸,与 document 同理(族头扛 O(tail))。
  if (toolLive(state)) {
    final draft = state.argsSession.liveStringNamed('body');
    if (draft == null) return const SizedBox.shrink();
    return AnLiveTail(draft, style: AnLiveTailStyle.prose);
  }
  final body = state.argsSession.closedStringAt(['body']) ?? '';
  final ctx = state.argsSession.closedStringAt(['context']) ?? 'inline';
  final allowed = argStringList(state.argsText, 'allowedTools');
  final isEdit = state.toolName == 'edit_skill';

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    toolIntent(context, state),
    Wrap(spacing: AnGap.inline, runSpacing: AnGap.stackTight, crossAxisAlignment: WrapCrossAlignment.center, children: [
      AnChip(ctx == 'fork' ? t.chat.tool.skillFork : t.chat.tool.skillInline, tone: AnTone.none),
      // allowedTools in WARN — activation pre-authorizes these, skipping the danger gate. 警示色:权限让渡。
      for (final tool in allowed) AnChip(tool, tone: AnTone.warn),
    ]),
    if (allowed.isNotEmpty)
      Padding(padding: const EdgeInsets.only(top: AnSpace.s4), child: Text(t.chat.tool.skillPreauth, style: AnText.meta.copyWith(color: c.warn))),
    const SizedBox(height: AnGap.block),
    if (body.isNotEmpty) ProseWindow(markdown: body),
    if (isEdit)
      Padding(padding: const EdgeInsets.only(top: AnSpace.s6), child: Text(t.chat.tool.skillNoRevert, style: AnText.meta.copyWith(color: c.inkFaint))),
  ]);
}
