import 'package:flutter/material.dart'
    show
        Material,
        MaterialType,
        Theme,
        CheckboxThemeData,
        MaterialTapTargetSize,
        VisualDensity,
        WidgetState,
        WidgetStateProperty;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

import '../../i18n/strings.g.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../entity/mention_source.dart';
import 'an_doc_editor_components.dart';
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
    required this.code,
    required this.divider,
    required this.todo,
  });

  final String text, h1, h2, h3, bulleted, numbered, quote, code, divider, todo;
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
  State<AnDocEditor> createState() => AnDocEditorState();
}

/// Which typeahead currently owns the shared popover (they never compose at once). 当前占用共享 popover 的是哪种。
enum _PopKind { none, mention, slash }

/// One `/` slash block option — an icon key (→ [AnIcons] glyph), an i18n label, and the built-in transform
/// request(s) to run on the current node (a divider REPLACES the node + re-seats the caret, so an option
/// yields a request LIST). 一个斜杠块选项:图标键 + 文案 + 对当前节点跑的内建变换请求(分隔线要换节点+重置光标,
/// 故为请求列表)。
class _SlashBlock {
  const _SlashBlock(this.iconKey, this.label, this.requests);
  final String iconKey;
  final String label;
  final List<EditRequest> Function(String nodeId) requests;
}

class AnDocEditorState extends State<AnDocEditor> {
  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _editor;
  StableTagPlugin? _mentionPlugin;
  ActionTagsPlugin? _slashPlugin;
  List<_SlashBlock> _slashOptions = const [];
  FocusNode? _ownFocus;

  // ── shared caret-anchored popover 共享 caret 锚定 popover ──
  // A hand-managed OverlayEntry, NOT an OverlayPortal: the editor renders AS A SLIVER when embedded under
  // an ancestor Scrollable, and OverlayPortal is a box widget — wrapping would break the sliver protocol.
  // 手动 OverlayEntry、非 OverlayPortal:嵌入祖先滚动时编辑器渲染成 sliver,OverlayPortal 是盒件、包了会破坏协议。
  final GlobalKey _docLayoutKey = GlobalKey();
  OverlayEntry? _pickerEntry;
  _PopKind _popKind = _PopKind.none;
  Rect _anchorRect = Rect.zero; // GLOBAL rect of the trigger token — the panel hangs below, or flips above. token 全局矩形。
  DocumentRange? _anchorBounds; // the token range behind [_anchorRect] — re-resolved when the host scrolls. 锚定的 token 范围,滚动时重算。
  ScrollPosition? _hostScroll; // the ancestor scrollable watched while the picker is open. 面板开时监听的祖先滚动。
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
  void didUpdateWidget(AnDocEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different source (new document opened) → rebuild the block document from the new markdown. 换文档即重建。
    if (widget.initialMarkdown != oldWidget.initialMarkdown) {
      _teardown();
      setState(() => _build(widget.initialMarkdown));
    }
  }

  void _build(String markdown) {
    // The custom fence converter preserves the code language (upstream drops it — an edit would save
    // the document back without its ```lang tags). 自定义围栏 converter 保语言(上游丢弃,编辑保存即丢标)。
    _doc = deserializeMarkdownToDocument(markdown,
        syntax: MarkdownSyntax.normal,
        customElementToNodeConverters: const [AnCodeBlockElementConverter()]);
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
    _hidePicker();
    _editor.dispose();
    _composer.dispose();
  }

  void _showPicker() {
    if (_pickerEntry != null) return;
    final entry = OverlayEntry(builder: _pickerOverlay);
    _pickerEntry = entry;
    Overlay.of(context).insert(entry);
    // Follow the page scroll while open: the token moves with the document, so the panel must re-anchor
    // (else it floats detached over stale coordinates). 开着时跟随页面滚动重锚,否则面板脱钩悬空。
    _hostScroll = Scrollable.maybeOf(context)?.position;
    _hostScroll?.addListener(_onHostScroll);
  }

