import 'package:freezed_annotation/freezed_annotation.dart';

part 'trigger_schedule.freezed.dart';
part 'trigger_schedule.g.dart';

// GET /trigger-schedule (WRK-069 工单⑧) — the FORWARD-LOOKING schedule timeline: every cron tick due
// inside `?within=`, capped by `?limit=`. Bounded (N4-exempt: no cursor). Feeds the Overview's
// AnScheduleTrack future points.
//
// Two contract facts the rendering side MUST hold on to:
//   • Only LISTENING, UNPAUSED cron triggers contribute points. Paused ones, unequipped ones, and
//     webhook/fsnotify/sensor (whose next fire is unknowable) are ALL absent — deliberately: a
//     paused trigger has no schedule, and stamping a time on it would be a lie. So the LANES must
//     come from the trigger LIST (which carries `paused`), never be reverse-derived from these
//     points — reverse-deriving makes a paused lane vanish, breaking 判决①.
//   • The cap is GLOBAL across triggers (union sorted, then truncated), so the earliest N points
//     really are the earliest N; [truncated] honestly reports «there is more inside the window».
//
// 前瞻调度时间线(⑧):窗内每个 cron 刻度,有界免游标。**只有正在监听且未暂停的 cron 贡献点**——暂停的、
// 无引用的、非 cron 的一律缺席(暂停即无排程,给时间戳就是撒谎)→ 泳道**行集须来自 trigger 列表**(它带
// paused),绝不从这些点反推(反推会让暂停泳道消失,直接违反判决①)。cap 跨 trigger 全局(并集排序后才截),
// truncated 诚实报告窗内还有更多。

/// One scheduled cron tick. [at] carries the backend's LOCAL offset (cron `Next()` keeps its input
/// location) while flowrun stamps are normalized UTC — compare only after `.toLocal()`, never as
/// strings. [workflowIds] is reverse-looked-up from the in-memory listener table (= the same
/// reference set as `refCount`), so a point never promises a run that cannot happen.
/// 一个 cron 刻度;at 带后端本地偏移(cron Next 保留入参时区)而 flowrun 戳是 UTC——一律 toLocal 后再比,
/// 绝不比字符串。workflowIds 取自内存监听表(与 refCount 同源),故点绝不承诺不会发生的运行。
@freezed
abstract class SchedulePoint with _$SchedulePoint {
  const factory SchedulePoint({
    required DateTime at,
    @Default('') String triggerId,
    @Default('') String triggerName,
    @Default(<String>[]) List<String> workflowIds,
  }) = _SchedulePoint;
  factory SchedulePoint.fromJson(Map<String, dynamic> json) =>
      _$SchedulePointFromJson(json);
}

/// The schedule envelope. [points] is `at`-ASC (same-instant ties broken by triggerId, so the order
/// is stable to depend on). [truncated] = the window really holds more than [points] shows — the UI
/// must say so out loud rather than let the track read as complete.
/// 调度信封:points 按 at 升序(同刻 triggerId 定序,可依赖);truncated=窗内确实还有更多,UI 必须明说,
/// 不能让轨道读起来像是全部。
@freezed
abstract class TriggerSchedule with _$TriggerSchedule {
  const factory TriggerSchedule({
    @Default(<SchedulePoint>[]) List<SchedulePoint> points,
    @Default(false) bool truncated,
  }) = _TriggerSchedule;
  factory TriggerSchedule.fromJson(Map<String, dynamic> json) =>
      _$TriggerScheduleFromJson(json);
}
