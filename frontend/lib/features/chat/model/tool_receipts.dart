/// Receipt parsers — pure functions that turn a tool's RAW output string into the collapsed
/// line's dimmed receipt (the "proof" that makes past tense trustworthy: line counts, match
/// counts, exit codes). Each is pinned to the backend's EXACT output format; when a format
/// doesn't match, the receipt silently defaults to none — a receipt must never guess.
///
/// 回执解析器——纯函数:把工具**原始输出串**变成收起行的灰回执(让过去时可信的「凭据」:行数/
/// 命中数/exit code)。逐个钉死后端**精确**输出格式;不匹配即静默无回执——回执绝不猜。
library;

import 'dart:convert';

import '../../../i18n/strings.g.dart';

/// The receipt tone — the collapsed row's dimmed suffix carries one of three voices:
///   none   — neutral proof (line/match counts, exit 0): inkFaint;
///   warn   — a soft half-state (env building, draining, not-activated, truncated): amber;
///   danger — a failure the user should see (non-zero exit, timeout, env failed): red, and the
///            chassis AUTO-EXPANDS the card once (warn never auto-expands — a soft state ≠ failure).
/// 回执三声:none 中性凭据(inkFaint)/ warn 软半态(琥珀,不自动展开)/ danger 失败(红,自动展开一次)。
enum ToolReceiptTone { none, warn, danger }

/// A parsed receipt: the suffix text (already localized by the caller's formatter) + its tone.
/// 解析结果:后缀文本(调用方已本地化)+ 声调。
typedef ToolReceipt = ({String text, ToolReceiptTone tone});

/// Replace the stable backend validation wrapper with a localized, actionable sentence. The raw
/// result remains in the durable block and LLM wire; only the human-facing projection is softened
/// so internal field names and framework phrasing never become the product's error copy (E1).
/// 把后端稳定的校验包装替换为本地化、可行动的人话。原始结果仍保留在 durable block 与 LLM 线缆，
/// 只有面向人的投影变柔和，内部字段名和框架措辞不进入产品错误文案(E1)。
String toolErrorForDisplay(Translations t, String raw) {
  if (raw.trimLeft().startsWith('input validation failed:')) {
    return t.chat.tool.inputValidationError;
  }
  return raw;
}

/// Bash (verified backend/…/shell/bash.go): the foreground result ALWAYS ends `[exit code: N]`,
/// optionally preceded by a bracketed NOTE (`[command timed out after 2m0s]` / `[cancelled]` /
/// `[exec failed: …]` / `[blocked: … (refused; rephrase if intentional)]`). A background spawn instead
/// says `Started background command (bash_id=bsh_…): cmd`. Bash:前台恒尾缀 exit code、其前可有括号 note;
/// 后台=Started background command。
final RegExp _bashExit = RegExp(r'\[exit code: (-?\d+)\]\s*$');
final RegExp _bashTimeout = RegExp(r'\[command timed out after [^\]]+\]');
final RegExp _bashBlocked = RegExp(r'\[blocked: .*\(refused');
final RegExp _bashCancelled = RegExp(r'\[cancelled\]');
final RegExp _bashBackground = RegExp(
  r'Started background command \(bash_id=(bsh_[0-9a-f]+)\)',
);
const String _toolResultTrunc = '[tool result truncated:';

/// The Bash receipt with NOTE PRIORITY (cancel/timeout/block all close exit -1, so the note must be
/// read BEFORE the exit code or -1 mis-reads as a plain failure): background > double-cap > blocked >
/// timeout > cancelled > exit. cancelled = muted (never auto-expands, aligned with the chassis cancel
/// phase); a non-zero exit (no note) = danger. 带 note 优先级的 Bash 回执。
ToolReceipt? bashReceipt(
  String output, {
  required String Function(int code) exitLabel,
  required String timedOutLabel,
  required String blockedLabel,
  required String cancelledLabel,
  required String exitUnknownLabel,
  required String Function(String bashId) backgroundLabel,
}) {
  final bg = _bashBackground.firstMatch(output);
  if (bg != null) {
    return (text: backgroundLabel(bg.group(1)!), tone: ToolReceiptTone.none);
  }
  // Double-cap collision: the general tool-result cap ate Bash's own footer → the exit is truly
  // unknown (the content, not the exit, is what got dropped). 双 cap 冲突:footer 被砍→exit 未知。
  if (output.contains(_toolResultTrunc)) {
    return (text: exitUnknownLabel, tone: ToolReceiptTone.warn);
  }
  final m = _bashExit.firstMatch(output);
  if (m == null) return null;
  final code = int.parse(m.group(1)!);
  if (_bashBlocked.hasMatch(output)) {
    return (text: blockedLabel, tone: ToolReceiptTone.danger);
  }
  if (_bashTimeout.hasMatch(output)) {
    return (text: timedOutLabel, tone: ToolReceiptTone.danger);
  }
  if (_bashCancelled.hasMatch(output)) {
    return (text: cancelledLabel, tone: ToolReceiptTone.none);
  }
  return (
    text: exitLabel(code),
    tone: code != 0 ? ToolReceiptTone.danger : ToolReceiptTone.none,
  );
}

