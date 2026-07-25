import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/model/status_state.dart';
import '../../../../core/notice/notice_center.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_expand_reveal.dart';
import '../../../../core/ui/an_last_good.dart';
import '../../../../core/ui/an_menu.dart';
import '../../../../core/ui/an_row.dart';
import '../../../../core/ui/an_skeleton.dart';
import '../../../../core/ui/an_state.dart';
import '../../../../core/ui/an_version_diff.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_format.dart';
import '../../state/detail/version_list_provider.dart';
import '../../state/detail/version_list_state.dart';
import '../../state/selected_entity.dart';

/// The 版本 tab (kind-agnostic) — a FULL-WIDTH STICKY ACCORDION (WRK-077 VT, 用户 0723 拍板). One version
/// per row, spanning the whole content column, opening IN PLACE to its diff against the next-older
/// loaded version. It replaces the old left-list / right-diff split: cutting an already-narrow reading
/// column in two left the diff ~60% wide and chopped code horizontally — the scheduler run flagship's
/// grammar (`scheduler_run.dart`: full-width zones stacked vertically over ONE shared selection, deep
/// evidence one click away, never a left/right split) is the one this page had violated.
///
/// The row IS the selection: tapping it toggles the card and tints the row (`selected: open`), the lead
/// slot is the disclosure chevron (the active-version marker moved to the trail — 拍板「lead 位归
/// chevron」), and the row itself carries enough to read without opening anything: version · time ·
/// change note · structured summary · **+N −N** · the active marker · a hover-revealed ⋯ menu. The card
/// opens in HUNK mode (changed lines + 3 context, folded runs tappable) with soft-wrap ON — full width
/// only pays off if long lines are readable to their end — and «show all» flips it to the whole text.
///
/// Both open sets live in [VersionListState] (never in these widgets), so the ⋯ menu drives the exact
/// same truth as the row body and nothing is lost to a rebuild.
///
/// 版本 tab = **全宽粘性手风琴**(0723 拍板):一版一行、占满整宽、就地展开对下一更旧版本的 diff。旧的左列表 /
/// 右 diff 对切被废——在本就不宽的阅读列里再切一刀让 diff 只剩 ~60% 宽、代码横向被砍;学 scheduler 运行旗舰的
/// 语法(整页纵向堆叠全宽区 × 一个共享选区 × 深证据一键直达,从不左右对切)。行即选区(点即展开+提墨,lead 归
/// chevron、活动标记移到 trail),行上信息给足(版本·时间·说明·结构小签·+N −N·活动标记·hover ⋯ 菜单)。卡默认
/// hunk 模式(变更行 + 3 行上下文,折叠段可点)且默认软换行,「展开全部」翻成整份文本。两个开合集住在
/// VersionListState(不在 widget 里),故 ⋯ 菜单与行身驱动同一份真相、重建不丢。
class VersionTab extends ConsumerWidget {
  const VersionTab(this.entityRef, {super.key});

  final EntityRef entityRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = context.t.entities.detail;
    final async = ref.watch(versionListProvider(entityRef));
    final notifier = ref.read(versionListProvider(entityRef).notifier);

    // Last-known-good, hard reset on entity switch (snapshot bridges same-entity refreshes only —
    // cross-entity hold would be data corruption). last-known-good,实体切换硬换代,快照只桥同实体刷新。
    return AnLastGood(
      value: async,
      resetKey: entityRef,
      placeholder: const AnSkeleton.lines(6),
      errorBuilder: (_, _, _) => AnState(
        kind: AnStateKind.error,
        size: AnStateSize.inset,
        title: d.state.errorTitle,
        action: AnButton(
          label: d.state.retry,
          onPressed: () => ref.invalidate(versionListProvider(entityRef)),
        ),
      ),
      builder: (context, st) {
        if (st.versions.isEmpty) {
          return AnState(
            kind: AnStateKind.empty,
            size: AnStateSize.inset,
            title: d.state.noVersions,
          );
        }
        // Column (not ListView): the surrounding AnPage owns the single document scroll (flow tabs).
        // 文档单滚,用 Column。
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < st.versions.length; i++)
              _VersionAccordionRow(
                entityRef: entityRef,
                row: st.versions[i],
                // The diff pairs each version with the next-older LOADED row; the last loaded row has
                // no neighbour (the earliest version shows full context). 与下一更旧已载入行成对;末行无邻。
                older: i + 1 < st.versions.length ? st.versions[i + 1] : null,
                open: st.expanded.contains(st.versions[i].version),
                full: st.fullSource.contains(st.versions[i].version),
                activating: st.activatingVersion != null,
              ),
            if (st.loadingMore)
              const AnSkeleton.row()
            else if (st.hasMore)
              AnButton(label: d.state.loadMore, onPressed: notifier.loadMore),
          ],
        );
      },
    );
  }
}

