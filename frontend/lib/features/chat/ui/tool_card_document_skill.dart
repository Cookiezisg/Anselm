import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';

/// A PROSE READING WINDOW (WRK-056 #11) — settled rendered content (AnMarkdown 15/1.6) inside a bordered
/// surface, FadeCollapse'd past a height so a long document/skill/approval body doesn't own an unbounded
/// wall. What the model authored, read as a TYPESET page (not a source wall). 散文阅读窗:落定排版态 +
/// 超高 FadeCollapse(长文不背无界墙);读成成品排版、非源码。
class ProseWindow extends StatelessWidget {
  const ProseWindow({required this.markdown, this.collapsedHeight = 340, super.key});

  final String markdown;
  final double collapsedHeight;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    // Only clamp+fade when the prose is long enough to plausibly overflow the collapsed height —
    // AnFadeCollapse always reserves its full height + a toggle, so a SHORT answer (invoke_agent's
    // one-sentence result, a short doc) would otherwise sit in a tall empty box with a pointless
    // «展开全文». Length-based (allowed — it's a size decision, not markdown sniffing). 短稿内联、不装长盒。
    final long = markdown.length > 480 || '\n'.allMatches(markdown).length > 10;
    return Container(
      width: double.infinity,
      padding: AnInset.card,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.card),
      ),
      child: long
          ? AnFadeCollapse(
              collapsible: true,
              collapsedHeight: collapsedHeight,
              expandLabel: t.chat.tool.proseExpand,
              collapseLabel: t.chat.tool.proseCollapse,
              fadeColor: c.surface,
              child: AnMarkdown(markdown),
            )
          : AnMarkdown(markdown),
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
  final result = state.resultText.trim();
  // Session read, closed-only: this settled body is CONSTRUCTED every frame while streaming (hidden
  // inside the collapsed reveal) — an O(bytes) argsText rescan per frame melts on MB-scale content.
  // 会话闭合值:settled 体在流入期每帧被隐形构造——O(字节) 重扫在 MB 级必炸。
  final content = state.argsSession.closedStringAt(['content']) ?? '';

  if (result.isNotEmpty && !_docSucceeded(result)) {
    // Soft failure — the backend's English prompt, framed calmly (not red). 软失败:后端英文提示,琥珀。
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(AnIcons.info, size: AnSize.icon, color: c.warn),
      const SizedBox(width: AnSpace.s6),
      Expanded(child: Text(result, style: AnText.body.copyWith(color: c.inkMuted))),
    ]);
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (state.summary.isNotEmpty)
      Padding(padding: const EdgeInsets.only(bottom: AnSpace.s6), child: Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted))),
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
  try {
    final d = jsonDecode(state.resultText);
    if (d is Map<String, dynamic>) {
      final name = d['created'] ?? d['updated'];
      if (name is String && name.isNotEmpty) return (text: name, tone: ToolReceiptTone.none);
    }
  } catch (_) {}
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
  final body = state.argsSession.closedStringAt(['body']) ?? '';
  final ctx = state.argsSession.closedStringAt(['context']) ?? 'inline';
  final allowed = argStringList(state.argsText, 'allowedTools');
  final isEdit = state.toolName == 'edit_skill';

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (state.summary.isNotEmpty)
      Padding(padding: const EdgeInsets.only(bottom: AnSpace.s6), child: Text(state.summary, style: AnText.meta.copyWith(color: c.inkMuted))),
    Wrap(spacing: AnGap.inline, runSpacing: AnSpace.s4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      AnBadge(ctx == 'fork' ? t.chat.tool.skillFork : t.chat.tool.skillInline, tone: AnTone.none),
      // allowedTools in WARN — activation pre-authorizes these, skipping the danger gate. 警示色:权限让渡。
      for (final tool in allowed) AnBadge(tool, tone: AnTone.warn),
    ]),
    if (allowed.isNotEmpty)
      Padding(padding: const EdgeInsets.only(top: AnSpace.s4), child: Text(t.chat.tool.skillPreauth, style: AnText.meta.copyWith(color: c.warn))),
    const SizedBox(height: AnGap.block),
    if (body.isNotEmpty) ProseWindow(markdown: body),
    if (isEdit)
      Padding(padding: const EdgeInsets.only(top: AnSpace.s6), child: Text(t.chat.tool.skillNoRevert, style: AnText.meta.copyWith(color: c.inkFaint))),
  ]);
}
