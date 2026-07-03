/// Receipt parsers — pure functions that turn a tool's RAW output string into the collapsed
/// line's dimmed receipt (the "proof" that makes past tense trustworthy: line counts, match
/// counts, exit codes). Each is pinned to the backend's EXACT output format; when a format
/// doesn't match, the receipt silently defaults to none — a receipt must never guess.
///
/// 回执解析器——纯函数:把工具**原始输出串**变成收起行的灰回执(让过去时可信的「凭据」:行数/
/// 命中数/exit code)。逐个钉死后端**精确**输出格式;不匹配即静默无回执——回执绝不猜。
library;

/// A parsed receipt: the suffix text (already localized by the caller's formatter) plus
/// whether it carries the danger tone (non-zero exit, timeouts).
/// 解析结果:后缀文本(调用方已本地化)+ 是否危险色(非零 exit/超时)。
typedef ToolReceipt = ({String text, bool danger});

/// Bash: the backend ALWAYS appends `[exit code: N]` (optionally preceded by a note line
/// `[cancelled]` / `[command timed out after Xs]` / `[exec failed: …]`).
/// Bash:后端恒尾缀 `[exit code: N]`(其前可有 note 行)。
final RegExp _bashExit = RegExp(r'\[exit code: (-?\d+)\]\s*$');
final RegExp _bashTimeout = RegExp(r'\[command timed out after [^\]]+\]');

ToolReceipt? bashReceipt(String output, {required String Function(int) exitLabel, required String timedOutLabel}) {
  final m = _bashExit.firstMatch(output);
  if (m == null) return null;
  final code = int.parse(m.group(1)!);
  if (_bashTimeout.hasMatch(output)) return (text: timedOutLabel, danger: true);
  return (text: exitLabel(code), danger: code != 0);
}

/// Read: cat -n lines (`%5d\t…`), optionally ending with the truncation footer
/// `... [truncated at line N; use offset+limit to read more]`.
/// Read:cat -n 行,可尾缀截断 footer。
final RegExp _readTruncated = RegExp(r'\.\.\. \[truncated at line (\d+);');
final RegExp _readLine = RegExp(r'^\s*\d+\t', multiLine: true);

ToolReceipt? readReceipt(String output,
    {required String Function(int) linesLabel, required String Function(int) truncatedLabel}) {
  final t = _readTruncated.firstMatch(output);
  if (t != null) return (text: truncatedLabel(int.parse(t.group(1)!)), danger: false);
  final n = _readLine.allMatches(output).length;
  if (n == 0) return null; // not file content (directory hint / error prose) 非文件内容
  return (text: linesLabel(n), danger: false);
}

/// Grep / Glob / LS: count-style receipts. "No matches for …" is the backend's honest empty;
/// a `[truncated at N lines…]` marker means the count is a floor ("N+").
/// 检索族:计数回执。"No matches for" 是后端诚实空;截断标记时计数是下界(N+)。
final RegExp _capTruncated = RegExp(r'\[truncated at (\d+) lines');

ToolReceipt? countReceipt(String output,
    {required String Function(String) countLabel, required String noneLabel}) {
  final trimmed = output.trimRight();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('No matches for') ||
      trimmed.startsWith('No files') ||
      trimmed.startsWith('Cannot access') ||
      trimmed.startsWith('Invalid glob')) {
    return trimmed.startsWith('No ') ? (text: noneLabel, danger: false) : null;
  }
  final lines = trimmed.split('\n').where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return null;
  if (_capTruncated.hasMatch(trimmed)) {
    final n = lines.length - 1; // marker line itself 截断行自身不计
    return (text: countLabel('$n+'), danger: false);
  }
  return (text: countLabel('${lines.length}'), danger: false);
}

/// Tolerant mid-stream arg extraction: pull a string field out of a (possibly PARTIAL) args
/// JSON fragment so the collapsed line can name its target while args are still streaming.
/// 容忍式流中参数提取:从(可能**不完整**的)args JSON 片段拉字符串字段,收起行在 args 流入期
/// 就能点名目标。
String? argString(String argsFragment, String key) {
  final m = RegExp('"$key"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"').firstMatch(argsFragment);
  if (m == null) return null;
  final raw = m.group(1)!;
  // Unescape the common JSON escapes (enough for paths/commands/patterns). 常用转义即可。
  return raw
      .replaceAll(r'\"', '"')
      .replaceAll(r'\\', r'\')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\t', '\t');
}

/// Like [argString] but ALSO accepts a still-open value: when the closing quote hasn't
/// streamed in yet, returns everything emitted so far — the builds family streams its code
/// window with this (the whole point of "全系统最强流式").
///
/// 同 [argString] 但**接受未闭合值**:收尾引号未到时返已流入的全部——builds 族靠它流代码窗
/// (「全系统最强流式」的落点)。
String? argStringPartial(String argsFragment, String key) {
  final closed = argString(argsFragment, key);
  if (closed != null) return closed;
  final start = RegExp('"$key"\\s*:\\s*"').firstMatch(argsFragment);
  if (start == null) return null;
  final buf = StringBuffer();
  var escaped = false;
  for (var i = start.end; i < argsFragment.length; i++) {
    final ch = argsFragment[i];
    if (escaped) {
      buf.write(switch (ch) { 'n' => '\n', 't' => '\t', _ => ch });
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

/// Path → basename for the target chip (full path belongs in a tooltip).
/// 路径 → basename 作目标 chip(全路径归 tooltip)。
String pathBasename(String path) {
  final trimmed = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
  final i = trimmed.lastIndexOf('/');
  return i < 0 ? trimmed : trimmed.substring(i + 1);
}

/// Command → first line, collapsed whitespace (the chip is one line always).
/// 命令 → 首行、折叠空白(chip 恒单行)。
String commandChip(String command) {
  final first = command.split('\n').first.trim();
  return first.replaceAll(RegExp(r'\s+'), ' ');
}
