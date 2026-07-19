import 'package:anselm/features/chat/model/tool_card_state.dart';
import 'package:anselm/features/chat/ui/tool_card_catalog.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter_test/flutter_test.dart';

// F07 dual-channel verb (WRK-056 §F07.2) — search when query present, list when empty; the channel
// is decided ONLY after args complete (argsStreaming locks the default search channel, never flips).
// F07 双声道:有 query=搜、空=列;仅 args 完整后判,流中锁默认搜索。

ToolCardState _state({required ToolCardPhase phase, required String args}) => ToolCardState(
      phase: phase,
      toolName: 'search_function',
      summary: '',
      danger: '',
      argsText: args,
      resultText: '',
      errorText: '',
      progressText: '',
      progressLive: false,
    );

String _verb(ToolCardState s, {required bool live}) {
  final spec = toolCardSpecFor(s.toolName);
  return spec.verbOf?.call(t, s, live: live) ?? spec.verb(t, live: live);
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  test('query present → SEARCH channel (running + settled)', () {
    final running = _state(phase: ToolCardPhase.running, args: '{"query":"http retry"}');
    expect(_verb(running, live: true), t.chat.tool.searchingKind(kind: t.chat.tool.kind.function));
    final done = _state(phase: ToolCardPhase.succeeded, args: '{"query":"http retry"}');
    expect(_verb(done, live: false), t.chat.tool.searchedKind(kind: t.chat.tool.kind.function));
  });

  test('empty / absent query (args complete) → LIST channel', () {
    final emptyQ = _state(phase: ToolCardPhase.succeeded, args: '{"query":""}');
    expect(_verb(emptyQ, live: false), t.chat.tool.listedKind(kind: t.chat.tool.kind.function));
    final noQ = _state(phase: ToolCardPhase.succeeded, args: '{}');
    expect(_verb(noQ, live: false), t.chat.tool.listedKind(kind: t.chat.tool.kind.function));
  });

  test('argsStreaming locks the default SEARCH channel (query not-yet-arrived ≠ won\'t-come)', () {
    // Mid-stream with no query yet — must NOT flip to the list channel. 流中尚无 query,绝不翻列声道。
    final streaming = _state(phase: ToolCardPhase.argsStreaming, args: '{"que');
    expect(_verb(streaming, live: true), t.chat.tool.searchingKind(kind: t.chat.tool.kind.function));
  });

  test('list_documents is listOnly — always the list channel (no verbOf)', () {
    final spec = toolCardSpecFor('list_documents');
    expect(spec.verbOf, isNull);
    expect(spec.verb(t, live: true), t.chat.tool.listingKind(kind: t.chat.tool.kind.document));
    expect(spec.target, isNull); // no query chip
  });

  test('query becomes the target chip; empty query → no chip', () {
    final spec = toolCardSpecFor('search_function');
    expect(spec.target!(_state(phase: ToolCardPhase.succeeded, args: '{"query":"http retry"}')), '"http retry"');
    expect(spec.target!(_state(phase: ToolCardPhase.succeeded, args: '{"query":""}')), isNull);
  });
}
