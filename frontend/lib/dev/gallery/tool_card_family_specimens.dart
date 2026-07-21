import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../core/sse/frame.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// V3b family skins — the MACHINE-WINDOW identity: a tool call is an operation against the
// outside world, so its machine output lives in contained sunken windows (terminal / diff /
// hit list), NEVER thinking's whisper rail. Fixtures carry the backend's EXACT output formats
// (cat -n, [exit code: N] footer, rg lines) so the receipt parsers run for real.
//
// V3b 族皮肤——**机器窗口**身份:tool call 是对外部世界的操作,机器输出住在凹陷容器窗里
// (终端/diff/命中列表),绝不借 thinking 的低语 rail。夹具带后端**精确**输出格式(cat -n、
// exit footer、rg 行),回执解析器真跑。

BlockNode _call(
  String id,
  String name, {
  String status = 'completed',
  String? args,
  String? summary,
  String? danger,
  String? result,
  String? resultError,
  String? progress,
  bool progressLive = false,
}) {
  final node = BlockNode(id: 'tc_$id', kind: BlockKind.toolCall)
    ..status = status
    ..content = {
      'name': name,
      'arguments': ?args,
      'summary': ?summary,
      'danger': ?danger,
    };
  if (progress != null) {
    node.children.add(
      BlockNode(id: 'pr_$id', kind: BlockKind.progress)
        ..status = progressLive ? 'open' : 'completed'
        ..content = {'text': progress},
    );
  }
  if (result != null || resultError != null) {
    node.children.add(
      BlockNode(id: 'tr_$id', kind: BlockKind.toolResult)
        ..status = resultError != null ? 'error' : 'completed'
        ..error = resultError
        ..content = {'content': result ?? resultError ?? ''},
    );
  }
  return node;
}

// ── F3 shell fixtures 终端夹具 ──

const String _testRunTail =
    ' ✓ src/rollup.test.ts (8 tests) 214ms\n'
    ' ✓ src/quarters.test.ts (5 tests) 88ms\n'
    ' ✓ src/currency.test.ts (3 tests) 41ms\n'
    'Test Files  3 passed (3)\n'
    '     Tests  16 passed (16)';

// progress = raw output (no footer, the Close snapshot); result = raw + the [exit code] footer (which
// bashToolBody strips into the bottom bar). progress=原始输出(无 footer);result=原始+footer。
const String _bashOkRaw = '$_testRunTail\n  Duration  1.92s';
const String _bashOkResult = '$_bashOkRaw\n\n[exit code: 0]';

const String _bashFailRaw =
    ' ✓ src/rollup.test.ts (8 tests) 214ms\n'
    ' ✗ src/quarters.test.ts (5 tests | 1 failed) 96ms\n'
    '   → expected Q4 total 143000, got 141200\n'
    'Test Files  1 failed | 1 passed (2)\n'
    '     Tests  1 failed | 15 passed (16)';
const String _bashFailResult = '$_bashFailRaw\n\n[exit code: 1]';

