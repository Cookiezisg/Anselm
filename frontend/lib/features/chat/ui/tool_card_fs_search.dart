import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/byte_format.dart';
import '../../../core/ui/an_count_up.dart';
import '../../../core/ui/an_heat_bar.dart';
import '../../../core/ui/an_window.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import 'tool_card_skins.dart';
import 'tool_hit_list.dart';

// F02 fs-search bodies (B4) — LS / Glob / Grep. Settle-only, so the drama is the «计数揭示» ([AnCountUp])
// + a directory-like [ToolHitList] (folder/file glyphs, size · mtime). Rows are INERT (files have no
// entity panel). F02 检索:计数揭示 + 目录感命中窗。

// ── LS (line-text template) ──
typedef LsEntry = ({String type, String name, String? size, String? mtime});
typedef LsListing = ({
  String root,
  int total,
  List<LsEntry> entries,
  bool truncated,
  int shown,
});

// The type column is aligned to width 6 (dir+3sp / link+2sp / file+2sp), so tolerate variable spacing.
// file rows end with `size   mtime`. 类型列对齐宽 6,容忍变距;file 行尾 size + mtime。
final _lsHeader = RegExp(r'^(.*) \((\d+) entries\)$');
final _lsFile = RegExp(
  r'^  file\s+(.+?)\s{2,}(.+?)\s{2,}(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\s*$',
);
final _lsDirLink = RegExp(r'^  (dir|link)\s+(.+)$');
final _lsTrunc = RegExp(r'showing (\d+) of (\d+) entries');

/// Parse the LS listing template (census: `<abs> (T entries)` + `  <type>  <name>[  size  mtime]`).
/// null if the header doesn't match (an error string / non-listing). LS 行式模板解析。
LsListing? parseLsListing(String output) {
  final lines = output.split('\n');
  if (lines.isEmpty) return null;
  final h = _lsHeader.firstMatch(lines.first.trim());
  if (h == null) return null;
  final root = h.group(1)!;
  final total = int.parse(h.group(2)!);
  final entries = <LsEntry>[];
  var truncated = false;
  var shown = 0;
  for (final line in lines.skip(1)) {
    if (line.trim() == '(empty)') continue;
    final tr = _lsTrunc.firstMatch(line);
    if (tr != null) {
      truncated = true;
      shown = int.parse(tr.group(1)!);
      continue;
    }
    final f = _lsFile.firstMatch(line);
    if (f != null) {
      entries.add((
        type: 'file',
        name: f.group(1)!.trim(),
        size: f.group(2)!.trim(),
        mtime: f.group(3),
      ));
      continue;
    }
    final d = _lsDirLink.firstMatch(line);
    if (d != null) {
      entries.add((
        type: d.group(1)!,
        name: d.group(2)!.trim(),
        size: null,
        mtime: null,
      ));
    }
  }
  return (
    root: root,
    total: total,
    entries: entries,
    truncated: truncated,
    shown: truncated ? shown : entries.length,
  );
}

IconData _fsGlyph(String type) => switch (type) {
  'dir' => AnIcons.folder,
  'link' => AnIcons.web,
  _ => AnIcons.doc,
};

/// LS settled body — a directory listing in a machine window: root header + ToolHitList (glyph + name,
/// dir names get a trailing `/`; file rows show size · mtime). LS 目录清单。
Widget lsToolBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final ls = parseLsListing(state.resultText);
  if (ls == null) {
    return rawMonoWindow(
      context,
      state.resultText,
      maxLines: AnCap.monoBodyLines,
      color: c.inkMuted,
    );
  }
  if (ls.entries.isEmpty) {
    return rawMonoWindow(context, t.chat.tool.lsEmpty, color: c.inkFaint);
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: AnSpace.s4),
        child: Text(ls.root, style: AnText.mono.copyWith(color: c.inkFaint)),
      ),
      ToolHitList(
        rows: [
          for (final e in ls.entries)
            ToolHitRow(
              glyph: _fsGlyph(e.type),
              title: e.type == 'dir' ? '${e.name}/' : e.name,
              trailing: e.size == null
                  ? null
                  : Text(
                      '${e.size} · ${e.mtime}',
                      style: AnText.meta.copyWith(color: c.inkFaint),
                    ),
            ),
        ],
        cap: 30,
        total: ls.truncated ? ls.total : null,
        serverTruncated: ls.truncated,
        rawJson: state.resultText,
      ),
    ],
  );
}

// ── Glob (JSON) ──
typedef GlobMatch = ({String path, String type, int size, String mtime});

