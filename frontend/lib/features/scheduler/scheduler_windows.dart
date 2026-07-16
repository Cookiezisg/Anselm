/// Every statistics window the Scheduler ocean speaks, in ONE place (WRK-069 §8 窗口立法).
///
/// Four surfaces each quoting their own window IS the «乱» this ocean exists to prevent: a bead strip
/// of 10, a matrix of 20, a 7d failure roll-up and a 24h KPI tile are four different questions, and a
/// reader who cannot tell which is which cannot trust any of them. So the values live here, named, and
/// the i18n sentences that render them carry the window word EXPLICITLY (`home.statsLine($window,…)`)
/// — never a bare percentage whose window the reader has to guess.
///
/// Deliberately NOT `core/`: §8 said «(core)», but core is what features SHARE, and nothing outside
/// this feature reads these — a scheduler-only table parked in core is exactly the pollution the law
/// was written against. Recorded as a placement deviation (S4 偏差① set the precedent: put it where it
/// honestly belongs, record it). The backend pins the same numbers independently (matrix.go cites
/// this table by name) — they are a shared decision, not a shared import.
///
/// scheduler 海洋说的每一个统计窗口,单源于此(§8 窗口立法)。四处窗口各说各话本身即「乱」——珠串 10、
/// 矩阵 20、失败 7d、KPI 24h 是四个不同的问题,读者分不清哪个是哪个就一个也信不了。故值具名住在这里,
/// 且渲它们的 i18n 句**显式含窗口词**,绝不给一个让读者猜窗口的裸百分比。**刻意不放 core**:§8 原话是
/// (core),但 core 是 features **共享**之物、本 feature 之外无人读这些——把 scheduler 专用表停在 core
/// 正是此法要防的污染(记放置偏差,S4 偏差① 先例:放它诚实该在的地方并记档)。后端独立钉同一组数
/// (matrix.go 按名引用本表)——它们是共享的**决定**,不是共享的 import。
library;

abstract final class SchedulerWindows {
  /// The health head's bead strip — the last 10 runs (`flowrun-stats?recentN=`). 珠串=近 10。
  static const int beadRecentN = 10;

  /// The linked pane's third face — the last 20 runs (`flowrun-matrix?recentN=`). This is the
  /// backend's default AND its hard cap: a narrow viewport may want fewer, nothing wants more.
  /// 矩阵=近 20(后端的默认即上限:窄视口可要更少,没有任何东西要得到更多)。
  static const int matrixRecentN = 20;

  /// Success rate / average elapsed — a 7d rolling window (`flowrun-stats?since=`). Wire grammar is
  /// a Go duration, so 7d is spelled in hours. 成功率/均时=7d 滚动(线缆走 Go duration 文法,故写小时)。
  static const String statsSince = '168h';

  /// The word the 7d sentence must SAY (§8: the window is never left to be guessed). 7d 句里的窗口词。
  static const String statsWindowWord = '7d';

  /// The KPI failure tile — 24h, plus a 48h probe so the delta is (last 24h) − (previous 24h).
  /// KPI 失败牌=24h;delta 双窗差分故另探 48h。
  static const String kpiFailedSince = '24h';
  static const String kpiFailedDeltaSince = '48h';

  /// The Overview's schedule track horizon (`trigger-schedule?within=`, Go duration). 24h is what the
  /// board's zone head promises; the endpoint would allow up to 30d.
  /// Overview 时间轴视野(⑧ 的 ?within=,Go duration);24h=区头承诺的窗,端点最多可到 30d。
  static const Duration trackWindow = Duration(hours: 24);
  static const String trackWithin = '24h';

  /// The failure roll-up — 7d rolling, deliberately NOT 24h: a failure at 02:00 must still be on the
  /// board at 04:00 the next day (a 24h window drops it while the human is asleep).
  /// 失败聚合=7d 滚动,**刻意不是 24h**:凌晨 26h 前的失败不能在人睡觉时漏窗。
  static const String failuresSince = '168h';
}
