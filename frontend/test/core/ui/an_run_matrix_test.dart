import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// AnRunMatrix (WRK-069 §12 + 判决③, S5). The contracts worth locking are the ones a careless refactor
// would break silently: 「未及」 must stay an EMPTY square (a sparse cell is a real answer, not a
// missing one), a running column must NOT grow a duration bar, «×N» must ride in the cell, the three
// selection grains must each report the right key, and an unknown status must fold neutral — never
// green.
// 值得锁死的是「粗心重构会静默弄坏」的那些:未及=**空格**(稀疏格是真答案不是缺答案)/在跑列**不长**时长条/
// ×N 在格内/三粒度各报对键/未知状态折中性——绝不绿。

const _rows = [
  MatrixRowHead(nodeId: 'fetch', kind: 'action'),
  MatrixRowHead(nodeId: 'analyze', kind: 'agent'),
];

const _cols = [
  // CHRONOLOGICAL, oldest LEFT (主页重建拍板 0717) — the viewport anchors at the newest end.
  // 时序旧在左;视口锚最新端。
  RunColumn(id: 'fr_1', status: 'failed', elapsedMs: 8000),
  RunColumn(id: 'fr_2', status: 'running'), // in flight → NO elapsed 在跑→无耗时
];

// The real host is a SCROLLING page ([AnPage]'s 720 reading column), which hands the grid unbounded
// height — so the host here must too, or a tall grid "overflows" against a test-window ceiling that
// does not exist in the app. 真实宿主是**可滚动**的页(AnPage 的 720 阅读列),给格阵无界高——故此处宿主
// 也必须给,否则高格阵会撞上一个 app 里根本不存在的测试窗天花板。
Widget _host(Widget child, {double width = 600}) => MaterialApp(
      theme: AnTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(child: SizedBox(width: width, child: child)),
        ),
      ),
    );

/// Cells are the interactive squares; row/col heads render inert when the caller passes no handler,
/// so «the first AnInteractive» is NOT reliably a cell. 格才是可交互方块;调用方不给 handler 时行/列头
/// 是惰性的,故「第一个 AnInteractive」并不可靠地是格。
Finder get _cells => find.byWidgetPredicate((w) => w is AnInteractive && w.onTap != null);

/// A named focus stop AFTER the grid — the thing an escaping user must land on. 格阵**之后**的具名停靠。
class _After extends StatelessWidget {
  const _After();

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: FocusNode(debugLabel: 'after'),
        child: const SizedBox(width: 100, height: 40),
      );
}