/// Parse the Glob JSON `{root, matches:[{path,type,size,mtime}], total, truncated}`. null on non-JSON.
/// Glob JSON 解析。
({String root, List<GlobMatch> matches, int total, bool truncated})?
parseGlobResult(String output) {
  Map<String, dynamic>? d;
  try {
    final p = jsonDecode(output);
    if (p is Map<String, dynamic>) d = p;
  } catch (_) {}
  if (d == null || d['matches'] is! List) return null;
  final matches = <GlobMatch>[];
  for (final m in d['matches'] as List) {
    if (m is Map) {
      matches.add((
        path: '${m['path'] ?? ''}',
        type: '${m['type'] ?? 'file'}',
        size: m['size'] is int ? m['size'] as int : 0,
        mtime: '${m['mtime'] ?? ''}',
      ));
    }
  }
  return (
    root: '${d['root'] ?? ''}',
    matches: matches,
    total: d['total'] is int ? d['total'] as int : matches.length,
    truncated: d['truncated'] == true,
  );
}

String _basename(String path) {
  final trimmed = path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  final i = trimmed.lastIndexOf('/');
  return i < 0 ? trimmed : trimmed.substring(i + 1);
}

/// Glob settled body — matches in a machine window (basename + size · mtime), mtime-desc as the wire
/// gives them; a header `"pattern" in <root>` + a raw-JSON escape hatch. Glob 命中窗。
Widget globToolBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final t = Translations.of(context);
  final g = parseGlobResult(state.resultText);
  if (g == null) {
    // non-JSON = an error / timeout string. 非 JSON=错误/超时串。
    return rawMonoWindow(
      context,
      state.resultText,
      maxLines: AnCap.monoCompactLines,
      color: c.danger,
    );
  }
  final pattern = argString(state.argsText, 'pattern') ?? '';
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: AnSpace.s4),
        child: Text(
          t.chat.tool.globHeader(pattern: '"$pattern"', root: g.root),
          style: AnText.mono.copyWith(color: c.inkFaint),
        ),
      ),
      ToolHitList(
        rows: [
          for (final m in g.matches)
            ToolHitRow(
              glyph: _fsGlyph(m.type),
              title: _basename(m.path),
              subtitle: m.path,
              trailing: Text(
                '${formatBytes(m.size)} · ${_shortMtime(m.mtime)}',
                style: AnText.meta.copyWith(color: c.inkFaint),
              ),
            ),
        ],
        cap: 30,
        total: g.total,
        serverTruncated: g.truncated,
        rawJson: state.resultText,
      ),
    ],
  );
}

