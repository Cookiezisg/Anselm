import 'package:flutter/widgets.dart';

import '../../core/design/tokens.dart';
import '../../core/ui/ui.dart';
import 'specimen.dart';

// AnScheduleTrack (WRK-069 §12, S5) — the absolute-time track. These specimens are where the three
// event faces are PROVEN side by side, because the whole value of the widget is that they cannot be
// confused: a solid status dot (it ran, here's how it went) vs a hollow ring (a forecast) vs a grey ✕
// (the tick came due while the machine slept — booked, not caught up, and NOT an error).
//
// The a11y walkthrough happens here (§12 requires it): every dot is a real focus node — a
// CustomPainter's pixels have no identity and cannot be focused — and the track is **ONE** Tab stop
// (a roving cursor): Tab once to enter, ←→ to walk a lane in time order, ↑↓ to cross to the dot
// NEAREST IN TIME on another lane (a track is a clock), and an arrow off the edge to leave. Before the
// roving cursor, the 8-lane stress bed below measured **227** Tab stops. The screen reader reads each
// dot as «{lane} {time} {status}» from [eventSemanticLabel].
//
// AnScheduleTrack 绝对时间轴。三张脸在此并排验明——本件的全部价值就在于它们不会被混淆:实心状态点(跑了,
// 结局如此)/ 空心环(预告)/ 灰 ✕(睡过头的刻度:记账不补跑,且**不是**错误)。§12 要求的读屏走查在此发生:
// 每点是真焦点节点(painter 的像素没有身份、不可聚焦),且整条轨是**唯一一个** Tab 停靠(roving 光标):
// Tab 一次进、←→ 按时序走本泳道、↑↓ 跨到另一泳道**时间上最近**的点(轨是钟)、出边即离开。在 roving 光标
// 之前,下面那张 8 泳道压力床实测有 **227** 个 Tab 停靠。读屏逐点念「{泳道} {时刻} {状态}」。

final _now = DateTime(2026, 7, 16, 14, 30);

String _label(TrackLane lane, TrackEvent e) {
  final when = '${e.at.hour.toString().padLeft(2, '0')}:${e.at.minute.toString().padLeft(2, '0')}';
  final what = switch (e.kind) {
    TrackEventKind.past => e.status == AnStatus.err ? '失败' : '成功',
    TrackEventKind.future => '预计',
    TrackEventKind.missed => '已错过',
  };
  return '${lane.label} $when $what';
}

/// The full grammar: history on the left of the now line, forecasts on its right, a missed tick in
/// between. 全文法:now 线左为史、右为预告,中间夹一个错过的刻度。
List<TrackLane> _mixed() => [
      TrackLane(id: 'a', label: '数据清洗', events: [
        TrackEvent(
            at: _now.subtract(const Duration(hours: 5)),
            kind: TrackEventKind.past,
            status: AnStatus.done,
            label: '数据清洗'),
        TrackEvent(
            at: _now.subtract(const Duration(hours: 4)),
            kind: TrackEventKind.past,
            status: AnStatus.done,
            label: '数据清洗'),
        TrackEvent(
            at: _now.subtract(const Duration(hours: 3)),
            kind: TrackEventKind.missed,
            label: '数据清洗'),
        TrackEvent(
            at: _now.subtract(const Duration(hours: 2)),
            kind: TrackEventKind.past,
            status: AnStatus.err,
            label: '数据清洗'),
        TrackEvent(
            at: _now.subtract(const Duration(minutes: 20)),
            kind: TrackEventKind.past,
            status: AnStatus.run,
            label: '数据清洗'),
        TrackEvent(at: _now.add(const Duration(hours: 3)), kind: TrackEventKind.future, label: '数据清洗'),
        TrackEvent(at: _now.add(const Duration(hours: 9)), kind: TrackEventKind.future, label: '数据清洗'),
        TrackEvent(at: _now.add(const Duration(hours: 15)), kind: TrackEventKind.future, label: '数据清洗'),
      ]),
      TrackLane(id: 'b', label: '周报生成', events: [
        TrackEvent(at: _now.add(const Duration(hours: 8)), kind: TrackEventKind.future, label: '周报生成'),
      ]),
      // 判决① — a paused lane greys but NEVER disappears, and legitimately holds no future points
      // (the backend refuses to stamp a next-fire on a paused trigger). 暂停泳道灰显但绝不消失,且
      // 合法地没有未来点(后端拒绝给暂停的 trigger 盖下次时间戳)。
      TrackLane(id: 'c', label: '每晚归档', dimmed: true, note: '已暂停', events: [
        TrackEvent(
            at: _now.subtract(const Duration(hours: 6)),
            kind: TrackEventKind.past,
            status: AnStatus.done,
            label: '每晚归档'),
      ]),
    ];

