import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import '../../i18n/strings.g.dart';
import '../design/an_fonts.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../entity/mention_source.dart';
import '../ui/an_mention_picker.dart';
import '../perf/debouncer.dart';
import 'an_editor_caret.dart';
import 'an_editor_components.dart';
import 'an_editor_gestures.dart';
import 'an_editor_inline_code.dart';
import 'an_editor_list_components.dart';
import 'an_editor_quote.dart';
import 'an_editor_markdown_shortcuts.dart';
import 'an_editor_selection.dart';
import 'an_editor_text_component.dart';
import 'an_editor_markdown.dart';
import 'an_editor_mention.dart';
import 'an_editor_slash_menu.dart';
import 'an_editor_stylesheet.dart';
import 'an_editor_table.dart';
import 'an_editor_toolbar.dart';

/// The native document editor (super_editor) — the pivot OFF Milkdown-in-webview so every element is a
/// real Flutter widget drawn with our own An primitives (true pixel 1:1), not a CSS approximation.
///
/// **E1 (this step) = the MINIMAL editable surface**: a bare [SuperEditor] over a [MutableDocument] with
/// the DEFAULT components + stylesheet + IME text input. Its only job is to prove "mounts + edits +
/// double-click select-word + rapid clicking + CJK IME — all WITHOUT freezing" BEFORE any visual or
/// feature layer is stacked on top. The previous (deleted) rebuild stacked every layer first, then could
/// never find the "double-click freeze"; this time we bisect — add one layer, deep-test, only then the
/// next, so a regression names its own cause.
///
/// Anti-bug discipline held here (from the E0 post-mortem):
///  1. NO preset non-empty selection at mount — super_editor #2995 (`DocumentSelectionOpenAndClose
///     ImePolicy` remounted with an active selection → setState-during-build crash). Any programmatic
///     selection is set AFTER the first frame.
///  2. A FRESH [documentLayoutKey] per State — never shared/churned across document rebuilds (the old
///     build reused one GlobalKey and crashed on document swap with "duplicate GlobalKey").
///  3. Returns a BARE [SuperEditor] — no box wrapper. Under an ancestor Scrollable it renders as a sliver;
///     wrapping it in a box breaks that protocol (and overlays must be hand-managed, not Stack/Positioned).
///  4. [inputSource] = IME (CJK's lifeline — only the IME path handles the composing region).
///
/// Everything above the floor is layered on: An-primitive component builders + the from-scratch
/// stylesheet, slash / @ / the selection toolbar (with link input), syntax highlight, tables, and the
/// markdown codec (an_editor_markdown.dart).
///
/// 原生编辑器 E1:最小可编辑面。先证「挂载+编辑+双击选词+狂点+中文 IME 不卡死」,再逐层往上盖(严格增量二分,
/// 哪层引卡当场抓),而非像上次攒齐所有层后对着「点两下卡死」猜。避坑铁律见上。
class AnEditor extends StatefulWidget {
  const AnEditor({
    super.key,
    this.initialMarkdown,
    this.resolvedNames = const {},
    this.onChangedMarkdown,
    this.mentionSource,
    this.shrinkWrap = false,
    this.scrollController,
    this.prose,
  }) : debugDocument = null;

  /// Seed the editor with a caller-built document (KNOWN node ids) so widget-tests can drive the robot's
  /// `nodeId`-addressed taps/carets. Not for production — the real editor loads from markdown. 测试用:传已知 id 文档。
  @visibleForTesting
  const AnEditor.withDocument(
    MutableDocument this.debugDocument, {
    super.key,
    this.mentionSource,
    this.onChangedMarkdown,
  })  : initialMarkdown = null,
        resolvedNames = const {},
        shrinkWrap = false,
        scrollController = null,
        prose = null;

  final MutableDocument? debugDocument;

  /// The document's markdown content to load (E9). Mentions (`[[id]]`) inflate to pills, resolving display
  /// names from [resolvedNames]. Null → an EMPTY document. 载入的 markdown(`[[id]]`→药丸);null=空文档。
  final String? initialMarkdown;

  /// id→name for the `[[id]]` mentions in [initialMarkdown] (from `MentionSource.resolveNames`, resolved by
  /// the caller before build). Unknown ids show the bare id. `[[id]]` 的 id→名(调用方先解析)。
  final Map<String, String> resolvedNames;

