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

  /// The KPI strip's window — 24h, plus a 48h probe so the failure delta is (last 24h) − (previous 24h).
  ///
  /// **A Duration, not a wire word, and that is load-bearing** (工单⑭/判决⑥). The 「错过 N」 card reads
  /// `totals.missed`, which the backend counts with `{status: missed, createdAfter: since}` — the very
  /// predicate the card's click must deep-link to on `GET /firings`. Spelling `since` as the relative
  /// word `'24h'` would let the BACKEND resolve the anchor (its `now − 24h`) while the front end had to
  /// guess a second one for the list — two clocks, two predicates, and «the card says 3, the list it
  /// opens shows 4» is precisely the bug this ocean legislates against. So the anchor instant is
  /// computed HERE-side, ONCE, from this Duration, and the same value is sent to both endpoints
  /// (`?since=` takes RFC3339 absolute — api.md flowrun-stats 契约). One value, one predicate.
  ///
  /// KPI 窗=24h;失败 delta 双窗差分故另探 48h。**它是 Duration 而非线缆词,且这一点是承重的**(工单⑭/判决⑥):
  /// 「错过 N」牌读 totals.missed,后端用 `{status: missed, createdAfter: since}` 数它——而那正是牌点击必须
  /// 深链过去的谓词。若把 since 写成相对词 `'24h'`,锚点就由**后端**解(它的 now−24h),前端只能为列表再猜第二个
  /// ——两口钟、两份谓词,而「牌上写 3、点开列表显示 4」正是本海洋立法要防的 bug。故锚点在**前端**算、只算
  /// **一次**,同一个值发给两个端点(`?since=` 收 RFC3339 绝对起点)。一个值,一份谓词。
  static const Duration kpiWindow = Duration(hours: 24);
  static const Duration kpiDeltaWindow = Duration(hours: 48);

  /// The word the 24h sentences must SAY (§8: the window is never left to be guessed). 24h 句里的窗口词。
  static const String kpiWindowWord = '24h';

  /// The Overview's schedule track horizon (`trigger-schedule?within=`, Go duration). 24h is what the
  /// board's zone head promises; the endpoint would allow up to 30d.
  /// Overview 时间轴视野(⑧ 的 ?within=,Go duration);24h=区头承诺的窗,端点最多可到 30d。
  static const Duration trackWindow = Duration(hours: 24);
  static const String trackWithin = '24h';

  /// The track's PAST half (工单⑭/判决⑥) — deliberately EQUAL to [kpiWindow], and equal by
  /// CONSTRUCTION rather than by coincidence: the 「错过 N」 card deep-links to the ✕ marks on this
  /// track, so if the track looked back less far than the card counts, a missed tick could be counted
  /// by the card and be off the axis of the very surface its click opens. §3's sketch drew the now
  /// line left-of-centre («now 线偏左») when the past half was decoration; 判决⑥ made it the card's
  /// evidence, and correctness outranks the sketch — so now sits at the CENTRE (past 24h + future 24h).
  /// 轨道的**过去**半:刻意等于 kpiWindow,且是**构造上**相等而非碰巧相等——牌深链到本轨的 ✕,故轨若回看得比牌
  /// 数的短,就会有被牌数进去、却落在它自己点开的那个面的轴外的刻度。§3 草图画「now 线偏左」是在过去半还只是
  /// 装饰的时候;判决⑥ 让它成了牌的**证据**,而正确性大过草图——故 now 居中(过去 24h + 未来 24h)。
  static const Duration trackPastWindow = kpiWindow;

  /// One page of the firing ledger behind the track's past half (`GET /firings?limit=`) — the
  /// endpoint's hard cap. Rows come newest-first, so a truncated page is the NEWEST slice and the
  /// older end of the window becomes UNKNOWN, not empty — the zone must say so (§3 区 4).
  /// 轨道过去半那一页 firing 账的上限(端点硬帽)。行新→旧,故截断的一页是**最新**那片、窗口更老那端成为
  /// **未知**而非空——区必须明说。
  static const int firingPageLimit = 200;

  /// The failure roll-up — 7d rolling, deliberately NOT 24h: a failure at 02:00 must still be on the
  /// board at 04:00 the next day (a 24h window drops it while the human is asleep).
  /// 失败聚合=7d 滚动,**刻意不是 24h**:凌晨 26h 前的失败不能在人睡觉时漏窗。
  static const String failuresSince = '168h';
}