/// BashOutput (verified …/shell/output.go): a poll returns new output (or `(no new output since last
/// poll)`) + an optional `[note: N bytes dropped …]` + a status footer `[status: running|exited (code
/// N)|killed|errored]`; a dead session says «not found: id». HONESTY: status
/// is a poll-time snapshot — `exited`/`errored` are DANGER but NEVER auto-expand (a dead process returns
/// the same status every poll; only «session not found» auto-expands). BashOutput 状态回执:轮询时点快照。
final RegExp _bashStatus = RegExp(
  r'\[status: (running|exited \(code (-?\d+)\)|killed|errored)\]\s*$',
);
ToolReceipt? statusReceipt(
  String output, {
  required String running,
  required String Function(int code) exited,
  required String killed,
  required String errored,
  required String notFound,
}) {
  if (output.startsWith('Background shell process not found')) {
    return (text: notFound, tone: ToolReceiptTone.danger);
  }
  final m = _bashStatus.firstMatch(output);
  if (m == null) return null;
  final s = m.group(1)!;
  if (s == 'running') return (text: running, tone: ToolReceiptTone.none);
  if (s == 'killed') return (text: killed, tone: ToolReceiptTone.none);
  if (s == 'errored') return (text: errored, tone: ToolReceiptTone.danger);
  return (
    text: exited(int.parse(m.group(2)!)),
    tone: ToolReceiptTone.danger,
  ); // exited (code N)
}

/// KillShell's result is the verb, not a second receipt. The backend is deliberately idempotent:
/// a live process is killed, an already-finished process is a no-op, and an unknown id is harmless.
/// Keep those three facts in the primary line so it never says «Terminated» beside «session not found».
/// KillShell 的结果本身就是动词,不再叠加第二条回执。后端刻意幂等:运行中=终止,已结束=无操作,
/// 未知 id=无害。三种事实直接进入主行,避免「已终止」旁边又写「会话不存在」的语义冲突。
String killShellTerminalVerb(Translations t, String output) {
  final value = output.trimRight();
  if (value.contains('already finished')) return t.chat.tool.killFinished;
  if (value.startsWith('Background shell process not found')) {
    return t.chat.tool.killNotFound;
  }
  return t.chat.tool.killed3;
}

/// The fs error KIND — every Read/Write/Edit error (and the shared PathGuard / fspath prefixes) is a
/// normal (err==nil) tool_result STRING, classified here into one honest category (the caller maps it
/// to a localized danger receipt). null = not a recognized fs error. fs 错误分类(纯,i18n 归调用方)。
enum FsErrorKind {
  notFound, // File not found / Cannot access / Path is a directory
  denied, // Permission denied / path is denied by safety guard
  readFirst, // must be read first (Write/Edit guard)
  noMatch, // old_string not found
  ambiguous, // Found N matches, replace_all is false
  modified, // File has been modified since last read
  parentMissing, // Parent directory does not exist / not a directory
  badPath, // path must be absolute / required / cannot expand ~
  failed, // Write failed / Edit failed / Failed to read
}

final RegExp _fsAmbiguous = RegExp(r'^Found (\d+) match');

