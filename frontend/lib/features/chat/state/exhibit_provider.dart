import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The user-pinned Cast exhibit (WRK-061 exhibit mode). Tapping a Cast row puts that ENTITY on the
/// sidestage from settled truth — deliberately OUTSIDE the director: a [StageActivity] is born only
/// from a tool_call open and [StageScene] demands a live node + args session, while a touchpoint
/// row may have neither (an attachment never does — it enters via the composer, not a build tool).
/// The exhibit is user-held: it stays until dismissed or replaced by another row (pinned semantics
/// — the director's automatic staging never displaces it; its live activity still shows on the
/// channel strip).
///
/// 用户钉起的 Cast 展品(WRK-061 exhibit mode)。点 Cast 行=把该**实体**以落定真相搬上侧幕——刻意在
/// 导演器**之外**:StageActivity 只能由 tool_call open 出生、StageScene 要求活节点+args session,而
/// 触点行可能两者皆无(attachment 恒无——它从 composer 进、不走建造工具)。展品由用户持有:驻留到
/// 关闭或换行(pinned 语义——导演器自动登台绝不顶掉它;其活动仍上频道条)。
class ExhibitSubject {
  const ExhibitSubject({
    required this.kind,
    required this.id,
    required this.name,
    this.lastMessageId = '',
    this.tombstoned = false,
  });

  final String kind;
  final String id;
  final String name;
  final String lastMessageId; // '' = no「跳到发生处」 无跳转锚
  final bool tombstoned;
}

class ExhibitController extends Notifier<ExhibitSubject?> {
  ExhibitController(this.conversationId);

  final String conversationId;

  @override
  ExhibitSubject? build() => null;

  void pin(ExhibitSubject subject) => state = subject;

  void dismiss() => state = null;
}

/// Per-conversation exhibit slot (autoDispose family — dies with the thread's UI).
/// 每会话展品位(autoDispose family)。
final exhibitProvider = NotifierProvider.autoDispose
    .family<ExhibitController, ExhibitSubject?, String>(ExhibitController.new);
