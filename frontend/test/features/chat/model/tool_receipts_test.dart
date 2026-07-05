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
  group('bashReceipt', () {
    test('exit 0 → none tone; non-zero → danger tone', () {
      final ok = bashReceipt('out\n\n[exit code: 0]', exitLabel: exitLabel, timedOutLabel: '超时');
      expect(ok, (text: 'exit 0', tone: ToolReceiptTone.none));
      final bad = bashReceipt('boom\n[exit code: 1]', exitLabel: exitLabel, timedOutLabel: '超时');
      expect(bad, (text: 'exit 1', tone: ToolReceiptTone.danger));
      final neg = bashReceipt('x\n[exit code: -1]', exitLabel: exitLabel, timedOutLabel: '超时');
      expect(neg!.tone, ToolReceiptTone.danger);
    });

    test('timeout note wins over the exit code', () {
      final r = bashReceipt('\n[command timed out after 120s]\n[exit code: -1]',
          exitLabel: exitLabel, timedOutLabel: '超时');
      expect(r, (text: '超时', tone: ToolReceiptTone.danger));
    });

    test('no footer (background-start prose) → null, never guessed', () {
      expect(
          bashReceipt('Started background command (bash_id=bsh_1): npm run dev',
              exitLabel: exitLabel, timedOutLabel: '超时'),
          isNull);
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
