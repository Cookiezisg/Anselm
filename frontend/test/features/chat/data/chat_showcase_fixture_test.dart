import 'dart:convert';

import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/features/chat/data/chat_showcase_fixture.dart';
import 'package:anselm/features/chat/model/conversation_transcript.dart';
import 'package:anselm/features/chat/ui/tool_card_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

// The demo showcase fixture guard — every showcase tool card must (1) resolve to a REAL catalog entry
// (not the generic fallback) and (2) carry a tool_result whose JSON-shaped content actually PARSES (a
// raw newline in a single-quoted Dart string silently produces invalid JSON — the ec1 logs bug). This
// keeps `make demo` honest: every card shows its real body, never a degraded fallback. 展台夹具守卫。

/// A result is "JSON-shaped" if it starts with `{` (an object — the wire shape every JSON-parsing card
/// reads). Plain-text results (Bash/BashOutput/todo/Subagent) are rendered strings and may legitimately
/// start with `[` (e.g. BashOutput's `[2/4] …` progress line), so only `{` triggers the parse check.
/// JSON 形态=以 `{` 起(对象);纯文本结果可能以 `[` 起(BashOutput 进度行),故只对 `{` 校验。
bool _looksJson(String s) => s.trimLeft().startsWith('{');

void main() {
  final shows = showcaseConversations();

  test('showcase has conversations covering all 7 batches', () {
    expect(shows.length, greaterThanOrEqualTo(7));
  });

  for (final s in shows) {
    group('showcase ${s.conv.id}', () {
      final assistant = s.messages.firstWhere((m) => m.role == 'assistant');
      final turn = ConversationTranscript.hydrateTurn(assistant);
      final calls = turn.children
          .where((b) => b.kind == BlockKind.toolCall)
          .toList();

      test('has at least one tool card', () => expect(calls, isNotEmpty));

      for (final call in calls) {
        final name = call.name ?? '';
        test('$name: is cataloged (not the generic fallback)', () {
          expect(name, isNotEmpty);
          // A cataloged tool (or a mount-routed one) has a non-generic spec. The generic fallback's verb
          // is 正在调用/已调用; a real card has its own verb. Assert by identity: the resolved spec must
          // NOT be the generic instance. 已编目工具解析出非通用 spec。
          final spec = toolCardSpecFor(name);
          expect(
            identical(spec, genericToolCardSpec),
            isFalse,
            reason: '$name fell to the generic card — not cataloged',
          );
        });

        test('$name: args JSON parses', () {
          expect(
            () => jsonDecode(call.argumentsText),
            returnsNormally,
            reason: '$name argsText is invalid JSON',
          );
        });

        final result = call.children
            .where((c) => c.kind == BlockKind.toolResult)
            .map((c) => c.displayText)
            .firstOrNull;
        test('$name: result wire is valid (JSON parses or is plain text)', () {
          expect(result, isNotNull, reason: '$name has no tool_result');
          if (_looksJson(result!)) {
            // A raw newline inside a JSON string = invalid JSON = the card silently renders a fallback.
            expect(
              () => jsonDecode(result),
              returnsNormally,
              reason:
                  '$name result is JSON-shaped but does NOT parse (likely a raw newline — use \\\\n)',
            );
          }
        });
      }
    });
  }
}