  /// Fires the document's full markdown on EVERY edit (the caller debounces for the save). 每次编辑吐 markdown。
  final ValueChanged<String>? onChangedMarkdown;

  /// The @-mention data seam (entity search + id→name resolve). Null → `@` inserts a literal `@` with no
  /// picker (e.g. tests that don't exercise mentions). @ 提及数据缝;null=无 picker(不测提及时)。
  final MentionSource? mentionSource;

  /// Size the editor to its content instead of owning its own scroll — the documents ocean sets this so
  /// its header co-scrolls with the body inside ONE outer scrollable (super_editor then attaches its
  /// caret keep-visible auto-scroll to that ancestor scrollable). 随内容高、滚动归外层(文档海洋同滚头)。
  final bool shrinkWrap;

  /// The editor-owned scroll controller (standalone hosts, e.g. the harness, when NOT [shrinkWrap]).
  /// 编辑器自持滚动时的控制器(独立宿主用;shrinkWrap 时不传)。
  final ScrollController? scrollController;

  /// The CONTENT (②) font override — the serif / system face layered over the editor's PROSE blocks
  /// (body / headings / blockquote / table), from `contentFaceProvider`. `null` = the default sans → the
  /// document renders exactly as today. Code blocks + inline code stay mono (the code axis governs them).
  /// The stylesheet re-memoizes when this changes (a live switch). 内容字体覆盖:衬线/系统脸覆盖编辑器 prose 块;
  /// null=默认 sans(=现状);代码块与内联码守 mono;变化时样式表重记忆(即时切换)。
  final AnFace? prose;

  @override
  State<AnEditor> createState() => AnEditorState();
}

/// The editor's state — public so a host (the documents document view) can reach the document for outline
/// extraction + a heading's on-screen rect for scroll-to-heading, via a `GlobalKey<AnEditorState>`. 公开态:
/// 供文档视图取文档(抽大纲)+ 标题屏上矩形(跳转)。
class AnEditorState extends State<AnEditor> {
  /// The live document — the host derives the outline + heading node ids from it. 活文档(供宿主抽大纲)。
  Document get document => _document;

  /// The ordered node ids of the document's headings (paragraphs whose blockType is a header). A heading INSIDE
  /// a blockquote (`> # x`, quoteDepth>0) is quoted content, NOT a document heading — it renders heading-styled
  /// but is excluded from the outline (matching `extractDocOutline`, which also skips quoted `#`). 引用内的 `#`
  /// 是引用内容、非文档标题:样式仍是标题、但不进大纲(与 extractDocOutline 一致)。
  List<String> get headingNodeIds => [
        for (final node in _document)
          if (node is ParagraphNode && _isHeader(node.getMetadataValue('blockType')) && quoteDepthOf(node) == 0)
            node.id,
      ];

