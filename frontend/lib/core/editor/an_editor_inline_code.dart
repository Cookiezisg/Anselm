import 'package:super_editor/super_editor.dart';

/// Marks the non-breaking-space (U+00A0) PADDING characters we inject on each side of every inline-code
/// (`codeAttribution`) run. They give the paint-beneath rounded background REAL horizontal padding that PUSHES
/// neighbours apart — instead of a paint-time inflation that would overlap a glyph glued to the code (e.g.
/// `d\`c\`` → the gray would cover the `d`). The spacers ARE part of the code token (undeletable — the reconcile
/// re-adds them) and are stripped by the codec on save so the markdown stays `` `code` ``, never `` ` code ` ``.
/// NBSP not a plain space: a plain space collapses to zero width at a soft-wrap and is a break opportunity (the
/// code could wrap away from its pad); NBSP is line-break class "glue" — non-breaking, keeps its cell width.
/// 标记塞进行内代码两侧的 NBSP 内距字符:给 paint-beneath 圆角背景真水平内距、把邻居顶开(而非画膨胀盖住紧贴的字形);
/// 属代码 token 一部分(规整器补回=删不掉),存盘按此标记剥离(markdown 恒 `code` 不含内距空格)。用 NBSP 非普通空格:
/// 普通空格换行处折零宽且可断行(代码会和内距分家),NBSP 是「胶水」不折不断、宽度稳。
const codeSpacerAttribution = NamedAttribution('code_spacer');

const _nbsp =
    ' '; // NON-BREAKING SPACE (U+00A0) — real width, non-collapsing, non-breaking

bool _isSpacerAt(AttributedText text, int offset) =>
    offset >= 0 &&
    offset < text.length &&
    text.getAllAttributionsAt(offset).contains(codeSpacerAttribution);

/// Idempotently ensure every `codeAttribution` run in [source] is flanked by a spacer-NBSP on each side. Returns
/// the (possibly new) text + the ASCENDING original offsets where a spacer was inserted (so a caret/selection
/// can be remapped by counting inserts at-or-before it). A run already flanked by spacers is left untouched →
/// idempotent (safe to run on every edit without an infinite loop). 幂等:保证每个 codeAttribution run 两侧各有一个
/// spacer-NBSP;返回(可能新的)文本 + 插入点原始偏移升序(供光标/选区按「≤此偏移的插入数」平移)。已带 spacer 的不动。
({AttributedText text, List<int> inserts}) padCodeRuns(AttributedText source) {
  // DESCENDING by start so inserting for a later (higher) run never shifts an earlier run's original offsets.
  // 降序处理:先补靠后的 run,不动靠前 run 的原始偏移。
  final spans = source.getAttributionSpans({codeAttribution}).toList()
    ..sort((a, b) => b.start.compareTo(a.start));
  var text = source;
  final inserts = <int>[];
  for (final span in spans) {
    // Trailing first (higher offset) then leading, so span.start stays valid for the leading insert. 先尾后头。
    if (!_isSpacerAt(text, span.end)) {
      final at = span.end + 1;
      text = text.insertString(
        textToInsert: _nbsp,
        startOffset: at,
        applyAttributions: {codeAttribution, codeSpacerAttribution},
      );
      inserts.add(at);
    }
    if (!_isSpacerAt(text, span.start)) {
      final at = span.start;
      text = text.insertString(
        textToInsert: _nbsp,
        startOffset: at,
        applyAttributions: {codeAttribution, codeSpacerAttribution},
      );
      inserts.add(at);
    }
  }
  inserts.sort();
  return (text: text, inserts: inserts);
}

/// Remove every spacer-NBSP (the padding chars carrying [codeSpacerAttribution]) — used by the codec on SAVE so
/// the serialized markdown is `` `code` `` with no injected padding. 剥离所有 spacer-NBSP(存盘用,markdown 无内距空格)。
AttributedText stripCodeSpacers(AttributedText source) {
  final spacers = source.getAttributionSpans({codeSpacerAttribution}).toList()
    ..sort((a, b) => b.start.compareTo(a.start));
  var text = source;
  for (final s in spacers) {
    text = text.removeRegion(
      startOffset: s.start,
      endOffset: s.end + 1,
    ); // DESCENDING → earlier offsets stay valid
  }
  return text;
}

DocumentPosition _remapPosition(
  DocumentPosition pos,
  String nodeId,
  List<int> inserts,
) {
  if (pos.nodeId != nodeId || pos.nodePosition is! TextNodePosition) return pos;
  final off = (pos.nodePosition as TextNodePosition).offset;
  final shift = inserts
      .where((o) => o <= off)
      .length; // each spacer inserted at/before the offset pushes it right
  return DocumentPosition(
    nodeId: nodeId,
    nodePosition: TextNodePosition(offset: off + shift),
  );
}