  void _hidePicker() {
    _hostScroll?.removeListener(_onHostScroll);
    _hostScroll = null;
    _pickerEntry?.remove();
    _pickerEntry = null;
  }

  void _onHostScroll() {
    final bounds = _anchorBounds;
    if (bounds == null || _pickerEntry == null) return;
    if (_updateAnchor(bounds)) _pickerEntry!.markNeedsBuild();
  }

  /// GLOBAL top-left of the [index]-th HEADING block (header1/2/3, document order) — the outline panel's
  /// jump anchor (the host converts to its scroll offset). null when out of range / layout not ready.
  /// 第 [index] 个标题块(h1–h3,文档序)的全局左上——大纲跳转锚点(宿主换算滚动量);越界/未布局=null。
  Offset? headingOriginGlobal(int index) {
    if (index < 0) return null;
    final origins = headingOriginsGlobal();
    return index < origins.length ? origins[index] : null;
  }

  /// GLOBAL top-left of EVERY heading block (h1–h3, document order) in ONE walk — the outline's live-focus
  /// tracker reads all origins each scroll tick (per-index calls would be O(n²)). Empty when layout isn't
  /// ready. 所有标题块全局左上,一次遍历——大纲实时焦点每滚动 tick 读全表(逐下标调用是 O(n²));未布局返空。
  List<Offset> headingOriginsGlobal() {
    final layout = _docLayoutKey.currentState as DocumentLayout?;
    if (layout == null) return const [];
    final origins = <Offset>[];
    for (final node in _doc) {
      if (node is! ParagraphNode) continue;
      final blockType = node.metadata['blockType'];
      if (blockType != header1Attribution && blockType != header2Attribution && blockType != header3Attribution) {
        continue;
      }
      final rect = layout.getRectForPosition(
        DocumentPosition(nodeId: node.id, nodePosition: node.beginningPosition),
      );
      if (rect == null) return const []; // layout mid-flight — skip this tick 布局未提交,本 tick 跳过
      origins.add(layout.getGlobalOffsetFromDocumentOffset(rect.topLeft));
    }
    return origins;
  }

  // Built-in super_editor transform requests — no custom command needed (all in defaultRequestHandlers;
  // tasks render via the auto-registered TaskComponentBuilder and serialize as GitHub `- [ ]`; a divider
  // REPLACES the emptied paragraph with a HorizontalRuleNode and re-seats the caret in a fresh paragraph
  // after it, since an HR can't hold a caret). 内建变换请求;待办走自动注册的 TaskComponentBuilder、序列化
  // `- [ ]`;分隔线把清空后的段换成 HR 节点 + 光标落进其后新段(HR 不能持光标)。
  List<_SlashBlock> _buildSlashOptions(SlashMenuLabels l) => [
        _SlashBlock('paragraph', l.text,
            (id) => [ChangeParagraphBlockTypeRequest(nodeId: id, blockType: paragraphAttribution)]),
        _SlashBlock('heading1', l.h1,
            (id) => [ChangeParagraphBlockTypeRequest(nodeId: id, blockType: header1Attribution)]),
        _SlashBlock('heading2', l.h2,
            (id) => [ChangeParagraphBlockTypeRequest(nodeId: id, blockType: header2Attribution)]),
        _SlashBlock('heading3', l.h3,
            (id) => [ChangeParagraphBlockTypeRequest(nodeId: id, blockType: header3Attribution)]),
        _SlashBlock('listBulleted', l.bulleted,
            (id) => [ConvertParagraphToListItemRequest(nodeId: id, type: ListItemType.unordered)]),
        _SlashBlock('listNumbered', l.numbered,
            (id) => [ConvertParagraphToListItemRequest(nodeId: id, type: ListItemType.ordered)]),
        _SlashBlock('quote', l.quote,
            (id) => [ChangeParagraphBlockTypeRequest(nodeId: id, blockType: blockquoteAttribution)]),
        _SlashBlock('codeBlock', l.code,
            (id) => [ChangeParagraphBlockTypeRequest(nodeId: id, blockType: codeAttribution)]),
        _SlashBlock('todo', l.todo, (id) => [ConvertParagraphToTaskRequest(nodeId: id)]),
        _SlashBlock('divider', l.divider, (id) {
          final para = ParagraphNode(id: Editor.createNodeId(), text: AttributedText(''));
          return [
            ReplaceNodeRequest(existingNodeId: id, newNode: HorizontalRuleNode(id: id)),
            InsertNodeAfterNodeRequest(existingNodeId: id, newNode: para),
            ChangeSelectionRequest(
              DocumentSelection.collapsed(
                position: DocumentPosition(nodeId: para.id, nodePosition: const TextNodePosition(offset: 0)),
              ),
              SelectionChangeType.insertContent,
              SelectionReason.userInteraction,
            ),
          ];
        }),
      ];