  /// A node's top Y in the document's CONTENT space (0 = top of content) — i.e. the scroll offset that
  /// brings it to the viewport top. Null until laid out. 节点在内容空间的顶 Y(=让它到视口顶的滚动位)。
  double? contentTopForNode(String nodeId) {
    final layout = _docLayoutKey.currentState as DocumentLayout?;
    if (layout == null) return null;
    final rect = layout.getRectForPosition(
      DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 0)),
    );
    return rect?.top;
  }

  // ALL six ATX depths count — the outline extractor (extractDocOutline) lists h4–h6 too (folded into
  // level 3), and the outline's jump key is the SHARED document-order index: excluding any depth here
  // would misalign every jump after the first deep heading. 六档全算——大纲提取含 h4–h6(并入 3 级),跳转键
  // 是共享的文档序下标,漏任何一档都会让其后的跳转全体错位。
  static bool _isHeader(Object? blockType) =>
      blockType == header1Attribution ||
      blockType == header2Attribution ||
      blockType == header3Attribution ||
      blockType == header4Attribution ||
      blockType == header5Attribution ||
      blockType == header6Attribution;

  late final Editor _editor;
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final FocusNode _focusNode;

  // Fresh per State — never shared across document rebuilds (old build reused one GlobalKey → crash on
  // document swap). E1 never swaps the document, but the key discipline is set from the start. 每 State 一把。
  final GlobalKey _docLayoutKey = GlobalKey();

  // One stable GlobalKey per code-block node id — keeps the embedded AnCodeEditor's State (controller /
  // focus / caret) alive across the whole-node ReplaceNode we run on every keystroke. Owned here (per
  // AnEditor State), passed into AnCodeBlockComponentBuilder. 每代码节点一把稳定 key,保嵌入编辑器 State 跨整节点替换。
  final Map<String, GlobalKey> _codeKeys = {};

  // Same discipline for tables: one stable key per table node — cell field States survive the per-edit
  // whole-node replace, and the keyboard "enter the table" action reaches the grid to focus a cell.
  // 表格同款:每表一把稳定 key——cell 字段态跨整节点替换存活,键盘进表动作也经它聚焦格。
  final Map<String, GlobalKey<AnEditableTableState>> _tableKeys = {};

  // The live locale's translations, cached here because the slash listener fires OUTSIDE build (a
  // ValueNotifier dispatch mid-edit) where an inherited lookup is unreliable — didChangeDependencies is
  // the sanctioned refresh point (also re-runs on a locale flip). 监听器在 build 外跑,inherited 查询不可靠
  // ——在 didChangeDependencies 缓存(换语言也会重跑)。
  late Translations _t;

  // ── E4 slash menu ──────────────────────────────────────────────────────────────────────────────
  // The official ActionTagsPlugin tokenizes the `/` trigger (detect / track query / cancel-on-space) so
  // we never hand-roll that; we only draw the popover. It rides an OverlayPortal (clean insert/remove
  // lifecycle — NOT a hand-managed Overlay + reused GlobalKey, the freeze the old rebuild died on, E0 #2).
  // 官方 ActionTagsPlugin 托管 `/` 词法,我只画弹层;弹层走 OverlayPortal(干净生命周期,非手管 Overlay+复用 GlobalKey)。
  late final ActionTagsPlugin _slashTags;

  List<SlashCommand> _slashMatches = const [];
  int _slashActive = 0;
  IndexedTag? _slashTag;
  bool get _slashOpen => _slashTag != null && _slashMatches.isNotEmpty;

  // Memoized SuperEditor stylesheet + component builders (C-010) — rebuilt only when the theme [colors]
  // instance changes, so SuperEditor keeps the SAME config across content rebuilds. 样式表+组件建造器记忆化。
  Stylesheet? _stylesheet;
  List<ComponentBuilder>? _componentBuilders;
  SelectionStyles? _selectionStyles;
  AnColors? _styleColors;
  String? _hintText; // the empty-doc placeholder (locale-dependent) — re-memoized when it changes
  AnFace? _styleProse; // the CONTENT face the sheet was built with — re-memoized on a live switch 内容脸(切换即重建)

  // Serialize-on-idle: markdown serialization is O(document) — running it on EVERY keystroke (the change
  // listener) made each key pay a whole-document serialize. The autosave semantics only need the LAST state
  // of a typing burst, so the serialize itself rides the autosave debounce tier; flushed on dispose so the
  // final edit is never dropped (C-001 discipline). 序列化按闲:整篇序列化 O(文档),逐键跑=每键全文档开销;
  // 自动存语义只要突发的最终态,故序列化本身也走 autosave 防抖档;dispose flush 保末次编辑不丢。
  final Debouncer _serializeDebouncer = Debouncer(AnMotion.autosave);

  // ── E5 @ mention ───────────────────────────────────────────────────────────────────────────────
  // StableTagPlugin tokenizes the `@` trigger (its own key, so it coexists with the slash ActionTagsPlugin
  // — two ActionTagsPlugins would clash on a shared key). We drive the picker off its composing state and
  // do our OWN commit (insert an inline mention pill, not the plugin's stable-tag token). 官方 `@` 词法。
  StableTagPlugin? _mentionTags;
  List<MentionCandidate> _mentionMatches = const [];
  int _mentionActive = 0;
  ComposingStableTag? _mentionComposing;
  int _mentionSearchSeq = 0; // guards async search races (only the latest query's results win) 防异步竞态
  bool get _mentionOpen => _mentionComposing != null && _mentionMatches.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _slashTags = ActionTagsPlugin();
    // The `@` plugin only exists when a mention source is wired (no source → no picker). 有源才建 @ 插件。
    if (widget.mentionSource != null) _mentionTags = StableTagPlugin();
    // Load order: a test/harness-supplied document, else markdown (E9), else an EMPTY doc. No demo seed
    // lives in this production file — the dev harness supplies its own content. 无 demo 种子在生产文件;
    // harness 自带内容,兜底为空文档(单空段)。
    _document = widget.debugDocument ??
        (widget.initialMarkdown != null
            ? documentFromMarkdown(widget.initialMarkdown!, names: widget.resolvedNames)
            : MutableDocument(nodes: [ParagraphNode(id: Editor.createNodeId(), text: AttributedText())]));
    // NO initial selection — the composer starts with a null selection (#2995 discipline). A caret appears
    // on the first tap / focus. 起手不给选区(#2995)。
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: _document,
      composer: _composer,
      isHistoryEnabled: true, // undo/redo
    );
    // Inline markdown-on-type (placeholder-guarded official reaction) runs FIRST — a closed `**bold**` /
    // `` `code` `` / etc. upstream of the caret converts to its attribution. A′ 行内 markdown 即打即转在前。
    _editor.reactionPipeline.insert(0, const InlineMarkdownReaction());
    // Notion-parity BLOCK shortcuts super_editor's defaults lack: `[]`+space→todo, ```` ``` ````+space→code
    // block, `+`+space→bullet (headings/bullets/ordered/quote/hr already fire via the default reactions).
    // 补 super_editor 默认缺的 Notion 块级快捷(标题/列表/引用/分隔线走默认)。
    _editor.reactionPipeline.addAll(const [
      TodoConversionReaction(),
      CodeFenceConversionReaction(),
      PlusBulletConversionReaction(),
      // LAST: after any reaction that creates/edits inline code, ensure each `codeAttribution` run keeps its real
      // NBSP padding spacers (so the paint-beneath background has true padding that pushes neighbours, not a
      // paint inflation that overlaps them). Idempotent + IME-safe. 末位:保行内代码两侧真 NBSP 内距(顶开邻居,非画膨胀盖字)。
      CodePadReconcileReaction(),
    ]);
    _slashTags.composingActionTag.addListener(_onSlashComposingChanged);
    _mentionTags?.tagIndex.composingStableTag.addListener(_onMentionComposingChanged);
    _focusNode.addListener(_onEditorFocusChanged);
    if (widget.onChangedMarkdown != null) _document.addListener(_onDocumentChanged);
  }

  // ONE caret at a time. super_editor clears its selection when the editor "loses focus", but its test is
  // `!focusNode.hasFocus` (document_focus_and_selection_policies.dart:228) — and `hasFocus` stays TRUE while
  // a DESCENDANT holds the keyboard. Our embedded editables (the code block's field, a table cell) live
  // INSIDE the editor's subtree, so clicking into one left the document caret alive and blinking next to the
  // field's own: two carets, one of them the block-edge bar as tall as the whole block (measured 72px on a
  // table). The editor hands its own node to every subsystem (IME + gestures both get `focusNode: _focusNode`),
  // so `hasFocus && !hasPrimaryFocus` means exactly one thing: an embedded field took the keyboard → the
  // document must drop its caret. 一次只有一根光标。上游「失焦清选区」的判据是 `!hasFocus`,而后代持焦时
  // hasFocus 仍为 true——我们的内嵌可编辑件(码块字段/表格格)就在编辑器子树内,故点进去后文档光标继续闪、
  // 与字段自己的光标凑成两根(其一是与整块等高的块边条,表格上实测 72px)。编辑器把自身结点交给所有子系统
  // (IME 与手势都收 `focusNode: _focusNode`),故 `hasFocus && !hasPrimaryFocus` 只意味一件事:内嵌字段拿走了
  // 键盘 → 文档须收起光标。
  void _onEditorFocusChanged() {
    if (_focusNode.hasFocus && !_focusNode.hasPrimaryFocus && _composer.selection != null) {
      _editor.execute([const ClearSelectionRequest()]);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = Translations.of(context);
  }

  @override
  void dispose() {
    _slashTags.composingActionTag.removeListener(_onSlashComposingChanged);
    _mentionTags?.tagIndex.composingStableTag.removeListener(_onMentionComposingChanged);
    _focusNode.removeListener(_onEditorFocusChanged);
    if (widget.onChangedMarkdown != null) _document.removeListener(_onDocumentChanged);
    // Flush the pending serialize BEFORE tearing the document down — switching away inside the debounce
    // window must still deliver the last edit to the host's autosave. 先冲洗在途序列化再拆文档(防抖窗内切走不丢末次编辑)。
    _serializeDebouncer.flush();
    _serializeDebouncer.dispose();
    _editor.dispose();
    // Editor.dispose() does NOT cascade to its editables — dispose them explicitly or leak a broadcast
    // StreamController + notifier per mount. The composer is always ours; the document is only ours when
    // no debugDocument was injected. Editor.dispose 不级联 editable,须显式释放;debugDocument 归调用方。
    _composer.dispose();
    if (widget.debugDocument == null) _document.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Serialize the whole document to markdown ON IDLE (autosave debounce tier, see [_serializeDebouncer]) —
  // NOT per keystroke. 按闲序列化整篇为 markdown(autosave 防抖档),非逐键。
  void _onDocumentChanged(DocumentChangeLog _) =>
      _serializeDebouncer.run(() => widget.onChangedMarkdown?.call(markdownFromDocument(_document)));

  // The plugin drives this whenever the `/…` composing tag changes (opened, query grew, or cleared). We
  // filter the palette, clamp the active row, and show/hide the portal. Hiding on empty-matches keeps the
  // user typing without a dead panel. 词法变化→过滤命令、夹活动行、显隐弹层(无匹配即隐、不挡打字)。
  void _onSlashComposingChanged() {
    if (!mounted) return;
    final tag = _slashTags.composingActionTag.value;
    final matches =
        tag == null ? const <SlashCommand>[] : slashCommands.where((c) => c.matches(tag.tag.token, _t)).toList();
    setState(() {
      _slashTag = tag;
      _slashMatches = matches;
      _slashActive = _slashActive.clamp(0, matches.isEmpty ? 0 : matches.length - 1);
    });
    // No imperative show/hide — the document overlay layer reads _slashTag/_slashMatches on the rebuild
    // this setState triggers, and positions itself after layout. 无命令式显隐:overlay 层随此 setState 重建自定位。
  }

  // Applies a command: the official SubmitComposingActionTag deletes the `/query` text and collapses the
  // caret where it was, then the block-conversion requests run on the SAME node — one undoable step.
  // 应用命令:官方 Submit 删 `/query`+光标归位,紧接块转换请求(同节点,一个可撤销步)。
  void _selectSlash(SlashCommand command) {
    final tag = _slashTag;
    if (tag == null) return;
    // The requests are built BEFORE the submit deletes the `/query`, so pre-compute whether the trigger
    // paragraph will be EMPTY afterwards: it is iff the whole node IS the tag text. 请求在删 tag 前构建,
    // 预判提交后是否空段:整节点即 tag 文本时为空。
    final node = _document.getNodeById(tag.nodeId);
    final plain = node is TextNode ? node.text.toPlainText() : '';
    final emptyAfterSubmit = plain == '/${tag.tag.token}';
    _editor.execute([
      const SubmitComposingActionTagRequest(),
      ...command.requests((nodeId: tag.nodeId, document: _document, emptyAfterSubmit: emptyAfterSubmit)),
    ]);
    // The plugin clears composingActionTag → _onSlashComposingChanged hides the portal. 词法归零→自动隐。
  }

  void _dismissSlash() {
    _editor.execute([const CancelComposingActionTagRequest(defaultActionTagRule)]);
  }

  // Runs BEFORE the editor's own key handling (first in keyboardActions) — but only steals arrows/enter/
  // escape WHILE the menu is open, so normal typing/caret movement is untouched otherwise (E0 #3: custom
  // actions halt only when the panel is open). 菜单开时才截方向/回车/Esc,否则一律放行(仅开时 halt)。
  ExecutionInstruction _slashKeyAction({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
    if (!_slashOpen) return ExecutionInstruction.continueExecution;
    if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) return ExecutionInstruction.continueExecution;
    final n = _slashMatches.length;
    switch (keyEvent.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() => _slashActive = (_slashActive + 1) % n);
        return ExecutionInstruction.haltExecution;
      case LogicalKeyboardKey.arrowUp:
        setState(() => _slashActive = (_slashActive - 1 + n) % n);
        return ExecutionInstruction.haltExecution;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.tab:
        _selectSlash(_slashMatches[_slashActive]);
        return ExecutionInstruction.haltExecution;
      case LogicalKeyboardKey.escape:
        _dismissSlash();
        return ExecutionInstruction.haltExecution;
      default:
        return ExecutionInstruction.continueExecution;
    }
  }

  // ── table entry ────────────────────────────────────────────────────────────────────────────────
  // When the document caret sits ON a table block (arrows land on it as an atomic block — upstream's
  // design gives it no interior positions), Enter/↓ enter the FIRST row and ↑ the LAST row, focusing the
  // cell grid through the table's stable key. Fixes "arrows can reach the table but never get inside".
  // 光标落在表块上(方向键只能落块、进不去——上游无内部位置)时,Enter/↓ 进首行、↑ 进末行,经稳定 key 聚焦格。
  ExecutionInstruction _tableEnterKeyAction({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
    if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) return ExecutionInstruction.continueExecution;
    final key = keyEvent.logicalKey;
    final entersDown =
        key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.arrowDown;
    final entersUp = key == LogicalKeyboardKey.arrowUp;
    if (!entersDown && !entersUp) return ExecutionInstruction.continueExecution;
    final selection = _composer.selection;
    if (selection == null || !selection.isCollapsed) return ExecutionInstruction.continueExecution;
    final node = _document.getNodeById(selection.extent.nodeId);
    if (node is! TableBlockNode) return ExecutionInstruction.continueExecution;
    final table = _tableKeys[node.id]?.currentState;
    if (table == null) return ExecutionInstruction.continueExecution;
    table.focusCell(entersUp ? node.rowCount - 1 : 0, 0);
    return ExecutionInstruction.haltExecution;
  }

  // ── @ mention handlers ─────────────────────────────────────────────────────────────────────────
  // The composing `@query` changed — search the source (async, race-guarded) and refresh the picker. On
  // clear, close. 组字 `@query` 变→异步搜(防竞态)刷新 picker;清空则关。
  Future<void> _onMentionComposingChanged() async {
    final source = widget.mentionSource;
    if (!mounted || source == null) return;
    final composing = _mentionTags!.tagIndex.composingStableTag.value;
    if (composing == null) {
      // Bump the seq so any in-flight search from the just-cleared query is discarded when it resolves —
      // else a stale result would re-open the picker at a gone anchor. 作废在途搜索,防清空后 picker 复活。
      ++_mentionSearchSeq;
      setState(() {
        _mentionComposing = null;
        _mentionMatches = const [];
        _mentionActive = 0;
      });
      return;
    }
    final seq = ++_mentionSearchSeq;
    final results = await source.search(composing.token);
    if (!mounted || seq != _mentionSearchSeq) return; // a newer query superseded this one 更新的查询已覆盖
    setState(() {
      _mentionComposing = composing;
      _mentionMatches = results;
      _mentionActive = _mentionActive.clamp(0, results.isEmpty ? 0 : results.length - 1);
    });
  }

  // Commit: delete the `@query` span, insert the mention pill at its start, and clear the composing tag —
  // one undoable step. 删 `@query`+原位插药丸+清词法,一个可撤销步。
  void _selectMention(int index) {
    final composing = _mentionComposing;
    if (composing == null || index < 0 || index >= _mentionMatches.length) return;
    // Discard any in-flight search so it can't re-open the picker after we commit the pill. 作废在途搜索。
    ++_mentionSearchSeq;
    final c = _mentionMatches[index];
    // contentBounds starts AFTER the `@` trigger (startOffset+1), so extend the delete back one char to
    // swallow the `@` itself; the pill is inserted where the `@` was. contentBounds 不含 `@`,故起点退一位吞掉 `@`。
    final start = composing.contentBounds.start;
    final atStart = DocumentPosition(
      nodeId: start.nodeId,
      nodePosition: TextNodePosition(offset: (start.nodePosition as TextNodePosition).offset - 1),
    );
    _editor.execute([
      DeleteContentRequest(documentRange: DocumentRange(start: atStart, end: composing.contentBounds.end)),
      InsertAttributedTextRequest(
        atStart,
        AttributedText(' ', null, {0: MentionPlaceholder(id: c.id, name: c.name, kind: c.type)}),
      ),
      const CancelComposingStableTagRequest(userTagRule),
    ]);
  }

  void _dismissMention() {
    _editor.execute([const CancelComposingStableTagRequest(userTagRule)]);
  }

  ExecutionInstruction _mentionKeyAction({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
    if (!_mentionOpen) return ExecutionInstruction.continueExecution;
    if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) return ExecutionInstruction.continueExecution;
    final n = _mentionMatches.length;
    switch (keyEvent.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() => _mentionActive = (_mentionActive + 1) % n);
        return ExecutionInstruction.haltExecution;
      case LogicalKeyboardKey.arrowUp:
        setState(() => _mentionActive = (_mentionActive - 1 + n) % n);
        return ExecutionInstruction.haltExecution;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.tab:
        _selectMention(_mentionActive);
        return ExecutionInstruction.haltExecution;
      case LogicalKeyboardKey.escape:
        _dismissMention();
        return ExecutionInstruction.haltExecution;
      default:
        return ExecutionInstruction.continueExecution;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bare SuperEditor — no box wrapper (sliver protocol). IME input is CJK's lifeline. The stylesheet
    // carries the An prose voice onto the TEXT blocks (E2a); the block skins are ComponentBuilders; the
    // slash popover is a DOCUMENT OVERLAY LAYER (timing-safe, positions after layout). 裸 SuperEditor,IME 输入源;
    // slash 弹层=文档 overlay 层(布局就绪后自定位,时序安全)。
    final colors = context.colors;
    // Memoize the stylesheet + component builders on the (theme-stable) [colors] instance (C-010): rebuilt
    // fresh every build, SuperEditor saw a NEW stylesheet each time and could re-run its whole style
    // pipeline over the document. AnColors is a ThemeExtension (const light/dark), so identity is stable
    // until the theme flips → same instances → SuperEditor skips the re-style. 样式表+组件建造器按主题稳定
    // 的 colors 记忆化:同实例→SuperEditor 跳全文档重跑 style pipeline。
    final hint = _t.documents.editorHint;
    if (!identical(_styleColors, colors) || _hintText != hint || _styleProse != widget.prose) {
      _styleColors = colors;
      _hintText = hint;
      _styleProse = widget.prose;
      _stylesheet = buildAnEditorStylesheet(colors, prose: widget.prose);
      // The selection sweep colour — the An [AnColors.selection] token (semi-transparent accent), replacing
      // the package's hardcoded 0xFFACCEF7. Memoized with the stylesheet (same theme axis). 选区色走 token。
      _selectionStyles = SelectionStyles(selectionColor: colors.selection);
      _componentBuilders = [
        AnTaskComponentBuilder(_editor, colors), // tasks aren't in the defaults — must be added
        AnCodeBlockComponentBuilder(_editor, colors, _codeKeys),
        AnBlockquoteComponentBuilder(colors),
        // Ordered/unordered list items: marker = prose `•`/`$n.` (not derived from the first char → fixes the
        // code-first-word bug) + inner AnTextComponent (inline-code background). Must precede the defaults.
        // 列表项:记号用正文档(非首字符,修首词代码 bug)+ AnTextComponent 内芯;须在默认前。
        AnListItemComponentBuilder(colors, _document),
        // The EDITABLE table (cells = SuperTextFields over the upstream TableBlockNode; right-click menu;
        // Tab/arrow grid nav) — the upstream component is read-only by design. 可编辑表格(上游组件是刻意只读)。
        AnTableComponentBuilder(_editor, _document, _focusNode, _tableKeys),
        // The empty-doc placeholder: the hint builder paints [hint] on the ONE empty first paragraph (its
        // createViewModel returns a HintComponentViewModel only when node is the single first ParagraphNode) —
        // vanishes the moment the user types or a second block exists. View-only (never in the document model →
        // empty doc still serializes empty). MUST sit before the defaults so its createViewModel wins for the
        // empty first node. An-flavored so a SINGLE-paragraph doc with inline code still paints the code
        // background (its vm is a HintComponentViewModel, which AnParagraphComponentBuilder can't touch). 空文档
        // 灰提示只在「单个首空段」渲;须在默认前抢建 view-model;An 版让单段文档的行内代码也有背景。
        AnHintComponentBuilder(hint, (_) => AnText.reading.copyWith(color: colors.inkFaint),
            codeBackgroundColor: colors.surfaceSunken, codeBackgroundRadius: AnRadius.tag),
        // Paragraph/heading via AnParagraphComponent (AnTextComponent) so inline code paints a per-line
        // rounded background beneath the text. Must precede the default paragraph builder. 段落/标题换 An 组件。
        AnParagraphComponentBuilder(
            codeBackgroundColor: colors.surfaceSunken,
            codeBackgroundRadius: AnRadius.tag,
            document: _document,
            quoteColors: colors),
        ...defaultComponentBuilders,
      ];
    }
    return SuperEditor(
      editor: _editor,
      focusNode: _focusNode,
      documentLayoutKey: _docLayoutKey,
      shrinkWrap: widget.shrinkWrap,
      scrollController: widget.scrollController,
      inputSource: TextInputSource.ime,
      selectionPolicies: const SuperEditorSelectionPolicies(
        restorePreviousSelectionOnGainFocus: false,
        placeCaretAtEndOfDocumentOnGainFocus: false,
      ),
      // A DESKTOP editor — force MOUSE gestures so no mobile touch interactor puts up selection-handle
      // pointer-absorbers over the content (they'd swallow taps meant for our floating toolbar). 桌面=鼠标手势。
      gestureMode: DocumentGestureMode.mouse,
      plugins: {_slashTags, ?_mentionTags},
      // Our nav handlers run first, but each only intercepts while ITS menu is open. 导航处理先跑,各仅自开时截。
      keyboardActions: [
        _slashKeyAction,
        _mentionKeyAction,
        _tableEnterKeyAction,
        backspaceRevertBlockAction,
        ...defaultImeKeyboardActions,
      ],
      stylesheet: _stylesheet!,
      selectionStyle: _selectionStyles,
      // The default link-launch handler PLUS the block double/triple-tap guard (poisoned word-drag NPE —
      // see an_editor_gestures.dart). 默认链接 handler + 原子块双/三击守卫(防 word-drag 毒态 NPE)。
      contentTapDelegateFactories: const [superEditorLaunchLinkTapHandlerFactory, anBlockTapGuardFactory],
      // An-primitive block skins take precedence over the defaults they extend (first non-null wins);
      // the rest of the default chain (paragraph/list/image/hr) stays. An 块皮在默认前、优先命中。
      componentBuilders: _componentBuilders!,
      // Popovers + the selection toolbar overlay the content. The default caret layer is swapped for the An
      // caret (content-sized, ink — see an_editor_caret.dart); the gap layer fills inter-block padding
      // inside a cross-block sweep (an_editor_selection.dart). 浮层与划选条叠在内容上;默认 caret 层换 An 光标
      // (内容尺寸+ink),缝隙层填跨块选区的块间距。
      documentOverlayBuilders: [
        for (final builder in defaultSuperEditorDocumentOverlayBuilders)
          if (builder is! DefaultCaretOverlayBuilder) builder,
        AnSelectionGapLayerBuilder(colors.selection),
        const AnCaretOverlayBuilder(),
        FunctionalSuperEditorLayerBuilder(
          (context, editContext) => AnSelectionToolbar(
              editor: _editor, document: _document, composer: _composer, editorFocusNode: _focusNode),
        ),
        FunctionalSuperEditorLayerBuilder(
          (context, editContext) => AnSlashMenuOverlay(
            tag: _slashTag,
            matches: _slashMatches,
            activeIndex: _slashActive,
            onSelect: _selectSlash,
          ),
        ),
        FunctionalSuperEditorLayerBuilder(
          (context, editContext) => AnMentionOverlay(
            composing: _mentionComposing,
            items: [for (final c in _mentionMatches) AnMentionRowData(kind: c.type, name: c.name, description: c.description)],
            activeIndex: _mentionActive,
            onPick: _selectMention,
          ),
        ),
      ],
    );
  }
}