/// Keeps every inline-code run padded with real NBSP spacers (see [codeSpacerAttribution]). Runs in `react`
/// AFTER inline code is created (typed `` `x` `` conversion or the toolbar toggle) and re-pads if a spacer was
/// deleted — that is what makes the padding "undeletable". Idempotent: it mutates ONLY when an inline-code run
/// lacks its spacers, so on the vast majority of edits it is a pure no-op (and it can't loop — a padded run is
/// left untouched). It does NOT guard on the composing region: an unpadded run only ever appears the instant
/// code is CREATED (a committed backtick conversion or the toolbar toggle — never mid-CJK-composition, which
/// happens on already-padded or non-code text), so mutating is safe there. Because the ReplaceNode restructures
/// the text, it clears the now-stale composing region afterwards. Only the node under the selection is
/// reconciled (the just-edited one; load/paste padding is handled by the codec's [padCodeRuns]).
/// 保持行内代码两侧真 NBSP 内距:代码创建后补、被删后补回(=删不掉)。幂等——只在缺 spacer 时动,故绝大多数编辑是纯 no-op、
/// 不会死循环。不守组字区:缺 spacer 的 run 只在代码「创建瞬间」出现(已提交的反引号转换或工具条 toggle,绝非 CJK 组字中——
/// 组字发生在已内距或非代码文本上),故此刻改是安全的;ReplaceNode 重构文本后顺手清掉已失效的组字区。
class CodePadReconcileReaction extends EditReaction {
  const CodePadReconcileReaction();

  @override
  void react(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    final composer = editorContext.find<MutableDocumentComposer>(
      Editor.composerKey,
    );
    final sel = composer.selection;
    if (sel == null) return;
    final document = editorContext.find<MutableDocument>(Editor.documentKey);
    final node = document.getNodeById(sel.extent.nodeId);
    if (node is! TextNode) return;
    final padded = padCodeRuns(node.text);
    if (padded.inserts.isEmpty) {
      return; // already fully padded — idempotent no-op (the common case)
    }
    requestDispatcher.execute([
      ReplaceNodeRequest(
        existingNodeId: node.id,
        newNode: node.copyTextNodeWith(text: padded.text),
      ),
      ChangeSelectionRequest(
        DocumentSelection(
          base: _remapPosition(sel.base, node.id, padded.inserts),
          extent: _remapPosition(sel.extent, node.id, padded.inserts),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.contentChange,
      ),
      // The text was restructured — drop the now-stale composing region. 文本已重构,清失效组字区。
      const ClearComposingRegionRequest(),
    ]);
  }
}

/// Wraps super_editor's OFFICIAL inline-markdown-on-type reaction ([MarkdownInlineUpstreamSyntaxReaction]) so
/// typing a closed `**bold**` / `*italic*` / `~strike~` / `` `code` `` / `[name](url)` immediately upstream of
/// the caret converts it to the attribution — BUT with a placeholder guard: the dev.40 parser casts every
/// upstream character to `String` (markdown_inline_upstream_plugin.dart:269/281) and throws on an inline
/// placeholder (a @mention pill). So we skip conversion whenever any placeholder sits upstream of the caret in
/// its node. Inline code becomes a plain `codeAttribution` run — it renders as WRAPPING editable text with a
/// rounded background painted BENEATH it by AnTextComponent (the paint-beneath design), not an atomic chip.
/// 官方行内 markdown 即打即转的占位符守卫(dev.40 parser 对上游占位符 cast String 会崩,故光标上游有占位符时跳过);
/// 行内代码=可换行的 codeAttribution 文本,由 AnTextComponent 底层画圆角背景(paint-beneath),非原子芯片。
class InlineMarkdownReaction extends EditReaction {
  const InlineMarkdownReaction()
    : _inner = const MarkdownInlineUpstreamSyntaxReaction(
        defaultUpstreamInlineMarkdownParsers,
      );

  final MarkdownInlineUpstreamSyntaxReaction _inner;

  @override
  void react(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    final composer = editorContext.find<MutableDocumentComposer>(
      Editor.composerKey,
    );
    final sel = composer.selection;
    if (sel != null &&
        sel.isCollapsed &&
        sel.extent.nodePosition is TextNodePosition) {
      final node = editorContext
          .find<MutableDocument>(Editor.documentKey)
          .getNodeById(sel.extent.nodeId);
      final caret = (sel.extent.nodePosition as TextNodePosition).offset;
      if (node is TextNode &&
          node.text.placeholders.keys.any((offset) => offset < caret)) {
        return; // a placeholder is upstream of the caret — the dev.40 parser would crash casting it to String
      }
    }
    _inner.react(editorContext, requestDispatcher, changeList);
  }
}
