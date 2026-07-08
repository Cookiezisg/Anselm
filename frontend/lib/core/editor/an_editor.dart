import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

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
/// Visual 1:1 (An-primitive component builders), the from-scratch stylesheet, slash / @ / the selection
/// toolbar, syntax highlight and the markdown codec all land in E2+.
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
  /// names from [resolvedNames]. Null → the built-in demo seed. 载入的 markdown(`[[id]]`→药丸,名从 resolvedNames)。
  final String? initialMarkdown;

  /// id→name for the `[[id]]` mentions in [initialMarkdown] (from `MentionSource.resolveNames`, resolved by
  /// the caller before build). Unknown ids show the bare id. `[[id]]` 的 id→名(调用方先解析)。
  final Map<String, String> resolvedNames;

  /// Fires the document's full markdown on EVERY edit (the caller debounces for the save). 每次编辑吐 markdown。
  final ValueChanged<String>? onChangedMarkdown;

  /// The @-mention data seam (entity search + id→name resolve). Null → `@` inserts a literal `@` with no
  /// picker (e.g. tests that don't exercise mentions). @ 提及数据缝;null=无 picker(不测提及时)。
  final MentionSource? mentionSource;

  /// Size the editor to its content instead of owning its own scroll — so a header can co-scroll with the
  /// body inside ONE outer scrollable (the documents ocean characteristic). 随内容高(与头同滚于外层)。
  final bool shrinkWrap;

  /// The outer scroll controller (when [shrinkWrap] + an ancestor scrollable own the scroll). 外层滚动控。
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

  static bool _isHeader(Object? blockType) =>
      blockType == header1Attribution || blockType == header2Attribution || blockType == header3Attribution;

  late final Editor _editor;
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final FocusNode _focusNode;

  // Fresh per State — never shared across document rebuilds (old build reused one GlobalKey → crash on
  // document swap). E1 never swaps the document, but the key discipline is set from the start. 每 State 一把。
  final GlobalKey _docLayoutKey = GlobalKey();

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
    // Load order: a test-supplied document, else markdown (E9), else the demo seed. 载入优先级。
    _document = widget.debugDocument ??
        (widget.initialMarkdown != null
            ? documentFromMarkdown(widget.initialMarkdown!, names: widget.resolvedNames)
            : _seedDocument());
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
  void dispose() {
    _slashTags.composingActionTag.removeListener(_onSlashComposingChanged);
    _mentionTags?.tagIndex.composingStableTag.removeListener(_onMentionComposingChanged);
    if (widget.onChangedMarkdown != null) _document.removeListener(_onDocumentChanged);
    _editor.dispose();
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
    final matches = tag == null ? const <SlashCommand>[] : slashCommands.where((c) => c.matches(tag.tag.token)).toList();
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
    _editor.execute([
      const SubmitComposingActionTagRequest(),
      ...command.requests(tag.nodeId),
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
      stylesheet: buildAnEditorStylesheet(colors),
      // An-primitive block skins take precedence over the defaults they extend (first non-null wins);
      // the rest of the default chain (paragraph/list/image/hr) stays. An 块皮在默认前、优先命中。
      componentBuilders: [
        AnTaskComponentBuilder(_editor, colors), // tasks aren't in the defaults — must be added
        AnCodeBlockComponentBuilder(colors),
        AnBlockquoteComponentBuilder(colors),
        const MarkdownTableComponentBuilder(), // tables aren't in the defaults either (E8)
        ...defaultComponentBuilders,
      ],
      // Popovers + the selection toolbar overlay the content, ON TOP of the default caret/handles layers.
      // 浮层与划选条叠在内容上。
      documentOverlayBuilders: [
        ...defaultSuperEditorDocumentOverlayBuilders,
        FunctionalSuperEditorLayerBuilder(
          (context, editContext) => AnSelectionToolbar(editor: _editor, document: _document, composer: _composer),
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

/// A small seed document exercising the block ladder (h1/h2/h3 + body) so the harness screenshot shows
/// the An prose voice. Later steps build the document from the documents feature's markdown content.
/// 种子文档:走一遍标题阶梯 + 正文,让 harness 截图看得见 An prose 声;markdown 编解码后置。
ParagraphNode _heading(String text, Attribution level) => ParagraphNode(
      id: Editor.createNodeId(),
      text: AttributedText(text),
      metadata: {'blockType': level},
    );

/// One table cell — a plain [TextNode] (the table grid holds these). 表格单元=纯文本节点。
ParagraphNode _cell(String text) => ParagraphNode(id: Editor.createNodeId(), text: AttributedText(text));

/// Builds an [AttributedText] from (text, inline-attribution?) runs, tracking offsets so each run's
/// [SpanRange] is exact (inclusive end). Lets a seed paragraph carry bold/italic/code/link spans without
/// hand-counting CJK indices. 从 (文本,行内属性?) 段拼 AttributedText,自动算 span 偏移(含 CJK)。
AttributedText _spans(List<(String, Attribution?)> runs) {
  final buffer = StringBuffer();
  final marks = <(Attribution, int, int)>[];
  var i = 0;
  for (final (text, attr) in runs) {
    if (attr != null) marks.add((attr, i, i + text.length - 1));
    buffer.write(text);
    i += text.length;
  }
  final at = AttributedText(buffer.toString());
  for (final (attr, start, end) in marks) {
    at.addAttribution(attr, SpanRange(start, end));
  }
  return at;
}

MutableDocument _seedDocument() => MutableDocument(
      nodes: [
        _heading('产品需求文档', header1Attribution),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText('原生 super_editor 编辑器 —— 每个块都是真 Flutter widget,用我们自己的 An 原语绘制,'
              '与产品其它面像素级一致。在这里直接打字,试试中文输入、双击选词、三击选段、狂点都不卡死。'),
        ),
        _heading('设计目标', header2Attribution),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText('视觉是第一标准:正文 15/1.6 的阅读声、标题阶梯靠字号与颜色分层,而非更重的字重。'),
        ),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: _spans([
            ('行内格式:', null),
            ('加粗', boldAttribution),
            ('(w400 两字重)、', null),
            ('斜体', italicsAttribution),
            ('、', null),
            ('删除线', strikethroughAttribution),
            ('、行内代码 ', null),
            ('print()', codeAttribution),
            (' 、以及', null),
            ('一条链接', LinkAttribution('https://anselm.website')),
            ('。', null),
          ]),
        ),
        // A @mention pill — the entity reference embedded inline (E5a). 内联实体提及药丸。
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText('输入 @ 可提及实体,如 。', null, {
            13: const MentionPlaceholder(id: 'wf_00000000000000a1', name: '每日销量对账', kind: 'workflow'),
          }),
        ),
        _heading('实现要点', header3Attribution),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText('这是第三层标题下的正文,用来验证跨块选区、光标落位与块间节奏。'),
        ),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText('引用是静默的旁白 —— 一条 2px 左边条 + 降一档的墨色,把补充说明从正文里轻轻托起,又不喧宾夺主。'),
          metadata: {'blockType': blockquoteAttribution},
        ),
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText('void main() {\n  print("你好, super_editor");\n}'),
          metadata: {'blockType': codeAttribution},
        ),
        _heading('列表', header3Attribution),
        ListItemNode.unordered(id: Editor.createNodeId(), text: AttributedText('无序项一 —— 圆点是 inkMuted 的静默标记。')),
        ListItemNode.unordered(id: Editor.createNodeId(), text: AttributedText('无序项二 —— 连续项收紧节奏。')),
        ListItemNode.ordered(id: Editor.createNodeId(), text: AttributedText('有序项一 —— 序号随 reading 正文声。')),
        ListItemNode.ordered(id: Editor.createNodeId(), text: AttributedText('有序项二。')),
        _heading('表格', header3Attribution),
        TableBlockNode(id: Editor.createNodeId(), cells: [
          [_cell('实体'), _cell('说明')],
          [_cell('工作流'), _cell('可 @ 提及、可 /trigger')],
          [_cell('函数'), _cell('可 /run')],
        ]),
        _heading('任务', header3Attribution),
        TaskNode(id: Editor.createNodeId(), text: AttributedText('未完成的任务 —— 方框可点切换。'), isComplete: false),
        TaskNode(id: Editor.createNodeId(), text: AttributedText('已完成的任务 —— 打勾变 ok 绿 + inkFaint 删除线。'), isComplete: true),
        // A trailing empty paragraph — a clean spot to type `/` (empty query → the whole slash palette).
        // 末尾空段:干净的 `/` 落点(空查询→整张 slash 表)。
        ParagraphNode(id: Editor.createNodeId(), text: AttributedText('')),
      ],
    );