/// Classify an fs error string into a [FsErrorKind] (+ the ambiguity count for [FsErrorKind.ambiguous]).
/// Pinned to the backend's EXACT prefixes (census). null = not an fs error → not a danger receipt.
/// fs 错误分类:钉后端精确前缀;未识别→null。
({FsErrorKind kind, int n})? fsErrorKind(String output) {
  final s = output.trimLeft();
  if (s.startsWith('old_string not found')) {
    return (kind: FsErrorKind.noMatch, n: 0);
  }
  final m = _fsAmbiguous.firstMatch(s);
  if (m != null) {
    return (kind: FsErrorKind.ambiguous, n: int.parse(m.group(1)!));
  }
  if (s.contains('must be read first') ||
      s.startsWith('Cannot verify Read-first guard')) {
    return (kind: FsErrorKind.readFirst, n: 0);
  }
  if (s.contains('has been modified since last read')) {
    return (kind: FsErrorKind.modified, n: 0);
  }
  if (s.startsWith('File not found') ||
      s.startsWith('Cannot access') ||
      s.startsWith('Path is a directory')) {
    return (kind: FsErrorKind.notFound, n: 0);
  }
  if (s.startsWith('Permission denied') ||
      s.startsWith('path is denied by safety guard')) {
    return (kind: FsErrorKind.denied, n: 0);
  }
  if (s.startsWith('Parent directory does not exist') ||
      s.startsWith('Parent path exists but is not')) {
    return (kind: FsErrorKind.parentMissing, n: 0);
  }
  if (s.startsWith('path must be absolute') ||
      s.startsWith('path is required') ||
      s.startsWith('cannot expand ~')) {
    return (kind: FsErrorKind.badPath, n: 0);
  }
  if (s.startsWith('Write failed') ||
      s.startsWith('Edit failed') ||
      s.startsWith('Failed to read')) {
    return (kind: FsErrorKind.failed, n: 0);
  }
  return null;
}

/// Read: cat -n lines (`%5d\t…`), optionally ending with the truncation footer
/// `... [truncated at line N; use offset+limit to read more]`. The FOUR-QUADRANT receipt (census): by
/// first line F (1 vs >1) × truncated (no vs yes) → `L 行` / `行 F–L` / `N+ 行` / `行 F–N+`. Read 四象限。
/// Read:cat -n 行 + 截断 footer;四象限回执(首行 F × 是否截断)。
final RegExp _readTruncated = RegExp(r'\.\.\. \[truncated at line (\d+);');
final RegExp _readLine = RegExp(r'^\s*(\d+)\t', multiLine: true);

ToolReceipt? readReceipt(
  String output, {
  required String Function(int lastLine) lines, // F==1, no trunc
  required String Function(int firstLine, int lastLine) range, // F>1, no trunc
  required String Function(int floorLine) linesFloor, // F==1, trunc → N+
  required String Function(int firstLine, int floorLine)
  rangeFloor, // F>1, trunc
}) {
  final matches = _readLine.allMatches(output).toList();
  if (matches.isEmpty) {
    return null; // not file content (directory hint / error prose) 非文件内容
  }
  final first = int.parse(matches.first.group(1)!);
  final trunc = _readTruncated.firstMatch(output);
  if (trunc != null) {
    final floor = int.parse(trunc.group(1)!);
    return (
      text: first == 1 ? linesFloor(floor) : rangeFloor(first, floor),
      tone: ToolReceiptTone.none,
    );
  }
  final last = int.parse(matches.last.group(1)!);
  return (
    text: first == 1 ? lines(last) : range(first, last),
    tone: ToolReceiptTone.none,
  );
}

/// Grep / Glob / LS: count-style receipts. "No matches for …" is the backend's honest empty;
/// a `[truncated at N …]` marker means the count is a floor ("N+"). Grep emits THREE markers by mode —
/// `N lines` (content), `N files` (files_with_matches), `N matches` (count) — all mean truncated, so
/// the receipt must recognize every unit. 检索族计数回执:三种截断单位(lines/files/matches)都算下界 N+。
final RegExp _capTruncated = RegExp(
  r'\[truncated at (\d+) (?:lines|files|matches)',
);

ToolReceipt? countReceipt(
  String output, {
  required String Function(String) countLabel,
  required String noneLabel,
}) {
  final trimmed = output.trimRight();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('No matches for') ||
      trimmed.startsWith('No files') ||
      trimmed.startsWith('Cannot access') ||
      trimmed.startsWith('Invalid glob')) {
    return trimmed.startsWith('No ')
        ? (text: noneLabel, tone: ToolReceiptTone.none)
        : null;
  }
  final lines = trimmed.split('\n').where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return null;
  if (_capTruncated.hasMatch(trimmed)) {
    final n = lines.length - 1; // marker line itself 截断行自身不计
    return (text: countLabel('$n+'), tone: ToolReceiptTone.none);
  }
  return (text: countLabel('${lines.length}'), tone: ToolReceiptTone.none);
}

