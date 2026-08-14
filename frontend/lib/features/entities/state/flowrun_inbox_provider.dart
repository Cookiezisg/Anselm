import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/workflow.dart'; // FlowrunNode
import '../data/entity_providers.dart';

/// The cross-run approval inbox — every parked approval node in the workspace (`GET /flowrun-inbox`).
/// autoDispose so it's fetched when the bell tray opens and torn down when it closes; invalidate after a
/// decision to reflect the shrunken list. 审批收件箱:跨 run 所有 parked approval 节点;决断后 invalidate。
final flowrunInboxProvider = FutureProvider.autoDispose<List<FlowrunNode>>((
  ref,
) {
  final repo = ref.watch(entityRepositoryProvider);
  // The tray can remain mounted while another run parks or another client decides. Keep the
  // REST projection authoritative, but invalidate it from both durable realtime sources.
  // 托盘可能一直挂着,期间别的 run 停车或别的客户端决策。保持 REST 为真相,由两条耐久来源唤醒重取。
  final signalSub = repo.flowrunInboxSignals().listen((_) {
    ref.invalidateSelf();
  });
  final resyncSub = repo.flowrunInboxResync().listen((_) {
    ref.invalidateSelf();
  });
  ref.onDispose(() {
    unawaited(signalSub.cancel());
    unawaited(resyncSub.cancel());
  });
  return repo.listFlowrunInbox();
});
