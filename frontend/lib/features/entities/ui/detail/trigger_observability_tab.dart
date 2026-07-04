import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/trigger.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_deferred_loading.dart';
import '../../../../core/ui/an_dropdown.dart';
import '../../../../core/ui/an_row.dart';
import '../../../../core/ui/an_row_detail.dart';
import '../../../../core/ui/an_skeleton.dart';
import '../../../../core/ui/an_state.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/detail/log_list_state.dart';
import '../../state/detail/observability_list_provider.dart';
import 'detail_sections.dart';

/// The trigger's two observability tabs — 活动 (activations, 触发面: did it fire, incl. non-fired probes)
/// and 派发 (firings, 运行面: it fired — did a run start, and why not). Each is a keyset-paged list of
/// expandable rows (the same `AnRowDetail` + KV + load-more shape as the 日志 tab) with a local filter
/// dropdown; flipping the filter re-watches a fresh provider instance. trigger 的活动/派发观测面。

/// 活动 tab — activations with a fired-only filter.
class TriggerActivityTab extends ConsumerStatefulWidget {
  const TriggerActivityTab(this.triggerId, {super.key});

  final String triggerId;

  @override
  ConsumerState<TriggerActivityTab> createState() => _TriggerActivityTabState();
}

class _TriggerActivityTabState extends ConsumerState<TriggerActivityTab> {
  bool _firedOnly = false;

  @override
  Widget build(BuildContext context) {
    final d = context.t.entities.detail;
    final key = (triggerId: widget.triggerId, firedOnly: _firedOnly);
    final async = ref.watch(activationListProvider(key));
    final notifier = ref.read(activationListProvider(key).notifier);
    return _ObsScaffold(
      filter: AnDropdown<bool>(
        value: _firedOnly,
        options: [
          AnDropdownOption(value: false, label: d.trigger.allActivity),
          AnDropdownOption(value: true, label: d.trigger.firedOnly),
        ],
        onChanged: (v) => setState(() => _firedOnly = v),
        menuAlignEnd: true,
      ),
      async: async,
      onToggle: notifier.toggle,
      onLoadMore: notifier.loadMore,
      onRetry: () => ref.invalidate(activationListProvider(key)),
      emptyTitle: d.state.noActivations,
      emptyHint: d.state.noActivationsHint,
    );
  }
}

/// 派发 tab — firings with a status filter.
class TriggerDispatchTab extends ConsumerStatefulWidget {
  const TriggerDispatchTab(this.triggerId, {super.key});

  final String triggerId;

  @override
  ConsumerState<TriggerDispatchTab> createState() => _TriggerDispatchTabState();
}

class _TriggerDispatchTabState extends ConsumerState<TriggerDispatchTab> {
  // '' = all; otherwise a valid FiringStatus wire value (never send the inbound-only `unknown`). ''=全部。
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final d = context.t.entities.detail;
    final key = (triggerId: widget.triggerId, status: _status.isEmpty ? null : _status);
    final async = ref.watch(firingListProvider(key));
    final notifier = ref.read(firingListProvider(key).notifier);
    return _ObsScaffold(
      filter: AnDropdown<String>(
        value: _status,
        options: [
          AnDropdownOption(value: '', label: d.trigger.allDispatch),
          // The sealed disposition set, minus the transient `claimed` (never a resting filter). 封闭处置集(去瞬态 claimed)。
          for (final s in const [
            FiringStatus.pending,
            FiringStatus.started,
            FiringStatus.skipped,
            FiringStatus.superseded,
            FiringStatus.shed,
          ])
            AnDropdownOption(value: s.name, label: s.name),
        ],
        onChanged: (v) => setState(() => _status = v),
        menuAlignEnd: true,
      ),
      async: async,
      onToggle: notifier.toggle,
      onLoadMore: notifier.loadMore,
      onRetry: () => ref.invalidate(firingListProvider(key)),
      emptyTitle: d.state.noFirings,
      emptyHint: d.state.noFiringsHint,
    );
  }
}

/// Shared observability scaffold: a right-aligned filter dropdown over the async paged rows (loading
/// skeleton / error+retry / empty inset / expandable rows + load-more). 观测面共用骨架:过滤 + 分页行。
class _ObsScaffold extends StatelessWidget {
  const _ObsScaffold({
    required this.filter,
    required this.async,
    required this.onToggle,
    required this.onLoadMore,
    required this.onRetry,
    required this.emptyTitle,
    required this.emptyHint,
  });

  final Widget filter;
  final AsyncValue<LogListState> async;
  final void Function(String id) onToggle;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final String emptyTitle;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final d = context.t.entities.detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerRight, child: filter),
        const SizedBox(height: AnSpace.s8),
        async.when(
          loading: () => const AnDeferredLoading(child: AnSkeleton.lines(6)),
          error: (_, _) => AnState(
            kind: AnStateKind.error,
            size: AnStateSize.inset,
            title: d.state.errorTitle,
            action: AnButton(label: d.state.loadMore, onPressed: onRetry),
          ),
          data: (st) => st.rows.isEmpty
              ? AnState(kind: AnStateKind.empty, size: AnStateSize.inset, title: emptyTitle, hint: emptyHint)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final row in st.rows)
                      AnRowDetail(
                        open: st.openIds.contains(row.id),
                        row: AnRow(
                          icon: AnIcons.byKey('trigger'),
                          dot: row.dot,
                          label: row.label,
                          meta: row.meta,
                          hint: row.hint,
                          collapsible: true,
                          open: st.openIds.contains(row.id),
                          onToggle: () => onToggle(row.id),
                          onSelect: () => onToggle(row.id),
                        ),
                        detail: kvList([for (final r in row.detailRows) (r.$1, r.$2)], wrap: true),
                      ),
                    if (st.loadingMore)
                      const AnSkeleton.row()
                    else if (st.hasMore)
                      AnButton(label: d.state.loadMore, onPressed: onLoadMore),
                  ],
                ),
        ),
      ],
    );
  }
}
