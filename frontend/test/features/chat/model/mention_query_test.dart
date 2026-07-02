import 'package:anselm/features/chat/model/mention_query.dart';
import 'package:flutter_test/flutter_test.dart';

// The @-token trigger rules (the industry vocabulary): line-start / after-whitespace only, query runs
// to the caret, whitespace exits, a word-internal @ (email) never triggers.
// @ 触发规则:行首/空白后才触发;query 到光标;空白退出;词中 @(邮箱)不触发。

void main() {
  test('@ at line start opens with an empty query', () {
    expect(activeMentionQuery('@', 1), (start: 0, query: ''));
  });

  test('@ after whitespace, query runs to the caret', () {
    expect(activeMentionQuery('查一下 @syn', 8), (start: 4, query: 'syn'));
  });

  test('a word-internal @ (email) never triggers', () {
    expect(activeMentionQuery('mail me a@b.com', 10), isNull);
  });

  test('whitespace after @ exits the token', () {
    expect(activeMentionQuery('@name 后面', 8), isNull);
  });

  test('a newline breaks the token; @ right after a newline is line-start', () {
    expect(activeMentionQuery('第一行\n@ag', 7), (start: 4, query: 'ag'));
    expect(activeMentionQuery('@ab\ncd', 6), isNull);
  });

  test('caret before/at the @ is not inside a token', () {
    expect(activeMentionQuery('@abc', 0), isNull);
    expect(activeMentionQuery('x @abc', 2), isNull);
  });

  test('out-of-range cursors are null, never a throw', () {
    expect(activeMentionQuery('', 0), isNull);
    expect(activeMentionQuery('ab', 9), isNull);
  });
}
