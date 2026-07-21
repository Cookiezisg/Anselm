import 'dart:math';

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/editor/an_editor_components.dart';
import 'package:anselm/core/editor/an_editor_list_components.dart';
import 'package:anselm/core/editor/an_editor_quote.dart';
import 'package:anselm/core/editor/an_editor_stylesheet.dart';
import 'package:anselm/core/editor/an_editor_table.dart';
import 'package:anselm/core/editor/an_editor_text_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
// The composing-region styler is package-internal (not exported by the upstream barrel) but the
// production pipeline includes it (super_editor.dart:629) — the rig must replicate that pipeline 1:1.
// 组字相是包内部类(上游 barrel 未导出)但生产管线包含它——rig 必须 1:1 复刻。
// ignore: implementation_imports
import 'package:super_editor/src/default_editor/layout_single_column/_styler_composing_region.dart';

// ══════════════════════════════════════════════════════════════════════════════════════════════════
// The DIFFERENTIAL rig for the vendored presenter (ADR 0009) — the "bug free" contract made executable.
//
// Two [SingleColumnLayoutPresenter]s are mounted over the SAME document + composer, each with its OWN
// pipeline instances (sharing one pipeline would silently rewire `dirtyCallback` — a single slot — onto
// the second presenter and make every comparison a false green). Presenter A runs the retained FULL
// rebuild path (upstream's exact behaviour = the oracle); presenter B runs the node-level incremental
// path. After every edit both are pulled and their view models compared FIELD BY FIELD — `==` first
// (every vm implements a deep ==), then a STYLE PROBE: `==` deliberately skips the `textStyleBuilder`
// closure, and a closure that captured a stale stylesheet would silently pass `==` while rendering the
// wrong font on screen, so each text vm's builder is invoked with fixed attribution sets and the
// resulting TextStyles compared.
//
// Coverage: a scripted pass that hits every edge of the cross-node dependency map (ordinal runs /
// prev-block heading gap / quote continuation / `.after()` selector / first+last / hint node-count /
// selection interval / composing region), then seeded random fuzz (documents × edit sequences; failures
// print the seed + step for exact replay).
//
// 差分 rig(ADR 0009)——「bug free」的可执行契约。两个 presenter 骑同一份文档+composer,**各自持有独立的
// pipeline 实例**(共享会把单槽 dirtyCallback 静默改挂到第二个身上=假绿)。A=保留的全量路径(上游原行为,
// oracle);B=节点级增量路径。每次编辑后双方拉取并**逐字段**比对:先 `==`(全部 vm 都实现深比),再**样式
// 探针**——`==` 刻意不比 textStyleBuilder 闭包,捕获了陈旧样式表的闭包能静默过 `==` 而真机字体渲错,故用
// 固定 attribution 集调用 builder、比对产出的 TextStyle。覆盖:先按跨节点依赖图逐边打的脚本(序号串/
// 前驱标题距/引用延续/.after() 选择器/首末块/hint 节点数/选区区间/组字区),再种子化随机 fuzz(失败打印
// 种子+步数,可逐字复现)。
// ══════════════════════════════════════════════════════════════════════════════════════════════════

/// The probe attribution sets — chosen to exercise every branch of [anInlineTextStyler]. 样式探针集。
final List<Set<Attribution>> _probeSets = [
  const {},
  {boldAttribution},
  {italicsAttribution},
  {codeAttribution},
  {boldAttribution, italicsAttribution},
];

/// One presenter + its own pipeline over the shared document/composer. 一台 presenter+自有管线。
class _Rig {
  _Rig({
    required MutableDocument document,
    required MutableDocumentComposer composer,
    required Editor editor,
    required FocusNode focusNode,
    required bool incremental,
  }) : presenter = SingleColumnLayoutPresenter(
         document: document,
         componentBuilders: _builders(document, editor, focusNode),
         pipeline: _pipeline(document, composer),
         incremental: incremental,
       );

  final SingleColumnLayoutPresenter presenter;

