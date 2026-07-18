import 'package:flutter/widgets.dart';

import '../../core/design/colors.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/ui/ui.dart';
import 'specimen.dart';

// AnScheduleTrack (WRK-069 §12 · WRK-070 调度轨重造 0718) — the schedule board's one row per schedule, a
// now line splitting a time-BINNED past bar (uptime bar / contribution grid) from a fixed-width future
// «next-fire» sentence (Cronitor next-run). These specimens PROVE the five forms side by side, because
// the whole value is that they cannot be confused: a dense high-frequency lane whose every hour is
// filled, a sparse lane, a lane with a missed ✕ over a filled hour, a paused lane greyed with «已暂停»,
// and a lane with no forecast. The a11y walkthrough happens here (§12): the track is ONE Tab stop (a
// roving cursor over the 24 hourly cells + the future ○), ←→ walks a lane, ↑↓ crosses to the SAME hour
// of the next lane (a track is a clock). Hover a content cell or the ○ for its detail card.
//
// AnScheduleTrack 调度看板逐排程一行,now 线劈开时段分箱的过去条(uptime bar/贡献格)与定宽的「下一发」未来一句话
// (Cronitor next-run)。五形态在此并排验明:高频满格 / 疏格 / 满格上叠 missed ✕ / 暂停灰显「已暂停」/ 无预告。§12
// 读屏走查在此:整轨**唯一一个** Tab 停靠(roving 光标走 24 小时格 + 未来 ○),←→ 走本泳道、↑↓ 跨到下条泳道**同一
// 小时**(轨是钟);hover 内容格或 ○ 出明细卡。

final _now = DateTime(2026, 7, 16, 14, 30);
// Whole-hour bins (v2 拍板): 25 = 24 complete hours + the in-progress one. 整点 25 格。
final _end = DateTime(2026, 7, 16, 15);
final _start = _end.subtract(const Duration(hours: 25));
const int _bins = 25;

String _headOf(TrackBin bin) =>
    bin.start.hour == 0 ? '${bin.start.month}/${bin.start.day}' : '${bin.start.hour}';

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TrackRun _run(int hoursAgo, AnStatus status, {int elapsedS = 30, int min = 0}) {
  final at = _now.subtract(Duration(hours: hoursAgo, minutes: -min));
  return TrackRun(
    id: 'fr_${hoursAgo}_$min',
    workflowId: 'wf_demo',
    at: at,
    status: status,
    sourceLabel: 'cron · ${_hm(at)}',
    elapsed: status == AnStatus.run ? null : Duration(seconds: elapsedS),
  );
}

TrackLane _lane(
  String id,
  String label, {
  List<TrackRun> runs = const [],
  List<DateTime> missed = const [],
  TrackFuture? future,
  bool dimmed = false,
  String note = '',
}) =>
    TrackLane(
      id: id,
      label: label,
      bins: binTrackEvents(
          start: _start, end: _end, binCount: _bins, runs: runs, missed: missed),
      future: future,
      dimmed: dimmed,
      note: note,
    );

/// The full grammar in one track: a dense lane, a sparse lane with a missed ✕, a paused lane, a lane
/// with no forecast. 全文法一轨:高频满格 / 疏格带 missed / 暂停 / 无预告。
List<TrackLane> _mixed() => [
      // High-frequency: a run most hours, a couple failed — the dense bar. 高频满格,含两次失败。
      _lane('a', '周报生成',
          runs: [
            for (var h = 1; h < 24; h++)
              _run(h, h == 4 || h == 15 ? AnStatus.err : AnStatus.done, elapsedS: 12 + h),
            _run(0, AnStatus.run, min: -5),
          ],
          future: TrackFuture(
              at: _now.add(const Duration(minutes: 2)),
              time: '14:32',
              relative: '(2m 后)',
              schedule: '之后每 15 分钟')),
      // Sparse + missed: a few runs and two overslept ticks (the grey ✕). 疏格 + 两次错过(灰 ✕)。
      _lane('b', '库存同步',
          runs: [
            _run(21, AnStatus.err),
            _run(15, AnStatus.done),
            _run(9, AnStatus.done),
          ],
          missed: [
            _now.subtract(const Duration(hours: 19)),
            _now.subtract(const Duration(hours: 13)),
          ],
          future: TrackFuture(
              at: _now.add(const Duration(hours: 5)),
              time: '23:00',
              relative: '(5h 后)',
              schedule: '每日 23:00')),
      // No forecast in the window (a lane whose next fire is unknown) — the future segment is blank.
      // 窗内无预告(下次不可知)——未来段留空。
      _lane('c', '数据清洗流水线', runs: [
        _run(16, AnStatus.done),
        _run(10, AnStatus.done),
        _run(6, AnStatus.done),
      ]),
      // Paused (判决①): greyed, «已暂停», zero forecast — but the fires it made before it was paused stay.
      // 暂停(判决①):灰显、「已暂停」、零预告——但暂停前开过的火仍在。
      _lane('d', '邮件归档',
          dimmed: true,
          note: '已暂停',
          runs: [_run(20, AnStatus.done), _run(14, AnStatus.done)]),
    ];

String _binA11y(TrackLane lane, TrackBin bin) {
  final ok = bin.runs.where((r) => r.status == AnStatus.done).length;
  final fail = bin.runs.where((r) => r.status == AnStatus.err).length;
  final base = '${bin.start.hour} 时,${bin.runs.length} 次:$ok 成 $fail 败';
  return bin.missedCount > 0 ? '$base,含 ${bin.missedCount} 次错过' : base;
}