  void _onChange(DocumentChangeLog _) {
    if (widget.onChanged == null) return;
    // Serialize to strict-CommonMark (the custom serializer writes language-tagged fences), then COLLAPSE
    // the in-editor `[name](anselm-entity:id)` mention links back to the stored `[[id]]` wire form (the
    // backend's wikilink parser reads that). 序列化(自定义序列化器写带语言围栏)后把 mention 链接塌回 `[[id]]`
    // 线缆形。保存去抖归调用方。
    widget.onChanged!(collapseEntityRefs(serializeDocumentToMarkdown(_doc,
        syntax: MarkdownSyntax.normal, customNodeSerializers: const [AnCodeBlockSerializer()])));
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
    // trailing space, then seat the caret AFTER the chip+space explicitly (typing must continue past the
    // chip, never inside it). 插「名+隐藏 id 链接」chip+尾空格,并**显式把光标落到 chip 之后**(继续打字在
    // chip 外,绝不卡在中间)。
    final link = LinkAttribution('$kEntityRefScheme:${cand.id}');
    final chipText = '${cand.name} ';
    final chip = AttributedText(chipText)..addAttribution(link, SpanRange(0, cand.name.length - 1));
    final caretAfter = DocumentPosition(
      nodeId: tokenStart.nodeId,
      nodePosition: TextNodePosition(
          offset: (tokenStart.nodePosition as TextNodePosition).offset - 1 + chipText.length),
    );
    _committing = true;
    _editor.execute([
      DeleteContentRequest(documentRange: deleteRange),
      InsertAttributedTextRequest(triggerPos, chip),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(position: caretAfter),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
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
    _editor.execute([const SubmitComposingActionTagRequest(), ..._slashMatches[index].requests(tag.nodeId)]);
  }

  // ── shared popover 共享 popover ──

  /// Anchor the panel to the trigger token's START — a single caret-position rect converted to GLOBAL
  /// coords (the app Overlay fills the screen). The start is STABLE across keystrokes; anchoring the whole
  /// token range wobbled per keystroke (the selection rect is re-measured against a layout that may not
  /// have committed the newest character yet). Remembers the range for scroll re-anchoring; false if
  /// layout isn't ready. 锚=token **起点**的单点矩形转全局——起点逐键恒稳;整段范围矩形会因布局未提交最新字符
  /// 而逐键漂移。记范围供滚动重锚;布局未就绪返 false。
  bool _updateAnchor(DocumentRange bounds) {
    final layout = _docLayoutKey.currentState as DocumentLayout?;
    if (layout == null) return false;
    final rect = layout.getRectForPosition(bounds.start);
    if (rect == null) return false;
    final topLeft = layout.getGlobalOffsetFromDocumentOffset(rect.topLeft);
    _anchorRect = topLeft & rect.size;
    _anchorBounds = bounds;
    return true;
  }

  void _openPopover(_PopKind kind, List<AnMentionRowData> rows) {
    setState(() {
      _popKind = kind;
      _rows = rows;
      _activeIndex = 0;
    });
    if (rows.isEmpty) {
      _hidePicker();
    } else {
      _showPicker();
      _pickerEntry?.markNeedsBuild();
    }
  }

  void _closePopover() {
    _hidePicker();
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

  /// The fence language for a code node — kept on node METADATA by the custom converter (the paragraph
  /// view model doesn't carry it). 代码节点的围栏语言(converter 存 metadata;段落 VM 不带)。
  String? _codeLanguageOf(String nodeId) => _doc.getNodeById(nodeId)?.getMetadataValue('language') as String?;

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
    if (_pickerEntry == null || _rows.isEmpty) return ExecutionInstruction.continueExecution;
    if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) return ExecutionInstruction.continueExecution;
    final k = keyEvent.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      setState(() => _activeIndex = (_activeIndex + 1) % _rows.length);
      _pickerEntry?.markNeedsBuild();
      return ExecutionInstruction.haltExecution;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      setState(() => _activeIndex = (_activeIndex - 1 + _rows.length) % _rows.length);
      _pickerEntry?.markNeedsBuild();
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

  /// Backspace right after an entity-ref chip deletes the WHOLE chip (it reads as one token, so it must
  /// die as one token — matching the composer's pill behavior). The chip is the maximal span carrying the
  /// `anselm-entity:` link at the char before the caret; halting keeps the key from ALSO reaching the IME
  /// (no double delete). chip 尾退格=整删 chip(读作一个 token 就整体删,同 composer 药丸);halt 后按键不再
  /// 进 IME,不会双删。
  ExecutionInstruction _chipBackspace({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
    if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) return ExecutionInstruction.continueExecution;
    if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) return ExecutionInstruction.continueExecution;
    final sel = _composer.selection;
    if (sel == null || !sel.isCollapsed) return ExecutionInstruction.continueExecution;
    final pos = sel.extent.nodePosition;
    if (pos is! TextNodePosition || pos.offset == 0) return ExecutionInstruction.continueExecution;
    final node = _doc.getNodeById(sel.extent.nodeId);
    if (node is! TextNode) return ExecutionInstruction.continueExecution;
    final link = node.text
        .getAllAttributionsAt(pos.offset - 1)
        .whereType<LinkAttribution>()
        .where((l) => l.plainTextUri.startsWith('$kEntityRefScheme:'))
        .firstOrNull;
    if (link == null) return ExecutionInstruction.continueExecution;
    final span = node.text.getAttributedRange({link}, pos.offset - 1);
    _editor.execute([
      DeleteContentRequest(
        documentRange: DocumentRange(
          start: DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: span.start)),
          end: DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: span.end + 1)),
        ),
      ),
    ]);
    return ExecutionInstruction.haltExecution;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasTypeahead = _mentionPlugin != null || _slashPlugin != null;
    // The bare SuperEditor IS the return value — under an ancestor Scrollable it renders as a sliver, so
    // no box widget may wrap it here (the typeahead popover lives in a hand-managed OverlayEntry instead;
    // the Theme below is an InheritedWidget — no render object, sliver-safe). 裸 SuperEditor 即返回值——
    // 祖先滚动下渲染成 sliver,不得包盒件(浮层走手动 OverlayEntry;下方 Theme 是 InheritedWidget、无渲染盒)。
    return Theme(
      // The task block's checkbox is a raw Material Checkbox driven by the ambient theme — untamed it
      // paints the stock oversized blue box. Compact it and paint it in tokens (accent fill, hairline
      // side, small radius). 待办块的勾选框是裸 Material Checkbox、吃环境主题——不管就是超大蓝盒;这里紧凑化
      // 并按 token 上色(accent 填充/细边/小圆角)。
      data: Theme.of(context).copyWith(
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        checkboxTheme: CheckboxThemeData(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AnRadius.tag))),
          side: BorderSide(color: c.lineStrong, width: 1.2),
          fillColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? c.accent : const Color(0x00000000)),
          checkColor: WidgetStateProperty.all(c.surface),
        ),
      ),
      child: SuperEditor(
      editor: _editor,
      focusNode: widget.focusNode ?? (_ownFocus ??= FocusNode()),
      autofocus: widget.autofocus,
      documentLayoutKey: _docLayoutKey,
      stylesheet: _anStylesheet(c),
      selectionStyle: SelectionStyles(selectionColor: c.accentSoft),
      // The AnMarkdown-parity components (code chrome / quote bar / hairline HR / quiet list markers /
      // glyph tasks) run FIRST (first-non-null-wins); TaskComponentBuilder's view-model duty rides inside
      // AnTaskComponentBuilder (SuperEditor only auto-appends the stock one when NO custom list is given).
      // 基准对齐组件先行(先非空者胜);任务 VM 职责在 AnTaskComponentBuilder 里(传自定义列表后 SuperEditor 不再自动补)。
      componentBuilders: [
        AnCodeBlockComponentBuilder(c, languageOf: _codeLanguageOf, copyLabel: Translations.of(context).action.copy),
        AnTaskComponentBuilder(_editor, c),
        AnListItemComponentBuilder(c),
        AnBlockquoteComponentBuilder(c),
        AnHrComponentBuilder(c),
        ...defaultComponentBuilders,
      ],
      // Group-boundary rhythm (ul↔ol / ↔task) + per-token code colouring — both restyle VIEW MODELS
      // only (nothing reaches the document/serializer). 组边界节奏 + 代码逐 token 上色——都只染视图模型。
      customStylePhases: [
        AnListBoundaryStylePhase(),
        AnCodeHighlightStylePhase(context.syntax, _codeLanguageOf),
      ],
      plugins: {?_mentionPlugin, ?_slashPlugin},
      // SuperEditor's input source is IME (the default) — the actions MUST be the IME set: the hardware set
      // (`defaultKeyboardActions`) consumes raw key-downs before the OS input method sees them, which kills
      // CJK composition entirely (pinyin letters insert raw, no candidate window). The IME set ends with
      // `sendKeyEventToMacOs`, handing keys to the macOS IME; the picker's keys stay prepended (arrows /
      // Enter / Esc are non-text keys that still arrive here first). 输入源=IME(默认),动作集必须配 IME 集:
      // 硬件集会在输入法看到按键前吃掉 key-down,中文组合直接失效;IME 集以 sendKeyEventToMacOs 收尾把键放行给
      // 系统输入法。picker 键仍前置(方向/回车/Esc 非文本键,先到这里)。
      keyboardActions: [if (hasTypeahead) _pickerKeys, _chipBackspace, ...defaultImeKeyboardActions],
      ),
    );
  }

  /// The typeahead follower — anchored below the trigger token in global coords, clamped horizontally, and
  /// FLIPPED above the token when the space below can't hold the panel (a caret near the window bottom must
  /// not push the menu off-screen); whichever side wins, the panel's height is capped to the space actually
  /// there. 面板 follower:全局坐标挂 token 下方、水平夹取;下方装不下即**翻到 token 上方**(窗口底部的光标不能把
  /// 菜单顶出屏),且高度封顶为该侧真实余量。
  Widget _pickerOverlay(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final left = _anchorRect.left.clamp(AnInset.pageX, screen.width - AnSize.menuMaxWidth - AnInset.pageX);
    final spaceBelow = screen.height - _anchorRect.bottom - AnGap.inlineLoose - AnInset.pageX;
    final spaceAbove = _anchorRect.top - AnGap.inlineLoose - AnInset.pageX;
    final below = spaceBelow >= AnSize.menuMaxHeight || spaceBelow >= spaceAbove;
    final maxH = (below ? spaceBelow : spaceAbove).clamp(AnSize.control, AnSize.menuMaxHeight).toDouble();
    return Positioned(
      left: left,
      top: below ? _anchorRect.bottom + AnGap.inlineLoose : null,
      bottom: below ? null : screen.height - _anchorRect.top + AnGap.inlineLoose,
      width: AnSize.menuMaxWidth,
      // Material(transparency): the Overlay sits OUTSIDE the app's Material tree — without one, every
      // Text in the panel paints the framework's yellow-double-underline fallback. 浮层在 Material 树外,
      // 不包一层透明 Material 面板文字会画出框架的黄双下划线兜底。
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: AnMentionPanel(items: _rows, activeIndex: _activeIndex, onPick: _pick),
        ),
      ),
    );
  }
}