  // The REAL builder chain, mirroring an_editor.dart's assembly (same order — first non-null wins).
  // 真实建造链,镜像 an_editor.dart 的装配(同序,首个非 null 胜出)。
  static List<ComponentBuilder> _builders(
    MutableDocument document,
    Editor editor,
    FocusNode focusNode,
  ) {
    const colors = AnColors.light;
    return [
      AnTaskComponentBuilder(editor, colors),
      AnCodeBlockComponentBuilder(editor, colors, {}),
      AnBlockquoteComponentBuilder(colors),
      AnListItemComponentBuilder(colors, document),
      AnTableComponentBuilder(editor, document, focusNode, {}),
      AnHintComponentBuilder(
        'hint',
        (_) => AnText.reading.copyWith(color: colors.inkFaint),
        codeBackgroundColor: colors.surfaceSunken,
        codeBackgroundRadius: AnRadius.tag,
      ),
      AnParagraphComponentBuilder(
        codeBackgroundColor: colors.surfaceSunken,
        codeBackgroundRadius: AnRadius.tag,
        document: document,
        quoteColors: colors,
      ),
      ...defaultComponentBuilders,
    ];
  }

  // The REAL pipeline, 1:1 with SuperEditor's `_createLayoutPresenter` (super_editor.dart:604-641) on
  // macOS (composing styler INCLUDED — the production target platform; CJK is this project's main input
  // path). FRESH instances per rig — never shared. 真实管线,1:1 复刻上游装配(macOS 含组字相);每台新建。
  static List<SingleColumnLayoutStylePhase> _pipeline(
    MutableDocument document,
    MutableDocumentComposer composer,
  ) {
    final stylesheet = buildAnEditorStylesheet(AnColors.light);
    return [
      SingleColumnStylesheetStyler(stylesheet: stylesheet),
      SingleColumnLayoutCustomComponentStyler(),
      CustomUnderlineStyler(),
      SingleColumnLayoutComposingRegionStyler(
        document: document,
        composingRegion: composer.composingRegion,
        showComposingUnderline: true,
      ),
      SingleColumnLayoutSelectionStyler(
        document: document,
        selection: composer.selectionNotifier,
        selectionStyles: SelectionStyles(
          selectionColor: AnColors.light.selection,
        ),
        selectedTextColorStrategy: stylesheet.selectedTextColorStrategy,
      ),
    ];
  }
}

/// Compare two layout view models FIELD BY FIELD; [context] names the failing step for replay.
/// 逐字段比对两个布局 vm;context 指名失败步供复现。
void _expectSame(
  SingleColumnLayoutViewModel a,
  SingleColumnLayoutViewModel b,
  String context,
) {
  expect(
    b.componentViewModels.length,
    a.componentViewModels.length,
    reason: '[$context] node count diverged',
  );
  for (var i = 0; i < a.componentViewModels.length; i++) {
    final va = a.componentViewModels[i], vb = b.componentViewModels[i];
    expect(
      vb.nodeId,
      va.nodeId,
      reason: '[$context] node order diverged at #$i',
    );
    expect(
      vb.runtimeType,
      va.runtimeType,
      reason: '[$context] vm TYPE diverged at #$i (${va.nodeId})',
    );
    expect(
      vb == va,
      isTrue,
      reason:
          '[$context] vm deep-== diverged at #$i (${va.nodeId}, ${va.runtimeType})\n  oracle: $va\n  incremental: $vb',
    );
    // STYLE PROBE — the closure gap `==` can't see. Known remaining unprobed closures:
    // `inlineWidgetBuilders` and `composingRegionUnderlineStyle` come exclusively from the stylesheet,
    // whose swap dirties the whole phase (full restyle) — physically backstopped today; re-probe if any
    // phase ever writes them per-node. 样式探针——== 看不见的闭包缺口。已知未探的闭包:
    // inlineWidgetBuilders/composingRegionUnderlineStyle 只来自样式表,换样式表=整相脏全量重刷,当下有
    // 物理兜底;将来若有相按节点写它们须补探。
    if (va is TextComponentViewModel && vb is TextComponentViewModel) {
      for (final probe in _probeSets) {
        final sa = (va as dynamic).textStyleBuilder(probe) as TextStyle;
        final sb = (vb as dynamic).textStyleBuilder(probe) as TextStyle;
        expect(
          sb,
          sa,
          reason:
              '[$context] textStyleBuilder($probe) diverged at #$i (${va.nodeId}) — '
              'a stale-stylesheet closure would pass == but render wrong',
        );
      }
    }
    // Table cells carry PER-CELL textStyleBuilder closures (header row ≠ data row) that the table vm's
    // `==` skips entirely — probe every cell. 表格 cell 逐格持样式闭包(表头≠数据行),表 vm 的 == 全跳,
    // 逐格探。
    if (va is MarkdownTableViewModel && vb is MarkdownTableViewModel) {
      expect(
        vb.cells.length,
        va.cells.length,
        reason: '[$context] table row count diverged (${va.nodeId})',
      );
      for (var r = 0; r < va.cells.length; r++) {
        expect(
          vb.cells[r].length,
          va.cells[r].length,
          reason: '[$context] table col count diverged (${va.nodeId} row $r)',
        );
        for (var c = 0; c < va.cells[r].length; c++) {
          for (final probe in _probeSets) {
            expect(
              vb.cells[r][c].textStyleBuilder(probe),
              va.cells[r][c].textStyleBuilder(probe),
              reason:
                  '[$context] table cell ($r,$c) textStyleBuilder($probe) diverged (${va.nodeId})',
            );
          }
        }
      }
    }
  }
}

