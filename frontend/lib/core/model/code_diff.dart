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

/// The unified-diff CONTEXT WINDOW — how many unchanged lines stay on EACH side of a change when a
/// consumer folds the untouched stretches away ([unchangedGaps]). **3** is the industry default and the
/// value every reader's eye is already trained on: `diff -U3` / `git diff`'s built-in `-U3`, GitHub's
/// collapsed file view and the unified-diff format's own conventional hunk width all use 3 — enough to
/// show the enclosing statement (a `def` line, a closing brace, the sibling above) without dragging the
/// whole file in. Named (never a literal at the call site) so retuning it is one line.
/// unified diff 上下文窗=**3**:业界默认(`diff -U3`/`git diff` 内置 -U3/GitHub 折叠视图),恰好带出包裹语句
/// (def 行/收尾括号/上一条兄弟)而不把整份文件拖进来;命名常量,调用点不写字面量。
const int diffContextLines = 3;

/// One folded run of unchanged lines: [start] = its FIRST index in the diffed sequence, [count] = how
/// many lines it swallows. The index is the run's identity — a consumer's «revealed» set keys off
/// [start], so a revealed gap stays revealed across rebuilds and across list virtualization.
/// 一段被折叠的未变更行:start=其在 diff 序列中的首个下标(即身份,消费方的展开集按它记键,跨重建/虚拟化保持)。
typedef DiffGap = ({int start, int count});

/// The runs of [DiffOp.context] lines a HUNK view folds away: every line that is neither a change nor
/// within [context] lines of one. Takes the ops ALONE (not the texts) so it is pure index arithmetic
/// over whatever the consumer already assembled — no second diff, no re-derivation.
///
/// Two rules earn their keep:
/// - **No change anywhere → no gaps at all** (returns empty). The earliest version renders as pure
///   context; folding it would leave a card that says only «… 42 lines omitted» — hiding 100% of the
///   content the reader opened. A diff with nothing to hunk AROUND has no hunks.
/// - **A single dropped line is never folded.** Its marker row would occupy the very row it saves while
///   revealing strictly less.
///
/// hunk 视图要折掉的未变更行段:既非变更行、又不在变更行 [context] 行内的行。只吃 ops(不吃文本)——纯下标
/// 算术,不重跑 diff。两条规则:①全无变更→零 gap(最早版本整段是 ctx,折了只剩一句「省略 N 行」=藏掉读者
/// 打开它要看的全部内容);②单行不折(标记行占掉它省下的那一行、还看得更少)。
List<DiffGap> unchangedGaps(
  List<DiffOp> ops, {
  int context = diffContextLines,
}) {
  final n = ops.length;
  var changed = false;
  for (final op in ops) {
    if (op != DiffOp.context) {
      changed = true;
      break;
    }
  }
  if (!changed) return const [];

  final keep = List<bool>.filled(n, false);
  for (var i = 0; i < n; i++) {
    if (ops[i] == DiffOp.context) continue;
    final lo = i - context < 0 ? 0 : i - context;
    final hi = i + context >= n ? n - 1 : i + context;
    for (var j = lo; j <= hi; j++) {
      keep[j] = true;
    }
  }

  final gaps = <DiffGap>[];
  var i = 0;
  while (i < n) {
    if (keep[i]) {
      i++;
      continue;
    }
    final start = i;
    while (i < n && !keep[i]) {
      i++;
    }
    final count = i - start;
    if (count > 1) gaps.add((start: start, count: count));
  }
  return gaps;
}

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