/// One accordion row: the [AnRow] head + its in-place [AnExpandReveal] diff card — the sidestage
/// accordion's exact shape (row identity single-sourced, open set external, LAZY body so a collapsed
/// row never builds — and never diffs — its card).
/// 一条手风琴行:AnRow 行头 + 就地 AnExpandReveal diff 卡(侧幕同形:行身份单源、开合集外置、体惰性——收起
/// 的行绝不建卡、也就绝不跑 diff)。
class _VersionAccordionRow extends ConsumerWidget {
  const _VersionAccordionRow({
    required this.entityRef,
    required this.row,
    required this.older,
    required this.open,
    required this.full,
    required this.activating,
  });

  final EntityRef entityRef;
  final VersionRow row;
  final VersionRow? older;
  final bool open;
  final bool full;

  /// A set-active is in flight (anywhere in the list) → the menu item is inert. 有设为活跃在途→菜单项惰性。
  final bool activating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final d = t.entities.detail;
    final notifier = ref.read(versionListProvider(entityRef).notifier);
    void toggle() => notifier.toggleExpanded(row.version);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnRow(
          label: 'v${row.version}',
          mono: true,
          hint: _hint(),
          meta: _counts(),
          // collapsible with no icon → the chevron is the PERMANENT lead, rotating 90° when open: the
          // «小点点变箭头» the user asked for, and why the active marker moved to the trail.
          // collapsible 且无 icon → 箭头常驻 lead、展开旋 90°(用户要的「小点点变箭头」),故活动标记移到 trail。
          collapsible: true,
          open: open,
          selected: open,
          // The active version's marker: the trail's persistent status dot (visible at rest, unlike the
          // hover-revealed actions). 活动版本标记=trail 常驻状态点(静息即可见,异于 hover 才现的 actions)。
          trailingDot: row.active ? AnStatus.done : null,
          actions: [_menu(context, ref, t, notifier)],
          onSelect: toggle,
          onToggle: toggle,
        ),
        // LAZY: a collapsed row must not build its diff card (an eager card would run its LCS + build
        // every row for versions nobody opened). 惰性:收起的行不建 diff 卡(急建=替没人展开的版本跑 LCS)。
        AnExpandReveal.builder(
          open: open,
          childBuilder: (context) => Padding(
            // Symmetric breathing above/below, flush left/right — the card spans the head box's full
            // width (hierarchy reads from position; a narrower card just looks misaligned).
            // 上下对称呼吸、左右齐平:卡与行头框同宽(层级靠位置读,瘦一圈反显没对齐)。
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
            child: AnVersionDiff(
              reading: true,
              after: row.src,
              before: older?.src,
              lang: row.lang,
              range: older != null
                  ? 'v${older!.version} → v${row.version}'
                  : 'v${row.version} · ${d.state.earliest}',
              note: row.changeReason,
              // Full width + soft-wrap is the pair that actually fixes «code cut off»; hunks keep the
              // card about the CHANGE. 全宽 + 软换行才真正治好「代码被砍」;hunk 让卡只谈变更。
              wrap: true,
              hunks: !full,
              onHunksChanged: (h) => notifier.setFullSource(row.version, !h),
              // A bound is what makes the rows lazy — «show all» on a thousand-line version scrolls
              // inside the card instead of building a thousand rows into the page.
              // 有钳才有惰性:千行版本「展开全部」在卡内滚,而非把千行铺进页面。
              maxHeight: AnSize.codeViewport,
            ),
          ),
        ),
      ],
    );
  }

  // Everything the row can say without being opened: when it landed, why (the change note) and the
  // structured non-text deltas (signature / dependency / graph chips, joined — the row is prose, the
  // chips' own surface is the overview). 行不展开也说得清:何时落、为何(说明)、结构化非文本变更(签名/依赖/
  // 图小签,以点连读——行是散文,小签的展台在概览)。
  String _hint() {
    final parts = <String>[
      fmtTime(row.createdAt),
      if (row.changeReason != null && row.changeReason!.isNotEmpty)
        row.changeReason!,
      ...row.summary,
    ];
    return parts.join(' · ');
  }

  // +N −N against the next-older loaded row, tabular in the trail. Null (no neighbour: the earliest
  // version or a page boundary) renders nothing rather than a lying «+0 −0».
  // 对下一更旧行的 +N −N(trail tabular);无邻(最早版本/页边界)则不渲,而非撒谎的「+0 −0」。
  String? _counts() {
    final a = row.added;
    final r = row.removed;
    if (a == null || r == null) return null;
    return '+$a −$r'; // U+2212 minus, 1:1 the diff bar's counts 与 diff bar 的计数逐字同形
  }

  // The row's ⋯ menu (hover-revealed, the conversation/entity rail idiom) — the ONE home for this
  // version's actions. «Show diff» / «Show all» are second entrances to the accordion's own state (not
  // a private copy); «Set active» is the `:revert` call that used to sit as a lone trailing button
  // under the diff. Deleting a version is deliberately absent: it needs a constitutional ruling
  // (D1 log-vs-business, the broken diff chain, a vanished `:revert` target) the user has deferred —
  // and a half-wired menu item would be a promise the backend cannot keep.
  // 行内 ⋯ 菜单(hover 揭示,同会话/实体 rail 文法)=本版本动作的唯一家。「展开 diff」「展开全部」是手风琴自身
  // 状态的第二入口(不是私有副本);「设为活跃版本」即原先孤零零挂在 diff 下的 :revert 按钮。**删除版本刻意缺席**
  // ——它需要一次宪法裁决(D1 归属/diff 链断裂/:revert 目标消失),用户已推迟;半接线的菜单项等于替后端许下
  // 它给不出的承诺。
  Widget _menu(
    BuildContext context,
    WidgetRef ref,
    Translations t,
    VersionListNotifier notifier,
  ) {
    return AnMenu(
      anchorBuilder: (context, toggle, isOpen) => AnButton.iconOnly(
        AnIcons.more,
        size: AnButtonSize.sm,
        semanticLabel: t.a11y.moreActions,
        onPressed: toggle,
      ),
      entries: [
        AnMenuItem(
          label: open ? t.diff.hide : t.diff.show,
          icon: open ? AnIcons.fold : AnIcons.unfold,
          onTap: () => notifier.toggleExpanded(row.version),
        ),
        // One slot, flipped by the current mode (never both listed side by side). 同一格位按现态二选一。
        AnMenuItem(
          label: full
              ? t.diff.onlyChanges
              : t.diff.showAll(n: '\n'.allMatches(row.src).length + 1),
          icon: full ? AnIcons.fold : AnIcons.unfold,
          onTap: () => notifier.setFullSource(row.version, !full),
        ),
        if (!row.active)
          AnMenuItem(
            label: t.entities.detail.state.setActive,
            icon: AnIcons
                .history, // the revert idiom (AnIcons maps revert_* → history) 回滚字形
            disabled: activating,
            onTap: () => _setActive(ref, t, notifier),
          ),
      ],
    );
  }

  Future<void> _setActive(
    WidgetRef ref,
    Translations t,
    VersionListNotifier notifier,
  ) async {
    try {
      await notifier.setActive(row.version);
    } catch (_) {
      ref
          .read(noticeCenterProvider.notifier)
          .show(t.entities.detail.state.setActiveFailed, tone: AnTone.danger);
    }
  }
}