/// The whole comparison step: pull both presenters, compare. 拉取双方并比对。
void _pullAndCompare(_Rig oracle, _Rig incremental, String context) {
  oracle.presenter.updateViewModel();
  incremental.presenter.updateViewModel();
  _expectSame(
    oracle.presenter.viewModel,
    incremental.presenter.viewModel,
    context,
  );
}

/// A 2×2 table node (header row + one data row). The header/data rows carry DIFFERENT textStyleBuilder
/// closures once styled — the style-probe must see both. 2×2 表(表头+数据行);两行被盖不同样式闭包,
/// 探针须两行都探。
TableBlockNode _table(String id, String seed) => TableBlockNode(
  id: id,
  cells: [
    [
      TextNode(id: '${id}_h0', text: AttributedText('Head A $seed')),
      TextNode(id: '${id}_h1', text: AttributedText('Head B $seed')),
    ],
    [
      TextNode(id: '${id}_d0', text: AttributedText('data 0 $seed')),
      TextNode(id: '${id}_d1', text: AttributedText('data 1 $seed')),
    ],
  ],
);

/// A mixed-block document exercising every builder + every dependency edge. 混排文档,踩全建造器+依赖边。
MutableDocument _mixedDocument() => MutableDocument(
  nodes: [
    ParagraphNode(
      id: 'p0',
      text: AttributedText('opening paragraph with some words'),
    ),
    ParagraphNode(
      id: 'h1',
      text: AttributedText('A heading'),
      metadata: {'blockType': header1Attribution},
    ),
    ParagraphNode(
      id: 'p1',
      text: AttributedText('after heading — the heading-gap dependency'),
    ),
    ListItemNode(
      id: 'ol1',
      itemType: ListItemType.ordered,
      text: AttributedText('first ordered'),
    ),
    ListItemNode(
      id: 'ol2',
      itemType: ListItemType.ordered,
      text: AttributedText('second ordered'),
    ),
    ListItemNode(
      id: 'ol3',
      itemType: ListItemType.ordered,
      text: AttributedText('third ordered'),
    ),
    ListItemNode(
      id: 'ul1',
      itemType: ListItemType.unordered,
      text: AttributedText('a bullet'),
    ),
    TaskNode(id: 't1', text: AttributedText('a task'), isComplete: false),
    ParagraphNode(
      id: 'q1',
      text: AttributedText('quoted line'),
      metadata: const {quoteDepthKey: 1},
    ),
    ParagraphNode(
      id: 'q2',
      text: AttributedText('quoted continuation'),
      metadata: const {quoteDepthKey: 1},
    ),
    ParagraphNode(
      id: 'bq',
      text: AttributedText('blockquote'),
      metadata: {'blockType': blockquoteAttribution},
    ),
    CodeBlockNode(id: 'cb', code: 'var x = 1;', language: 'dart'),
    _table('tbl', 'v1'),
    HorizontalRuleNode(id: 'hr'),
    ParagraphNode(id: 'pEnd', text: AttributedText('the last paragraph')),
  ],
);

/// Everything a differential step needs. 一步差分所需的全部现场。
({
  MutableDocument doc,
  MutableDocumentComposer composer,
  Editor editor,
  _Rig oracle,
  _Rig incremental,
  FocusNode focusNode,
})
_mount(MutableDocument doc) {
  final composer = MutableDocumentComposer();
  final editor = createDefaultDocumentEditor(
    document: doc,
    composer: composer,
    isHistoryEnabled: true,
  );
  final focusNode = FocusNode();
  final oracle = _Rig(
    document: doc,
    composer: composer,
    editor: editor,
    focusNode: focusNode,
    incremental: false,
  );
  final incremental = _Rig(
    document: doc,
    composer: composer,
    editor: editor,
    focusNode: focusNode,
    incremental: true,
  );
  return (
    doc: doc,
    composer: composer,
    editor: editor,
    oracle: oracle,
    incremental: incremental,
    focusNode: focusNode,
  );
}