final anScheduleTrackGalleryItem = GalleryItem(
  'AnScheduleTrack 调度时间轴',
  '绝对时间轴 + now 线 + 逐泳道事件点:过去实心着状态色 / 未来空心环(预告) / missed 灰 ✕(睡过头记账,不染红);'
      '暂停泳道灰显不消失(判决①);bucket 按 (像素桶×kind) 聚合防爆、折叠点带计数;每点=真焦点节点(←→ 遍历由框架白送)',
  [
    GallerySpecimen(
        '全文法(过去/未来/missed/暂停泳道)',
        (_) => Padding(
              padding: const EdgeInsets.all(AnSpace.s16),
              child: AnScheduleTrack(
                lanes: _mixed(),
                now: _now,
                window: const Duration(hours: 18),
                pastWindow: const Duration(hours: 6),
                onTap: (_) {},
                eventSemanticLabel: _label,
                foldedLabel: (n) => '共 $n 次',
              ),
            ),
        span: true),
    GallerySpecimen(
        '只有未来 + now 线贴左(过去点无数据源时的诚实态)',
        (_) => Padding(
              padding: const EdgeInsets.all(AnSpace.s16),
              child: AnScheduleTrack(
                lanes: [
                  TrackLane(id: 'a', label: '数据清洗', events: [
                    for (var i = 1; i <= 4; i++)
                      TrackEvent(
                          at: _now.add(Duration(hours: i * 5)),
                          kind: TrackEventKind.future,
                          label: '数据清洗'),
                  ]),
                  TrackLane(id: 'b', label: '周报生成', events: [
                    TrackEvent(
                        at: _now.add(const Duration(hours: 8)),
                        kind: TrackEventKind.future,
                        label: '周报生成'),
                  ]),
                ],
                now: _now,
                eventSemanticLabel: _label,
              ),
            ),
        span: true),
    GallerySpecimen(
        '暂停泳道(灰显 + 「已暂停」+ 零未来点)',
        (_) => Padding(
              padding: const EdgeInsets.all(AnSpace.s16),
              child: AnScheduleTrack(
                lanes: [
                  TrackLane(id: 'c', label: '每晚归档', dimmed: true, note: '已暂停', events: const []),
                  TrackLane(id: 'a', label: '数据清洗', events: [
                    TrackEvent(
                        at: _now.add(const Duration(hours: 6)),
                        kind: TrackEventKind.future,
                        label: '数据清洗'),
                  ]),
                ],
                now: _now,
                eventSemanticLabel: _label,
              ),
            ),
        span: true),
    // ── 压力床 ──
    GallerySpecimen(
        '压力:8 条 */5 的 cron(各 288 刻度)→ bucket 折叠成带计数的点,绝不亚像素纸屑;'
        '2304 个事件 → 约 224 个点 → **恰好 1 个 Tab 停靠**(折叠封点数,roving 光标封停靠数)',
        (_) => Padding(
              padding: const EdgeInsets.all(AnSpace.s16),
              child: AnScheduleTrack(
                lanes: [
                  for (var l = 0; l < 8; l++)
                    TrackLane(id: 'l$l', label: '高频采样 $l', events: [
                      for (var i = 1; i <= 288; i++)
                        TrackEvent(
                            at: _now.add(Duration(minutes: i * 5 + l)),
                            kind: TrackEventKind.future,
                            label: '高频采样 $l'),
                    ]),
                ],
                now: _now,
                // Focusable dots are the point of this bed: folding alone left 227 Tab stops here.
                // 可聚焦的点正是这张床的要害:光靠折叠,这里还剩 227 个 Tab 停靠。
                onTap: (_) {},
                eventSemanticLabel: _label,
                foldedLabel: (n) => '共 $n 次',
              ),
            ),
        stress: true,
        span: true,
        height: 320),
    GallerySpecimen(
        '压力:超长泳道名(定宽车道内裁切,绝不挤走轨道)',
        (_) => Padding(
              padding: const EdgeInsets.all(AnSpace.s16),
              child: AnScheduleTrack(
                lanes: [
                  TrackLane(
                      id: 'a',
                      label: '每天凌晨把上游三个数据源全量拉下来做去重清洗再回写到仓库的那条流水线',
                      note: '已暂停',
                      dimmed: true,
                      events: [
                        TrackEvent(
                            at: _now.add(const Duration(hours: 4)),
                            kind: TrackEventKind.future,
                            label: '清洗'),
                      ]),
                ],
                now: _now,
                eventSemanticLabel: _label,
              ),
            ),
        stress: true,
        maxWidth: 420),
    GallerySpecimen(
        '空 lanes 渲空 · 轴外事件不渲(放不下就不假装放得下)',
        (_) => Padding(
              padding: const EdgeInsets.all(AnSpace.s16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AnScheduleTrack(lanes: const [], now: _now),
                AnScheduleTrack(
                  lanes: [
                    TrackLane(id: 'a', label: '窗外事件', events: [
                      // 30 天后 — 24h 轴放不下它,故不渲(轴外不可诚实定位)
                      TrackEvent(
                          at: _now.add(const Duration(days: 30)),
                          kind: TrackEventKind.future,
                          label: '窗外'),
                    ]),
                  ],
                  now: _now,
                  eventSemanticLabel: _label,
                ),
              ]),
            ),
        stress: true,
        span: true),
  ],
);

