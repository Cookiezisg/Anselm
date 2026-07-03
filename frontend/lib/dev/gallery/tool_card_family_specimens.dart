import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
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
    node.children.add(BlockNode(id: 'pr_$id', kind: BlockKind.progress)
      ..status = progressLive ? 'open' : 'completed'
      ..content = {'text': progress});
  }
  if (result != null || resultError != null) {
    node.children.add(BlockNode(id: 'tr_$id', kind: BlockKind.toolResult)
      ..status = resultError != null ? 'error' : 'completed'
      ..error = resultError
      ..content = {'content': result ?? resultError ?? ''});
  }
  return node;
}

// ── F3 shell fixtures 终端夹具 ──

const String _testRunTail = ' ✓ src/rollup.test.ts (8 tests) 214ms\n'
    ' ✓ src/quarters.test.ts (5 tests) 88ms\n'
    ' ✓ src/currency.test.ts (3 tests) 41ms\n'
    'Test Files  3 passed (3)\n'
    '     Tests  16 passed (16)';

const String _bashOkOutput = '$_testRunTail\n  Duration  1.92s\n\n[exit code: 0]';

const String _bashFailOutput = ' ✓ src/rollup.test.ts (8 tests) 214ms\n'
    ' ✗ src/quarters.test.ts (5 tests | 1 failed) 96ms\n'
    '   → expected Q4 total 143000, got 141200\n'
    'Test Files  1 failed | 1 passed (2)\n'
    '     Tests  1 failed | 15 passed (16)\n\n[exit code: 1]';

final toolCardShellGalleryItem = GalleryItem(
  'ChatToolCard · shell 族',
  'F3:执行中=收起行下的**活终端窗**(progress 尾 3 行,机器窗身份非低语 rail);完成=exit 回执'
      '(footer 解析);失败=exit 红+自动展开完整终端窗(\$ 命令回显头);意图(summary)常显——全族红。',
  [
    GallerySpecimen('执行中 · 活终端尾巴(收起行下的小机器窗)',
        (c) => ChatToolCard(
            node: _call('bash-live', 'Bash',
                args: '{"command":"npm test","summary":"Run the test suite","danger":"cautious"}',
                summary: 'Run the test suite', danger: 'cautious',
                progress: _testRunTail, progressLive: true)),
        span: true),
    GallerySpecimen('完成 · exit 0 回执(尾巴已溶进展开体)',
        (c) => ChatToolCard(
            node: _call('bash-ok', 'Bash',
                args: '{"command":"npm test"}',
                summary: 'Run the test suite', danger: 'cautious',
                progress: _bashOkOutput, result: _bashOkOutput)),
        span: true),
    GallerySpecimen('失败 · exit 1(自动展开终端窗,命令回显头)',
        (c) => ChatToolCard(
            node: _call('bash-fail', 'Bash',
                args: '{"command":"npm test"}',
                summary: 'Run the test suite', danger: 'cautious',
                progress: _bashFailOutput,
                result: _bashFailOutput)),
        span: true),
    GallerySpecimen('超时(note 解析成回执)',
        (c) => ChatToolCard(
            node: _call('bash-timeout', 'Bash',
                args: '{"command":"sleep 999"}',
                result: '\n[command timed out after 120s]\n[exit code: -1]')),
        span: true, stress: true),
  ],
);

// ── F1 fs-ops fixtures 文件操作夹具 ──

const String _readOutput = '    1\timport json\n'
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
    GallerySpecimen('Read · 回执即卡(9 行,无 chevron)',
        (c) => ChatToolCard(
            node: _call('read', 'Read',
                args: '{"file_path":"/ws/functions/rollup.py"}', result: _readOutput)),
        span: true),
    GallerySpecimen('Read · 截断回执(前 2000 行)',
        (c) => ChatToolCard(
            node: _call('read-trunc', 'Read',
                args: '{"file_path":"/ws/logs/huge.log"}',
                result:
                    '    1\tfirst line\n... [truncated at line 2000; use offset+limit to read more]\n')),
        span: true, stress: true),
    GallerySpecimen('Write · 代码窗(展开态)',
        (c) => ChatToolCard(
            node: _call('write', 'Write',
                args:
                    '{"file_path":"/ws/functions/quarters.py","content":"def quarter_of(date):\\n    return (date.month - 1) // 3 + 1\\n"}',
                result: 'Wrote /ws/functions/quarters.py')),
        span: true),
    GallerySpecimen('Edit · diff 窗(old→new,展开态)',
        (c) => ChatToolCard(
            node: _call('edit', 'Edit',
                args: '{"file_path":"/ws/functions/rollup.py",'
                    '"old_string":"        by_quarter.setdefault(q, 0)\\n        by_quarter[q] += it.amount",'
                    '"new_string":"        by_quarter.setdefault(q, 0)\\n        # refunds count against the quarter 退款冲减当季\\n        by_quarter[q] += it.amount"}',
                result: 'Edited /ws/functions/rollup.py')),
        span: true),
  ],
);

// ── F2 fs-search fixtures 检索夹具 ──

const String _grepOutput = 'functions/rollup.py:8:        by_quarter[q] += it.amount\n'
    'functions/rollup.py:14:    total = sum(amounts)\n'
    'functions/quarters.py:2:    return (date.month - 1) // 3 + 1\n'
    'handlers/invoice_sync.py:31:        self.amounts.append(row.amount)\n';

final toolCardSearchGalleryItem = GalleryItem(
  'ChatToolCard · fs-search 族',
  'F2:回执=计数(过去时的凭据,含截断下界 N+);展开=命中窗(行式等宽);"No matches"=诚实空回执、'
      '无展开体。目标=引号包 pattern / LS 用 basename。',
  [
    GallerySpecimen('Grep · 4 处匹配(展开命中窗)',
        (c) => ChatToolCard(
            node: _call('grep', 'Grep',
                args: '{"pattern":"amount","path":"/ws"}', result: _grepOutput)),
        span: true),
    GallerySpecimen('Glob · 3 个文件',
        (c) => ChatToolCard(
            node: _call('glob', 'Glob',
                args: '{"pattern":"**/*.py"}',
                result:
                    'functions/rollup.py\nfunctions/quarters.py\nhandlers/invoice_sync.py\n')),
        span: true),
    GallerySpecimen('Grep · 无匹配(诚实空回执)',
        (c) => ChatToolCard(
            node: _call('grep-none', 'Grep',
                args: '{"pattern":"xyzzy"}',
                result: 'No matches for "xyzzy" in /ws.')),
        span: true),
    GallerySpecimen('LS · 截断下界 N+',
        (c) => ChatToolCard(
            node: _call('ls', 'LS',
                args: '{"path":"/ws/functions"}',
                result: 'rollup.py  1.2 KB\nquarters.py  310 B\n... [truncated at 200 lines; raise head_limit to see more]\n')),
        span: true, stress: true),
  ],
);