/// The whole editor look, authored from design tokens. super_editor spaces blocks via per-block TOP padding
/// + contextual `.after()` selectors — the same asymmetric-heading model AnMarkdown uses (heading owns the
/// space above; body hugs below). 整套外观走 token:super_editor 靠每块 top-padding + `.after()` 造节奏(同
/// AnMarkdown 的标题不对称)。
///
/// ⚠️ Authored FROM SCRATCH, not `defaultStylesheet.copyWith(addRulesAfter:)`: the stylesheet styler's
/// `_mergeStyles` can only merge TextStyle/CascadingPadding — any OTHER style a later rule re-sets (like
/// `maxWidth`, a double) is silently DROPPED, so an addRulesAfter override of the default 640 column can
/// never win (the body then floats 40px right of a 720 header). One base rule sets `maxWidth` exactly once.
/// ⚠️ 从零作者、不 copyWith:上游 `_mergeStyles` 只会合并 TextStyle/Padding,其余重复键(如 maxWidth)静默丢弃
/// 后规则——覆盖不了默认 640 列(正文比 720 头右漂 40)。基础规则把 maxWidth 一次定死。
Stylesheet _anStylesheet(AnColors c) {
  TextStyle ink(TextStyle s) => s.copyWith(color: c.ink);
  return Stylesheet(
    // No document-level padding — the vertical rhythm is authored entirely by the per-block token rules
    // (and an embedding host brings its own page insets). 文档级 padding 归零:节奏全由每块 token 规则定。
    documentPadding: EdgeInsets.zero,
    // Inline styling — the stock attribution styles, then the PARITY fixes so inline runs read exactly
    // like AnMarkdown: ① bold re-weighted via `.weight()` (the default's bare `fontWeight: bold` is
    // overridden by the pinned `wght` axis and renders NOT-bold / synthesized-heavy — the same
    // two-weight bug AnMarkdown fixed); ② inline `code` → mono on a sunken ground (the default styles it
    // NOT AT ALL); ③ web links → accent (default is Material lightBlue); ④ an entity-ref mention → accent
    // chip, emphasis weight, no underline (a branded reference, not a web link).
    // 内联对齐 AnMarkdown:①粗体走 `.weight()` 钉轴(默认裸 fontWeight 被钉轴覆盖/合成过重——AnMarkdown 修过的
    // 同一 bug);②内联 code → mono+凹陷底(默认完全没样式);③网链 → accent(默认 lightBlue);④实体 mention →
    // accent 药丸无下划线。
    inlineTextStyler: (attributions, existingStyle) {
      var style = defaultInlineTextStyler(attributions, existingStyle);
      if (attributions.contains(boldAttribution)) {
        style = style.weight(AnText.emphasisWeight);
      }
      if (attributions.contains(codeAttribution)) {
        style = style.copyWith(
          fontFamily: AnText.mono.fontFamily,
          fontFamilyFallback: AnText.mono.fontFamilyFallback,
          backgroundColor: c.surfaceSunken,
        );
      }
      final link = attributions.whereType<LinkAttribution>().firstOrNull;
      if (link != null) {
        final isEntityRef = link.plainTextUri.startsWith('$kEntityRefScheme:');
        style = isEntityRef
            ? style
                .weight(AnText.emphasisWeight)
                .copyWith(color: c.accent, decoration: TextDecoration.none)
            : style.copyWith(color: c.accent, decorationColor: c.accent);
      }
      return style;
    },
    inlineWidgetBuilders: defaultInlineWidgetBuilderChain,
    rules: [
      // Base: reading body (13/1.6 w300, Notion air), the ocean's 720 reading column + page-X pad — the SAME
      // numbers as AnPage, and the single-column layout centers each block in the full-width editor, so the
      // body lines up exactly with a `Center > 720 > pageX` header above. 基础:720 列+pageX(AnPage 同数),
      // 布局把每块在全宽编辑器里居中,与头精确对齐。
      StyleRule(BlockSelector.all, (doc, node) => {
            Styles.maxWidth: AnSize.content,
            Styles.padding: const CascadingPadding.symmetric(horizontal: AnInset.pageX),
            Styles.textStyle: ink(AnText.reading),
          }),
      // Paragraph ↔ paragraph = the one block gap (12); heading→body inherits this too (12). 段间距 12。
      StyleRule(const BlockSelector('paragraph'),
          (doc, node) => {Styles.padding: const CascadingPadding.only(top: AnFlow.block)}),
      // List items sit TIGHT within a list (AnFlow.listItem 4); the first one (after a paragraph) takes the
      // full block gap so the list separates from the prose above. Tasks follow the same rhythm. The bullet
      // dot matches AnMarkdown's quiet marker (inkFaint, ~3px — not the default full-ink 4px). 列表项内紧
      // (4);首项离上文一个块间距;待办同律;圆点=AnMarkdown 的安静记号(inkFaint 小点)。
      StyleRule(const BlockSelector('listItem'), (doc, node) => {
            Styles.padding: const CascadingPadding.only(top: AnFlow.listItem),
            Styles.dotColor: c.inkFaint,
            Styles.dotSize: const Size(3, 3),
          }),
      StyleRule(const BlockSelector('listItem').after('paragraph'),
          (doc, node) => {Styles.padding: const CascadingPadding.only(top: AnFlow.block)}),
      StyleRule(const BlockSelector('task'),
          (doc, node) => {Styles.padding: const CascadingPadding.only(top: AnFlow.listItem)}),
      StyleRule(const BlockSelector('task').after('paragraph'),
          (doc, node) => {Styles.padding: const CascadingPadding.only(top: AnFlow.block)}),
      // Headings: AnMarkdown's downshifted reading-column sizes (h1→h3 tier / h2→strong / h3→body-emphasis)
      // with ONE uniform space-above (AnFlow.headingTop 24 ≈ AnMarkdown's 12+12) — the baseline breathes
      // every heading level the same. 标题降档 + 上方统一 24(基准全级同律)。
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
            Styles.padding: const CascadingPadding.only(top: AnFlow.headingTop),
          }),
      // Fenced code — the code face + the uniform block gap (the custom component brings the frame). 代码块。
      StyleRule(const BlockSelector('code'), (doc, node) => {
            Styles.textStyle: AnText.code.copyWith(color: c.ink),
            Styles.padding: const CascadingPadding.only(top: AnFlow.block),
          }),
      // Blockquote — the quiet-aside register (inkMuted prose), matching AnMarkdown; the custom component
      // brings the 2px left bar. 引用:静默旁白(inkMuted);左条归自定义组件。
      StyleRule(const BlockSelector('blockquote'), (doc, node) => {
            Styles.textStyle: AnText.reading.copyWith(color: c.inkMuted),
            Styles.padding: const CascadingPadding.only(top: AnFlow.block),
          }),
      // Horizontal rule — the uniform block gap (hairline look comes from the custom component). 分隔线间距。
      StyleRule(const BlockSelector('horizontalRule'),
          (doc, node) => {Styles.padding: const CascadingPadding.only(top: AnFlow.block)}),
      // Trailing scroll runway.
      StyleRule(BlockSelector.all.last(),
          (doc, node) => {Styles.padding: const CascadingPadding.only(bottom: AnInset.pageBottom)}),
    ],
  );
}
