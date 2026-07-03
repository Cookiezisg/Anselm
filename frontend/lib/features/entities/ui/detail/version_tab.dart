import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/model/status_state.dart';
import '../../../../core/overlay/an_overlay.dart';
import '../../../../core/ui/an_action_group.dart';
import '../../../../core/ui/an_badge.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_two_zone.dart';
import '../../../../core/ui/an_deferred_loading.dart';
import '../../../../core/ui/an_row.dart';
import '../../../../core/ui/an_skeleton.dart';
import '../../../../core/ui/an_state.dart';
import '../../../../core/ui/an_toast.dart';
import '../../../../core/ui/an_version_diff.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_format.dart';
import '../../state/detail/version_list_provider.dart';
import '../../state/detail/version_list_state.dart';
import '../../state/selected_entity.dart';

/// The 版本 tab (kind-agnostic): a selectable version list (left) + the adjacent-version [AnVersionDiff]
/// (right). Selecting a version diffs it against the next-older loaded version (the earliest shows full
/// context). The diff sits FIRST in the right column so its top never moves; the per-version metadata
/// (structured-summary chips) and the set-active action live in a footer BELOW it — selecting a
/// version can only grow/shrink the footer, never shift the diff. 版本 tab:左列表 + 右相邻版本 diff;
/// diff 置顶(顶不动),摘要小签 + 设为活跃在其下的 footer(选版本只改 footer、不移 diff)。
class VersionTab extends ConsumerWidget {
  const VersionTab(this.entityRef, {super.key});

  final EntityRef entityRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = context.t.entities.detail;
    final async = ref.watch(versionListProvider(entityRef));
    final notifier = ref.read(versionListProvider(entityRef).notifier);

    return async.when(
      loading: () => const AnDeferredLoading(child: AnSkeleton.lines(6)),
      error: (_, _) => AnState(
        kind: AnStateKind.error,
        size: AnStateSize.inset,
        title: d.state.errorTitle,
        action: AnButton(label: d.state.retry, onPressed: () => ref.invalidate(versionListProvider(entityRef))),
      ),
      data: (st) {
        if (st.versions.isEmpty) {
          return AnState(kind: AnStateKind.empty, size: AnStateSize.inset, title: d.state.noVersions);
        }
        // Defensive clamp — the read site never RangeErrors even if selectedIndex ever goes stale. 防越界。
        final selIndex = st.selectedIndex.clamp(0, st.versions.length - 1);
        final sel = st.versions[selIndex];
        final older = selIndex + 1 < st.versions.length ? st.versions[selIndex + 1] : null;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _list(context, st, selIndex, notifier)),
            const SizedBox(width: AnSpace.s16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Diff FIRST → its top is pinned; nothing below it can move it. diff 置顶、顶点恒定。
                  AnVersionDiff(
                    after: sel.src,
                    before: older?.src,
                    lang: sel.lang,
                    range: older != null ? 'v${older.version} → v${sel.version}' : 'v${sel.version} · ${d.state.earliest}',
                    note: sel.changeReason,
                  ),
                  _footer(context, ref, st, sel, notifier),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Below the diff: structured-summary chips (left) + the set-active action (right), on the kit's
  // two-zone + action-group idioms (no hand-placed buttons). Its height varies with selection, but it
  // sits AFTER the diff so it never shifts it. footer 在 diff 下(AnTwoZone+AnActionGroup),增缩不移 diff。
  Widget _footer(BuildContext context, WidgetRef ref, VersionListState st, VersionRow sel,
      VersionListNotifier notifier) {
    final d = context.t.entities.detail;
    final showChips = sel.summary.isNotEmpty;
    final showActivate = !sel.active;
    if (!showChips && !showActivate) return const SizedBox.shrink();
    final pending = st.activatingVersion != null;
    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s8),
      child: AnTwoZone(
        label: showChips
            ? Wrap(
                spacing: AnSpace.s6,
                runSpacing: AnSpace.s4,
                children: [for (final s in sel.summary) AnBadge(s, tone: AnTone.none)],
              )
            : const SizedBox.shrink(),
        trailing: !showActivate
            ? const SizedBox.shrink()
            : AnActionGroup([
                AnButton(
                  label: d.state.setActive,
                  size: AnButtonSize.sm,
                  onPressed: pending
                      ? null
                      : () async {
                          try {
                            await notifier.setActive(sel.version);
                          } catch (_) {
                            ref
                                .read(overlayProvider.notifier)
                                .showToast(d.state.setActiveFailed, tone: AnToastTone.danger);
                          }
                        },
                ),
              ]),
      ),
    );
  }

  // Column (not ListView): the surrounding AnPage owns the single document scroll (flow tabs). 文档单滚,用 Column。
  Widget _list(BuildContext context, VersionListState st, int selIndex, VersionListNotifier notifier) {
    final d = context.t.entities.detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < st.versions.length; i++)
          AnRow(
            label: 'v${st.versions[i].version}',
            dot: st.versions[i].active ? AnStatus.done : null,
            hint: _hint(st.versions[i]),
            selected: i == selIndex,
            onSelect: () => notifier.select(i),
          ),
        if (st.loadingMore)
          const AnSkeleton.row()
        else if (st.hasMore)
          AnButton(label: d.state.loadMore, onPressed: notifier.loadMore),
      ],
    );
  }

  String _hint(VersionRow row) {
    final time = fmtTime(row.createdAt);
    final reason = row.changeReason;
    return reason != null && reason.isNotEmpty ? '$time · $reason' : time;
  }
}
