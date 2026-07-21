import 'package:flutter/widgets.dart';

import '../../core/design/tokens.dart';
import '../../core/ui/ui.dart';
import 'specimen.dart';

// AnRunMatrix (WRK-069 §12 + 判决③, S5) — the node×run grid. What these specimens must prove is the
// thing the gantt and the graph structurally cannot show: a node that fails EVERY run reads as a
// horizontal red streak, while a one-off failure reads as a single square. That pattern is the whole
// reason the third face exists.
//
// Also proven here: 「未及」 is an EMPTY square (sparse by contract — a run that never reached a node
// has no cell), never a colour; a still-running column has NO duration bar (an unfinished run has no
// share of «longest» to take); «×N» rides inside the cell for loop iterations.
//
// **The keyboard walkthrough happens here**: Tab ONCE to enter (a 20×24 grid is 524 focusable
// positions and exactly ONE Tab stop — the roving cursor), arrows to walk, an arrow off the edge to
// leave, Enter to pick. And the screen-reader walkthrough: every row states its own PATTERN as a
// summary, the cursor speaks its coordinate (the desktop transports no table structure, so the
// coordinate can only ride inside the label string), and no other square says a word.
//
// AnRunMatrix 节点×run 格阵。这些样本要验明的正是甘特与图**结构上**给不出的东西:每次都坏的节点读作一道
// 横向红条,偶发失败读作孤零零一格——那个模式就是第三脸存在的全部理由。另验:「未及」=**空格**(契约级稀疏,
// 没跑到即无格),绝不着色;在跑的列**无**时长条(未完的 run 没有「最长」的份额可占);×N 在格内。
// **键盘走查在此**:Tab **一次**进(20×24=524 个可聚焦位置、**恰好一个** Tab 停靠=roving 光标)、方向键走、
// 出边即离开、Enter 选中。**读屏走查**:每行用摘要说出自己的**模式**,光标报出坐标(桌面运不动表格结构,
// 坐标只能在 label 字符串里),其余方块一个字都不说。

const _rows = [
  MatrixRowHead(nodeId: 'fetch', kind: 'action'),
  MatrixRowHead(nodeId: 'gate', kind: 'control'),
  MatrixRowHead(nodeId: 'analyze', kind: 'agent'),
  MatrixRowHead(nodeId: 'approve', kind: 'approval'),
  MatrixRowHead(nodeId: 'notify', kind: 'action'),
];

List<RunColumn> _cols() => [
  // CHRONOLOGICAL, oldest LEFT — a timeline; the viewport anchors at the newest (right) end
  // (主页重建拍板 0717). 时序旧在左——时间轴;视口锚最新(右)端。
  const RunColumn(
    id: 'fr_3',
    status: 'completed',
    elapsedMs: 40500,
    label: 'fr_3 · 成功 · 40.5s',
  ),
  const RunColumn(
    id: 'fr_4',
    status: 'cancelled',
    elapsedMs: 2000,
    label: 'fr_4 · 已取消 · 2s',
  ),
  const RunColumn(
    id: 'fr_5',
    status: 'completed',
    elapsedMs: 39000,
    label: 'fr_5 · 成功 · 39s',
  ),
  const RunColumn(
    id: 'fr_6',
    status: 'failed',
    elapsedMs: 6100,
    label: 'fr_6 · 失败 · 6.1s',
  ),
  const RunColumn(
    id: 'fr_7',
    status: 'completed',
    elapsedMs: 42000,
    label: 'fr_7 · 成功 · 42s',
  ),
  const RunColumn(
    id: 'fr_8',
    status: 'failed',
    elapsedMs: 8200,
    label: 'fr_8 · 失败 · 8.2s',
  ),
  const RunColumn(id: 'fr_9', status: 'running', label: 'fr_9 · 在跑'),
];

/// «analyze» breaks in three of seven runs — the horizontal streak the single-run lenses can't show.
/// analyze 七次里坏三次——单 run 透镜看不见的那道横条。
MatrixCellState? _cell(String runId, String nodeId) {
  const reached = {
    'fr_9': {'fetch', 'gate'},
    'fr_8': {'fetch', 'gate', 'analyze'},
    'fr_7': {'fetch', 'gate', 'analyze', 'approve', 'notify'},
    'fr_6': {'fetch', 'gate', 'analyze'},
    'fr_5': {'fetch', 'gate', 'analyze', 'approve', 'notify'},
    'fr_4': {'fetch', 'gate'},
    'fr_3': {'fetch', 'gate', 'analyze', 'approve', 'notify'},
  };
  if (!(reached[runId]?.contains(nodeId) ?? false)) {
    return null; // 未及 — sparse, no cell 稀疏无格
  }
  if (nodeId == 'analyze' && (runId == 'fr_8' || runId == 'fr_6')) {
    // The worst disposition across iterations wins — a loop that failed on round 3 DID fail.
    // 各轮取最坏:第 3 轮失败的 loop 就是失败过。
    return const MatrixCellState(
      status: 'failed',
      iterations: 3,
      label: 'analyze · 失败 · ×3 轮',
    );
  }
  if (nodeId == 'approve' && runId == 'fr_5') {
    return const MatrixCellState(status: 'parked', label: 'approve · 等审批');
  }
  return MatrixCellState(status: 'completed', label: '$nodeId · 成功');
}

