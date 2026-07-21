import '../../core/ui/ui.dart';
import 'specimen.dart';

// AnCountdown (WRK-069 S0) — the deadline countdown behind the Scheduler inbox rows («⏳剩 2h» on a
// parked approval). One shared half-minute Timer drives every instance (C-track law). Faces: pending
// amber (default) / pending neutral / overdue danger. AnCountdown 截止倒计时三态。

final anCountdownGalleryItem = GalleryItem(
  'AnCountdown 截止倒计时',
  '单顶层 Timer 共驱的截止倒计时文本;未到=剩 x(默认琥珀),已过=已超时(红);30s 粒度绝不逐秒跳字',
  [
    GallerySpecimen(
      '2 小时后到期(琥珀,默认)',
      (c) =>
          AnCountdown(deadline: DateTime.now().add(const Duration(hours: 2))),
    ),
    GallerySpecimen(
      '45 分钟后到期(中性 tone)',
      (c) => AnCountdown(
        deadline: DateTime.now().add(const Duration(minutes: 45)),
        tone: AnTone.none,
      ),
    ),
    GallerySpecimen(
      '3 天后到期',
      (c) => AnCountdown(deadline: DateTime.now().add(const Duration(days: 3))),
    ),
    GallerySpecimen(
      '已超时(恒 danger)',
      (c) => AnCountdown(
        deadline: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ),
  ],
);
