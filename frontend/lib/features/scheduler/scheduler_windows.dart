/// Every statistics window the Scheduler ocean speaks, in ONE place (WRK-069 §8 窗口立法).
///
/// Surfaces each quoting their own window IS the «乱» this ocean exists to prevent: a matrix page of
/// 50, a 7d failure roll-up and a 24h KPI tile are different questions, and a reader who cannot tell
/// which is which cannot trust any of them. So the values live here, named, and the i18n sentences
/// that render them carry the window word EXPLICITLY (`home.statsLine($window,…)`) — never a bare
/// percentage whose window the reader has to guess. (The old bead-10/matrix-20 windows died with the
/// 0717 主页重建: the operations home's matrix + table now share the page-level AnTimeRange lens.)
///
/// Deliberately NOT `core/`: §8 said «(core)», but core is what features SHARE, and nothing outside
/// this feature reads these — a scheduler-only table parked in core is exactly the pollution the law
/// was written against. Recorded as a placement deviation (S4 偏差① set the precedent: put it where it
/// honestly belongs, record it). Where the backend shares a bound (matrixPageSize == the flowrun-matrix
/// ids cap of 50) it pins its own constant independently — a shared decision, not a shared import.
///
/// scheduler 海洋说的每一个统计窗口,单源于此(§8 窗口立法)。各面各说各话本身即「乱」——矩阵页 50、
/// 失败 7d、KPI 24h 是不同的问题,读者分不清哪个是哪个就一个也信不了(旧珠串 10/矩阵 20 窗随 0717 主页
/// 重建死去:运营主页矩阵+大表共用页级 AnTimeRange 镜头)。故值具名住在这里,
/// 且渲它们的 i18n 句**显式含窗口词**,绝不给一个让读者猜窗口的裸百分比。**刻意不放 core**:§8 原话是
/// (core),但 core 是 features **共享**之物、本 feature 之外无人读这些——把 scheduler 专用表停在 core
/// 正是此法要防的污染(记放置偏差,S4 偏差① 先例:放它诚实该在的地方并记档)。后端对共享的界
/// (matrixPageSize==flowrunIds 批帽 50)独立钉自己的常量——共享的是**决定**,不是 import。
library;

abstract final class SchedulerWindows {
  /// One matrix page — how many runs each slide toward the oldest edge pulls in (主页重建拍板
  /// 0717): pages ride `GET /flowruns` and each page's grid is ONE `flowrun-matrix?flowrunIds=`
  /// batch, whose backend cap is 50 — page size == batch cap, one page is one batch, never split.
  /// 矩阵一页=一次向最旧缘滑动拉入的 run 数:页走 GET /flowruns、每页格阵恰一次 flowrunIds 批查
  /// (后端上限 50)——页尺=批帽,一页一批、绝不拆。
  static const int matrixPageSize = 50;

  /// Success rate / average elapsed — a 7d rolling window (`flowrun-stats?since=`). Wire grammar is
  /// a Go duration, so 7d is spelled in hours. 成功率/均时=7d 滚动(线缆走 Go duration 文法,故写小时)。
  static const String statsSince = '168h';


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

  /// The track's past grid, in WHOLE-HOUR bins (0718 v2 拍板「都弄整个小时的」): 25 cells = 24 complete
  /// hours + the in-progress one. 25, not 24, is the ✕-completeness invariant reborn (工单⑭/判决⑥ 的
  /// 本意): the 「错过 N」 card counts a ROLLING 24h window, whole-hour cells are up to 59min offset
  /// from it — 25 whole hours are a superset of ANY rolling 24h window, so a tick the card counts can
  /// never be off the grid of the very surface its click opens. [trackFetchWindow] is the matching
  /// data lower bound (runs + firings must be fetched at least this far back).
  /// 轨的过去格=**整点**分箱:25 格=24 完整小时+进行中那格。取 25 不取 24 是 ✕ 完整性不变式的新形态
  /// (牌数**滚动** 24h 窗,整点格与它最多错开 59 分钟——25 个整点小时是任意滚动 24h 窗的**超集**,牌数进去
  /// 的刻度绝不会落在它点开的那个面的格外)。[trackFetchWindow]=配套取数下界。
  static const int trackBinCount = 25;
  static const Duration trackFetchWindow = Duration(hours: trackBinCount);

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