/// A parsed F07 entity-search result (WRK-056 §F07.5) — count + optional total + the hit rows. BOTH
/// the collapsed receipt ([searchReceipt]) and the ToolHitList body read this ONE extractor.
/// 一次 F07 搜索结果反解:count + 可选 total + 命中行。回执与命中窗同读此一处。
typedef SearchHits = ({
  int count,
  int? total,
  List<Map<String, dynamic>> items,
});

/// Parse a search tool's JSON output, tolerant of BOTH wire shapes it emits (the shape is probed by
/// KEY EXISTENCE, never by guessing which path ran):
///   • content-engine path `{count, total, <listKey>:[...], nextCursor?, hasMore?}` (has `total`);
///   • substring-fallback path `{count, <listKey>:[...]}` (no `total`).
/// nil-slice defense (F170-class): `{count:0, <listKey>:null}` (a Go nil slice) or the key absent is
/// a VALID empty — `count==0` wins. But `count>0` with a missing/empty list is a BROKEN shape → null
/// (a parse-miss the caller degrades on, never a phantom count). null also on no-JSON / no int `count`.
/// 双形状(键存在性探测)+ null 列表防御:count==0 即有效空;count>0 但列表缺失=坏形状→null。
SearchHits? parseSearchHits(String output, String listKey) {
  final trimmed = output.trimRight();
  if (trimmed.isEmpty) return null;
  Map<String, dynamic>? d;
  try {
    final p = jsonDecode(trimmed);
    if (p is Map<String, dynamic>) d = p;
  } catch (_) {}
  if (d == null) return null;
  final count = d['count'];
  if (count is! int) return null; // no parseable count → don't guess 无 count→不猜
  final total = d['total'] is int ? d['total'] as int : null;
  final raw = d[listKey];
  final items = raw is List
      ? raw.whereType<Map<String, dynamic>>().toList()
      : const <Map<String, dynamic>>[];
  if (count > 0 && items.isEmpty) {
    return null; // count claims hits but no list → broken shape 坏形状
  }
  return (count: count, total: total, items: items);
}

/// The F07 entity-search collapsed-row receipt — `N` / `N·共M` (server-truncated) / empty. Reads
/// [parseSearchHits] (double-shape, nil-slice safe); a known soft-empty string ("No blocks matched …",
/// search_blocks) also → empty; anything else unparseable → null (never guess). count==0 → the honest
/// empty label (the family's core empty state is «receipt IS the card» — it must never fall through to
/// a generic empty window). F07 搜索回执:N / N·共M / 空;软空串也判空;解析不中→无回执。
ToolReceipt? searchReceipt(
  String output, {
  required String listKey,
  required String Function(int n) hits,
  required String Function(int n, int total) hitsOfTotal,
  required String empty,
}) {
  if (output.trimRight().startsWith('No blocks matched')) {
    return (text: empty, tone: ToolReceiptTone.none);
  }
  final h = parseSearchHits(output, listKey);
  if (h == null) return null;
  if (h.count == 0) return (text: empty, tone: ToolReceiptTone.none);
  if (h.total != null && h.total! > h.count) {
    return (text: hitsOfTotal(h.count, h.total!), tone: ToolReceiptTone.none);
  }
  return (text: hits(h.count), tone: ToolReceiptTone.none);
}

// ══ F05 lifecycle receipt parsers (WRK-056 §F05) — the thin cards' honest ledger ══

// Memoized decode (C-005): the lifecycle receipt parsers each `_obj(output)` the SAME settled result
// string, and settled cards re-render on the 1s ticker + inside live turns — so without a cache a KB~百KB
// result JSON re-parses every frame, N cards × per frame. A decoded value for a given string is immutable
// (same string → same tree), so the cache never needs invalidation; a FIFO bound keeps it small. 记忆化
// 解码:同一 settled 结果串每帧重解析(ticker/live 回合重建);解码对给定串不可变故无需失效,FIFO 有界。
final _objCache = <String, Map<String, dynamic>?>{};

Map<String, dynamic>? _obj(String s) {
  final hit = _objCache[s];
  if (hit != null || _objCache.containsKey(s)) return hit;
  Map<String, dynamic>? r;
  try {
    final d = jsonDecode(s);
    if (d is Map<String, dynamic>) r = d;
  } catch (_) {}
  if (_objCache.length >= 64) {
    _objCache.remove(_objCache.keys.first); // FIFO cap 有界
  }
  _objCache[s] = r;
  return r;
}

