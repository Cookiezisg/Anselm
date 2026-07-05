import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// AnDocEditor — the Notion-style WYSIWYG markdown editor, a token-locked FACADE over `super_editor`
/// (pinned dev.40; only this file + the round-trip spike import it). **markdown is the source of truth**:
/// [initialMarkdown] deserializes into the editor's block document, and every edit serializes back to a
/// markdown string via [onChanged] (strict CommonMark — the backend stores plain markdown). The ENTIRE
/// look is authored from design tokens (AnText.reading two-weight body / AnColors ink+selection / AnFlow
/// vertical rhythm) — super_editor ships unstyled, so there is no Material chrome to fight. Headings breathe
/// MORE above than below (AnFlow.headingTop), matching AnMarkdown's read rhythm.
///
/// P3.1/P3.2 scope: editable WYSIWYG + round-trip + token stylesheet. @ mentions (StableTagPlugin →
/// MentionSource), / slash (ActionTagsPlugin), fenced-code → AnCodeEditor, and the `[[id]]` wikilink chip
/// codec are the P3.3–P3.5 follow-ups.
///
/// AnDocEditor:super_editor 的 Notion 式 token 锁定门面。markdown 为真相(load→edit→serialize);整套外观
/// 走设计 token(reading 两字重 / AnColors / AnFlow 节奏),super_editor 无内建样式故不打架;标题上方留多。
class AnDocEditor extends StatefulWidget {
  const AnDocEditor({
    required this.initialMarkdown,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// The markdown source of truth to load. Changing it (a new document selected) rebuilds the editor.
  /// 加载的真相 markdown;变更(选了新文档)即重建编辑器。
  final String initialMarkdown;

  /// Fires the serialized markdown on every edit (the consumer debounces the PATCH-save). 每次编辑派出序列化 markdown。
  final ValueChanged<String>? onChanged;

  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<AnDocEditor> createState() => _AnDocEditorState();
}

class _AnDocEditorState extends State<AnDocEditor> {
  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _editor;
  FocusNode? _ownFocus;

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
    _editor = createDefaultDocumentEditor(document: _doc, composer: _composer);
    _doc.addListener(_onChange);
  }

  void _teardown() {
    _doc.removeListener(_onChange);
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SuperEditor(
      editor: _editor,
      focusNode: widget.focusNode ?? (_ownFocus ??= FocusNode()),
      autofocus: widget.autofocus,
      stylesheet: _anStylesheet(c),
      selectionStyle: SelectionStyles(selectionColor: c.accentSoft),
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