String _shortMtime(String rfc3339) {
  final dt = DateTime.tryParse(rfc3339);
  if (dt == null) return rfc3339;
  String two(int n) => n.toString().padLeft(2, '0');
  final l = dt.toLocal();
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

/// A count-up widget for a settle-only search count (the «计数揭示»). Used inside bodies. 计数揭示。
Widget fsSearchCount(int n, {String? suffix}) => AnCountUp(n, suffix: suffix);

// ── Grep (rg --no-heading style, three output modes) ──

bool _grepNoise(String l) =>
    l.isEmpty ||
    l == '--' ||
    l.startsWith('... [') ||
    l.startsWith('No matches');

/// files_with_matches: one absolute path per line. files 模式:每行一路径。
List<String> parseGrepFiles(String output) => [
  for (final l in output.trimRight().split('\n'))
    if (!_grepNoise(l)) l,
];

/// count mode: `path:N` per line (rg single-file target → bare `N`, path = the arg path). count 模式。
typedef GrepCount = ({String path, int count});
List<GrepCount> parseGrepCount(String output, String argPath) {
  final out = <GrepCount>[];
  for (final line in output.trimRight().split('\n')) {
    if (_grepNoise(line)) continue;
    final bare = int.tryParse(line.trim());
    if (bare != null) {
      out.add((path: argPath, count: bare)); // rg single-file bare N rg 单文件裸数字
    } else {
      final i = line.lastIndexOf(':');
      final n = i < 0 ? null : int.tryParse(line.substring(i + 1));
      if (n != null) out.add((path: line.substring(0, i), count: n));
    }
  }
  return out;
}

/// content mode: one entry per line, grouped by file, preserving order. A match line uses `:` after the
/// path/line; a context line uses `-`; a single-file result omits the path (line starts with a digit);
/// without `-n` there's no line number. content 模式:逐行(匹配 `:` / 上下文 `-` / 单文件省 path / 无 -n 省行号)。
typedef GrepLine = ({int? line, String text, bool isMatch});
typedef GrepGroup = ({String path, List<GrepLine> lines});

final _grepMatch = RegExp(r'^(.+?):(\d+):(.*)$'); // path:line:text
final _grepCtx = RegExp(r'^(.+?)-(\d+)-(.*)$'); // path-line-text
final _grepSfMatch = RegExp(r'^(\d+):(.*)$'); // line:text (single file)
final _grepSfCtx = RegExp(r'^(\d+)-(.*)$'); // line-text (single file)
final _grepNoLine = RegExp(r'^(.+?):(.*)$'); // path:text (no -n)

List<GrepGroup> parseGrepContent(String output, String argPath) {
  final lines = output.split('\n');
  // Single-file mode iff the first content line starts with a digit + separator. 单文件模式判定。
  final firstContent = lines.firstWhere(
    (l) => !_grepNoise(l),
    orElse: () => '',
  );
  final singleFile = RegExp(r'^\d+[:-]').hasMatch(firstContent);
  final order = <String>[];
  final groups = <String, List<GrepLine>>{};
  void add(String path, GrepLine gl) {
    if (!order.contains(path)) order.add(path);
    (groups[path] ??= []).add(gl);
  }

  for (final raw in lines) {
    if (_grepNoise(raw)) continue;
    if (singleFile) {
      final m = _grepSfMatch.firstMatch(raw);
      if (m != null) {
        add(argPath, (
          line: int.parse(m.group(1)!),
          text: m.group(2)!,
          isMatch: true,
        ));
        continue;
      }
      final ctx = _grepSfCtx.firstMatch(raw);
      if (ctx != null) {
        add(argPath, (
          line: int.parse(ctx.group(1)!),
          text: ctx.group(2)!,
          isMatch: false,
        ));
        continue;
      }
      add(argPath, (line: null, text: raw, isMatch: true));
    } else {
      final m = _grepMatch.firstMatch(raw);
      if (m != null) {
        add(m.group(1)!, (
          line: int.parse(m.group(2)!),
          text: m.group(3)!,
          isMatch: true,
        ));
        continue;
      }
      final ctx = _grepCtx.firstMatch(raw);
      if (ctx != null) {
        add(ctx.group(1)!, (
          line: int.parse(ctx.group(2)!),
          text: ctx.group(3)!,
          isMatch: false,
        ));
        continue;
      }
      final nl = _grepNoLine.firstMatch(raw);
      if (nl != null) {
        add(nl.group(1)!, (line: null, text: nl.group(2)!, isMatch: true));
      }
    }
  }
  return [for (final p in order) (path: p, lines: groups[p]!)];
}

/// Highlight the [pattern] occurrences inside [text] (a case-insensitive literal-ish search). A pattern
/// that won't compile as a regex, or a multiline flag, → no highlight (honest, never a wrong span). 行内
/// 命中点亮(编译失败/multiline→不点亮)。
List<InlineSpan> highlightMatches(
  String text,
  String pattern,
  AnColors c, {
  required TextStyle base,
  bool caseInsensitive = false,
  bool multiline = false,
}) {
  if (pattern.isEmpty || multiline) return [TextSpan(text: text, style: base)];
  RegExp? re;
  try {
    re = RegExp(pattern, caseSensitive: !caseInsensitive);
  } catch (_) {
    return [TextSpan(text: text, style: base)]; // uncompilable → plain 编译失败→纯文本
  }
  final spans = <InlineSpan>[];
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start == m.end) continue; // zero-width → skip (would loop) 零宽跳过
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start), style: base));
    }
    spans.add(
      TextSpan(
        text: text.substring(m.start, m.end),
        style: base
            .copyWith(backgroundColor: c.accentSoft, color: c.ink)
            .weight(AnText.emphasisWeight),
      ),
    );
    last = m.end;
  }
  if (spans.isEmpty) return [TextSpan(text: text, style: base)];
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: base));
  }
  return spans;
}

/// The GREP CONTENT VIEW — an editor-style global-search panel in the transcript: matches grouped by
/// file (a path header), each line with its number gutter + inline match highlight; context lines dim;
/// a `···` gap between non-contiguous line ranges. Capped at 200 lines. Grep content 视图:分组 + 行号 +
/// 行内点亮 + 上下文降色。
class GrepContentView extends StatelessWidget {
  const GrepContentView({
    required this.groups,
    required this.pattern,
    this.caseInsensitive = false,
    this.multiline = false,
    super.key,
  });