/// The row's spoken summary — it must answer 「老是坏还是就这一次」 in WORDS, because a screen-reader
/// user gets no red streak to look at. 行的读屏摘要:必须用**词**答出「老是坏还是就这一次」——读屏用户
/// 看不见那道红条。
String _rowSummary(MatrixRowSummary s) {
  final reached = s.cells.where((c) => c != null).toList();
  final bad = reached.where((c) => c!.status == 'failed').length;
  return '${s.row.nodeId}，第 ${s.index + 1} 行 共 ${s.total} 行,'
      '${reached.length} 次运行:${reached.length - bad} 成功 $bad 失败';
}

final anRunMatrixGalleryItem = GalleryItem(
  'AnRunMatrix 节点×run 格阵',
  '行=节点、列=**时序**(旧在左、新在右,视口锚最新端;向最旧缘滑动即懒加载更多历史,前插零位移)+ 列顶 run '
      '时长微条;格渲最坏处置色、iterations>1 渲「×N」、稀疏格=「未及」空格;三粒度选区(点格/点列/点行);'
      '**键盘=唯一一个 Tab 停靠**(roving 光标:一次 Tab 进、方向键走、出边即出、Enter 选中);**读屏=行级**'
      '(逐行摘要说出模式 + 光标句内嵌坐标——桌面运不动 table role);刻意不虚拟化(列按 ≤50 有界页到达、'
      '只随用户显式滑动生长,行是图节点——几十不是几千)',
  [
    GallerySpecimen(
      '全文法(横向红条=老是坏的节点 / 未及空格 / ×N / parked / 在跑列无条)· 键盘:Tab 一次进,方向键走,出边即出',
      (_) => Padding(
        padding: const EdgeInsets.all(AnSpace.s16),
        child: AnRunMatrix(
          rows: _rows,
          cols: _cols(),
          cellStatus: _cell,
          onCell: (_, _) {},
          onCol: (_) {},
          onRow: (_) {},
          notReachedLabel: '未及',
          runningLabel: '在跑(无耗时)',
          cellSemanticLabel: (col, row, cell) =>
              '${row.nodeId} ${col.id} ${cell?.status ?? '未及'}',
          colSemanticLabel: (col) => 'run ${col.id} ${col.status}',
          rowSemanticLabel: (row) => '节点 ${row.nodeId}',
          rowSummaryLabel: _rowSummary,
          // The coordinate rides IN the label: desktop Flutter ships no table role and no
          // indexInParent (they die at the embedder's C ABI), so there is nowhere else to put
          // it. 坐标就在 label 里:桌面 Flutter 没有 table role、没有 indexInParent(它们死在
          // embedder 的 C ABI 上),没有别处可放。
          coordinateLabel: (r, rows, c, cols) =>
              '第 ${r + 1} 行 共 $rows 行，第 ${c + 1} 列 共 $cols 列',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      '三粒度选区:选中一格(该 run 该节点)',
      (_) => Padding(
        padding: const EdgeInsets.all(AnSpace.s16),
        child: AnRunMatrix(
          rows: _rows,
          cols: _cols(),
          cellStatus: _cell,
          selection: const MatrixSelection(
            flowrunId: 'fr_8',
            nodeId: 'analyze',
          ),
          onCell: (_, _) {},
          onCol: (_) {},
          onRow: (_) {},
          notReachedLabel: '未及',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      '三粒度选区:选中一列(该 run)',
      (_) => Padding(
        padding: const EdgeInsets.all(AnSpace.s16),
        child: AnRunMatrix(
          rows: _rows,
          cols: _cols(),
          cellStatus: _cell,
          selection: const MatrixSelection(flowrunId: 'fr_7'),
          onCell: (_, _) {},
          onCol: (_) {},
          onRow: (_) {},
          notReachedLabel: '未及',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      '三粒度选区:选中一行(节点历史)',
      (_) => Padding(
        padding: const EdgeInsets.all(AnSpace.s16),
        child: AnRunMatrix(
          rows: _rows,
          cols: _cols(),
          cellStatus: _cell,
          selection: const MatrixSelection(nodeId: 'analyze'),
          onCell: (_, _) {},
          onCol: (_) {},
          onRow: (_) {},
          notReachedLabel: '未及',
        ),
      ),
      span: true,
    ),
    // ── 压力床 ──
    // The VERTICAL scroll here is the HOST's, mirroring production: the grid sizes to content and the
    // page owns the vertical axis ([AnPage]'s one true scroller). The gallery cell is a bounded box,
    // so the specimen must supply the scroller the real page already is — otherwise this bed would
    // "prove" an overflow that cannot happen in the app. The HORIZONTAL axis is the grid's OWN (用户
    // 0717 判决:阅读列绝对,宽内容自带横滚) — at the real 720 reading column 20 columns overspill by
    // ~52px, so the thumb is visible here and that is the intended production shape, not a defect.
    // 此处的**纵向**滚动是**宿主**的,与生产一致:格阵按内容定尺寸、纵轴归页面(AnPage 唯一的滚动器)。画廊
    // 格是个有界盒,故样本必须自备真页面本就是的那个滚动器——否则这张床会「证明」一个 app 里不可能发生的
    // 溢出。**横**轴归格阵自己(用户 0717 判决:阅读列绝对、宽内容自带横滚)——在真实 720 阅读列上 20 列溢出
    // ~52px,故此处 thumb 可见,那是**预期的生产形态**而非缺陷。
    GallerySpecimen(
      '压力:满格阵 20 列 × 24 行(= 一整页的量级)= 524 个可聚焦位置、**恰好 1 个 Tab 停靠**;'
      '横向自滚(锚最新端)、纵向归宿主',
      (_) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AnSpace.s16),
          child: AnRunMatrix(
            rows: [
              for (var i = 0; i < 24; i++)
                MatrixRowHead(
                  nodeId: 'node_$i',
                  kind: i.isEven ? 'action' : 'agent',
                ),
            ],
            cols: [
              for (var i = 20; i > 0; i--)
                RunColumn(
                  id: 'fr_$i',
                  status: i % 5 == 0 ? 'failed' : 'completed',
                  elapsedMs: 1000 * i,
                  label: 'fr_$i',
                ),
            ],
            cellStatus: (runId, nodeId) => MatrixCellState(
              status: runId.endsWith('5') ? 'failed' : 'completed',
            ),
            onCell: (_, _) {},
            onCol: (_) {},
            onRow: (_) {},
            notReachedLabel: '未及',
            // This is the bed where the keyboard claim is walked: Tab in, hold an arrow across
            // 20 columns, arrow off the edge to leave. Before the roving cursor this bed cost
            // 527 Tab presses to cross.
            // 键盘主张就在这张床上走:Tab 进、按住方向键横穿 20 列、出边即离开。在 roving 光标之前,
            // 穿过这张床要按 527 次 Tab。
            cellSemanticLabel: (col, row, cell) =>
                '${row.nodeId} ${col.id} ${cell?.status}',
            colSemanticLabel: (col) => 'run ${col.id}',
            rowSemanticLabel: (row) => '节点 ${row.nodeId}',
            rowSummaryLabel: _rowSummary,
            coordinateLabel: (r, rows, c, cols) =>
                '第 ${r + 1} 行 共 $rows 行，第 ${c + 1} 列 共 $cols 列',
          ),
        ),
      ),
      stress: true,
      span: true,
      height: 360,
    ),
    GallerySpecimen(
      '压力:超长 nodeId(定宽车道内裁切)· 全稀疏(一格未及,整阵空格)',
      (_) => Padding(
        padding: const EdgeInsets.all(AnSpace.s16),
        child: AnRunMatrix(
          rows: const [
            MatrixRowHead(
              nodeId: 'a_very_long_node_identifier_that_must_ellipsize',
              kind: 'action',
            ),
            MatrixRowHead(nodeId: 'short', kind: 'agent'),
          ],
          cols: const [
            RunColumn(id: 'fr_1', status: 'completed', elapsedMs: 100),
            RunColumn(id: 'fr_2', status: 'running'),
          ],
          cellStatus: (_, _) => null, // 全稀疏:一格也没跑到 all sparse
          notReachedLabel: '未及',
        ),
      ),
      stress: true,
      maxWidth: 420,
    ),
    GallerySpecimen(
      '空(零行 / 零列)渲空',
      (_) => Padding(
        padding: const EdgeInsets.all(AnSpace.s16),
        child: AnRunMatrix(
          rows: const [],
          cols: const [],
          cellStatus: (_, _) => null,
        ),
      ),
      stress: true,
    ),
  ],
);
