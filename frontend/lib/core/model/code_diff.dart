/// Line-level text diff — a framework-free port of the demo's LCS (`version-diff.js`), the SINGLE
/// deterministic diff source for AnVersionDiff (WRK-040 G5.0). Reverse DP for the longest common
/// subsequence, then backtrack into an ordered [context]/[add]/[del] sequence — exactly the shape a
/// unified (single-column) diff renders, no post-projection. Pure: no widgets, no I/O, unit-testable.
///
/// 行级文本 diff——demo LCS(version-diff.js)的框架无关移植,AnVersionDiff 的唯一确定性 diff 源(WRK-040 G5.0)。
/// 逆向 DP 求最长公共子序列 + 回溯出顺序的 ctx/add/del——正是 unified 单栏 diff 要的形状,无需后投影。纯函数、可单测。
library;

/// One diffed line: its operation + the line text (WITHOUT the trailing newline). A NAMED record so
/// callers read `.op` / `.text` (positional `(DiffOp, String)` would force `.$1`/`.$2`). 一条 diff 行(命名记录)。
typedef DiffLine = ({DiffOp op, String text});

/// The three unified-diff operations. [context] = unchanged (shown for surrounding context),
/// [add] = present only in `after` (green +), [del] = present only in `before` (red −).
/// 三种 unified diff 操作。
enum DiffOp { context, add, del }

/// Degrade gate (WRK-040 §4, corrected by the G5.0 review) — the (m+1)×(n+1) LCS DP matrix IS the real
/// time+memory cost, so we cap the CELL COUNT, faithful to the demo's gate (principle #8). Beyond it we
/// DON'T run LCS and fall back to a whole-segment replace (every `before` line as [del] then every
/// `after` line as [add]) — semantically correct, just not the minimal edit script. The BALANCED case
/// (m≈n) is the trap a total-LINE cap (m+n) misses: m=n=2500 is only 5000 lines yet a ~6.25M-cell
/// (~50MB) matrix — the cell cap bounds the real cost directly, one metric, no leak. (WRK-040 had
/// proposed an m+n cap reasoning "Myers has no matrix"; but v1 IS LCS and DOES — so the cell cap is
/// correct here.) CONSERVATIVE placeholder: only ever RAISE it after a real-machine stress test proves
/// headroom (verify-by-real-run), never lower silently.
/// 退化闸:LCS 矩阵单元数 (m+1)(n+1) 即真实成本,按 cell 封顶(忠实移植 demo,#8)。超阈整段替换(语义正确、非最小编辑)。
/// 平衡型 m≈n 是行数闸(m+n)漏网的陷阱——m=n=2500 仅 5000 行却撑 ~50MB 矩阵;cell 闸直接封顶真实成本。保守占位、真机只上调。
const int lineDiffMaxCells =
    4000000; // (m+1)*(n+1) DP-matrix cell cap (~2000×2000), = demo LCS_CELL_CAP

/// Diff [before] → [after] line-by-line. The empty/earliest-version case (no older text to compare)
/// is the CALLER's concern (AnVersionDiff renders an absent `before` as all-context, uncoloured) —
/// here an empty string still splits to a single empty line, so callers gate that upstream.
/// 逐行 diff。空/最早版本(无更旧可比)由调用方处理(AnVersionDiff 把缺失 before 整段以 ctx 渲染)。
List<DiffLine> lineDiff(String before, String after) {
  final a = before.split('\n');
  final b = after.split('\n');
  final m = a.length;
  final n = b.length;

  // Degrade: matrix too large to run LCS → whole-segment replace (all del, then all add). 退化:整段替换。
  if ((m + 1) * (n + 1) > lineDiffMaxCells) {
    return [
      for (final line in a) (op: DiffOp.del, text: line),
      for (final line in b) (op: DiffOp.add, text: line),
    ];
  }

  // Reverse DP: dp[i][j] = LCS length of a[i:] and b[j:]. 逆向 DP:dp[i][j]=后缀 LCS 长度。
  final dp = List.generate(
    m + 1,
    (_) => List<int>.filled(n + 1, 0),
    growable: false,
  );
  for (var i = m - 1; i >= 0; i--) {
    for (var j = n - 1; j >= 0; j--) {
      dp[i][j] = a[i] == b[j]
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] >= dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }

  // Backtrack forward into the ordered op sequence. 回溯出顺序 op 序列。
  final out = <DiffLine>[];
  var i = 0;
  var j = 0;
  while (i < m && j < n) {
    if (a[i] == b[j]) {
      out.add((op: DiffOp.context, text: a[i]));
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      out.add((op: DiffOp.del, text: a[i]));
      i++;
    } else {
      out.add((op: DiffOp.add, text: b[j]));
      j++;
    }
  }
  while (i < m) {
    out.add((op: DiffOp.del, text: a[i]));
    i++;
  }
  while (j < n) {
    out.add((op: DiffOp.add, text: b[j]));
    j++;
  }
  return out;
}
