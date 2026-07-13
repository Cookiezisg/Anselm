import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../entity/mention_source.dart';
import '../ui/an_mention_picker.dart';
import 'an_editor_components.dart';
import 'an_editor_markdown.dart';
import 'an_editor_mention.dart';
import 'an_editor_slash_menu.dart';
import 'an_editor_stylesheet.dart';
import 'an_editor_syntax.dart';
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
        scrollController = null;

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

  @override
  State<AnEditor> createState() => AnEditorState();
}

/// The editor's state — public so a host (the documents document view) can reach the document for outline
/// extraction + a heading's on-screen rect for scroll-to-heading, via a `GlobalKey<AnEditorState>`. 公开态:
/// 供文档视图取文档(抽大纲)+ 标题屏上矩形(跳转)。
class AnEditorState extends State<AnEditor> {
  /// The live document — the host derives the outline + heading node ids from it. 活文档(供宿主抽大纲)。
  Document get document => _document;

  /// The ordered node ids of the document's headings (paragraphs whose blockType is a header). 标题节点 id 序。
  List<String> get headingNodeIds => [
        for (final node in _document)
          if (node is ParagraphNode && _isHeader(node.getMetadataValue('blockType'))) node.id,
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

  // The memoized syntax-highlight phase for code blocks (E7). Created once, its palette updated on a
  // theme flip. 代码块语法高亮 phase(记忆化);建一次、主题翻转换色。
  AnCodeSyntaxStylePhase? _syntaxPhase;

  // Memoized SuperEditor stylesheet + component builders (C-010) — rebuilt only when the theme [colors]
  // instance changes, so SuperEditor keeps the SAME config across content rebuilds. 样式表+组件建造器记忆化。
  Stylesheet? _stylesheet;
  List<ComponentBuilder>? _componentBuilders;
  AnColors? _styleColors;

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
    _slashTags.composingActionTag.addListener(_onSlashComposingChanged);
    _mentionTags?.tagIndex.composingStableTag.addListener(_onMentionComposingChanged);
    if (widget.onChangedMarkdown != null) _document.addListener(_onDocumentChanged);
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
    if (widget.onChangedMarkdown != null) _document.removeListener(_onDocumentChanged);
    _editor.dispose();
    // Editor.dispose() does NOT cascade to its editables — dispose them explicitly or leak a broadcast
    // StreamController + notifier per mount. The composer is always ours; the document is only ours when
    // no debugDocument was injected. Editor.dispose 不级联 editable,须显式释放;debugDocument 归调用方。
    _composer.dispose();
    if (widget.debugDocument == null) _document.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Serialize the whole document to markdown on every edit — the caller debounces this for the save.
  // 每次编辑序列化整篇为 markdown(调用方防抖后存)。
  void _onDocumentChanged(DocumentChangeLog _) => widget.onChangedMarkdown?.call(markdownFromDocument(_document));

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
    // Create the syntax phase once, refresh its palette each build (cheap; no-ops unless the theme flipped).
    // 语法 phase 建一次、每 build 刷新调色板(主题没变即 no-op)。
    (_syntaxPhase ??= AnCodeSyntaxStylePhase(context.syntax)).colors = context.syntax;
    // Memoize the stylesheet + component builders on the (theme-stable) [colors] instance (C-010): rebuilt
    // fresh every build, SuperEditor saw a NEW stylesheet each time and could re-run its whole style
    // pipeline over the document. AnColors is a ThemeExtension (const light/dark), so identity is stable
    // until the theme flips → same instances → SuperEditor skips the re-style. 样式表+组件建造器按主题稳定
    // 的 colors 记忆化:同实例→SuperEditor 跳全文档重跑 style pipeline。
    if (!identical(_styleColors, colors)) {
      _styleColors = colors;
      _stylesheet = buildAnEditorStylesheet(colors);
      _componentBuilders = [
        AnTaskComponentBuilder(_editor, colors), // tasks aren't in the defaults — must be added
        AnCodeBlockComponentBuilder(colors),
        AnBlockquoteComponentBuilder(colors),
        const MarkdownTableComponentBuilder(), // tables aren't in the defaults either (E8)
        ...defaultComponentBuilders,
      ];
    }
    return SuperEditor(
      editor: _editor,
      focusNode: _focusNode,
      documentLayoutKey: _docLayoutKey,
      customStylePhases: [_syntaxPhase!],
      shrinkWrap: widget.shrinkWrap,
      scrollController: widget.scrollController,
      inputSource: TextInputSource.ime,
      // A DESKTOP editor — force MOUSE gestures so no mobile touch interactor puts up selection-handle
      // pointer-absorbers over the content (they'd swallow taps meant for our floating toolbar). 桌面=鼠标手势。
      gestureMode: DocumentGestureMode.mouse,
      plugins: {_slashTags, ?_mentionTags},
      // Our nav handlers run first, but each only intercepts while ITS menu is open. 导航处理先跑,各仅自开时截。
      keyboardActions: [_slashKeyAction, _mentionKeyAction, ...defaultImeKeyboardActions],
      stylesheet: _stylesheet!,
      // An-primitive block skins take precedence over the defaults they extend (first non-null wins);
      // the rest of the default chain (paragraph/list/image/hr) stays. An 块皮在默认前、优先命中。
      componentBuilders: _componentBuilders!,
      // Popovers + the selection toolbar overlay the content, ON TOP of the default caret/handles layers.
      // 浮层与划选条叠在内容上。
      documentOverlayBuilders: [
        ...defaultSuperEditorDocumentOverlayBuilders,
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
