import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:flutter_test/flutter_test.dart';

// Receipt parsers are pinned to the backend's EXACT output formats — these tests are the
// wire-format contract. A parser must under-report (null) on anything unrecognized, never guess.
// 回执解析器钉后端**精确**输出格式——本文件即线缆格式契约。不认识就少报(null),绝不猜。

String exitLabel(int c) => 'exit $c';
String lines(int n) => '$n 行';
String truncated(int n) => '前 $n 行(截断)';
String count(String n) => '$n 个';

void main() {
  ToolReceipt? bashR(String out) => bashReceipt(out,
      exitLabel: exitLabel,
      timedOutLabel: '超时',
      blockedLabel: '已拦截',
      cancelledLabel: '已取消',
      exitUnknownLabel: 'exit 未知',
      backgroundLabel: (id) => '$id · 后台');

  group('bashReceipt', () {
    test('exit 0 → none tone; non-zero → danger tone', () {
      expect(bashR('out\n\n[exit code: 0]'), (text: 'exit 0', tone: ToolReceiptTone.none));
      expect(bashR('boom\n[exit code: 1]'), (text: 'exit 1', tone: ToolReceiptTone.danger));
      expect(bashR('x\n[exit code: -1]')!.tone, ToolReceiptTone.danger);
    });

    test('note priority: blocked > timeout > cancelled (all close exit -1, note must win)', () {
      expect(bashR('\n[command timed out after 2m0s]\n[exit code: -1]'), (text: '超时', tone: ToolReceiptTone.danger));
      expect(bashR('\n[blocked: rm -rf / (refused; rephrase if intentional)]\n[exit code: -1]'),
          (text: '已拦截', tone: ToolReceiptTone.danger));
      // cancelled is MUTED (none) — never auto-expands. 取消=muted。
      expect(bashR('partial\n\n[cancelled]\n[exit code: -1]'), (text: '已取消', tone: ToolReceiptTone.none));
    });

    test('background spawn → «bsh_… · 后台» (muted), NOT null', () {
      expect(bashR('Started background command (bash_id=bsh_1a2b3c): npm run dev\nUse BashOutput…'),
          (text: 'bsh_1a2b3c · 后台', tone: ToolReceiptTone.none));
    });

    test('double-cap: the general tool-result cap ate the footer → exit unknown (warn)', () {
      expect(bashR('huge output …[tool result truncated: 4096 bytes]')!.text, 'exit 未知');
    });

    test('no footer at all → null (never guessed)', () {
      expect(bashR('just some prose'), isNull);
    });
  });

  group('statusReceipt (BashOutput)', () {
    ToolReceipt? st(String out) => statusReceipt(out,
        running: '运行中', exited: (c) => '退出 $c', killed: '已终止', errored: '出错', notFound: '会话不存在');
    test('four states + not-found; exited/errored danger, running/killed neutral', () {
      expect(st('log\n\n[status: running]'), (text: '运行中', tone: ToolReceiptTone.none));
      expect(st('done\n\n[status: exited (code 0)]'), (text: '退出 0', tone: ToolReceiptTone.danger));
      expect(st('\n\n[status: killed]'), (text: '已终止', tone: ToolReceiptTone.none));
      expect(st('\n\n[status: errored]'), (text: '出错', tone: ToolReceiptTone.danger));
      expect(st('Background shell process not found: bsh_9'), (text: '会话不存在', tone: ToolReceiptTone.danger));
      expect(st('no status footer'), isNull);
    });
  });

  group('killShellReceipt', () {
    ToolReceipt? kl(String out) => killShellReceipt(out, finished: '已自行结束', notFound: '会话不存在');
    test('killed → null (verb self-sufficient); finished → muted; not-found → warn', () {
      expect(kl('Killed background shell bsh_1.'), isNull);
      expect(kl('Background shell bsh_1 already finished; removed from registry.'),
          (text: '已自行结束', tone: ToolReceiptTone.none));
      expect(kl('Background shell process not found: bsh_1'), (text: '会话不存在', tone: ToolReceiptTone.warn));
    });
  });

  group('readReceipt', () {
    test('cat -n lines counted', () {
      final r = readReceipt('    1\ta\n    2\tb\n    3\tc\n',
          linesLabel: lines, truncatedLabel: truncated);
      expect(r, (text: '3 行', tone: ToolReceiptTone.none));
    });

    test('truncation footer wins with the emitted line count', () {
      final r = readReceipt(
          '    1\ta\n... [truncated at line 2000; use offset+limit to read more]\n',
          linesLabel: lines, truncatedLabel: truncated);
      expect(r, (text: '前 2000 行(截断)', tone: ToolReceiptTone.none));
    });

    test('non-file prose (directory hint / access error) → null', () {
      expect(
          readReceipt('Path is a directory, not a file: /ws. Use Glob…',
              linesLabel: lines, truncatedLabel: truncated),
          isNull);
    });
  });

  group('countReceipt', () {
    test('counts non-empty lines', () {
      final r = countReceipt('a.py\nb.py\nc.py\n', countLabel: count, noneLabel: '无匹配');
      expect(r, (text: '3 个', tone: ToolReceiptTone.none));
    });

    test('truncation marker → floor count N+', () {
      final r = countReceipt('a\nb\n... [truncated at 200 lines; raise head_limit to see more]\n',
          countLabel: count, noneLabel: '无匹配');
      expect(r, (text: '2+ 个', tone: ToolReceiptTone.none));
    });

    test('honest empties and errors', () {
      expect(countReceipt('No matches for "x" in /ws.', countLabel: count, noneLabel: '无匹配'),
          (text: '无匹配', tone: ToolReceiptTone.none));
      expect(countReceipt('Cannot access /nope: permission denied', countLabel: count, noneLabel: '无匹配'),
          isNull);
      expect(countReceipt('   ', countLabel: count, noneLabel: '无匹配'), isNull);
    });
  });

  group('argString — streaming-tolerant extraction', () {
    test('complete args', () {
      expect(argString('{"file_path":"/a/b.py","x":1}', 'file_path'), '/a/b.py');
    });

    test('PARTIAL fragment mid-stream still yields a closed earlier field', () {
      expect(argString('{"command":"npm test","summary":"Run the te', 'command'), 'npm test');
      expect(argString('{"command":"npm te', 'command'), isNull); // value not closed yet 未闭合
    });

    test('escapes unescaped', () {
      expect(argString(r'{"command":"echo \"hi\"\nls"}', 'command'), 'echo "hi"\nls');
    });
  });

  test('pathBasename + commandChip', () {
    expect(pathBasename('/a/b/c.py'), 'c.py');
    expect(pathBasename('solo.md'), 'solo.md');
    expect(pathBasename('/a/b/'), 'b');
    expect(commandChip('npm   test\n&& echo done'), 'npm test');
  });
}
