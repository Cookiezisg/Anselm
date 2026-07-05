import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../entity/mention_source.dart';
import 'an_mention_picker.dart';
import 'entity_ref_codec.dart';

/// The @ mention trigger rule — Notion-style: `@` opens a token that ends on whitespace / a dot / a
/// newline. Committed mentions may still contain spaces (they're frozen text, not re-parsed). @ 规则:空白/点/换行结束 token。
const _mentionTagRule = TagRule(trigger: '@', excludedCharacters: {' ', '.', '\n'});

/// The i18n labels for the `/` slash block menu, injected by the feature layer (AnDocEditor is a core/ui
/// primitive — it never hardcodes strings). Providing this enables `/`; `null` turns the slash menu off.
/// `/` 斜杠块菜单的 i18n 文案,由 feature 层注入(core/ui 不硬编串);给了即开 `/`,null=关。
class SlashMenuLabels {
  const SlashMenuLabels({
    required this.text,
    required this.h1,
    required this.h2,
    required this.h3,
    required this.bulleted,
    required this.numbered,
    required this.quote,
  });

  final String text, h1, h2, h3, bulleted, numbered, quote;
}

/// AnDocEditor — the Notion-style WYSIWYG markdown editor, a token-locked FACADE over `super_editor`
/// (pinned dev.40; only this file + the round-trip spike import it). **markdown is the source of truth**:
/// [initialMarkdown] deserializes into the editor's block document, and every edit serializes back to a
/// markdown string via [onChanged] (strict CommonMark — the backend stores plain markdown). The ENTIRE
/// look is authored from design tokens (AnText.reading two-weight body / AnColors ink+selection / AnFlow
/// vertical rhythm) — super_editor ships unstyled, so there is no Material chrome to fight. Headings breathe
/// MORE above than below (AnFlow.headingTop), matching AnMarkdown's read rhythm.
///
/// **@ typeahead** (when [mentionSource] is supplied) + **`/` slash block menu** (when [slashLabels] is
/// supplied) share ONE caret-anchored popover ([AnMentionPanel] on the shared menu chrome). @ is fed by the
/// shared [MentionSource] DIP (the SAME seam chat's composer uses); `/` offers block-type conversions
/// (text / H1–H3 / bulleted / numbered / quote) via super_editor's built-in transform requests. Both drive
/// the popover the same way: arrow keys move the active row, Enter/Tab pick, Esc cancels; the picker OWNS
/// those keys while open (a custom [DocumentKeyboardAction] prepended before super_editor's defaults). A
/// mention pick inserts `@name ` as an atomic span; a slash pick submits (deletes the `/query` text) then
/// converts the block.
///
/// AnDocEditor:super_editor 的 Notion 式 token 锁定门面。markdown 为真相;外观全走设计 token。
/// **@ 提及**(给 mentionSource)+ **`/` 斜杠块菜单**(给 slashLabels)共用**同一** caret 锚定 popover:
/// 方向键移动、Enter/Tab 选、Esc 取消,面板开时接管这些键。@ 选中插 `@name ` 原子 span;`/` 选中删 `/query`
/// 再变当前块类型(正文/标题/列表/引用)。`[[id]]` 往返 chip codec 是后续。
class AnDocEditor extends StatefulWidget {
  const AnDocEditor({
    required this.initialMarkdown,
    this.onChanged,
    this.mentionSource,
    this.slashLabels,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// The markdown source of truth to load. Changing it (a new document selected) rebuilds the editor.
  /// 加载的真相 markdown;变更(选了新文档)即重建编辑器。
  final String initialMarkdown;

  /// Fires the serialized markdown on every edit (the consumer debounces the PATCH-save). 每次编辑派出序列化 markdown。
  final ValueChanged<String>? onChanged;

  /// The @ mention data seam (from the app's `mentionSourceProvider`). `null` → @ typeahead off. @ 数据缝;null=关。
  final MentionSource? mentionSource;

  /// The `/` slash block-menu labels (i18n, injected). `null` → slash menu off. `/` 块菜单文案;null=关。
  final SlashMenuLabels? slashLabels;

  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<AnDocEditor> createState() => _AnDocEditorState();
}

/// Which typeahead currently owns the shared popover (they never compose at once). 当前占用共享 popover 的是哪种。
enum _PopKind { none, mention, slash }

/// One `/` slash block option — an icon key (→ [AnIcons] glyph), an i18n label, and the built-in transform
/// request to run on the current node. 一个斜杠块选项:图标键 + 文案 + 对当前节点跑的内建变换请求。
class _SlashBlock {
  const _SlashBlock(this.iconKey, this.label, this.request);
  final String iconKey;
  final String label;
  final EditRequest Function(String nodeId) request;
}

class _AnDocEditorState extends State<AnDocEditor> {
  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _editor;
  StableTagPlugin? _mentionPlugin;
  ActionTagsPlugin? _slashPlugin;
  List<_SlashBlock> _slashOptions = const [];
  FocusNode? _ownFocus;

  // ── shared caret-anchored popover 共享 caret 锚定 popover ──
  final GlobalKey _docLayoutKey = GlobalKey();
  final OverlayPortalController _portal = OverlayPortalController();
  _PopKind _popKind = _PopKind.none;
  Offset _anchor = Offset.zero; // GLOBAL bottom-left of the trigger token → the panel hangs just below. token 全局左下。
  int _activeIndex = 0;
  List<AnMentionRowData> _rows = const []; // the rendered rows (either kind) 渲染行(两种通用)
  // Parallel match lists so a pick index maps back to its source. 平行匹配表,选中下标回源。
  List<MentionCandidate> _mentionMatches = const [];
  List<_SlashBlock> _slashMatches = const [];
  int _queryToken = 0; // in-flight guard for the async mention search 异步 @ 查询竞态守卫
  bool _committing = false; // true while a pick rewrites the doc — suppress the tag listener re-opening 选中改文时抑制监听重开

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
    _slashPlugin = widget.slashLabels == null ? null : ActionTagsPlugin();
    _slashOptions = widget.slashLabels == null ? const [] : _buildSlashOptions(widget.slashLabels!);
    _editor = createDefaultDocumentEditor(document: _doc, composer: _composer);
    _doc.addListener(_onChange);
    _mentionPlugin?.tagIndex.composingStableTag.addListener(_onMentionTag);
    _slashPlugin?.composingActionTag.addListener(_onSlashTag);
  }

  void _teardown() {
    _doc.removeListener(_onChange);
    _mentionPlugin?.tagIndex.composingStableTag.removeListener(_onMentionTag);
    _slashPlugin?.composingActionTag.removeListener(_onSlashTag);
    if (_portal.isShowing) _portal.hide();
    _editor.dispose();
    _composer.dispose();
  }

  // Built-in super_editor transform requests — no custom command needed (all in defaultRequestHandlers).
  // 内建 super_editor 变换请求——无需自定义命令(都在 defaultRequestHandlers)。
  List<_SlashBlock> _buildSlashOptions(SlashMenuLabels l) => [
        _SlashBlock('paragraph', l.text,
            (id) => ChangeParagraphBlockTypeRequest(nodeId: id, blockType: paragraphAttribution)),
        _SlashBlock('heading1', l.h1,
            (id) => ChangeParagraphBlockTypeRequest(nodeId: id, blockType: header1Attribution)),
        _SlashBlock('heading2', l.h2,
            (id) => ChangeParagraphBlockTypeRequest(nodeId: id, blockType: header2Attribution)),
        _SlashBlock('heading3', l.h3,
            (id) => ChangeParagraphBlockTypeRequest(nodeId: id, blockType: header3Attribution)),
        _SlashBlock('listBulleted', l.bulleted,
            (id) => ConvertParagraphToListItemRequest(nodeId: id, type: ListItemType.unordered)),
        _SlashBlock('listNumbered', l.numbered,
            (id) => ConvertParagraphToListItemRequest(nodeId: id, type: ListItemType.ordered)),
        _SlashBlock('quote', l.quote,
            (id) => ChangeParagraphBlockTypeRequest(nodeId: id, blockType: blockquoteAttribution)),
      ];

  void _onChange(DocumentChangeLog _) {
    if (widget.onChanged == null) return;
    // Serialize to strict-CommonMark, then COLLAPSE the in-editor `[name](anselm-entity:id)` mention links
    // back to the stored `[[id]]` wire form (the backend's wikilink parser reads that). 序列化后把 mention
    // 链接塌回 `[[id]]` 线缆形(后端 wikilink 解析读它)。保存去抖归调用方。
    widget.onChanged!(collapseEntityRefs(serializeDocumentToMarkdown(_doc, syntax: MarkdownSyntax.normal)));
  }

  @override
  void dispose() {
    _teardown();
    _ownFocus?.dispose();
    super.dispose();
  }

  // ── @ typeahead @ 预输入 ──

  void _onMentionTag() {
    if (_committing) return; // a pick is rewriting the doc — don't re-open from a stale composing value. pick 改文中,勿重开。
    final tag = _mentionPlugin?.tagIndex.composingStableTag.value;
    if (tag == null) {
      if (_popKind == _PopKind.mention) _closePopover();
      return;
    }
    if (widget.mentionSource == null) return;
    // Layout may not be laid out on the very first frame — the next keystroke retries. 布局未就绪,下键重试。
    if (!_updateAnchor(tag.contentBounds)) return;
    _runMentionQuery(tag.token);
  }

  Future<void> _runMentionQuery(String query) async {
    final token = ++_queryToken;
    final results = await widget.mentionSource!.search(query);
    if (!mounted || token != _queryToken) return;
    // The @token may have closed while the query was in flight. 查询在途中 @token 可能已关。
    if (_mentionPlugin?.tagIndex.composingStableTag.value == null) {
      if (_popKind == _PopKind.mention) _closePopover();
      return;
    }
    _mentionMatches = results;
    _openPopover(_PopKind.mention,
        [for (final c in results) AnMentionRowData(kind: c.type, name: c.name, description: c.description)]);
  }

  void _pickMention(int index) {
    if (index < 0 || index >= _mentionMatches.length) return;
    final cand = _mentionMatches[index];
    final tag = _mentionPlugin?.tagIndex.composingStableTag.value;
    if (tag == null) return;
    // `contentBounds` spans the token WITHOUT the `@` trigger (its start = triggerOffset + 1); extend it one
    // char left so the delete swallows the `@` too. contentBounds 不含 `@`(start=触发符+1),左扩一格连 `@` 一起删。
    final tokenStart = tag.contentBounds.start;
    final triggerPos = DocumentPosition(
      nodeId: tokenStart.nodeId,
      nodePosition: TextNodePosition(offset: (tokenStart.nodePosition as TextNodePosition).offset - 1),
    );
    final deleteRange = DocumentRange(start: triggerPos, end: tag.contentBounds.end);
    // Replace `@query` with the entity NAME carrying a hidden link to `anselm-entity:<id>` (styled as a chip;
    // the codec collapses that link to the stored `[[id]]` on save — id survives, name is display-only) + a
    // trailing space so the caret continues after the chip. 插「名+隐藏 id 链接」chip+尾空格。
    final link = LinkAttribution('$kEntityRefScheme:${cand.id}');
    final chip = AttributedText('${cand.name} ')..addAttribution(link, SpanRange(0, cand.name.length - 1));
    _committing = true;
    _editor.execute([
      DeleteContentRequest(documentRange: deleteRange),
      InsertAttributedTextRequest(triggerPos, chip),
    ]);
    _committing = false;
    // Deleting the composing token also drops its composing attribution, but close the picker explicitly
    // rather than rely on the plugin's null-notify ordering. 删组合 token 后显式关面板,不赖插件通知时序。
    _closePopover();
  }

  // ── `/` slash block menu `/` 斜杠块菜单 ──

  void _onSlashTag() {
    final tag = _slashPlugin?.composingActionTag.value;
    if (tag == null) {
      if (_popKind == _PopKind.slash) _closePopover();
      return;
    }
    if (!_updateAnchor(tag.range)) return;
    final q = tag.tag.token.toLowerCase();
    _slashMatches = [for (final b in _slashOptions) if (q.isEmpty || b.label.toLowerCase().contains(q)) b];
    _openPopover(_PopKind.slash, [for (final b in _slashMatches) AnMentionRowData(kind: b.iconKey, name: b.label)]);
  }

  void _pickSlash(int index) {
    final tag = _slashPlugin?.composingActionTag.value;
    if (tag == null || index < 0 || index >= _slashMatches.length) return;
    // Submit deletes the "/query" text, then the block converts on the SAME node id. Submit 删 /query,再变同节点。
    _editor.execute([const SubmitComposingActionTagRequest(), _slashMatches[index].request(tag.nodeId)]);
  }

  // ── shared popover 共享 popover ──

  /// Convert the trigger token's document rect to a GLOBAL bottom-left offset (the app Overlay fills the
  /// screen, so global coords place the follower directly). Returns false if layout isn't ready yet.
  /// 把 token 文档矩形转全局左下(Overlay 铺满屏);布局未就绪返 false。
  bool _updateAnchor(DocumentRange bounds) {
    final layout = _docLayoutKey.currentState as DocumentLayout?;
    if (layout == null) return false;
    final rect = layout.getRectForSelection(bounds.start, bounds.end);
    if (rect == null) return false;
    _anchor = layout.getGlobalOffsetFromDocumentOffset(rect.bottomLeft);
    return true;
  }

  void _openPopover(_PopKind kind, List<AnMentionRowData> rows) {
    setState(() {
      _popKind = kind;
      _rows = rows;
      _activeIndex = 0;
    });
    if (rows.isEmpty) {
      if (_portal.isShowing) _portal.hide();
    } else if (!_portal.isShowing) {
      _portal.show();
    }
  }

  void _closePopover() {
    if (_portal.isShowing) _portal.hide();
    if (_popKind != _PopKind.none || _rows.isNotEmpty) {
      setState(() {
        _popKind = _PopKind.none;
        _rows = const [];
      });
    }
  }

  void _pick(int index) {
    switch (_popKind) {
      case _PopKind.mention:
        _pickMention(index);
      case _PopKind.slash:
        _pickSlash(index);
      case _PopKind.none:
        break;
    }
  }

  void _cancel() {
    switch (_popKind) {
      case _PopKind.mention:
        _editor.execute([const CancelComposingStableTagRequest(_mentionTagRule)]);
      case _PopKind.slash:
        _editor.execute([const CancelComposingActionTagRequest(defaultActionTagRule)]);
      case _PopKind.none:
        break;
    }
    _closePopover();
  }

  /// A [DocumentKeyboardAction] prepended before super_editor's defaults: while the picker is open it OWNS
  /// arrows / Enter / Tab / Esc (halting super_editor's caret handling); everything else falls through so
  /// typing keeps refining the query. 面板开时接管方向/回车/Tab/Esc,其余放行让继续打字精化查询。
  ExecutionInstruction _pickerKeys({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
    if (!_portal.isShowing || _rows.isEmpty) return ExecutionInstruction.continueExecution;
    if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) return ExecutionInstruction.continueExecution;
    final k = keyEvent.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      setState(() => _activeIndex = (_activeIndex + 1) % _rows.length);
      return ExecutionInstruction.haltExecution;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      setState(() => _activeIndex = (_activeIndex - 1 + _rows.length) % _rows.length);
      return ExecutionInstruction.haltExecution;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.tab) {
      _pick(_activeIndex);
      return ExecutionInstruction.haltExecution;
    }
    if (k == LogicalKeyboardKey.escape) {
      _cancel();
      return ExecutionInstruction.haltExecution;
    }
    return ExecutionInstruction.continueExecution;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasTypeahead = _mentionPlugin != null || _slashPlugin != null;
    final editor = SuperEditor(
      editor: _editor,
      focusNode: widget.focusNode ?? (_ownFocus ??= FocusNode()),
      autofocus: widget.autofocus,
      documentLayoutKey: _docLayoutKey,
      stylesheet: _anStylesheet(c),
      selectionStyle: SelectionStyles(selectionColor: c.accentSoft),
      plugins: {?_mentionPlugin, ?_slashPlugin},
      keyboardActions: [if (hasTypeahead) _pickerKeys, ...defaultKeyboardActions],
    );
    if (!hasTypeahead) return editor;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _pickerOverlay,
      child: editor,
    );
  }

  /// The typeahead follower — anchored below the trigger token in global coords, clamped to stay on-screen.
  /// 面板 follower:全局坐标挂 token 下方,夹取防出屏。
  Widget _pickerOverlay(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final left = _anchor.dx.clamp(AnInset.pageX, screen.width - AnSize.menuMaxWidth - AnInset.pageX);
    return Positioned(
      left: left,
      top: _anchor.dy + AnGap.inlineLoose,
      width: AnSize.menuMaxWidth,
      child: AnMentionPanel(items: _rows, activeIndex: _activeIndex, onPick: _pick),
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
    // Inline styling: keep the defaults, then paint an entity-ref mention (a link to `anselm-entity:…`) as an
    // accent chip — accent ink + emphasis weight, no link underline (it reads as a branded reference, not a
    // web link). 内联:留默认,再把实体 mention(anselm-entity 链接)画成 accent 药丸(accent 墨 + 加粗、无下划线)。
    inlineTextStyler: (attributions, existingStyle) {
      var style = defaultInlineTextStyler(attributions, existingStyle);
      final isEntityRef = attributions
          .whereType<LinkAttribution>()
          .any((l) => l.plainTextUri.startsWith('$kEntityRefScheme:'));
      if (isEntityRef) {
        style = style.copyWith(
          color: c.accent,
          fontWeight: AnText.emphasisWeight,
          fontVariations: const [FontVariation('wght', 400)],
          decoration: TextDecoration.none,
        );
      }
      return style;
    },
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
