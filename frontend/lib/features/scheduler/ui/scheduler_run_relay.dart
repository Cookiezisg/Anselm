import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../state/scheduler_run_provider.dart';

/// The `fr_` RELAY (`/scheduler/runs/:frId`, WRK-069 §11) — the id-only landing every flowrun
/// reference in the app funnels through: a pasted id in the rail's filter, a notification deep link,
/// a chat dossier's flowrun pill, `panel_registry`'s `flowrun` entry. None of those know the HOST
/// workflow, and the flagship's route needs it — so this page resolves the run, then go-REPLACEs
/// itself with the full path (replace, not push: the relay is a redirect, and Back must not bounce
/// the user through it).
///
/// It is deliberately a real page and not a router `redirect`: resolving the host means an async GET,
/// which a synchronous redirect cannot await, and the failure mode needs a FACE — «no run with this
/// id» is a sentence a user must be able to read, not a blank screen (§10 中转位解不出=诚实错态,
/// 不是空白).
///
/// fr_ 直达中转位:全域 flowrun 引用(粘贴 id / 通知深链 / chat 卷宗药丸 / panel_registry)都汇到这里;
/// 它们都不知道宿主 workflow,而旗舰路由需要它——故本页解出宿主后 go-replace 成全路径(replace 非 push:
/// 中转是重定向,返回键不该把人弹回来)。刻意做成真页而非路由 redirect:解宿主要 async GET(同步 redirect
/// 等不了),且失败必须有脸——「没有这个 id 的运行」是一句人要读到的话,不是一片空白。
class SchedulerRunRelayView extends ConsumerWidget {
  const SchedulerRunRelayView({required this.flowrunId, super.key});

  final String flowrunId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.scheduler.run;
    final async = ref.watch(schedulerRunProvider(flowrunId));

    final wfId = async.value?.run.workflowId;
    if (wfId != null && wfId.isNotEmpty) {
      // Resolved → hand over to the flagship. Post-frame (navigating during build is illegal) and
      // REPLACE (the relay leaves no history entry of its own). 解出即交棒:后帧 + replace(中转不留史)。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pushReplacement('/scheduler/w/$wfId/runs/$flowrunId');
      });
    }

    if (async.hasError) {
      // A dead id (mistyped, from another workspace, cleared by the retention policy) gets a
      // sentence — never a blank. 死 id(打错/别的工作区/已被保留策略清)给一句话,绝不空白。
      return Center(
        child: AnState(
          kind: AnStateKind.empty,
          title: t.relayFailedTitle,
          hint: t.relayFailedHint,
        ),
      );
    }

    return Center(
      child: AnState(
        kind: AnStateKind.loading,
        title: t.relayResolving,
        hint: truncate(flowrunId, AnTrunc.id),
      ),
    );
  }
}