void _unmount(
  ({
    MutableDocument doc,
    MutableDocumentComposer composer,
    Editor editor,
    _Rig oracle,
    _Rig incremental,
    FocusNode focusNode,
  })
  m,
) {
  m.oracle.presenter.dispose();
  m.incremental.presenter.dispose();
  m.editor.dispose();
  m.composer.dispose();
  m.doc.dispose();
  m.focusNode.dispose();
}

DocumentPosition _text(String nodeId, int offset) => DocumentPosition(
  nodeId: nodeId,
  nodePosition: TextNodePosition(offset: offset),
);

void main() {
  group('presenter differential — scripted (one step per dependency edge)', () {
    late ({
      MutableDocument doc,
      MutableDocumentComposer composer,
      Editor editor,
      _Rig oracle,
      _Rig incremental,
      FocusNode focusNode,
    })
    m;

    setUp(() {
      m = _mount(_mixedDocument());
      _pullAndCompare(m.oracle, m.incremental, 'initial mount');
    });
    tearDown(() => _unmount(m));

    void step(String context, List<EditRequest> requests) {
      m.editor.execute(requests);
      _pullAndCompare(m.oracle, m.incremental, context);
    }

    test('typing into a paragraph (the hot path)', () {
      step('type 1 char', [
        InsertTextRequest(
          documentPosition: _text('p0', 7),
          textToInsert: 'X',
          attributions: {},
        ),
      ]);
      step('type attributed', [
        InsertTextRequest(
          documentPosition: _text('p0', 8),
          textToInsert: 'Y',
          attributions: {boldAttribution},
        ),
      ]);
      step('delete a char', [
        DeleteContentRequest(
          documentRange: DocumentRange(
            start: _text('p0', 7),
            end: _text('p0', 9),
          ),
        ),
      ]);
    });

    test('ordered-list ordinal run (the unbounded dependency)', () {
      step('type in ol1', [
        InsertTextRequest(
          documentPosition: _text('ol1', 3),
          textToInsert: 'x',
          attributions: {},
        ),
      ]);
      step('delete ol2 (run renumbers)', [DeleteNodeRequest(nodeId: 'ol2')]);
      step('paragraph → list item joins the run', [
        ConvertParagraphToListItemRequest(
          nodeId: 'p1',
          type: ListItemType.ordered,
        ),
      ]);
    });

    test('block-type flips (the .after() + heading-gap dependencies)', () {
      step('p1 → header (successor gap changes)', [
        ChangeParagraphBlockTypeRequest(
          nodeId: 'p1',
          blockType: header2Attribution,
        ),
      ]);
      step('header → plain paragraph', [
        ChangeParagraphBlockTypeRequest(nodeId: 'p1', blockType: null),
      ]);
      step('task completion flip', [
        ChangeTaskCompletionRequest(nodeId: 't1', isComplete: true),
      ]);
      // The TARGETED heading-gap edge: h1's top gap reads its PREDECESSOR (p0) — flipping p0 into a
      // heading must restyle h1 (headingTop 24 → headingStack 12) even though h1 itself never changed.
      // A dirty radius without the successor edge reuses h1's stale vm here. 定向 heading-gap 边:
      // h1 上距读前驱 p0——p0 翻成标题必须重刷 h1(24→12),h1 自身没变;脏半径缺后继边就会在此复用陈旧 vm。
      step('flip a HEADING\'s predecessor (p0 → header)', [
        ChangeParagraphBlockTypeRequest(
          nodeId: 'p0',
          blockType: header2Attribution,
        ),
      ]);
      step('flip it back', [
        ChangeParagraphBlockTypeRequest(nodeId: 'p0', blockType: null),
      ]);
    });

    test(
      'structure: insert/remove/move/split/merge (first/last/order dependencies)',
      () {
        step('insert at head (old first loses .first())', [
          InsertNodeAtIndexRequest(
            nodeIndex: 0,
            newNode: ParagraphNode(
              id: 'pNew0',
              text: AttributedText('new head'),
            ),
          ),
        ]);
        step('insert at tail (old last loses .last())', [
          InsertNodeAtIndexRequest(
            nodeIndex: m.doc.nodeCount,
            newNode: ParagraphNode(
              id: 'pNewEnd',
              text: AttributedText('new tail'),
            ),
          ),
        ]);
        step('split a paragraph', [
          SplitParagraphRequest(
            nodeId: 'p0',
            splitPosition: const TextNodePosition(offset: 4),
            newNodeId: 'p0b',
            replicateExistingMetadata: true,
          ),
        ]);
        step('merge paragraphs back', [
          CombineParagraphsRequest(firstNodeId: 'p0', secondNodeId: 'p0b'),
        ]);
        step('move a node', [MoveNodeRequest(nodeId: 'ul1', newIndex: 2)]);
        step('delete head + tail', [
          DeleteNodeRequest(nodeId: 'pNew0'),
          DeleteNodeRequest(nodeId: 'pNewEnd'),
        ]);
      },
    );

    test('atomic-node replace (the code-block/table seam)', () {
      final node = m.doc.getNodeById('cb')! as CodeBlockNode;
      step('replace code block (same id)', [
        ReplaceNodeRequest(
          existingNodeId: 'cb',
          newNode: node.copyWithCode('var x = 2;\nvar y = 3;'),
        ),
      ]);
      // The table edit path in production IS a whole-node replace (an_editor_table.dart cell edits).
      // 生产上表格编辑就是整节点替换。
      step('replace table (same id, edited cells)', [
        ReplaceNodeRequest(existingNodeId: 'tbl', newNode: _table('tbl', 'v2')),
      ]);
    });

    test(
      'selection sweeps (the interval dependency, incl. the clear-out half)',
      () {
        step('collapsed caret', [
          ChangeSelectionRequest(
            DocumentSelection.collapsed(position: _text('p0', 3)),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);
        step('cross-block expand', [
          ChangeSelectionRequest(
            DocumentSelection(base: _text('p0', 1), extent: _text('ol2', 3)),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          ),
        ]);
        step('sweep MOVES elsewhere (old members must clear)', [
          ChangeSelectionRequest(
            DocumentSelection(base: _text('q1', 0), extent: _text('bq', 4)),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          ),
        ]);
        step('clear selection', [const ClearSelectionRequest()]);
      },
    );

    test('composing region (the CJK path)', () {
      step('place caret', [
        ChangeSelectionRequest(
          DocumentSelection.collapsed(position: _text('p0', 3)),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
      ]);
      step('set composing', [
        ChangeComposingRegionRequest(
          DocumentRange(start: _text('p0', 1), end: _text('p0', 3)),
        ),
      ]);
      step('move composing', [
        ChangeComposingRegionRequest(
          DocumentRange(start: _text('p0', 2), end: _text('p0', 3)),
        ),
      ]);
      step('clear composing', [const ClearComposingRegionRequest()]);
    });

    test('single-node document (the hint node-count dependency)', () {
      final single = _mount(
        MutableDocument(
          nodes: [ParagraphNode(id: 'only', text: AttributedText(''))],
        ),
      );
      addTearDown(() => _unmount(single));
      single.editor.execute([
        InsertNodeAtIndexRequest(
          nodeIndex: 1,
          newNode: ParagraphNode(id: 'second', text: AttributedText('x')),
        ),
      ]);
      _pullAndCompare(single.oracle, single.incremental, 'hint: 1→2 nodes');
      single.editor.execute([DeleteNodeRequest(nodeId: 'second')]);
      _pullAndCompare(single.oracle, single.incremental, 'hint: 2→1 nodes');
    });

    test(
      'C1: bare node delete under a cross-block selection — no stale highlight on middle nodes',
      () {
        // The selection VALUE never changes (same instance), so the selection styler's listener never
        // fires — yet deleting the extent node dangles the range and every previously-selected node's
        // "am I selected" answer flips. Only the structural-pass whole-phase rule catches this.
        // 选区值不变(同实例)、监听不触发,但删掉 extent 节点让区间悬垂,原选中节点的答案全翻——
        // 只有结构趟整相规则接得住。
        step('cross-block selection p0@1 → ol2@3', [
          ChangeSelectionRequest(
            DocumentSelection(base: _text('p0', 1), extent: _text('ol2', 3)),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          ),
        ]);
        step('bare-delete the selection extent node', [
          DeleteNodeRequest(nodeId: 'ol2'),
        ]);
        step('bare-delete a middle selected node too', [
          DeleteNodeRequest(nodeId: 'h1'),
        ]);
      },
    );

    test('C2: deleting every node — no ghost view models', () {
      final tiny = _mount(
        MutableDocument(
          nodes: [
            ParagraphNode(id: 'g1', text: AttributedText('first')),
            ParagraphNode(id: 'g2', text: AttributedText('second')),
          ],
        ),
      );
      addTearDown(() => _unmount(tiny));
      _pullAndCompare(tiny.oracle, tiny.incremental, 'C2 mount');
      tiny.editor.execute([const ClearSelectionRequest()]);
      tiny.editor.execute([DeleteNodeRequest(nodeId: 'g1')]);
      tiny.editor.execute([DeleteNodeRequest(nodeId: 'g2')]);
      _pullAndCompare(tiny.oracle, tiny.incremental, 'C2 emptied');
      expect(
        tiny.incremental.presenter.viewModel.componentViewModels,
        isEmpty,
        reason: 'an emptied document must not render ghost view models',
      );
    });

    test('undo/redo replays through both presenters identically', () {
      step('type', [
        InsertTextRequest(
          documentPosition: _text('p0', 0),
          textToInsert: 'undoable',
          attributions: {},
        ),
      ]);
      m.editor.undo();
      _pullAndCompare(m.oracle, m.incremental, 'after undo');
      m.editor.redo();
      _pullAndCompare(m.oracle, m.incremental, 'after redo');
    });
  });

  group('presenter differential — seeded fuzz', () {
    // Every op goes through the real Editor so DocumentChangeLog events are production-shaped.
    // 每个操作走真 Editor,变更事件与生产同形。
    for (final seed in [7, 42, 20260716]) {
      test('seed $seed × 120 random edits', () {
        final rng = Random(seed);
        final m = _mount(_mixedDocument());
        addTearDown(() => _unmount(m));

        String randomTextNodeId() {
          final textNodes = m.doc.whereType<TextNode>().toList();
          return textNodes[rng.nextInt(textNodes.length)].id;
        }

        int randomOffsetIn(String nodeId) {
          final node = m.doc.getNodeById(nodeId)! as TextNode;
          return node.text.length == 0 ? 0 : rng.nextInt(node.text.length + 1);
        }

        for (var step = 0; step < 120; step++) {
          final ctx = 'seed=$seed step=$step';
          try {
            switch (rng.nextInt(16)) {
              case 0 || 1 || 2: // typing dominates real usage 打字占大头
                final id = randomTextNodeId();
                m.editor.execute([
                  InsertTextRequest(
                    documentPosition: _text(id, randomOffsetIn(id)),
                    textToInsert: 'abcXYZ 中文'[rng.nextInt(9)],
                    attributions: rng.nextBool() ? {} : {boldAttribution},
                  ),
                ]);
              case 3: // delete a char span 删一段
                final id = randomTextNodeId();
                final node = m.doc.getNodeById(id)! as TextNode;
                if (node.text.length > 1) {
                  final s = rng.nextInt(node.text.length - 1);
                  m.editor.execute([
                    DeleteContentRequest(
                      documentRange: DocumentRange(
                        start: _text(id, s),
                        end: _text(id, s + 1),
                      ),
                    ),
                  ]);
                }
              case 4: // block type flip 换块型
                final paras = m.doc.whereType<ParagraphNode>().toList();
                if (paras.isNotEmpty) {
                  final target = paras[rng.nextInt(paras.length)].id;
                  final types = [
                    null,
                    header1Attribution,
                    header2Attribution,
                    header3Attribution,
                    blockquoteAttribution,
                  ];
                  m.editor.execute([
                    ChangeParagraphBlockTypeRequest(
                      nodeId: target,
                      blockType: types[rng.nextInt(types.length)],
                    ),
                  ]);
                }
              case 5: // insert a node 插节点
                final kinds = [
                  () => ParagraphNode(
                    id: 'f$step',
                    text: AttributedText('fuzz $step'),
                  ),
                  () => ListItemNode(
                    id: 'f$step',
                    itemType: rng.nextBool()
                        ? ListItemType.ordered
                        : ListItemType.unordered,
                    text: AttributedText('item $step'),
                  ),
                  () => TaskNode(
                    id: 'f$step',
                    text: AttributedText('task $step'),
                    isComplete: rng.nextBool(),
                  ),
                  () => HorizontalRuleNode(id: 'f$step'),
                ];
                m.editor.execute([
                  InsertNodeAtIndexRequest(
                    nodeIndex: rng.nextInt(m.doc.nodeCount + 1),
                    newNode: kinds[rng.nextInt(kinds.length)](),
                  ),
                ]);
              case 6: // delete a node (keep ≥1) 删节点
                if (m.doc.nodeCount > 1) {
                  final victim = m.doc
                      .getNodeAt(rng.nextInt(m.doc.nodeCount))!
                      .id;
                  // Mirror the real IME pipeline: a composing region referencing a node about to be
                  // deleted is cleared first — a dangling region crashes the upstream composing styler
                  // (pristine package too), a state the mounted editor can never reach. 拟真:IME 管线
                  // 会先清指向将删节点的组字区——悬垂组字区会崩上游组字相(原版同崩),真机编辑器到不了
                  // 这个状态。
                  final region = m.composer.composingRegion.value;
                  m.editor.execute([
                    if (region != null &&
                        (region.start.nodeId == victim ||
                            region.end.nodeId == victim))
                      const ClearComposingRegionRequest(),
                    DeleteNodeRequest(nodeId: victim),
                  ]);
                }
              case 7: // move a node 移节点
                if (m.doc.nodeCount > 2) {
                  m.editor.execute([
                    MoveNodeRequest(
                      nodeId: m.doc.getNodeAt(rng.nextInt(m.doc.nodeCount))!.id,
                      newIndex: rng.nextInt(m.doc.nodeCount),
                    ),
                  ]);
                }
              case 8: // selection change (incl. cross-block + clear) 选区
                if (rng.nextInt(4) == 0) {
                  m.editor.execute([const ClearSelectionRequest()]);
                } else {
                  final a = randomTextNodeId(), b = randomTextNodeId();
                  m.editor.execute([
                    ChangeSelectionRequest(
                      DocumentSelection(
                        base: _text(a, randomOffsetIn(a)),
                        extent: _text(b, randomOffsetIn(b)),
                      ),
                      SelectionChangeType.expandSelection,
                      SelectionReason.userInteraction,
                    ),
                  ]);
                }
              case 9: // composing region (CJK) 组字区
                if (rng.nextBool()) {
                  final id = randomTextNodeId();
                  final node = m.doc.getNodeById(id)! as TextNode;
                  if (node.text.length >= 2) {
                    final s = rng.nextInt(node.text.length - 1);
                    m.editor.execute([
                      ChangeComposingRegionRequest(
                        DocumentRange(
                          start: _text(id, s),
                          end: _text(id, s + 1),
                        ),
                      ),
                    ]);
                  }
                } else {
                  m.editor.execute([const ClearComposingRegionRequest()]);
                }
              case 10: // cross-node delete (select-across-blocks then delete — heaviest event mix)
                // 跨节点删除(合并+多删混合事件流,归账压力最大的真实形状)。
                final pairs = <int>[];
                for (var i = 0; i + 1 < m.doc.nodeCount; i++) {
                  if (m.doc.getNodeAt(i) is TextNode &&
                      m.doc.getNodeAt(i + 1) is TextNode) {
                    pairs.add(i);
                  }
                }
                if (pairs.isNotEmpty) {
                  final i = pairs[rng.nextInt(pairs.length)];
                  final a = m.doc.getNodeAt(i)! as TextNode;
                  final b = m.doc.getNodeAt(i + 1)! as TextNode;
                  m.editor.execute([
                    // Mirror the IME: structural edits reset composition first. 拟真:结构编辑前清组字。
                    const ClearComposingRegionRequest(),
                    DeleteContentRequest(
                      documentRange: DocumentRange(
                        start: _text(
                          a.id,
                          a.text.length == 0 ? 0 : rng.nextInt(a.text.length),
                        ),
                        end: _text(
                          b.id,
                          b.text.length == 0 ? 0 : rng.nextInt(b.text.length),
                        ),
                      ),
                    ),
                  ]);
                }
              case 11: // Enter — split a paragraph (highest-frequency structural op) 分段
                final paras = m.doc.whereType<ParagraphNode>().toList();
                if (paras.isNotEmpty) {
                  final p = paras[rng.nextInt(paras.length)];
                  m.editor.execute([
                    SplitParagraphRequest(
                      nodeId: p.id,
                      splitPosition: TextNodePosition(
                        offset: p.text.length == 0
                            ? 0
                            : rng.nextInt(p.text.length + 1),
                      ),
                      newNodeId: 's$step',
                      replicateExistingMetadata: rng.nextBool(),
                    ),
                  ]);
                }
              case 12: // range attribution toggle (select + bold/italic) 划选加粗
                final id = randomTextNodeId();
                final node = m.doc.getNodeById(id)! as TextNode;
                if (node.text.length >= 2) {
                  final s = rng.nextInt(node.text.length - 1);
                  final e = s + 1 + rng.nextInt(node.text.length - s - 1);
                  m.editor.execute([
                    ToggleTextAttributionsRequest(
                      documentRange: DocumentRange(
                        start: _text(id, s),
                        end: _text(id, e),
                      ),
                      attributions: {
                        rng.nextBool() ? boldAttribution : italicsAttribution,
                      },
                    ),
                  ]);
                }
              case 13: // undo/redo (history replays through the accounting) 撤销/重做
                // Commit composition first, like a real IME does before undo. 拟真:undo 前先落组字。
                m.editor.execute([const ClearComposingRegionRequest()]);
                if (rng.nextBool()) {
                  m.editor.undo();
                } else {
                  m.editor.redo();
                }
              case 14: // code-block whole-node replace (production per-key path) 码块整节点替换
                final cb = m.doc.getNodeById('cb');
                if (cb is CodeBlockNode) {
                  m.editor.execute([
                    ReplaceNodeRequest(
                      existingNodeId: 'cb',
                      newNode: cb.copyWithCode('var s = $step;'),
                    ),
                  ]);
                }
              case 15: // table whole-node replace (production cell-edit path) 表格整节点替换
                if (m.doc.getNodeById('tbl') is TableBlockNode) {
                  m.editor.execute([
                    ReplaceNodeRequest(
                      existingNodeId: 'tbl',
                      newNode: _table('tbl', 'f$step'),
                    ),
                  ]);
                }
            }
          } catch (e) {
            // An op may be legitimately rejected (e.g. deleting the selected node's neighbour leaves a
            // dangling selection upstream throws on) — the CONTRACT is only: whatever the document/
            // composer ended up as, both presenters must agree. 操作可能被上游合法拒绝;契约只有一条:
            // 无论文档/composer 落在什么状态,两台 presenter 必须一致。
          }
          _pullAndCompare(m.oracle, m.incremental, ctx);
        }
      });
    }
  });

  group('presenter incremental — O(change) work-bound guard (the ratchet)', () {
    // The point of the surgery in numbers: a keystroke into a 200-node document must do work bounded
    // by the CHANGE, not the document. The bounds are deliberately loose (dirty radius can pull in a
    // successor + a list run + first/last) but orders of magnitude below N=200 — if a regression
    // reintroduces O(doc)/keystroke these blow up past 200/1000 and the guard trips.
    // 手术的数字化意义:200 节点文档打一键,工作量必须按「变更」而非「文档」计。上界故意放宽(脏半径
    // 可含后继+列表段+首末)但比 N=200 低数量级——若回归重新引入 O(doc)/键,计数会冲破上界报警。
    test(
      'typing one char into 200 paragraphs rebuilds a handful of view models, not 200',
      () {
        final m = _mount(
          MutableDocument(
            nodes: [
              for (var i = 0; i < 200; i++)
                ParagraphNode(
                  id: 'n$i',
                  text: AttributedText('paragraph number $i'),
                ),
            ],
          ),
        );
        addTearDown(() => _unmount(m));
        _pullAndCompare(m.oracle, m.incremental, 'guard mount');

        AnPresenterMetrics.reset();
        m.editor.execute([
          InsertTextRequest(
            documentPosition: _text('n100', 5),
            textToInsert: 'x',
            attributions: {},
          ),
        ]);
        _pullAndCompare(m.oracle, m.incremental, 'guard keystroke');

        expect(
          AnPresenterMetrics.baseVmCreates,
          lessThanOrEqualTo(8),
          reason:
              'a single-node text edit must rebuild only the dirty radius, not the document',
        );
        expect(
          AnPresenterMetrics.phaseVmStyled,
          lessThanOrEqualTo(40),
          reason: 'phases must be fed the dirty subset, not the whole document',
        );
      },
    );

    test(
      'moving the caret between nodes restyles only the touched nodes, zero rebuilds',
      () {
        final m = _mount(
          MutableDocument(
            nodes: [
              for (var i = 0; i < 200; i++)
                ParagraphNode(
                  id: 'n$i',
                  text: AttributedText('paragraph number $i'),
                ),
            ],
          ),
        );
        addTearDown(() => _unmount(m));
        m.editor.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(position: _text('n10', 3)),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);
        _pullAndCompare(m.oracle, m.incremental, 'guard caret seed');

        AnPresenterMetrics.reset();
        m.editor.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(position: _text('n150', 3)),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);
        _pullAndCompare(m.oracle, m.incremental, 'guard caret move');

        expect(
          AnPresenterMetrics.baseVmCreates,
          0,
          reason:
              'a selection move changes no document content — zero base view-model rebuilds',
        );
        expect(
          AnPresenterMetrics.phaseVmStyled,
          lessThanOrEqualTo(4),
          reason:
              'only the old + new caret nodes pass through the selection phase',
        );
      },
    );
  });
}