/// revert — `⤺ v{version}` from `{…, version}` (agent's key is the same `version`). null if no int
/// version. revert 倒带徽标。
ToolReceipt? revertReceipt(
  String output, {
  required String Function(int v) rewind,
}) {
  final v = _obj(output)?['version'];
  return v is int ? (text: rewind(v), tone: ToolReceiptTone.none) : null;
}

/// A delete's dependency annotation — the impact ledger: N refs + their {kind,id}. Parsed from BOTH
/// the JSON form (`dependents:[{kind,id}], dependentCount`) and delete_agent's STRING tail
/// (`… [ag_1 fn_2 …]` — kinds derived from the S15 id prefix, unknown → '?'). 删除依赖注解(双形)。
typedef Dependents = ({int count, List<({String kind, String id})> refs});

/// The S15 id-prefix → EntityKind wire table (database.md registry — compile-time, not guessed). id 前缀表。
const Map<String, String> _prefixKind = {
  'fn': 'function',
  'hd': 'handler',
  'ag': 'agent',
  'wf': 'workflow',
  'ctl': 'control',
  'apf': 'approval',
  'trg': 'trigger',
  'doc': 'document',
};

String _kindOfId(String id) {
  final us = id.indexOf('_');
  if (us <= 0) return '?';
  return _prefixKind[id.substring(0, us)] ?? '?';
}

/// Parse the JSON-form dependents. delete JSON 形依赖。
Dependents? parseDependents(String output) {
  final o = _obj(output);
  if (o == null) return null;
  final raw = o['dependents'];
  if (raw is! List) return null;
  final refs = <({String kind, String id})>[];
  for (final d in raw) {
    if (d is Map) {
      final id = '${d['id'] ?? ''}';
      if (id.isEmpty) continue;
      refs.add((kind: '${d['kind'] ?? _kindOfId(id)}', id: id));
    }
  }
  final count = o['dependentCount'] is int
      ? o['dependentCount'] as int
      : refs.length;
  return (count: count, refs: refs);
}