Widget _binCard(BuildContext context, TrackLane lane, TrackBin bin) {
  final c = context.colors;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('${_hm(bin.start)} · 共 ${bin.runs.length + bin.missedCount} 次',
          style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
      const SizedBox(height: AnFlow.headBodyDense),
      for (final m in bin.missed)
        Row(children: [
          Icon(AnIcons.close, size: AnSize.iconSm, color: c.inkMuted),
          const SizedBox(width: AnSpace.s6),
          Text('错过 ${_hm(m)}', style: AnText.meta.copyWith(color: c.inkFaint)),
        ]),
      for (final r in bin.runs.take(5))
        Row(children: [
          AnStatusDot(r.status),
          const SizedBox(width: AnSpace.s6),
          Text(_hm(r.at), style: AnText.metaTabular().copyWith(color: c.inkMuted)),
          const SizedBox(width: AnSpace.s8),
          Flexible(
              child: Text(r.sourceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.meta.copyWith(color: c.inkFaint))),
          const SizedBox(width: AnSpace.s8),
          Text(r.elapsed != null ? '${r.elapsed!.inSeconds}s' : '—',
              style: AnText.metaTabular().copyWith(color: c.inkFaint)),
        ]),
    ],
  );
}

final anScheduleTrackGalleryItem = GalleryItem(
  'AnScheduleTrack 调度时间轴',
  'now 线劈两半:过去=统一时段分箱条(uptime bar/贡献格,格色=时段内 run 最坏状态,空=淡描边;missed 叠灰 ✕);'
      '未来=定宽「下一发」一句话(○ + HH:mm(相对词)+ 排程句;暂停说「已暂停」)。点格=发射台、hover 出明细卡;'
      '每格=真焦点节点(←→ 遍历由框架白送)、整轨唯一 Tab 停靠(roving 光标)',
  [
    GallerySpecimen(
        '全文法(高频满格 / 疏格 + missed / 暂停 / 无预告)',
        (_) => Padding(
              padding: const EdgeInsets.all(AnSpace.s16),
              child: AnScheduleTrack(
                lanes: _mixed(),
                now: _now,
                binHeadLabel: _headOf,
                onBin: (_, _) {},
                binSemanticLabel: _binA11y,
                emptyBinSemanticLabel: (lane, bin) => '${bin.start.hour} 时,无运行',
                futureSemanticLabel: (lane) =>
                    lane.future == null ? lane.note : '下一发 ${lane.future!.time},${lane.future!.schedule}',
                laneSummaryLabel: (lane) => lane.dimmed ? '${lane.label} · 已暂停' : lane.label,
                binHoverBuilder: (lane, bin) => (ctx) => _binCard(ctx, lane, bin),
                futureHoverBuilder: (lane) => (ctx) => Text(
                    lane.future == null ? lane.note : '下一发 ${lane.future!.time} · ${lane.future!.schedule}',
                    style: AnText.meta.copyWith(color: ctx.colors.ink)),
              ),
            ),
        span: true),
    // ── 压力床 ──
    GallerySpecimen(
        '压力:8 条高频泳道(每条几乎格格有 run)→ 恒 24 格、恒 1 个 Tab 停靠(roving 光标封停靠数)',
        (_) => Padding(
              padding: const EdgeInsets.all(AnSpace.s16),
              child: AnScheduleTrack(
                lanes: [
                  for (var l = 0; l < 8; l++)
                    _lane('l$l', '高频采样 $l', runs: [
                      for (var h = 0; h < 24; h++)
                        _run(h, h % 7 == l % 7 ? AnStatus.err : AnStatus.done, min: l),
                    ], future: TrackFuture(at: _now.add(Duration(minutes: 5 + l)), time: '14:${35 + l}', relative: '(${5 + l}m 后)', schedule: '每 5 分钟')),
                ],
                now: _now,
                binHeadLabel: _headOf,
                onBin: (_, _) {},
                binSemanticLabel: _binA11y,
                emptyBinSemanticLabel: (lane, bin) => '${bin.start.hour} 时,无运行',
                futureSemanticLabel: (lane) => '下一发 ${lane.future?.time}',
                laneSummaryLabel: (lane) => lane.label,
                binHoverBuilder: (lane, bin) => (ctx) => _binCard(ctx, lane, bin),
              ),
            ),
        stress: true,
        span: true,
        height: 372),
    GallerySpecimen(
        '压力:超长泳道名(定宽车道内裁切,绝不挤走格条)',
        (_) => Padding(
              padding: const EdgeInsets.all(AnSpace.s16),
              child: AnScheduleTrack(
                lanes: [
                  _lane('a', '每天凌晨把上游三个数据源全量拉下来做去重清洗再回写到仓库的那条流水线',
                      dimmed: true,
                      note: '已暂停',
                      runs: [_run(4, AnStatus.done)]),
                ],
                now: _now,
                binHeadLabel: _headOf,
                futureSemanticLabel: (lane) => lane.note,
                laneSummaryLabel: (lane) => '${lane.label} · 已暂停',
              ),
            ),
        stress: true,
        maxWidth: 420),
    GallerySpecimen(
        '空 lanes 渲空 · 全空泳道(每格淡描边,空是真答案)',
        (_) => Padding(
              padding: const EdgeInsets.all(AnSpace.s16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AnScheduleTrack(lanes: const [], now: _now),
                AnScheduleTrack(
                  lanes: [_lane('a', '从未运行', runs: const [])],
                  now: _now,
                  binHeadLabel: _headOf,
                  onBin: (_, _) {},
                  emptyBinSemanticLabel: (lane, bin) => '${bin.start.hour} 时,无运行',
                  laneSummaryLabel: (lane) => lane.label,
                ),
              ]),
            ),
        stress: true,
        span: true),
  ],
);
