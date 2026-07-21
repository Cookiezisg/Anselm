import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/workflow.dart'; // FlowrunNode
import '../data/entity_providers.dart';

/// The cross-run approval inbox — every parked approval node in the workspace (`GET /flowrun-inbox`).
/// autoDispose so it's fetched when the bell tray opens and torn down when it closes; invalidate after a
/// decision to reflect the shrunken list. 审批收件箱:跨 run 所有 parked approval 节点;决断后 invalidate。
final flowrunInboxProvider = FutureProvider.autoDispose<List<FlowrunNode>>(
  (ref) => ref.watch(entityRepositoryProvider).listFlowrunInbox(),
);
