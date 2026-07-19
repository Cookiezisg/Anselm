import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/navigation.dart';

// The Scheduler ocean's URL-derived selection (WRK-069 §11) — the same one-way route→provider shim as
// entities' SelectedEntity: the rail/tables SET selection by navigating, everything else WATCHES this.
// Routes: /scheduler (overview) · /scheduler/w/:id (operations home) · /scheduler/w/:id/runs/:frId
// (run flagship) · /scheduler/runs/:frId (id-only relay — fr_ paste / panel_registry deep links land
// here; the page resolves the host workflow and go-replaces to the full path). Scheduler 海洋的 URL
// 派生选区——单向 route→provider,改选区唯一途径=导航;/scheduler/runs/:frId 是 fr_ 直达中转位。
sealed class SchedulerSelection {
  const SchedulerSelection();
}

/// The overview landing (`/scheduler`). Overview 看板态。
class SchedulerOverview extends SchedulerSelection {
  const SchedulerOverview();

  @override
  bool operator ==(Object other) => other is SchedulerOverview;

  @override
  int get hashCode => 0;
}

/// A workflow's operations home (`/scheduler/w/:id`), optionally with a run selected into the linked
/// pane (`?run=`). 运营主页态(联动区选中经 ?run=)。
class SchedulerWorkflow extends SchedulerSelection {
  const SchedulerWorkflow(this.workflowId, {this.linkedRunId});

  final String workflowId;
  final String? linkedRunId;

  @override
  bool operator ==(Object other) =>
      other is SchedulerWorkflow && other.workflowId == workflowId && other.linkedRunId == linkedRunId;

  @override
  int get hashCode => Object.hash(workflowId, linkedRunId);
}

/// The run flagship (`/scheduler/w/:id/runs/:frId`), optionally with a node selected (`?node=`,
/// `?iter=`). run 旗舰态(节点选区经 ?node=)。
class SchedulerRun extends SchedulerSelection {
  const SchedulerRun(this.workflowId, this.flowrunId, {this.nodeId, this.iteration});

  final String workflowId;
  final String flowrunId;
  final String? nodeId;
  final int? iteration;

  @override
  bool operator ==(Object other) =>
      other is SchedulerRun &&
      other.workflowId == workflowId &&
      other.flowrunId == flowrunId &&
      other.nodeId == nodeId &&
      other.iteration == iteration;

  @override
  int get hashCode => Object.hash(workflowId, flowrunId, nodeId, iteration);
}

/// The id-only run relay (`/scheduler/runs/:frId`) — the landing resolves the host workflow via
/// GET /flowruns/{id} and go-replaces to the full path (fr_ paste / notification deep links).
/// fr_ 直达中转态:解析宿主后跳全路径。
class SchedulerRunRelay extends SchedulerSelection {
  const SchedulerRunRelay(this.flowrunId);

  final String flowrunId;

  @override
  bool operator ==(Object other) => other is SchedulerRunRelay && other.flowrunId == flowrunId;

  @override
  int get hashCode => flowrunId.hashCode;
}

class SelectedScheduler extends Notifier<SchedulerSelection?> {
  @override
  SchedulerSelection? build() {
    final delegate = ref.watch(goRouterProvider).routerDelegate;
    void onRoute() => state = _parse(delegate.currentConfiguration.uri);
    delegate.addListener(onRoute);
    ref.onDispose(() => delegate.removeListener(onRoute));
    return _parse(delegate.currentConfiguration.uri);
  }

  /// The parse table, exposed for the S0 battery (the Notifier itself needs a live router).
  /// 解析表测试缝。
  @visibleForTesting
  static SchedulerSelection? parseForTest(Uri uri) => _parse(uri);

  static SchedulerSelection? _parse(Uri uri) {
    final segs = uri.pathSegments;
    if (segs.isEmpty || segs[0] != 'scheduler') return null;
    if (segs.length == 1) return const SchedulerOverview();
    if (segs.length == 2 && segs[1] == 'w') return null; // malformed — router redirects. 畸形,路由兜底。
    if (segs.length == 3 && segs[1] == 'runs') return SchedulerRunRelay(segs[2]);
    if (segs.length >= 2 && segs[1] == 'w') {
      final wfId = segs[2];
      if (segs.length == 3) {
        return SchedulerWorkflow(wfId, linkedRunId: uri.queryParameters['run']);
      }
      if (segs.length == 5 && segs[3] == 'runs') {
        final iterRaw = uri.queryParameters['iter'];
        return SchedulerRun(wfId, segs[4],
            nodeId: uri.queryParameters['node'], iteration: iterRaw != null ? int.tryParse(iterRaw) : null);
      }
    }
    return null;
  }
}

final selectedSchedulerProvider =
    NotifierProvider<SelectedScheduler, SchedulerSelection?>(SelectedScheduler.new);
