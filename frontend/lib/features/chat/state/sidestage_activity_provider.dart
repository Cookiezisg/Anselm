import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/todo.dart';
import '../../../core/perf/coalescing_notifier.dart';
import '../model/conversation_transcript.dart';
import '../model/stage_director.dart';
import 'conversation_stream_provider.dart';
import 'rundown_provider.dart';
import 'stage_director_provider.dart';
import 'touchpoint_ledger.dart';

/// Does the chat sidestage have anything to show for this conversation? — the ON-DEMAND EXISTENCE truth
/// (用户 0718-19 拍板): a chat conversation earns a right island (+ the panel-right toggle) ONLY when its
/// sidestage would render content. An empty conversation's right-island button would be a door onto a
/// tombstone, so no content → no door. This is derived from the sidestage's OWN data sources so the button
/// is NEVER lit over an empty panel (绝不「按钮亮点开却空」).
///
/// The judgement mirrors [StagePanel]'s `_AccordionList` non-empty check EXACTLY — same four sources, same
/// rules — so the toggle appears iff at least one accordion row (or the pinned todo board, or the honest
/// ledger-failure retry face) would render:
///  - the touchpoint LEDGER has an entity row (the broadest record of everything touched), OR its fetch
///    FAILED (the panel shows the error+retry face — content, not blank);
///  - a live STAGE subject is on / held (failedHold) or any live channel is running;
///  - a pinned TODO board;
///  - a SETTLED subagent run (WRK-064 B6 — a `Subagent` tool_call has no touchpoint, so the transcript is
///    its only truth).
///
/// A bare human GATE is deliberately EXCLUDED: `ask_user` (the only gate with no staged tool / touched
/// entity) renders INLINE in the transcript, never in the sidestage, so counting it would light the button
/// over an empty panel. Dangerous-tool gates stage a subject; `decide_approval` touches an approval — both
/// already covered above.
///
/// This provider keeps the ledger / director / rundown warm while a chat conversation is selected (island
/// open OR closed), which is exactly what lets the button appear reactively the moment activity lands.
///
/// chat 侧幕对本对话有内容可展否?——**按需存在**真相:有 activity 才有右岛(+ toggle)。空对话的右岛钮=通向
/// 墓碑的门,故无内容→无门。判定源=侧幕自己的四条数据源、逐条镜像 `_AccordionList` 的非空判断,故按钮**绝不亮
/// 在空面板上**:触点台账有实体行(或首拉失败→错误+重试面,亦是内容)· 活舞台主角/频道 · 待办板 · 落定子代理
/// (无触点,transcript 是唯一真相)。裸人闸(仅 ask_user 无舞台无实体,内联渲于对话流)刻意排除——计它会让
/// 按钮亮在空面板上;危险工具闸有舞台主角、decide_approval 碰 approval 实体,皆已被上面覆盖。选中对话时本
/// provider 保活台账/导演器/场记,正是这让 activity 一到按钮就能反应式亮相。
bool sidestageHasContent({
  required TouchpointLedgerState ledger,
  required StageState stage,
  required Map<String, ConversationTodos> rundown,
  required ConversationTranscript transcript,
}) {
  if (ledger.entities.isNotEmpty || ledger.failed) return true;
  if (stage.stageOpen || stage.channels.isNotEmpty) return true;
  if (rundown.values.any((b) => b.todos.isNotEmpty)) return true;
  for (final n in transcript.subagentBlocks) {
    // A LIVE subagent is the director's job (covered by stage.channels above); a SETTLED one is a
    // transcript-only row. 活的归导演器;落定的是 transcript-only 行。
    if (!n.isOpen) return true;
  }
  return false;
}

/// One conversation's sidestage-activity flag. Watches the same low-frequency providers the sidestage
/// itself does (their value-equality suppresses per-delta churn), plus the transcript coalescer for the
/// settled-subagent case (re-derived only when a subagent open→closed flip changes the boolean, never per
/// streaming delta). 会话侧幕活动旗:观侧幕同款低频 provider + transcript coalescer(仅布尔翻转才广播)。
class SidestageActivityController extends Notifier<bool> {
  SidestageActivityController(this.conversationId);

  final String conversationId;

  CoalescingNotifier<ConversationTranscript>? _tx;
  int _lastSubEpoch = -1;

  @override
  bool build() {
    final ledger = ref.watch(touchpointLedgerProvider(conversationId));
    final stage = ref.watch(stageDirectorProvider(conversationId));
    final rundown = ref.watch(rundownProvider(conversationId));
    // Watch the NOTIFIER (identity), not its state — the coalescer fires per delta, so a state-watch
    // would rebuild this provider on every frame. The transcript listener below drives the rare
    // subagent-flip re-derive. 观 notifier 身份(非 state):逐帧 delta 由下方 listener 处理,布尔翻转才更新。
    final tx = ref
        .watch(conversationStreamProvider(conversationId).notifier)
        .transcript;
    _tx = tx;
    tx.addListener(_onTranscript);
    // removeListener is dispose-safe on ChangeNotifier (no-op after dispose), so a rebuilt stream
    // controller's retired coalescer is handled cleanly. 释放安全(ChangeNotifier removeListener 幂等)。
    ref.onDispose(() => tx.removeListener(_onTranscript));
    return sidestageHasContent(
      ledger: ledger,
      stage: stage,
      rundown: rundown,
      transcript: tx.value,
    );
  }

  void _onTranscript() {
    final tx = _tx;
    if (tx == null || !ref.mounted) return;
    // The transcript's only contribution to the flag is its subagent set — gate on the epoch the
    // transcript maintains at its write sites (S7): a streaming delta exits here in ONE int compare
    // (the old path re-derived — and re-walked the tree — every coalesced frame; the ledger / stage /
    // rundown inputs re-derive through build()'s watches instead). transcript 对旗的唯一贡献是
    // subagent 集——按写入点维护的 epoch 早退(S7):流式 delta 一次 int 比对即离场(旧径每合并帧重
    // 推导+全树重走;ledger/stage/rundown 走 build 的 watch 路径)。
    final epoch = tx.value.subagentEpoch;
    if (epoch == _lastSubEpoch) return;
    _lastSubEpoch = epoch;
    final next = sidestageHasContent(
      ledger: ref.read(touchpointLedgerProvider(conversationId)),
      stage: ref.read(stageDirectorProvider(conversationId)),
      rundown: ref.read(rundownProvider(conversationId)),
      transcript: tx.value,
    );
    if (next != state) state = next;
  }
}

/// The sidestage-activity flag for a conversation (drives whether the chat right island + its toggle exist).
/// autoDispose family — leaving the thread frees it and the sources it kept warm. 会话侧幕活动旗。
final sidestageActivityProvider = NotifierProvider.autoDispose
    .family<SidestageActivityController, bool, String>(
      SidestageActivityController.new,
    );