final toolCardShellGalleryItem = GalleryItem(
  'ChatToolCard · shell 族',
  'F3:执行中=收起行下的**活终端窗**(progress 尾 3 行,机器窗身份非低语 rail);完成=exit 回执'
      '(footer 解析);失败=exit 红+自动展开完整终端窗(\$ 命令回显头);意图(summary)常显——全族红。',
  [
    GallerySpecimen(
      '执行中 · 活终端尾巴(收起行下的小机器窗)',
      (c) => ChatToolCard(
        node: _call(
          'bash-live',
          'Bash',
          args:
              '{"command":"npm test","summary":"Run the test suite","danger":"cautious"}',
          summary: 'Run the test suite',
          danger: 'cautious',
          progress: _testRunTail,
          progressLive: true,
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      '完成 · exit 0(footer 剥离→底条 · \$ cmd 头 · copy)',
      (c) => ChatToolCard(
        node: _call(
          'bash-ok',
          'Bash',
          args: '{"command":"npm test"}',
          summary: 'Run the test suite',
          danger: 'cautious',
          progress: _bashOkRaw,
          result: _bashOkResult,
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      '失败 · exit 1(红底条自动展开,命令回显头)',
      (c) => ChatToolCard(
        node: _call(
          'bash-fail',
          'Bash',
          args: '{"command":"npm test"}',
          summary: 'Run the test suite',
          danger: 'cautious',
          progress: _bashFailRaw,
          result: _bashFailResult,
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      '超时(note→底条 danger)',
      (c) => ChatToolCard(
        node: _call(
          'bash-timeout',
          'Bash',
          args: '{"command":"sleep 999"}',
          result:
              'partial output\n\n[command timed out after 2m0s]\n[exit code: -1]',
        ),
      ),
      span: true,
      stress: true,
    ),
    GallerySpecimen(
      '后台 spawn(薄会话体:可复制 bsh_id + 轮询提示)',
      (c) => ChatToolCard(
        node: _call(
          'bash-bg',
          'Bash',
          args: '{"command":"npm run dev","run_in_background":true}',
          result:
              'Started background command (bash_id=bsh_1a2b3c4d5e6f7a8b): npm run dev\n'
              'Use BashOutput with this bash_id to poll new output, or KillShell to terminate.',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'BashOutput · running(bsh chip + 新输出 + 状态底条 静态 accent)',
      (c) => ChatToolCard(
        node: _call(
          'bashout-run',
          'BashOutput',
          args: '{"bash_id":"bsh_1a2b3c4d5e6f7a8b"}',
          result:
              'VITE v5.0  ready in 312 ms\n  ➜  Local:   http://localhost:5173/\n\n[status: running]',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'BashOutput · 无新输出 + exited(code 0)(不自动展开)',
      (c) => ChatToolCard(
        node: _call(
          'bashout-done',
          'BashOutput',
          args: '{"bash_id":"bsh_1a2b3c4d5e6f7a8b"}',
          result:
              '(no new output since last poll)\n\n[status: exited (code 0)]',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'BashOutput · 会话不存在(danger + 中性穷举 hint)',
      (c) => ChatToolCard(
        node: _call(
          'bashout-gone',
          'BashOutput',
          args: '{"bash_id":"bsh_dead"}',
          result: 'Background shell process not found: bsh_dead',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'KillShell · 已终止(动词自足,无回执)',
      (c) => ChatToolCard(
        node: _call(
          'kill-ok',
          'KillShell',
          args: '{"bash_id":"bsh_1a2b3c4d5e6f7a8b"}',
          result: 'Killed background shell bsh_1a2b3c4d5e6f7a8b.',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'KillShell · 已自行结束(muted)',
      (c) => ChatToolCard(
        node: _call(
          'kill-fin',
          'KillShell',
          args: '{"bash_id":"bsh_9"}',
          result:
              'Background shell bsh_9 already finished; removed from registry.',
        ),
      ),
      span: true,
    ),
  ],
);

// ── F1 fs-ops fixtures 文件操作夹具 ──

const String _readOutput =
    '    1\timport json\n'
    '    2\t\n'
    '    3\tdef rollup(items):\n'
    '    4\t    by_quarter = {}\n'
    '    5\t    for it in items:\n'
    '    6\t        q = quarter_of(it.date)\n'
    '    7\t        by_quarter.setdefault(q, 0)\n'
    '    8\t        by_quarter[q] += it.amount\n'
    '    9\t    return by_quarter\n';

final toolCardFsGalleryItem = GalleryItem(
  'ChatToolCard · fs-ops 族',
  'F1:Read=**回执即卡**(无展开体、无 chevron,行数/截断从 cat -n 解析);Write=代码窗(内容+语言);'
      'Edit=old→new **diff 窗**(AnVersionDiff 绿红软底)。目标=basename。',
  [
    GallerySpecimen(
      'Read · 回执即卡(9 行,无 chevron)',
      (c) => ChatToolCard(
        node: _call(
          'read',
          'Read',
          args: '{"file_path":"/ws/functions/rollup.py"}',
          result: _readOutput,
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'Read · 截断回执(前 2000 行)',
      (c) => ChatToolCard(
        node: _call(
          'read-trunc',
          'Read',
          args: '{"file_path":"/ws/logs/huge.log"}',
          result:
              '    1\tfirst line\n... [truncated at line 2000; use offset+limit to read more]\n',
        ),
      ),
      span: true,
      stress: true,
    ),
    GallerySpecimen(
      'Write · 代码窗(展开态)',
      (c) => ChatToolCard(
        node: _call(
          'write',
          'Write',
          args:
              '{"file_path":"/ws/functions/quarters.py","content":"def quarter_of(date):\\n    return (date.month - 1) // 3 + 1\\n"}',
          result: 'Wrote /ws/functions/quarters.py',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'Write · 内容流入中(F01 生长秀:文件随打字长出)',
      (c) => ChatToolCard(node: _writeStreaming()),
      span: true,
    ),
    GallerySpecimen(
      'Edit · 两幕活窗(先 − old 流入,再 + new)',
      (c) => ChatToolCard(node: _editStreaming()),
      span: true,
    ),
    GallerySpecimen(
      'Edit · diff 窗(old→new,展开态)',
      (c) => ChatToolCard(
        node: _call(
          'edit',
          'Edit',
          args:
              '{"file_path":"/ws/functions/rollup.py",'
              '"old_string":"        by_quarter.setdefault(q, 0)\\n        by_quarter[q] += it.amount",'
              '"new_string":"        by_quarter.setdefault(q, 0)\\n        # refunds count against the quarter 退款冲减当季\\n        by_quarter[q] += it.amount"}',
          result: 'Replaced 1 occurrence in /ws/functions/rollup.py.',
        ),
      ),
      span: true,
    ),
  ],
);

/// Mid-stream Write: the `content` value is still OPEN — the live window shows what has streamed so far.
/// 流中 Write:content 未闭合,活窗显已流入部分。
BlockNode _writeStreaming() {
  const scope = StreamScope(kind: 'conversation', id: 'cv_w');
  final r = BlockTreeReducer()
    ..apply(
      const StreamEnvelope(
        seq: 1,
        scope: scope,
        id: 'tc_wstream',
        frame: FrameOpen(
          node: StreamNode(type: 'tool_call', content: {'name': 'Write'}),
        ),
      ),
    )
    ..apply(
      const StreamEnvelope(
        seq: 0,
        scope: scope,
        id: 'tc_wstream',
        frame: FrameDelta(
          chunk:
              '{"file_path":"/ws/functions/quarters.py","content":"import datetime\\n\\n'
              'def quarter_of(date):\\n    \\"\\"\\"Map a date to its fiscal quarter.\\"\\"\\"\\n'
              '    return (date.month - 1) // 3 + 1\\n\\ndef quarter_start(y',
        ),
      ),
    );
  return r.roots.single;
}

/// Mid-stream Edit: `old_string` fully arrived (the − segment), `new_string` still OPEN (+ growing).
/// 流中 Edit:old_string 已到(− 段),new_string 未闭合(+ 生长中)。
BlockNode _editStreaming() {
  const scope = StreamScope(kind: 'conversation', id: 'cv_e');
  final r = BlockTreeReducer()
    ..apply(
      const StreamEnvelope(
        seq: 1,
        scope: scope,
        id: 'tc_estream',
        frame: FrameOpen(
          node: StreamNode(type: 'tool_call', content: {'name': 'Edit'}),
        ),
      ),
    )
    ..apply(
      const StreamEnvelope(
        seq: 0,
        scope: scope,
        id: 'tc_estream',
        frame: FrameDelta(
          chunk:
              '{"file_path":"/ws/functions/rollup.py",'
              '"old_string":"    for it in items:\\n        by_quarter[q] += it.amount",'
              '"new_string":"    for it in items:\\n        if it.refund:\\n            by_quarter[q] -= it.amoun',
        ),
      ),
    );
  return r.roots.single;
}

// ── F2 fs-search fixtures 检索夹具 ──

const String _grepOutput =
    'functions/rollup.py:8:        by_quarter[q] += it.amount\n'
    'functions/rollup.py:14:    total = sum(amounts)\n'
    'functions/quarters.py:2:    return (date.month - 1) // 3 + 1\n'
    'handlers/invoice_sync.py:31:        self.amounts.append(row.amount)\n';

final toolCardSearchGalleryItem = GalleryItem(
  'ChatToolCard · fs-search 族',
  'F2:回执=计数(过去时的凭据,含截断下界 N+);展开=命中窗(行式等宽);"No matches"=诚实空回执、'
      '无展开体。目标=引号包 pattern / LS 用 basename。',
  [
    GallerySpecimen(
      'Grep · content(编辑器式全局搜索:分组 + 行号 + 行内点亮)',
      (c) => ChatToolCard(
        node: _call(
          'grep',
          'Grep',
          args:
              '{"pattern":"amount","path":"/ws","output_mode":"content","-n":true}',
          result: _grepOutput,
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'Grep · count(热度条:一眼看出模式聚居地)',
      (c) => ChatToolCard(
        node: _call(
          'grep-count',
          'Grep',
          args: '{"pattern":"amount","path":"/ws","output_mode":"count"}',
          result:
              '/ws/functions/rollup.py:5\n/ws/handlers/invoice_sync.py:12\n/ws/functions/quarters.py:1\n',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'Grep · files_with_matches(路径清单)',
      (c) => ChatToolCard(
        node: _call(
          'grep-files',
          'Grep',
          args: '{"pattern":"amount","path":"/ws"}',
          result:
              '/ws/functions/rollup.py\n/ws/handlers/invoice_sync.py\n/ws/functions/quarters.py\n',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'Glob · JSON 命中窗(basename + size·mtime,mtime 降序)',
      (c) => ChatToolCard(
        node: _call(
          'glob',
          'Glob',
          args: '{"pattern":"**/*.py","path":"/ws"}',
          result:
              '{"root":"/ws","total":3,"truncated":false,"matches":['
              '{"path":"/ws/functions/rollup.py","type":"file","size":1234,"mtime":"2026-07-05T14:00:00Z"},'
              '{"path":"/ws/functions/quarters.py","type":"file","size":310,"mtime":"2026-07-04T09:00:00Z"},'
              '{"path":"/ws/handlers/invoice_sync.py","type":"file","size":2480,"mtime":"2026-07-01T11:00:00Z"}]}',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'Grep · 无匹配(诚实空回执)',
      (c) => ChatToolCard(
        node: _call(
          'grep-none',
          'Grep',
          args: '{"pattern":"xyzzy"}',
          result: 'No matches for "xyzzy" in /ws.',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'LS · 目录清单(dir 优先 + file size·mtime)',
      (c) => ChatToolCard(
        node: _call(
          'ls',
          'LS',
          args: '{"path":"/ws/functions"}',
          result:
              '/ws/functions (4 entries)\n'
              '  dir   __pycache__\n'
              '  file  rollup.py   1.2 KB   2026-07-05 14:00\n'
              '  file  quarters.py   310 B   2026-07-04 09:00\n'
              '  link  latest.py',
        ),
      ),
      span: true,
    ),
  ],
);
