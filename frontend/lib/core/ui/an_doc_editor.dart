import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../entity/mention_source.dart';
import 'an_mention_picker.dart';

/// The @ mention trigger rule — Notion-style: `@` opens a token that ends on whitespace / a dot / a
/// newline. Committed mentions may still contain spaces (they're frozen text, not re-parsed). @ 规则:空白/点/换行结束 token。
const _mentionTagRule = TagRule(trigger: '@', excludedCharacters: {' ', '.', '\n'});

/// AnDocEditor — the Notion-style WYSIWYG markdown editor, a token-locked FACADE over `super_editor`
/// (pinned dev.40; only this file + the round-trip spike import it). **markdown is the source of truth**:
/// [initialMarkdown] deserializes into the editor's block document, and every edit serializes back to a
/// markdown string via [onChanged] (strict CommonMark — the backend stores plain markdown). The ENTIRE
/// look is authored from design tokens (AnText.reading two-weight body / AnColors ink+selection / AnFlow
/// vertical rhythm) — super_editor ships unstyled, so there is no Material chrome to fight. Headings breathe
/// MORE above than below (AnFlow.headingTop), matching AnMarkdown's read rhythm.
///
/// **@ typeahead** (when [mentionSource] is supplied): typing `@` opens a caret-anchored [AnMentionPanel]
/// fed by the shared [MentionSource] DIP (the SAME seam chat's composer uses — entities stay decoupled).
/// Arrow keys move the active row, Enter/Tab pick, Esc cancels; a pick inserts `@name ` committed as an
/// atomic mention span. The `[[id]]` round-trip codec (a mention serializing to a wikilink instead of plain
/// `@name`) + the `/` slash block menu are the P3.3/P3.4 follow-ups on top of this.
///
/// AnDocEditor:super_editor 的 Notion 式 token 锁定门面。markdown 为真相(load→edit→serialize);整套外观
/// 走设计 token(reading 两字重 / AnColors / AnFlow 节奏),super_editor 无内建样式故不打架;标题上方留多。
/// **@ 预输入**(给 [mentionSource] 时):打 `@` 弹 caret 锚定面板,复用 chat 同款 MentionSource 缝;方向键移动、
/// 回车/Tab 选、Esc 取消;选中插 `@name ` 原子 mention。`[[id]]` 往返 codec + `/` 斜杠菜单是后续。
class AnDocEditor extends StatefulWidget {
  const AnDocEditor({
    required this.initialMarkdown,
    this.onChanged,
    this.mentionSource,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// The markdown source of truth to load. Changing it (a new document selected) rebuilds the editor.
  /// 加载的真相 markdown;变更(选了新文档)即重建编辑器。
  final String initialMarkdown;

  /// Fires the serialized markdown on every edit (the consumer debounces the PATCH-save). 每次编辑派出序列化 markdown。
  final ValueChanged<String>? onChanged;

  /// The @ mention data seam (from the app's `mentionSourceProvider`). `null` → @ typeahead off (read-only /
  /// preview surfaces pass null). @ 数据缝(app 的 mentionSourceProvider);null=关(只读/预览面传 null)。
  final MentionSource? mentionSource;

  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<AnDocEditor> createState() => _AnDocEditorState();
}

class _AnDocEditorState extends State<AnDocEditor> {
  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _editor;
  StableTagPlugin? _mentionPlugin;
  FocusNode? _ownFocus;

  // ── @ typeahead state @ 预输入态 ──
  final GlobalKey _docLayoutKey = GlobalKey();
  final OverlayPortalController _portal = OverlayPortalController();
  List<MentionCandidate> _candidates = const [];
  int _activeIndex = 0;
  Offset _anchor = Offset.zero; // GLOBAL bottom-left of the @token span → the panel hangs just below. @token 全局左下。
  int _queryToken = 0; // in-flight guard: a stale async result must not clobber a newer token. 异步竞态守卫。

  @override
  void initState() {
    super.initState();
    _build(widget.initialMarkdown);
  }

  @override
  void didUpdateWidget(AnDocEditor old) {
    super.didUpdateWidget(old);
    // A different source (new document opened) → rebuild the block document from the new markdown. 换文档即重建。
    if (widget.initialMarkdown != old.initialMarkdown) {
      _teardown();
      setState(() => _build(widget.initialMarkdown));
    }
  }

  void _build(String markdown) {
    _doc = deserializeMarkdownToDocument(markdown, syntax: MarkdownSyntax.normal);
    _composer = MutableDocumentComposer();
    _mentionPlugin = widget.mentionSource == null ? null : StableTagPlugin(tagRule: _mentionTagRule);
    _editor = createDefaultDocumentEditor(document: _doc, composer: _composer);
    _doc.addListener(_onChange);
    _mentionPlugin?.tagIndex.composingStableTag.addListener(_onComposingTag);
  }

  void _teardown() {
    _doc.removeListener(_onChange);
    _mentionPlugin?.tagIndex.composingStableTag.removeListener(_onComposingTag);
    if (_portal.isShowing) _portal.hide();
    _editor.dispose();
    _composer.dispose();
  }

  void _onChange(DocumentChangeLog _) {
    if (widget.onChanged == null) return;
    // Serialize the whole block document back to strict-CommonMark markdown. The consumer debounces saves.
    // 把整块文档序列化回严格 CommonMark;保存去抖归调用方。
    widget.onChanged!(serializeDocumentToMarkdown(_doc, syntax: MarkdownSyntax.normal));
  }

  @override
  void dispose() {
    _teardown();
    _ownFocus?.dispose();
    super.dispose();
  }

  // ── @ typeahead ──

  /// The plugin's composing-tag index changed: a `@token` opened / moved / closed. Recompute the anchor
  /// and (re)run the query, or close the picker when the token is gone. 组合 tag 变更:重算锚点+查/关。
  void _onComposingTag() {
    final tag = _mentionPlugin?.tagIndex.composingStableTag.value;
    if (tag == null || widget.mentionSource == null) {
      _closePicker();
      return;
    }
    // Layout may not be laid out on the very first frame — the next keystroke retries. 布局未就绪,下键重试。
    if (!_updateAnchor(tag.contentBounds)) return;
    _runQuery(tag.token);
  }

  /// Convert the `@token` span's document rect to a GLOBAL bottom-left offset (the app Overlay fills the
  /// screen, so global coords place the follower directly). Returns false if layout isn't ready yet.
  /// 把 @token 文档矩形转全局左下(Overlay 铺满屏,全局坐标直接定位);布局未就绪返 false。
  bool _updateAnchor(DocumentRange bounds) {
    final layout = _docLayoutKey.currentState as DocumentLayout?;
    if (layout == null) return false;
    final rect = layout.getRectForSelection(bounds.start, bounds.end);
    if (rect == null) return false;
    _anchor = layout.getGlobalOffsetFromDocumentOffset(rect.bottomLeft);
    return true;
  }

  Future<void> _runQuery(String query) async {
    final token = ++_queryToken;
    final results = await widget.mentionSource!.search(query);
    if (!mounted || token != _queryToken) return;
    // The @token may have closed while the query was in flight. 查询在途中 @token 可能已关。
    if (_mentionPlugin?.tagIndex.composingStableTag.value == null) {
      _closePicker();
      return;
    }
    setState(() {
      _candidates = results;
      _activeIndex = 0;
    });
    if (results.isEmpty) {
      if (_portal.isShowing) _portal.hide();
    } else if (!_portal.isShowing) {
      _portal.show();
    }
  }

  void _closePicker() {
    if (_portal.isShowing) _portal.hide();
    if (_candidates.isNotEmpty) setState(() => _candidates = const []);
  }

  void _pick(int index) {
    if (index < 0 || index >= _candidates.length) return;
    // Fill the composing @token with the committed mention (inserts "@name " as an atomic span). The
    // composing-tag listener then fires null → the picker closes itself. 用提交 mention 填 @token;随后收 null 自关。
    _editor.execute([FillInComposingStableTagRequest(_candidates[index].name, _mentionTagRule)]);
  }

  /// A [DocumentKeyboardAction] prepended before super_editor's defaults: while the picker is open it OWNS
  /// arrows / Enter / Tab / Esc (halting super_editor's caret handling); everything else falls through so
  /// typing keeps refining the query. 面板开时接管方向/回车/Tab/Esc,其余放行让继续打字精化查询。
  ExecutionInstruction _pickerKeys({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
    if (!_portal.isShowing || _candidates.isEmpty) return ExecutionInstruction.continueExecution;
    if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) return ExecutionInstruction.continueExecution;
    final k = keyEvent.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      setState(() => _activeIndex = (_activeIndex + 1) % _candidates.length);
      return ExecutionInstruction.haltExecution;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      setState(() => _activeIndex = (_activeIndex - 1 + _candidates.length) % _candidates.length);
      return ExecutionInstruction.haltExecution;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.tab) {
      _pick(_activeIndex);
      return ExecutionInstruction.haltExecution;
    }
    if (k == LogicalKeyboardKey.escape) {
      _editor.execute([const CancelComposingStableTagRequest(_mentionTagRule)]);
      _closePicker();
      return ExecutionInstruction.haltExecution;
    }
    return ExecutionInstruction.continueExecution;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final editor = SuperEditor(
      editor: _editor,
      focusNode: widget.focusNode ?? (_ownFocus ??= FocusNode()),
      autofocus: widget.autofocus,
      documentLayoutKey: _docLayoutKey,
      stylesheet: _anStylesheet(c),
      selectionStyle: SelectionStyles(selectionColor: c.accentSoft),
      plugins: {?_mentionPlugin},
      keyboardActions: [if (widget.mentionSource != null) _pickerKeys, ...defaultKeyboardActions],
    );
    if (widget.mentionSource == null) return editor;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _pickerOverlay,
      child: editor,
    );
  }