/// Parse delete_agent's STRING tail `… [ag_1 fn_2 …]` (kinds derived from the S15 prefix). 字符串形依赖。
Dependents? parseAgentDependents(String output) {
  // delete_agent now returns the same structured dependency shape as the other delete tools.
  // Keep the legacy string-tail parser for old transcripts and imported showcase data.
  final decoded = _obj(output);
  if (decoded != null) return parseDependents(output);
  final m = RegExp(r'\[([^\]]*)\]').firstMatch(output);
  if (m == null) return null;
  final ids = m
      .group(1)!
      .split(RegExp(r'[,\s]+'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (ids.isEmpty) return null;
  return (
    count: ids.length,
    refs: [for (final id in ids) (kind: _kindOfId(id), id: id)],
  );
}

/// delete (JSON) — `已删除` / `已删除 · N 处引用受影响` (danger when refs exist → the impact ledger
/// opens). deleteFn accepts the whole output; agentForm reads the string tail. 删除回执(有依赖→danger)。
ToolReceipt? deleteReceipt(
  String output, {
  required String deleted,
  required String Function(int n) affected,
  bool agentForm = false,
}) {
  final o = _obj(output);
  // Success signal: JSON `{deleted:...}` or the agent string mentioning deletion. 删除成功信号。
  final isJsonDelete = o != null && (o['deleted'] != null || o['id'] != null);
  final dep = agentForm
      ? parseAgentDependents(output)
      : parseDependents(output);
  if (dep != null && dep.count > 0) {
    return (text: affected(dep.count), tone: ToolReceiptTone.danger);
  }
  if (isJsonDelete || (agentForm && output.isNotEmpty)) {
    return (text: deleted, tone: ToolReceiptTone.none);
  }
  return null;
}

/// delete_document soft/success STRING template (census 06). 文档删除模板。
final RegExp _docDescendants = RegExp(r'along with (\d+) descendant');
ToolReceipt? deletedDocReceipt(
  String output, {
  required String deleted,
  required String Function(int n) withDescendants,
}) {
  final t = output.trimRight();
  final m = _docDescendants.firstMatch(t);
  if (m != null) {
    return (
      text: withDescendants(int.parse(m.group(1)!)),
      tone: ToolReceiptTone.warn,
    );
  }
  if (t.startsWith('Deleted document')) {
    return (text: deleted, tone: ToolReceiptTone.warn);
  }
  return null;
}

/// delete_document returns a completed sentence for a missing tombstone, so the card must
/// reclassify that payload instead of trusting the transport status. 文档不存在是软失败。
bool deletedDocumentResultFailed(String output) {
  final t = output.trimLeft();
  return RegExp(r'^Document "[^"]+" not found').hasMatch(t);
}

/// move_document — `→ {new path}` from `… (new path: <path>).`. move 回执=新家地址。
final RegExp _movedPath = RegExp(r'new path:\s*([^)]+)\)');
ToolReceipt? movedReceipt(
  String output, {
  required String Function(String path) toPath,
}) {
  final m = _movedPath.firstMatch(output);
  return m == null
      ? null
      : (text: toPath(m.group(1)!.trim()), tone: ToolReceiptTone.none);
}

/// kill_workflow — `杀停 N 个在途运行` (danger, N>0) / `无在途运行` (none). kill 回执。
ToolReceipt? killReceipt(
  String output, {
  required String Function(int n) killedN,
  required String none,
}) {
  final n = _obj(output)?['killed'];
  if (n is! int) return null;
  return n > 0
      ? (text: killedN(n), tone: ToolReceiptTone.danger)
      : (text: none, tone: ToolReceiptTone.none);
}

/// restart_handler — the `runtimeState` word (running none / stopped warn / crashed danger); the
/// `error` key is the «green but broken» signal. restart 回执。
ToolReceipt? restartReceipt(
  String output, {
  required String Function(String state) label,
  required String Function(String error) errored,
}) {
  final o = _obj(output);
  if (o == null) return null;
  // Surface the ACTUAL error (the «green but broken» reason), not a generic "restart failed" label —
  // otherwise the failure cause is invisible (thin action card, no body). 渲真实错因、非通用「重启失败」。
  final err = (o['error'] as String?)?.trim();
  if (err != null && err.isNotEmpty) {
    return (text: errored(err), tone: ToolReceiptTone.danger);
  }
  final rs = o['runtimeState'] as String?;
  if (rs == null) return null;
  return (
    text: label(rs),
    tone: rs == 'crashed'
        ? ToolReceiptTone.danger
        : (rs == 'running' ? ToolReceiptTone.none : ToolReceiptTone.warn),
  );
}

/// Tolerant mid-stream arg extraction: pull a string field out of a (possibly PARTIAL) args
/// JSON fragment so the collapsed line can name its target while args are still streaming.
/// HAND-ROLLED, not a regex: a backtracking capture group (`((?:[^"\\]|\\.)*)`) STACK-OVERFLOWS the
/// Dart regex engine on MB-scale values (found live on the W0 1MB pressure bed) — the scan below is
/// O(n) with zero recursion. Only a CLOSED value is returned.
/// 容忍式流中参数提取(收起行在流入期就能点名目标)。**手写扫描、非正则**:回溯捕获组在 MB 级值上
/// 会把 Dart 正则引擎干爆栈(W0 1MB 压力床真机实锤)——此实现 O(n) 零递归。只接受闭合值。
String? argString(String argsFragment, String key) {
  final start = _argValueStart(argsFragment, key);
  if (start < 0) return null;
  final buf = StringBuffer();
  var escaped = false;
  for (var i = start; i < argsFragment.length; i++) {
    final ch = argsFragment[i];
    if (escaped) {
      buf.write(switch (ch) {
        'n' => '\n',
        't' => '\t',
        _ => ch,
      });
      escaped = false;
    } else if (ch == r'\') {
      escaped = true;
    } else if (ch == '"') {
      return buf.toString(); // closing quote — a complete value 闭合值
    } else {
      buf.write(ch);
    }
  }
  return null; // ran off the end — still streaming (argStringPartial's business) 未闭合归 partial 管
}

// The index just past `"key" <ws> : <ws> "` — the string value's first char; -1 when the pattern
// never occurs. Skips non-value occurrences of `"key"` honestly. 值起点定位(跳过非取值形态的同名串)。
int _argValueStart(String argsFragment, String key) {
  final anchor = '"$key"';
  var from = 0;
  while (true) {
    final at = argsFragment.indexOf(anchor, from);
    if (at < 0) return -1;
    var i = at + anchor.length;
    while (i < argsFragment.length && _isJsonWs(argsFragment.codeUnitAt(i))) {
      i++;
    }
    if (i < argsFragment.length && argsFragment.codeUnitAt(i) == 0x3a) {
      i++;
      while (i < argsFragment.length && _isJsonWs(argsFragment.codeUnitAt(i))) {
        i++;
      }
      if (i < argsFragment.length && argsFragment.codeUnitAt(i) == 0x22) {
        return i + 1;
      }
    }
    from = at + 1;
  }
}

bool _isJsonWs(int c) => c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d;

/// Like [argString] but ALSO accepts a still-open value: when the closing quote hasn't
/// streamed in yet, returns everything emitted so far — the builds family streams its code
/// window with this (the whole point of "全系统最强流式").
///
/// 同 [argString] 但**接受未闭合值**:收尾引号未到时返已流入的全部——builds 族靠它流代码窗
/// (「全系统最强流式」的落点)。
String? argStringPartial(String argsFragment, String key) {
  final closed = argString(argsFragment, key);
  if (closed != null) return closed;
  final start = _argValueStart(argsFragment, key);
  if (start < 0) return null;
  final buf = StringBuffer();
  var escaped = false;
  for (var i = start; i < argsFragment.length; i++) {
    final ch = argsFragment[i];
    if (escaped) {
      buf.write(switch (ch) {
        'n' => '\n',
        't' => '\t',
        _ => ch,
      });
      escaped = false;
    } else if (ch == r'\') {
      escaped = true;
    } else if (ch == '"') {
      break; // closed after all (argString would have caught it, but be safe) 已闭合兜底
    } else {
      buf.write(ch);
    }
  }
  final v = buf.toString();
  return v.isEmpty ? null : v;
}

/// The last [n] lines of [text] WITHOUT splitting the whole string — live windows call this every
/// frame on possibly-MB-scale streaming content, so it must be O(tail), not O(text) (WRK-061 W0).
/// 取末 n 行且不整段 split——活窗每帧调、内容可 MB 级,必须 O(tail) 而非 O(全文)。
String tailLines(String text, int n) {
  if (text.isEmpty || n <= 0) return '';
  var idx = text.length;
  for (var remaining = n; remaining > 0 && idx > 0; remaining--) {
    final nl = text.lastIndexOf('\n', idx - 1);
    if (nl < 0) return text; // fewer than n lines — whole text 不足 n 行,给全文
    idx = nl;
  }
  return text.substring(idx + 1);
}

/// Parse a JSON string-array arg (e.g. ask_user's `options`) from a COMPLETE args fragment. Returns
/// empty on absence / malformed / non-list (never guesses). 从完整 args 解析字符串数组(缺/畸形→空,不猜)。
List<String> argStringList(String argsFragment, String key) {
  try {
    final decoded = jsonDecode(argsFragment);
    if (decoded is Map && decoded[key] is List) {
      return [for (final e in decoded[key] as List) e.toString()];
    }
  } catch (_) {}
  return const [];
}

/// Path → basename for the target chip (full path belongs in a tooltip).
/// 路径 → basename 作目标 chip(全路径归 tooltip)。
String pathBasename(String path) {
  final trimmed = path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  final i = trimmed.lastIndexOf('/');
  return i < 0 ? trimmed : trimmed.substring(i + 1);
}

/// Command → first line, collapsed whitespace (the chip is one line always).
/// 命令 → 首行、折叠空白(chip 恒单行)。
String commandChip(String command) {
  final first = command.split('\n').first.trim();
  return first.replaceAll(RegExp(r'\s+'), ' ');
}

/// generate_image — the generation receipt (backend `tool/generate/image.go`, exact keys pinned):
/// `{attachmentId, filename, mime, sizeBytes, provider, aspect, source:"generate_image",
/// model?, width?, height?}`. Null unless `source` matches and `attachmentId` is a non-empty
/// string — receipts never guess (file-header contract).
///
/// generate_video——生成回执(后端 `tool/generate/video.go`)。`seconds` 是**真正做出来**的长度、
/// 不是被请求的那个(路由会把超上限的请求钳到它做得到的长度)。
({
  String attachmentId,
  String? mime,
  String? filename,
  int? sizeBytes,
  int? seconds,
  String? aspect,
  String? provider,
  String? model,
  String? source,
  String? sourceAttachmentId,
})?
parseGeneratedVideo(String? output) {
  if (output == null || output.isEmpty) return null;
  final o = _obj(output);
  final source = o?['source'];
  if (o == null || (source != 'generate_video' && source != 'animate_image')) {
    return null;
  }
  final id = o['attachmentId'];
  if (id is! String || id.isEmpty) return null;
  return (
    attachmentId: id,
    mime: o['mime'] is String ? o['mime'] as String : null,
    filename: o['filename'] is String ? o['filename'] as String : null,
    sizeBytes: (o['sizeBytes'] is num) ? (o['sizeBytes'] as num).toInt() : null,
    seconds: (o['seconds'] is num) ? (o['seconds'] as num).toInt() : null,
    aspect: o['aspect'] is String ? o['aspect'] as String : null,
    provider: o['provider'] is String ? o['provider'] as String : null,
    model: o['model'] is String ? o['model'] as String : null,
    source: source is String ? source : null,
    sourceAttachmentId: o['sourceAttachmentId'] is String
        ? o['sourceAttachmentId'] as String
        : null,
  );
}

/// generate_speech——朗读/合成回执(后端 `tool/generate/speech.go`)。与图像回执同一条律:source
/// 不符或 attachmentId 空即 null——回执绝不猜。文件名/大小/时长是卡片在附件行到达前可用的
/// 事实提示；durationMs 为 0 时代表后端无法从格式测出，不代表一段零秒音频。
///
/// generate_speech — the receipt is pinned to the backend's exact shape. Filename, byte size and
/// measured duration are hints for the first frame of the card; the attachment row remains the
/// authority once it arrives. A zero duration means unknown, never a zero-length clip.
({
  String attachmentId,
  String? mime,
  String? filename,
  int? sizeBytes,
  int? characters,
  int? durationMs,
  String? provider,
  String? model,
  String? source,
})?
parseGeneratedSpeech(String? output) {
  if (output == null || output.isEmpty) return null;
  final o = _obj(output);
  if (o == null || o['source'] != 'generate_speech') return null;
  final id = o['attachmentId'];
  if (id is! String || id.isEmpty) return null;
  return (
    attachmentId: id,
    mime: o['mime'] is String ? o['mime'] as String : null,
    filename: o['filename'] is String ? o['filename'] as String : null,
    sizeBytes: (o['sizeBytes'] is num) ? (o['sizeBytes'] as num).toInt() : null,
    characters: (o['characters'] is num)
        ? (o['characters'] as num).toInt()
        : null,
    durationMs: (o['durationMs'] is num)
        ? (o['durationMs'] as num).toInt()
        : null,
    provider: o['provider'] is String ? o['provider'] as String : null,
    model: o['model'] is String ? o['model'] as String : null,
    source: o['source'] is String ? o['source'] as String : null,
  );
}

/// generate_image / edit_image——图像回执(后端 `tool/generate/image.go`、`edit.go`,键逐字钉):source
/// 不符或 attachmentId 空即 null——回执绝不猜(文件头契约)。两者共享同一媒体卡,但 source 仍保留
/// 以让工具目录显示「已改图」而不是误称「已生成」。
({
  String attachmentId,
  String? mime,
  String? filename,
  String? aspect,
  int? sizeBytes,
  int? width,
  int? height,
  String? provider,
  String? model,
  String? source,
  String? sourceAttachmentId,
})?
parseGeneratedImage(String? output) {
  if (output == null || output.isEmpty) return null;
  final o = _obj(output);
  final source = o?['source'];
  if (o == null || (source != 'generate_image' && source != 'edit_image')) {
    return null;
  }
  final id = o['attachmentId'];
  if (id is! String || id.isEmpty) return null;
  return (
    attachmentId: id,
    mime: o['mime'] is String ? o['mime'] as String : null,
    filename: o['filename'] is String ? o['filename'] as String : null,
    aspect: o['aspect'] is String ? o['aspect'] as String : null,
    sizeBytes: (o['sizeBytes'] is num) ? (o['sizeBytes'] as num).toInt() : null,
    width: (o['width'] is num) ? (o['width'] as num).toInt() : null,
    height: (o['height'] is num) ? (o['height'] as num).toInt() : null,
    provider: o['provider'] is String ? o['provider'] as String : null,
    model: o['model'] is String ? o['model'] as String : null,
    source: source is String ? source : null,
    sourceAttachmentId: o['sourceAttachmentId'] is String
        ? o['sourceAttachmentId'] as String
        : null,
  );
}