void main() {
  testWidgets('empty rows/cols render nothing', (tester) async {
    await tester.pumpWidget(
        _host(AnRunMatrix(rows: const [], cols: const [], cellStatus: (_, _) => null)));
    expect(tester.getSize(find.byType(AnRunMatrix)).height, 0, reason: '零行零列=零高,不留空框废墟');
  });

  testWidgets('a SPARSE cell renders an empty square — never a colour, never a lie', (tester) async {
    await tester.pumpWidget(_host(AnRunMatrix(
      rows: _rows,
      cols: _cols,
      // fr_2 never reached analyze — no cell. fr_2 没跑到 analyze:无格。
      cellStatus: (runId, nodeId) => runId == 'fr_2' && nodeId == 'analyze'
          ? null
          : const MatrixCellState(status: 'completed'),
      notReachedLabel: '未及',
    )));
    // 4 squares are laid out (2×2), but the sparse one carries no fill — «未及» is its tooltip, and
    // an empty square must never be able to read as an outcome.
    // 2×2 四格都在,稀疏那格无填充——「未及」是它的 tooltip;空格绝不得被读成一种结局。
    expect(find.byTooltip('未及'), findsOneWidget, reason: '稀疏格说「未及」,不说成功也不说失败');
  });

  testWidgets('a still-running column grows NO duration bar (no zero that reads as «instant»)',
      (tester) async {
    await tester.pumpWidget(_host(AnRunMatrix(
      rows: _rows,
      cols: _cols,
      cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
      runningLabel: '在跑(无耗时)',
    )));
    // The in-flight column head speaks the caller's running word instead of a fabricated length.
    // 在跑列头说调用方的「在跑」词,而不是一个编出来的长度。
    expect(find.byTooltip('在跑(无耗时)'), findsOneWidget,
        reason: '未完的 run 没有「最长」的份额可占——绝不画零宽条冒充「瞬时」');
    // A settled column DOES take its share. 落定列才占份额。
    expect(find.byType(FractionallySizedBox), findsOneWidget, reason: '只有落定列长时长条');
  });

  testWidgets(
      'the head duration bar wears the run\'s FINAL-STATUS soft tint — blue is exclusive to live '
      '(用户拍板 0717-晚:颜色=状态、长度=耗时、蓝=在跑)', (tester) async {
    await tester.pumpWidget(_host(AnRunMatrix(
      rows: const [MatrixRowHead(nodeId: 'x')],
      cols: const [
        RunColumn(id: 'fr_done', status: 'completed', elapsedMs: 9000),
        RunColumn(id: 'fr_bad', status: 'failed', elapsedMs: 4000),
        RunColumn(id: 'fr_live', status: 'running'),
      ],
      cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
    )));
    final c = tester.element(find.byType(AnRunMatrix)).colors;

    Color barColorIn(FractionallySizedBox f) =>
        ((tester.widget<Container>(find.descendant(
                    of: find.byWidget(f), matching: find.byType(Container)))
                .decoration!) as BoxDecoration)
            .color!;
    final bars = tester.widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox)).toList();
    expect(bars.length, 2, reason: '两个落定列各一条;在跑列无长度');
    final colors = bars.map(barColorIn).toSet();
    expect(colors, {AnStatus.done.tone.softBg(c), AnStatus.err.tone.softBg(c)},
        reason: '条=最终状态淡色(与格子同族)——完成淡绿/失败淡红,绝不再是无差别的淡蓝');
  });

  testWidgets('the selection indicator lives ON TOP and reserves its pixels when idle '
      '(选中现墨杠,平时透明占位不跳变)', (tester) async {
    Widget grid({String? selectedRun}) => _host(AnRunMatrix(
          rows: const [MatrixRowHead(nodeId: 'x')],
          cols: _cols,
          cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
          selection: MatrixSelection(flowrunId: selectedRun),
          onCol: (_) {},
        ));
    await tester.pumpWidget(grid());
    final c = tester.element(find.byType(AnRunMatrix)).colors;
    Finder inkBar() => find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).color == c.ink);
    expect(inkBar(), findsNothing, reason: '未选中:无墨杠(透明占位)');
    final before = tester.getRect(find.text('x'));

    await tester.pumpWidget(grid(selectedRun: 'fr_2'));
    expect(inkBar(), findsOneWidget, reason: '选中列现墨杠');
    expect(tester.getRect(find.text('x')), before,
        reason: '选中只改外观、绝不动几何——占位早已保留(拍板:平时不见,不是不占)');
  });

  testWidgets('«×N» rides IN the cell for loop iterations; a single round grows no badge',
      (tester) async {
    await tester.pumpWidget(_host(AnRunMatrix(
      rows: _rows,
      cols: _cols,
      cellStatus: (runId, nodeId) => nodeId == 'analyze'
          ? const MatrixCellState(status: 'failed', iterations: 3)
          : const MatrixCellState(status: 'completed'),
    )));
    expect(find.text('3'), findsNWidgets(2), reason: 'iterations>1 才渲 ×N(两列各一格)');
    expect(find.text('1'), findsNothing, reason: '单轮不长徽——×1 是噪声');
  });

  testWidgets('an UNKNOWN status folds neutral — a cell never paints a success it never had',
      (tester) async {
    // Only CELLS carry a bordered box (row/col heads are fills), so this predicate names them.
    // 只有**格**带描边盒(行头/列头是填充),故此谓词唯一指认格。
    Color borderOf(WidgetTester t) {
      final c = t.widget<Container>(find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).border != null));
      return ((c.decoration! as BoxDecoration).border! as Border).top.color;
    }

    await tester.pumpWidget(_host(AnRunMatrix(
      rows: const [MatrixRowHead(nodeId: 'x')],
      cols: const [RunColumn(id: 'fr_1', status: 'completed', elapsedMs: 10)],
      cellStatus: (_, _) => const MatrixCellState(status: 'SOME_FUTURE_WORD'),
    )));
    final unknown = borderOf(tester);

    await tester.pumpWidget(_host(AnRunMatrix(
      rows: const [MatrixRowHead(nodeId: 'x')],
      cols: const [RunColumn(id: 'fr_1', status: 'completed', elapsedMs: 10)],
      cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
    )));
    final done = borderOf(tester);

    final theme = AnTheme.light().extension<AnColors>()!;
    expect(done, theme.ok, reason: 'completed 该是绿的');
    expect(unknown, isNot(theme.ok),
        reason: '未知状态绝不折成 done——不认识的词不得被画成一次绿色的成功(AnStatus 未知→idle 中性)');
    expect(unknown, theme.inkMuted, reason: '未知折 idle→tone.none→中性墨');
  });

  group('three selection grains (§12)', () {
    testWidgets('tapping a CELL reports (run, node)', (tester) async {
      (String, String)? got;
      await tester.pumpWidget(_host(AnRunMatrix(
        rows: _rows,
        cols: _cols,
        cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
        onCell: (f, n) => got = (f, n),
      )));
      // The first ACTIVATABLE square is the first cell: row «fetch» × column «fr_1» (oldest run is
      // the LEFT column now). 第一个可激活方块=第一格:fetch 行 × fr_1 列(旧在左)。
      await tester.tap(_cells.first, warnIfMissed: false);
      expect(got, ('fr_1', 'fetch'), reason: '点格必须报出 (run, node) 两个键——一个都不能少,且不能对调');
    });

    testWidgets('tapping a ROW head reports the node; tapping a COL head reports the run',
        (tester) async {
      String? row;
      String? col;
      await tester.pumpWidget(_host(AnRunMatrix(
        rows: _rows,
        cols: _cols,
        cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
        onRow: (n) => row = n,
        onCol: (f) => col = f,
      )));
      await tester.tap(find.text('fetch'));
      expect(row, 'fetch', reason: '点行=该节点的历史');
      // Activatable order now: frozen-lane row heads first (fetch, analyze), then the scroller's
      // col heads (fr_1, fr_2). The LAST col head is the newest run — the anchored end.
      // 可激活序:冻结车道行头在先(fetch,analyze),再滚动器列头(fr_1,fr_2);末位列头=最新=锚定端。
      await tester.tap(_cells.at(3), warnIfMissed: false);
      expect(col, 'fr_2', reason: '点列=该 run(时序新在右,末位列头是最新那次)');
    });

    testWidgets('selection highlights the picked cell / row without moving anything',
        (tester) async {
      await tester.pumpWidget(_host(AnRunMatrix(
        rows: _rows,
        cols: _cols,
        cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
        selection: const MatrixSelection(flowrunId: 'fr_1', nodeId: 'analyze'),
        onCell: (_, _) {},
      )));
      final before = tester.getRect(find.text('analyze'));
      await tester.pumpWidget(_host(AnRunMatrix(
        rows: _rows,
        cols: _cols,
        cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
        onCell: (_, _) {},
      )));
      expect(tester.getRect(find.text('analyze')), before,
          reason: '选区只改外观、绝不动几何(活性军规:几何只随用户动作/落账变)');
    });
  });

  group('a11y: row-level, because the desktop transports no table (§12)', () {
    testWidgets('rows carry the PATTERN as a summary; only the cursor + the selection speak',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(AnRunMatrix(
        rows: _rows,
        cols: _cols,
        cellStatus: (_, nodeId) =>
            nodeId == 'fetch' ? const MatrixCellState(status: 'completed') : null,
        onCell: (_, _) {},
        onCol: (_) {},
        onRow: (_) {},
        cellSemanticLabel: (col, row, cell) => '${row.nodeId} ${col.id} ${cell?.status ?? '未及'}',
        colSemanticLabel: (col) => 'run ${col.id} ${col.status}',
        rowSemanticLabel: (row) => '节点 ${row.nodeId}',
        rowSummaryLabel: (s) =>
            '${s.row.nodeId} 共 ${s.total} 行 ${s.cells.where((c) => c != null).length} 次抵达',
        coordinateLabel: (r, rc, c, cc) => '第 ${r + 1} 行 共 $rc 行，第 ${c + 1} 列 共 $cc 列',
      )));
      // The summary answers «老是坏还是就这一次» WITHOUT walking a single cell — that is the whole
      // point of row level. 摘要不走一格就答出「老是坏还是就这一次」——这就是行级的全部意义。
      expect(find.bySemanticsLabel('fetch 共 2 行 2 次抵达'), findsOneWidget);
      expect(find.bySemanticsLabel('analyze 共 2 行 0 次抵达'), findsOneWidget);
      // The cursor speaks, and its sentence carries the coordinate the desktop has nowhere else to
      // put. 光标说话,且它的句子带着桌面没有别处可放的坐标。
      // Default cursor = the NEWEST column (the anchored end) — fr_2 is column 2 of 2 now.
      // 默认光标=最新列(锚定端)——fr_2 现在是 2/2 列。
      expect(find.bySemanticsLabel('fetch fr_2 completed 第 1 行 共 2 行，第 2 列 共 2 列'),
          findsOneWidget,
          reason: '光标格必须报出坐标——桌面 role/indexInParent 全不过 embedder ABI,坐标只能在 label 里');
      // Every other square is SILENT: 480 unstructured nodes is a wall, not access.
      // 其余方块**沉默**:480 个无结构节点是墙,不是可访问性。
      expect(find.bySemanticsLabel('analyze fr_2 未及'), findsNothing,
          reason: '非光标非选区的格不带节点——替它们说话的是行摘要');
      expect(find.bySemanticsLabel('run fr_2 running'), findsOneWidget, reason: '列头各是一次 run,是新闻');
      expect(find.bySemanticsLabel('节点 fetch'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the SELECTED cell keeps its node even when the cursor is elsewhere', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(AnRunMatrix(
        rows: _rows,
        cols: _cols,
        cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
        selection: const MatrixSelection(flowrunId: 'fr_1', nodeId: 'analyze'),
        onCell: (_, _) {},
        cellSemanticLabel: (col, row, cell) => '${row.nodeId} ${col.id}',
        coordinateLabel: (r, rc, c, cc) => '第 ${r + 1} 行，第 ${c + 1} 列',
      )));
      // The selection is what the app is showing in the linked pane — a screen-reader user must be
      // able to find it, so it is the one other square worth a node.
      // 选区=联动格正在展示的那个,读屏用户必须找得到它,故它是另一个值得节点的方块。
      expect(find.bySemanticsLabel('analyze fr_1 第 2 行，第 1 列'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the cursor label rides the FOCUSABLE node, not a child of it', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(AnRunMatrix(
        rows: const [MatrixRowHead(nodeId: 'fetch')],
        cols: const [RunColumn(id: 'fr_1', status: 'completed', elapsedMs: 10)],
        cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
        onCell: (_, _) {},
        cellSemanticLabel: (col, row, cell) => 'fetch fr_1 completed',
      )));
      // A label stranded on a CHILD of the focused node is a label the screen reader may never read
      // on focus — the node that carries isFocusable must be the node that carries the words (a stock
      // button's does). Two Semantics layers annotating the same flag would split them apart, which is
      // why only ONE layer annotates `selected`.
      // label 若落在被聚焦节点的**孩子**上,聚焦时读屏可能永远读不到它——带 isFocusable 的节点必须就是带词的
      // 那个(原装按钮就是如此)。两层 Semantics 标同一面旗标会把它们拆开,这正是 selected 只由一层标注的原因。
      expect(tester.getSemantics(find.bySemanticsLabel('fetch fr_1 completed')),
          isSemantics(isFocusable: true),
          reason: '句子必须与可聚焦性同节点,否则聚焦时读屏读不到它');
      handle.dispose();
    });
  });

  group('keyboard: ONE tab stop (roving tabindex)', () {
    // Every FocusNode this widget owns is named — so a stop that belongs to the GRID is countable
    // apart from the host's own (a Scaffold/scroll view carries three of its own).
    // 本件自持的每个 FocusNode 都有名字——故属于**格阵**的停靠可以与宿主自带的(Scaffold/滚动视图自带三个)
    // 分开来数。
    int gridStops() => FocusManager.instance.rootScope.traversalDescendants
        .where((n) => n.debugLabel?.startsWith('AnRunMatrix') ?? false)
        .length;

    testWidgets('a 20×24 grid is ONE Tab stop, not 527', (tester) async {
      await tester.pumpWidget(_host(
        AnRunMatrix(
          rows: [for (var i = 0; i < 24; i++) MatrixRowHead(nodeId: 'node_$i')],
          cols: [for (var i = 20; i > 0; i--) RunColumn(id: 'fr_$i', status: 'completed', elapsedMs: i)],
          cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
          onCell: (_, _) {},
          onCol: (_) {},
          onRow: (_) {},
        ),
        width: 1100,
      ));
      // 480 cells + 24 row heads + 20 col heads = 524 focusable positions, and the user must be able
      // to Tab past ALL of them with ONE press. This is the whole reason the roving cursor exists.
      // 480 格 + 24 行头 + 20 列头 = 524 个可聚焦位置,而用户必须**一次**按键就能 Tab 过全部。roving 光标
      // 存在的全部理由就是这一条。
      expect(gridStops(), 1, reason: '一次 Tab 进、一次 Tab 出;524 个可聚焦位置只留一个停靠');
    });

    testWidgets('Tab lands ON the cursor cell, and the NEXT Tab leaves the grid entirely',
        (tester) async {
      await tester.pumpWidget(_host(Column(children: [
        AnRunMatrix(
          rows: _rows,
          cols: _cols,
          cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
          onCell: (_, _) {},
        ),
        const _After(),
      ])));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, contains('AnRunMatrix'),
          reason: 'Tab 进来落在光标格上');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      // The framework keeps a skipTraversal node in the sort when it is the CURRENT one, precisely so
      // Tab finds «the next traversable node from the current focused node» — i.e. what comes AFTER
      // the grid, never back to the top of the page.
      // 框架在当前节点 skipTraversal 时仍把它留在排序里,正是为了让 Tab 找到「当前焦点之后的下一个可遍历
      // 节点」——即格阵**之后**那个,而不是弹回页首。
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'after',
          reason: '第二次 Tab 必须直接离开格阵——不是再走 523 个格');
    });

    testWidgets('arrows walk the cursor; a move never selects (ARIA keeps the two axes apart)',
        (tester) async {
      final picked = <(String, String)>[];
      await tester.pumpWidget(_host(AnRunMatrix(
        rows: _rows,
        cols: _cols,
        cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
        onCell: (f, n) => picked.add((f, n)),
      )));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      // Cursor seeds on the NEWEST column (the anchored, visible end): row «fetch» × «fr_2».
      // 光标落种最新列(锚定的、看得见的那端):fetch × fr_2。
      expect(FocusManager.instance.primaryFocus?.debugLabel, contains('(fetch, fr_2)'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, contains('(fetch, fr_1)'),
          reason: '← 视觉左移一列=更旧一次 run');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, contains('(analyze, fr_1)'),
          reason: '↓ 下移一行');
      expect(picked, isEmpty, reason: '移动光标**绝不**等于选中——ARIA 把两条轴分开自有道理');
      // Enter is free: the default shortcut tables map it to ActivateIntent and every cell answers it.
      // Enter 白送:默认表把它绑到 ActivateIntent,每个格都应答。
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(picked, [('fr_1', 'analyze')], reason: 'Enter 激活光标格,报出 (run, node)');
    });

    testWidgets('the grid NEVER traps: an arrow off the edge hands focus back to the framework',
        (tester) async {
      await tester.pumpWidget(_host(Column(children: [
        AnRunMatrix(
          rows: _rows,
          cols: _cols,
          cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
          onCell: (_, _) {},
        ),
        const _After(),
      ])));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      // Walk to the bottom row, then keep pressing ↓ — the edge must be an EXIT, not a wall.
      // 走到最后一行再继续按 ↓——边界必须是**出口**,不是墙。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, contains('(analyze, fr_2)'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'after',
          reason: '出边 → super.invoke → 默认遍历把用户送出格阵(MenuAnchor 同款);绝不困住');
    });

    testWidgets('the cursor is addressed by ID: a new run prepending a column cannot slide it',
        (tester) async {
      Widget grid(List<RunColumn> cols) => _host(AnRunMatrix(
            rows: _rows,
            cols: cols,
            cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
            onCell: (_, _) {},
          ));
      await tester.pumpWidget(grid(_cols));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, contains('(fetch, fr_1)'));
      // An OLDER page arrives on the LEFT (the lazy-load case) — index (0,1) now names a different
      // run entirely. 更旧一页从**左**边到达(懒加载路径)——下标 (0,1) 现在指的完全是另一次 run 了。
      await tester.pumpWidget(grid(const [
        RunColumn(id: 'fr_0', status: 'completed', elapsedMs: 500),
        ..._cols,
      ]));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, contains('(fetch, fr_1)'),
          reason: '光标钉在**那一次 run** 上,不是钉在第几列——刷新绝不能把它悄悄挪到别的 run 上');
    });

    testWidgets('arrows are VISUAL: under RTL a Row mirrors, so → walks the other way', (tester) async {
      await tester.pumpWidget(_host(Directionality(
        textDirection: TextDirection.rtl,
        child: AnRunMatrix(
          rows: _rows,
          cols: _cols,
          cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
          onCell: (_, _) {},
        ),
      )));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, contains('(fetch, fr_2)'));
      // APG: «Right Arrow moves focus one cell to the right» — RIGHT is a place on screen, not an
      // index. Under RTL the Row mirrors: fr_1 (index 0) sits visually RIGHT of fr_2, so → must walk
      // toward the LOWER index; the ordinal reading would send the cursor visually backwards.
      // APG:右箭头=「向**右**移一格」——右是屏幕位置不是下标。RTL 镜像后 fr_1(下标 0)在 fr_2 视觉右侧,
      // 故 → 须朝更小下标走;按序数读键会让光标视觉倒行。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, contains('(fetch, fr_1)'),
          reason: 'RTL 下 → 走向 fr_1(它在 fr_2 的视觉右侧)');
    });

    testWidgets('an inert grid (no handlers) is a picture — zero stops, no ghost cursor',
        (tester) async {
      await tester.pumpWidget(_host(AnRunMatrix(
        rows: _rows,
        cols: _cols,
        cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
      )));
      expect(gridStops(), 0, reason: '调用方没给 handler=这是画;画不是键盘停靠');
    });
  });

  group('a11y announcement: macOS only, and that is not a preference', () {
    List<String> hook(WidgetTester tester) {
      final said = <String>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility, (msg) async {
        final m = (msg as Map<Object?, Object?>?) ?? const {};
        if (m['type'] == 'announce') {
          said.add((m['data']! as Map<Object?, Object?>)['message']! as String);
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, null));
      return said;
    }

    Widget grid() => _host(AnRunMatrix(
          rows: _rows,
          cols: _cols,
          cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
          onCell: (_, _) {},
          cellSemanticLabel: (col, row, cell) => '${row.nodeId} ${col.id}',
          coordinateLabel: (r, rc, c, cc) => '第 ${r + 1} 行，第 ${c + 1} 列',
        ));

    testWidgets('macOS: the cursor announces itself — its engine bridge drops FOCUS_CHANGED',
        (tester) async {
      final said = hook(tester);
      await tester.pumpWidget(grid());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      // On macOS a focused node is SILENT (the mac bridge files FOCUS_CHANGED under «not meaningful
      // on Mac»), so without this the cursor would move with nothing spoken at all. liveRegion is not
      // the alternative — it is a no-op on all three desktops (flutter#167318).
      // macOS 上被聚焦的节点是**哑的**(mac bridge 把 FOCUS_CHANGED 归进「在 Mac 上没意义」),没有这一发,
      // 光标移动将**全程无声**。liveRegion 不是替代——它在三个桌面上都是 no-op(flutter#167318)。
      expect(said, ['fetch fr_1 第 1 行，第 1 列'],
          reason: 'macOS 必须主动播报,否则光标移动无声');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('windows/linux: NOT announced — the focus notification already read it once',
        (tester) async {
      final said = hook(tester);
      await tester.pumpWidget(grid());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(said, isEmpty,
          reason: 'Windows/Linux 会发焦点通知、读屏已念过一遍;再播报=念两遍(flutter#153020)');
    }, variant: TargetPlatformVariant({TargetPlatform.windows, TargetPlatform.linux}));
  });

  testWidgets('stress: the full 20-column cap × 24 rows lays out without overflow', (tester) async {
    await tester.pumpWidget(_host(
      AnRunMatrix(
        rows: [for (var i = 0; i < 24; i++) MatrixRowHead(nodeId: 'node_$i', kind: 'action')],
        cols: [
          for (var i = 20; i > 0; i--)
            RunColumn(id: 'fr_$i', status: 'completed', elapsedMs: 1000 * i),
        ],
        cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
      ),
      // The REAL host width now: AnPage's 720 reading column, less the page inset and the card's own
      // (用户 0717 判决 — 全宽破例作废). The grid is WIDER than this, and that is the settled design:
      // it scrolls inside itself rather than asking the page for room.
      // 现在的**真实**宿主宽:AnPage 的 720 阅读列减去页 inset 与卡内距(用户 0717 判决,全宽破例作废)。
      // 格阵比它宽,而这是已定的设计:它在自己肚子里滚,不向页面讨宽度。
      width: 640,
    ));
    expect(tester.takeException(), isNull, reason: '20 列 × 24 行=格阵上限,在 720 阅读列内必须不溢出');
  });

  // WRK-069 判决③ 的全宽破例被用户 2026-07-17 当面否决(「我不允许有这种超宽的东西…可以弄那种可以左右滑动
  // 的」)。宽度问题因此整个搬进本件肚子里,这四条锁死搬进来的东西是**能用**的而不只是「不崩」。
  // The full-bleed exemption is gone; the width problem moved INSIDE this widget. These four lock that
  // what moved in actually WORKS, rather than merely not crashing.
  group('width lives inside the grid (用户 0717 判决 — 判决③ 全宽破例作废)', () {
    /// 20 columns at the reading column's real width — the production shape. 生产形态。
    Widget grid({void Function(String, String)? onCell, VoidCallback? onNearOldestEdge,
            bool loadingOlder = false, List<RunColumn>? cols}) =>
        AnRunMatrix(
          rows: [for (var i = 0; i < 6; i++) MatrixRowHead(nodeId: 'node_$i', kind: 'action')],
          cols: cols ??
              [
                // Chronological: fr_1 oldest LEFT … fr_20 newest RIGHT (the anchored end). 时序。
                for (var i = 1; i <= 20; i++)
                  RunColumn(id: 'fr_$i', status: 'completed', elapsedMs: 1000 * i),
              ],
          cellStatus: (_, _) => const MatrixCellState(status: 'completed'),
          onCell: onCell ?? (_, _) {},
          onNearOldestEdge: onNearOldestEdge,
          loadingOlder: loadingOlder,
        );

    Finder hBar() =>
        find.byWidgetPredicate((w) => w is RawScrollbar && w.child is ScrollConfiguration);

    testWidgets('the grid scrolls sideways in its OWN container — the host never does', (tester) async {
      await tester.pumpWidget(_host(grid(), width: 640));
      final sv = tester.widget<SingleChildScrollView>(
          find.descendant(of: find.byType(AnRunMatrix), matching: find.byType(SingleChildScrollView)));
      expect(sv.scrollDirection, Axis.horizontal, reason: '横滚器在格阵自己肚子里');
      // The HOST's scroll view (the page stand-in) stays vertical — 「宽内容自己滚,body 永不横滚」.
      // 宿主(页面替身)的滚动器仍是纵向的。
      final hostSv = tester.widget<SingleChildScrollView>(find
          .ancestor(of: find.byType(AnRunMatrix), matching: find.byType(SingleChildScrollView))
          .first);
      expect(hostSv.scrollDirection, Axis.vertical, reason: 'body 永不横滚');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the bar IS the discoverability: it paints when there is more, and only then',
        (tester) async {
      // Narrow host → the grid overflows → a thumb says so. 窄宿主→溢出→thumb 说出来。
      await tester.pumpWidget(_host(grid(), width: 640));
      await tester.pumpAndSettle();
      expect(hBar(), findsOneWidget, reason: '横滚条在场');
      var painted = tester
          .widget<SingleChildScrollView>(find.descendant(
              of: find.byType(AnRunMatrix), matching: find.byType(SingleChildScrollView)))
          .controller!;
      expect(painted.position.maxScrollExtent, greaterThan(0), reason: '真有得滚→thumb 有内容可画');

      // Wide host → nothing to scroll → the painter early-returns and no thumb is drawn (a bar that
      // lies about there being more is worse than no bar). 宽宿主→无得滚→painter 早退不画 thumb。
      await tester.pumpWidget(_host(grid(), width: 1400));
      await tester.pumpAndSettle();
      painted = tester
          .widget<SingleChildScrollView>(find.descendant(
              of: find.byType(AnRunMatrix), matching: find.byType(SingleChildScrollView)))
          .controller!;
      expect(painted.position.maxScrollExtent, 0, reason: '放得下就没有「右边还有」可宣称');
    });

    testWidgets('exactly ONE thumb — the local AnScrollBehavior kills the inherited desktop bar',
        (tester) async {
      // MaterialScrollBehavior wraps EVERY desktop scrollable (horizontal included) in a Scrollbar;
      // without the local ScrollConfiguration a gallery host would paint two thumbs (AnPage's 已成文坑).
      // 无局部 ScrollConfiguration,画廊宿主会画出两个 thumb(AnPage 已成文的坑)。
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(_host(grid(), width: 640));
        await tester.pumpAndSettle();
        expect(find.descendant(of: find.byType(AnRunMatrix), matching: find.byType(Scrollbar)),
            findsNothing, reason: '继承来的 Material 条被压制');
        expect(hBar(), findsOneWidget, reason: '只留格阵自己那根');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    // The cursor cell's rect against its own viewport's rect — «is the thing the user is driving
    // actually on screen». 光标格 vs 它自己视口的矩形——「用户正在开的那个东西,到底在不在屏上」。
    void expectCursorVisible(WidgetTester tester, String why) {
      final box = FocusManager.instance.primaryFocus!.context!.findRenderObject()! as RenderBox;
      final viewport = tester.getRect(find.descendant(
          of: find.byType(AnRunMatrix), matching: find.byType(SingleChildScrollView)));
      final cell = box.localToGlobal(Offset.zero) & box.size;
      expect(cell.left, greaterThanOrEqualTo(viewport.left - 0.5), reason: '$why:光标格左缘跑到视口左外');
      expect(cell.right, lessThanOrEqualTo(viewport.right + 0.5), reason: '$why:光标格右缘跑到视口右外');
    }

    ScrollController hCtl(WidgetTester tester) => tester
        .widget<SingleChildScrollView>(find.descendant(
            of: find.byType(AnRunMatrix), matching: find.byType(SingleChildScrollView)))
        .controller!;

    // Both the production width (720 reading column, less the page inset and the card's own: the grid
    // overspills it by ~52px) and a squeezed one — the narrow case is what proves the viewport really
    // TRACKS the cursor rather than the walk merely never leaving a nearly-fitting viewport.
    // 生产宽(720 阅读列减页 inset 与卡内距,格阵溢出 ~52px)与被挤窄的宽各跑一遍——窄的那个才证明视口真的
    // **跟着**光标走,而不是「差点就放得下、所以怎么走都没出界」。
    for (final w in [640.0, 300.0]) {
      testWidgets('arrow keys drag the viewport along — the cursor is NEVER walked out of sight (host ${w.toInt()})',
          (tester) async {
        // THE regression this whole group exists for: the roving cursor focuses nodes EXPLICITLY,
        // which skips FocusTraversalPolicy's own scroll-into-view. Walk right across all 20 columns
        // and the viewport must follow, or a keyboard user's cursor ends up off-screen.
        // 本组存在的**那个**回归:roving 光标**显式**聚焦,绕过了框架自带的滚动入视。向右走过 20 列,视口必须
        // 跟上——否则键盘用户的光标会走到屏幕外。
        await tester.pumpWidget(_host(grid(), width: w));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        // reverse anchor: offset 0 IS the newest (right) end — where the seeded cursor lives.
        // reverse 锚:offset 0 就是最新(右)端——落种的光标就在那儿。
        expect(hCtl(tester).offset, 0, reason: '起点锚在最新端');
        expectCursorVisible(tester, 'Tab 落种');

        for (var i = 0; i < 19; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pumpAndSettle();
          expectCursorVisible(tester, '第 ${i + 1} 次左移'); // every step, not just the end 每一步
        }
        final oldmost = hCtl(tester).offset;
        expect(oldmost, greaterThan(0), reason: '走到最旧端,视口确实跟着滚了');

        // …and back toward the newest. The policy only rewinds as far as the cursor NEEDS. Assert
        // what is actually promised: the cursor stays visible, and the viewport gave ground.
        // 反向走回最新端。策略只倒回**光标需要**的那么多。断言真正承诺的东西:光标始终可见、视口让位。
        for (var i = 0; i < 19; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          expectCursorVisible(tester, '第 ${i + 1} 次右移');
        }
        expect(hCtl(tester).offset, lessThanOrEqualTo(oldmost), reason: '右移绝不把视口越推越旧');
      });
    }

    // ── 主页重建拍板 0717:时序 + 右锚 + 左缘懒加载 ──

    testWidgets('first frame anchors at the NEWEST end — no post-frame jump', (tester) async {
      await tester.pumpWidget(_host(grid(), width: 640));
      // reverse: offset 0 IS the newest edge, so the anchor holds from the very first frame — a
      // jumpTo(maxScrollExtent) approach would flash the oldest end for one frame.
      // reverse:offset 0 就是最新缘,首帧即锚定——jumpTo(max) 的做法会闪一帧最旧端。
      expect(hCtl(tester).offset, 0, reason: '开屏即最新,零跳动');
      // The newest column's cell is on screen; the oldest's is not. 最新列在屏上,最旧列不在。
      final newest = tester.getRect(find.byKey(const ValueKey(('node_0', 'fr_20'))));
      final viewport = tester.getRect(find.descendant(
          of: find.byType(AnRunMatrix), matching: find.byType(SingleChildScrollView)));
      expect(newest.right, lessThanOrEqualTo(viewport.right + 0.5));
      expect(find.byKey(const ValueKey(('node_0', 'fr_1'))).hitTestable(), findsNothing,
          reason: '最旧列在锚外——要它就往左滑');
    });

    testWidgets('nearing the OLDEST edge fires onNearOldestEdge ONCE per approach, and re-arms',
        (tester) async {
      var fired = 0;
      // 30 columns: the scroll range must dwarf the threshold (4 pitches) AND the 2× re-arm line,
      // or «recede past 2×» is unreachable and the test judges arithmetic, not behaviour.
      // 30 列:滚动范围须远大于阈(4 列距)与 2 倍重上膛线,否则「退过 2 倍」不可达,测试判的是算术不是行为。
      await tester.pumpWidget(_host(
          grid(onNearOldestEdge: () => fired++, cols: [
            for (var i = 1; i <= 30; i++)
              RunColumn(id: 'fr_$i', status: 'completed', elapsedMs: 1000 * i),
          ]),
          width: 640));
      final ctl = hCtl(tester);
      final max = ctl.position.maxScrollExtent;

      ctl.jumpTo(max); // slam into the oldest edge 撞上最旧缘
      await tester.pump();
      expect(fired, 1, reason: '入阈发一次');
      ctl.jumpTo(max - 8); // jitter inside the threshold — must NOT refire 阈内抖动不复发
      await tester.pump();
      expect(fired, 1, reason: '一次逼近只发一次');

      ctl.jumpTo(0); // recede far past 2× the threshold 远退过 2 倍阈
      await tester.pump();
      ctl.jumpTo(max);
      await tester.pump();
      expect(fired, 2, reason: '退开重上膛,再逼近再发');
    });

    testWidgets('prepending an OLDER page moves NOTHING on screen (reverse-scroll geometry)',
        (tester) async {
      // BOTH states must overflow the viewport: an underfull grid is centered by the host, so the
      // whole widget would shift and «pixel-identical» would measure the host, not the geometry.
      // 前后两态都必须溢出视口:装得下的格阵会被宿主居中,整件挪位,「逐像素不动」量的就成了宿主。
      List<RunColumn> cols(int oldest) => [
            for (var i = oldest; i <= 30; i++)
              RunColumn(id: 'fr_$i', status: 'completed', elapsedMs: 1000 * i),
          ];
      await tester.pumpWidget(_host(grid(cols: cols(12)), width: 640)); // 19 cols, overflows 溢出
      final ctl = hCtl(tester);
      // Mid-scroll — the harder case than the anchor. 滚到半途——比锚点更硬的用例。
      ctl.jumpTo(ctl.position.maxScrollExtent / 2);
      await tester.pump();
      final offsetBefore = ctl.offset;
      expect(offsetBefore, greaterThan(0), reason: '前态真溢出、真滚了');
      final rectBefore = tester.getRect(find.byKey(const ValueKey(('node_0', 'fr_25'))));

      await tester.pumpWidget(_host(grid(cols: cols(1)), width: 640)); // +11 older cols 前插十一列
      await tester.pump();
      expect(hCtl(tester).offset, offsetBefore, reason: '前插旧页 offset 一动不动');
      expect(tester.getRect(find.byKey(const ValueKey(('node_0', 'fr_25')))), rectBefore,
          reason: '屏上的格逐像素不动——offset 从锚缘起量,远端生长与屏面无关');
    });

    testWidgets('loadingOlder renders the working spinner at the oldest edge', (tester) async {
      await tester.pumpWidget(_host(grid(loadingOlder: true), width: 640));
      expect(find.byType(AnSpinner), findsOneWidget, reason: '取数中,最旧缘有一个诚实的转圈');
      await tester.pumpWidget(_host(grid(), width: 640));
      expect(find.byType(AnSpinner), findsNothing, reason: '取完即收');
    });
  });
}