  /// The @ picker follower — anchored below the `@token` span in global coords, clamped to stay on-screen.
  /// @ 面板 follower:全局坐标挂 @token 下方,夹取防出屏。
  Widget _pickerOverlay(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final left = _anchor.dx.clamp(AnInset.pageX, screen.width - AnSize.menuMaxWidth - AnInset.pageX);
    return Positioned(
      left: left,
      top: _anchor.dy + AnGap.inlineLoose,
      width: AnSize.menuMaxWidth,
      child: AnMentionPanel(
        items: [
          for (final cand in _candidates)
            AnMentionRowData(kind: cand.type, name: cand.name, description: cand.description),
        ],
        activeIndex: _activeIndex,
        onPick: _pick,
      ),
    );
  }
}

/// The whole editor look, authored from design tokens. super_editor spaces blocks via per-block TOP padding
/// + contextual `.after()` selectors — the same asymmetric-heading model AnMarkdown uses (heading owns the
/// space above; body hugs below). 整套外观走 token:super_editor 靠每块 top-padding + `.after()` 造节奏(同
/// AnMarkdown 的标题不对称)。
Stylesheet _anStylesheet(AnColors c) {
  TextStyle ink(TextStyle s) => s.copyWith(color: c.ink);
  return defaultStylesheet.copyWith(
    addRulesAfter: [
      // Base: reading body (13/1.6 w300, Notion air), a 720 reading column, page-X horizontal pad.
      StyleRule(BlockSelector.all, (doc, node) => {
            Styles.maxWidth: AnSize.content,
            Styles.padding: const CascadingPadding.symmetric(horizontal: AnInset.pageX),
            Styles.textStyle: ink(AnText.reading),
          }),
      // Paragraph ↔ paragraph = the one block gap (12); heading→body inherits this too (12). 段间距 12。
      StyleRule(const BlockSelector('paragraph'),
          (doc, node) => {Styles.padding: const CascadingPadding.only(top: AnFlow.block)}),
      // List items sit TIGHT within a list (AnFlow.listItem 4); the first one (after a paragraph) takes the
      // full block gap so the list separates from the prose above. 列表项内紧(4);首项离上文一个块间距。
      StyleRule(const BlockSelector('listItem'),
          (doc, node) => {Styles.padding: const CascadingPadding.only(top: AnFlow.listItem)}),
      StyleRule(const BlockSelector('listItem').after('paragraph'),
          (doc, node) => {Styles.padding: const CascadingPadding.only(top: AnFlow.block)}),
      // Headings: AnMarkdown's downshifted reading-column sizes (h1→h3 tier / h2→strong / h3→body-emphasis),
      // and MORE space above (AnFlow.headingTop/subheadingTop) — they own the block below. 标题降档 + 上方留多。
      StyleRule(const BlockSelector('header1'), (doc, node) => {
            Styles.textStyle: ink(AnText.h3),
            Styles.padding: const CascadingPadding.only(top: AnFlow.headingTop),
          }),
      StyleRule(const BlockSelector('header2'), (doc, node) => {
            Styles.textStyle: ink(AnText.strong),
            Styles.padding: const CascadingPadding.only(top: AnFlow.headingTop),
          }),
      StyleRule(const BlockSelector('header3'), (doc, node) => {
            Styles.textStyle: ink(AnText.reading.weight(AnText.emphasisWeight)),
            Styles.padding: const CascadingPadding.only(top: AnFlow.subheadingTop),
          }),
      // Fenced code — the mono code face (super_editor's code paragraph doesn't honor a block background,
      // so the read-only AnCodeEditor frame stays AnMarkdown's job; here the mono font carries it). 代码块 mono。
      StyleRule(const BlockSelector('code'),
          (doc, node) => {Styles.textStyle: AnText.code.copyWith(color: c.ink)}),
      // Blockquote — the quiet-aside register (inkMuted prose), matching AnMarkdown. 引用:静默旁白(inkMuted)。
      StyleRule(const BlockSelector('blockquote'),
          (doc, node) => {Styles.textStyle: AnText.reading.copyWith(color: c.inkMuted)}),
      // Trailing scroll runway.
      StyleRule(BlockSelector.all.last(),
          (doc, node) => {Styles.padding: const CascadingPadding.only(bottom: AnInset.pageBottom)}),
    ],
  );
}
