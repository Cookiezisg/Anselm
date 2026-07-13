import 'package:anselm/features/chat/data/chat_showcase_fixture.dart';
import 'package:anselm/features/chat/model/conversation_transcript.dart';
import 'package:anselm/features/chat/model/stage_director.dart';
import 'package:anselm/features/chat/ui/stages/scene_from_truth.dart';
import 'package:anselm/features/chat/ui/tool_card_memory_web.dart';
import 'package:flutter_test/flutter_test.dart';

// D-014/016/018/019/020/022 — the failure & terminal showcase must carry, in ONE demo conversation,
// every card-level failure (edit_workflow morph, a RED WebFetch soft-fail, a hard tool_result error) and
// each honest turn-end banner (max_steps amber, LLM_RESOLVE_ERROR CTA, generic red error). 一处集齐六终态。
void main() {
  final term = showcaseConversations().firstWhere((c) => c.conv.id == 'cv_show_term');
  final bots = term.messages.where((m) => m.role == 'assistant').toList();

  test('D-019/018/022 turn-end banners: max_steps / LLM_RESOLVE_ERROR / generic error', () {
    expect(bots.any((m) => m.stopReason == 'max_steps'), isTrue, reason: '琥珀 max_steps');
    expect(bots.any((m) => m.errorCode == 'LLM_RESOLVE_ERROR'), isTrue, reason: '重选模型 CTA');
    expect(
      bots.any((m) => m.stopReason == 'error' && m.errorCode.isNotEmpty && m.errorCode != 'LLM_RESOLVE_ERROR'),
      isTrue,
      reason: '通用红 error 横幅',
    );
    // Every non-clean terminal carries an honest detail line. 非干净终态皆带诚实细节。
    for (final m in bots.where((m) => m.stopReason == 'error')) {
      expect(m.errorMessage, isNotEmpty);
    }
  });

  test('D-016 WebFetch soft-fail: status=completed but the sentence classifies RED', () {
    final blocks = bots.expand((m) => m.blocks).toList();
    final wf = blocks.firstWhere((b) => b.type == 'tool_result' && b.parentBlockId == 'tm_wf');
    expect(wf.status, 'completed', reason: '绿 status(软失败非硬错)');
    expect(webFetchOutcome(wf.content), WebFetchOutcome.fail, reason: '句子分类成红');
  });

  test('D-020 hard tool_result error: error:true → status=error / ownsError', () {
    final blocks = bots.expand((m) => m.blocks).toList();
    final hard = blocks.firstWhere((b) => b.type == 'tool_result' && b.parentBlockId == 'tm_hard');
    expect(hard.status, 'error');
    expect(hard.error, isNotEmpty, reason: '硬错误文本');
  });

  test('D-014 edit_workflow morph: an ops-delta tool_call is present', () {
    final calls = bots.expand((m) => m.blocks).where((b) => b.type == 'tool_call');
    final ew = calls.firstWhere((b) => b.attrs?['tool'] == 'edit_workflow');
    expect(ew.content, contains('"op":"add_node"'));
    expect(ew.content, contains('"op":"delete_node"'));
  });

  test('D-015 failedHold: a failed subagent (cv_show_nested) opens its sidestage to failedHold', () {
    final nested = showcaseConversations().firstWhere((c) => c.conv.id == 'cv_show_nested');
    final t = ConversationTranscript('cv_show_nested')..setHistory(nested.messages.reversed.toList());
    final failed = t.subagentBlocks.firstWhere((n) => n.id == 'sb0');
    expect(failed.isError, isTrue, reason: 'tool_call status=error');
    final scene = sceneFromSubagentNode(failed, 'cv_show_nested');
    expect(scene.phase, StagePhase.failedHold, reason: '失败舞台');
    expect(scene.subject.failed, isTrue, reason: '红丝带');
  });
}
