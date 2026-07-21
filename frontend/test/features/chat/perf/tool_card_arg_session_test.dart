import 'package:anselm/features/chat/model/tool_card_state.dart';
import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:flutter_test/flutter_test.dart';

// C-018 — argStringPartial re-scanned argsText O(bytes) every build (41 sites). ToolCardState.arg reads
// the value through the INCREMENTAL argsSession (already parsed) and decodes JSON escapes correctly (the
// old char-scan mis-decoded \r \f \b \u to their literal letters). Pins equivalence + the escape fix.
// 走增量 session 不重扫 + 正确转义。
ToolCardState _state(String argsText) => ToolCardState(
  phase: ToolCardPhase.succeeded,
  toolName: 't',
  summary: '',
  danger: 'safe',
  argsText: argsText,
  resultText: '',
  errorText: '',
  progressText: '',
  progressLive: false,
);

void main() {
  test(
    'C-018 arg reads a top-level string value (matches argStringPartial)',
    () {
      final s = _state('{"file_path":"/a/b.py","command":"go test ./..."}');
      expect(s.arg('file_path'), '/a/b.py');
      expect(s.arg('command'), 'go test ./...');
      expect(
        argStringPartial(s.argsText, 'file_path'),
        '/a/b.py',
      ); // the old helper agrees 旧 helper 一致
    },
  );

  test('C-018 an absent key is null', () {
    expect(_state('{"a":"1"}').arg('missing'), isNull);
  });

  test('C-018 \\n / \\t decode the same as the old scan (common case)', () {
    // Raw string → the JSON literally contains the backslash escapes. 原始串:JSON 含反斜杠转义。
    final s = _state(r'{"msg":"line1\nline2\ttab"}');
    expect(s.arg('msg'), 'line1\nline2\ttab');
    expect(
      argStringPartial(s.argsText, 'msg'),
      'line1\nline2\ttab',
      reason: r'\n \t 两者一致',
    );
  });

  test(
    'C-018 \\r decodes CORRECTLY via the session (the fix over the old char-scan)',
    () {
      final s = _state(r'{"x":"a\rb"}'); // JSON: a<CR>b
      expect(s.arg('x'), 'a\rb', reason: r'session 正确解 \r→CR');
      // The OLD char-scan wrote the literal letter 'r' (a latent bug the migration fixes). 旧扫写字面 r=bug。
      expect(argStringPartial(s.argsText, 'x'), 'arb');
      expect(
        s.arg('x'),
        isNot(argStringPartial(s.argsText, 'x')),
        reason: '迁移=同或更好',
      );
    },
  );

  test(
    'C-018 arg reads a NESTED key at any depth (depth-agnostic, like argStringPartial)',
    () {
      // create_/edit_ tools carry `name` inside ops[i], not top-level — the depth-agnostic match matters.
      // create/edit 工具的 name 嵌在 ops 内、非顶层——深度无关匹配是关键。
      final s = _state('{"ops":[{"op":"set_meta","name":"rollup"}]}');
      expect(s.arg('name'), 'rollup');
    },
  );

  test('C-018 an empty value is null', () {
    expect(_state('{"reason":""}').arg('reason'), isNull);
  });
}
