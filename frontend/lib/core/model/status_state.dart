/// Status translation — the single source that folds the backend's many status strings into the
/// 5 universal states a status dot / badge speaks (port of demo `config/state-model.js`). A domain
/// status ("running", "parked", "degraded"…) maps through [AnStatus.fromRaw] to one of
/// idle/run/wait/err/done, and each state carries a semantic [AnTone] so a badge never re-derives
/// colour with its own if-ladder. Pure Dart — no Flutter, no colour: the tone is a meaning; the
/// widget layer maps tone → token colour. Labels are NOT here (they go through i18n).
///
/// 状态翻译单源——把后端五花八门的状态字串折成状态点/徽章说的 5 通用态(移植 state-model.js)。任意域状态
/// 经 fromRaw → idle/run/wait/err/done,每态带语义 tone,徽章不再各写 if 链。纯 Dart、无色:tone 是含义,
/// widget 层映射 tone→token 色。标签不在此(走 i18n)。
library;

/// The 5 universal status states a [AnStatus] dot speaks. 状态点的 5 通用态。
enum AnStatus {
  idle,
  run,
  wait,
  err,
  done;

  /// Fold any backend status string into a universal state. Direct names win; then the alias
  /// table; unknown → [idle]. 任意后端状态字串 → 通用态:先直名、后别名表、未知 → idle。
  static AnStatus fromRaw(String? raw) {
    final k = (raw ?? '').toLowerCase();
    for (final s in AnStatus.values) {
      if (s.name == k) return s;
    }
    return _alias[k] ?? AnStatus.idle;
  }

  /// The semantic tone this state maps to (idle is neutral → [AnTone.none]).
  /// 该态映射的语义 tone(idle 中性 → none)。
  AnTone get tone => switch (this) {
    AnStatus.err => AnTone.danger,
    AnStatus.wait => AnTone.warn,
    AnStatus.done => AnTone.ok,
    AnStatus.run => AnTone.accent,
    AnStatus.idle => AnTone.none,
  };

  // Domain status string → universal state (the demo's STATE_MODEL.ALIAS). 域状态 → 通用态。
  static const Map<String, AnStatus> _alias = {
    'running': AnStatus.run,
    'crashed': AnStatus
        .err, // handler runtime — a dead resident process (events.md handler.crashed)
    'stopped': AnStatus.idle,
    'completed': AnStatus.done,
    'failed': AnStatus.err,
    'ready': AnStatus
        .done, // env/config ready (function envStatus, handler configState)
    'syncing': AnStatus.run, // function env materializing
    'partially_configured':
        AnStatus.wait, // handler missing some required config
    'unconfigured': AnStatus.idle,
    'cancelled': AnStatus.idle,
    'parked': AnStatus.wait,
    'active': AnStatus.done,
    'inactive': AnStatus.idle,
    'draining': AnStatus.wait,
    'listening': AnStatus.run,
    'fired': AnStatus.done,
    'started': AnStatus
        .done, // trigger firing terminal-ok (trigger.md — a fired run that launched)
    'pending': AnStatus.wait,
    'waiting': AnStatus.wait,
    'claimed':
        AnStatus.wait, // trigger firing in-flight (claim-transaction transient)
    'ok': AnStatus.done,
    'error': AnStatus.err,
    'timeout': AnStatus
        .err, // exec/call Log-table failure terminal (CHECK lists it beside failed/cancelled)
    'future': AnStatus.idle,
    // Trigger firing bypass dispositions — NEUTRAL non-executions, never red (a skipped debounce or a
    // superseded fire is bookkeeping, not an error; WRK-069 状态学「未执行」桶). `missed` (工单⑨) is the
    // misfire ledger: a cron tick that came due while the app slept, booked on wake WITHOUT a catch-up
    // run — the machine oversleeping is a desktop app's first reality, not a failure. Declared here
    // rather than left to the unknown→idle fallback: idle is the DECISION for these four, and a
    // decision must be readable in the table (the fallback is for words we've never met).
    // firing 旁路处置=中性未执行,绝不染红(六桶之「未执行」);missed=睡过头的 cron 刻度醒来记账、不补跑。
    // 四词显式入表而非靠 unknown→idle 兜底:idle 是对它们的**裁决**,裁决须在表里读得出(兜底只给没见过的词)。
    'skipped': AnStatus.idle,
    'superseded': AnStatus.idle,
    'shed': AnStatus.idle,
    'missed': AnStatus.idle,
  };
}

/// Semantic tone — a MEANING, not a colour. The widget layer binds each to a token colour
/// (ok→ok, warn→warn, danger→danger, accent→ink emphasis, none→neutral chrome).
/// 语义 tone——含义而非色;widget 层各绑一个 token 色(accent=墨强调,none=中性 chrome)。
enum AnTone { none, ok, warn, danger, accent }
