import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/contract/entities/common.dart';
import '../../../../core/contract/entities/workflow.dart';
import '../../../../core/model/status_state.dart';
import '../run/recent_runs_provider.dart';

part 'log_list_state.freezed.dart';

/// A kind-erased log row (function execution / handler call / agent execution / workflow flowrun): a
/// status dot + label/meta/hint for the collapsed row + pre-formatted key/value [detailRows] for the
/// expanded body. Pure (no widgets) — the tab resolves the kind icon + renders. 日志行(kind 无关)。
class LogRow {
  const LogRow({
    required this.id,
    required this.dot,
    required this.label,
    this.meta,
    this.hint,
    this.detailRows = const [],
    this.run,
  });

  final String id;
  final AnStatus dot;
  /// The reproduce projection (重现钥匙, 0719 拍板): the raw input/method/source of this execution,
  /// null for rows that can't reproduce (wf flowruns project no payload → source-only). 重现投影。
  final RecentRun? run;
  final String label;
  final String? meta;
  final String? hint;
  final List<(String, String)> detailRows;
}

/// The logs tab state: the loaded log page + ok/failed aggregate (zeros for workflow flowruns, which
/// carry no tally) + keyset paging + which rows are expanded + a lazy cache of fetched flowrun
/// composites (workflow only — the node list is fetched on first expand). 日志 tab 态。
@freezed
abstract class LogListState with _$LogListState {
  const factory LogListState({
    @Default(<LogRow>[]) List<LogRow> rows,
    @Default(ExecutionAggregates()) ExecutionAggregates aggregates,
    @Default(false) bool hasAggregate,
    String? nextCursor,
    @Default(false) bool hasMore,
    @Default(false) bool loadingMore,
    @Default(<String>{}) Set<String> openIds,
    @Default(<String, FlowrunComposite>{}) Map<String, FlowrunComposite> flowruns,
  }) = _LogListState;
}