  final List<GrepGroup> groups;
  final String pattern;
  final bool caseInsensitive;
  final bool multiline;

  static const int _cap = 200;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    var rendered = 0;
    final children = <Widget>[];
    for (final g in groups) {
      if (rendered >= _cap) break;
      children.add(
        Padding(
          padding: EdgeInsets.only(
            top: children.isEmpty ? AnSpace.s0 : AnSpace.s6,
            bottom: AnSpace.s2,
          ),
          child: Text(g.path, style: AnText.mono.copyWith(color: c.inkFaint)),
        ),
      );
      int? prevLine;
      for (final gl in g.lines) {
        if (rendered >= _cap) break;
        // A gap between non-contiguous lines → a `···` marker. 行号跳跃→···。
        if (prevLine != null && gl.line != null && gl.line! > prevLine + 1) {
          children.add(
            Text('···', style: AnText.code.copyWith(color: c.inkFaint)),
          );
        }
        prevLine = gl.line;
        rendered++;
        children.add(_line(context, c, gl));
      }
    }
    return AnWindow(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _line(BuildContext context, AnColors c, GrepLine gl) {
    final base = AnText.code.copyWith(
      color: gl.isMatch ? c.inkMuted : c.inkFaint,
    );
    final spans = gl.isMatch
        ? highlightMatches(
            gl.text,
            pattern,
            c,
            base: base,
            caseInsensitive: caseInsensitive,
            multiline: multiline,
          )
        : [TextSpan(text: gl.text, style: base)];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AnSize.trail,
          child: Text(
            gl.line?.toString() ?? '',
            textAlign: TextAlign.right,
            style: AnText.code.copyWith(color: c.inkFaint),
          ),
        ),
        const SizedBox(width: AnSpace.s8),
        Expanded(
          child: Text.rich(
            TextSpan(children: spans),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Grep settled body — dispatch by `output_mode`: content → [GrepContentView]; count → path·count heat
/// rows; files_with_matches (default) → a plain path list. Grep 体:按 output_mode 分派。
Widget grepToolBody(BuildContext context, ToolCardState state) {
  final c = context.colors;
  final result = state.resultText;
  if (result.trimLeft().startsWith('No matches') ||
      result.startsWith('Invalid regex')) {
    return rawMonoWindow(
      context,
      result.trim(),
      color: result.startsWith('Invalid') ? c.danger : c.inkFaint,
    );
  }
  final mode = argString(state.argsText, 'output_mode') ?? 'files_with_matches';
  final argPath = argString(state.argsText, 'path') ?? '';
  final pattern = argString(state.argsText, 'pattern') ?? '';

  if (mode == 'content') {
    final groups = parseGrepContent(result, argPath);
    if (groups.isEmpty) {
      return rawMonoWindow(
        context,
        result,
        maxLines: AnCap.monoBodyLines,
        color: c.inkMuted,
      );
    }
    return GrepContentView(
      groups: groups,
      pattern: pattern,
      caseInsensitive: RegExp(r'"-i"\s*:\s*true').hasMatch(state.argsText),
      multiline: RegExp(r'"multiline"\s*:\s*true').hasMatch(state.argsText),
    );
  }
  if (mode == 'count') {
    final counts = parseGrepCount(result, argPath);
    final maxN = counts.fold<int>(1, (m, e) => e.count > m ? e.count : m);
    return ToolHitList(
      rows: [
        for (final e in counts)
          ToolHitRow(
            glyph: AnIcons.doc,
            title: _basename(e.path),
            subtitle: e.path,
            trailing: _countHeat(context, c, e.count, maxN),
          ),
      ],
      cap: 30,
      rawJson: result,
    );
  }
  // files_with_matches
  final files = parseGrepFiles(result);
  return ToolHitList(
    rows: [
      for (final f in files)
        ToolHitRow(glyph: AnIcons.doc, title: _basename(f), subtitle: f),
    ],
    cap: 30,
    rawJson: result,
  );
}

// A relative-heat sliver, deliberately NOT AnMeter (that is the full-width quota meter with
// warn/danger thresholds; this is a trailing-slot comparison bar) — the full width is the named
// [AnSize.heatBar] tier (A-083). 相对热力短条,刻意不套 AnMeter(整行配额表角色不同);满宽走具名档。
Widget _countHeat(BuildContext context, AnColors c, int count, int maxN) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnHeatBar(fraction: count / maxN),
      const SizedBox(width: AnSpace.s6),
      Text('$count', style: AnText.body.copyWith(color: c.inkMuted)),
    ],
  );
}
