import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/an_count_up.dart';
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
typedef LsListing = ({String root, int total, List<LsEntry> entries, bool truncated, int shown});

// The type column is aligned to width 6 (dir+3sp / link+2sp / file+2sp), so tolerate variable spacing.
// file rows end with `size   mtime`. 类型列对齐宽 6,容忍变距;file 行尾 size + mtime。
final _lsHeader = RegExp(r'^(.*) \((\d+) entries\)$');
final _lsFile = RegExp(r'^  file\s+(.+?)\s{2,}(.+?)\s{2,}(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\s*$');
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
      entries.add((type: 'file', name: f.group(1)!.trim(), size: f.group(2)!.trim(), mtime: f.group(3)));
      continue;
    }
    final d = _lsDirLink.firstMatch(line);
    if (d != null) entries.add((type: d.group(1)!, name: d.group(2)!.trim(), size: null, mtime: null));
  }
  return (root: root, total: total, entries: entries, truncated: truncated, shown: truncated ? shown : entries.length);
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
    return ToolWindow(child: Text(state.resultText, style: AnText.code.copyWith(color: c.inkMuted), maxLines: 40, overflow: TextOverflow.ellipsis));
  }
  if (ls.entries.isEmpty) {
    return ToolWindow(child: Text(t.chat.tool.lsEmpty, style: AnText.code.copyWith(color: c.inkFaint)));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Padding(padding: const EdgeInsets.only(bottom: AnSpace.s4), child: Text(ls.root, style: AnText.mono.copyWith(color: c.inkFaint))),
    ToolHitList(
      rows: [
        for (final e in ls.entries)
          ToolHitRow(
            glyph: _fsGlyph(e.type),
            title: e.type == 'dir' ? '${e.name}/' : e.name,
            trailing: e.size == null ? null : Text('${e.size}  ·  ${e.mtime}', style: AnText.meta.copyWith(color: c.inkFaint)),
          ),
      ],
      cap: 30,
      total: ls.truncated ? ls.total : null,
      serverTruncated: ls.truncated,
      rawJson: state.resultText,
    ),
  ]);
}

// ── Glob (JSON) ──
typedef GlobMatch = ({String path, String type, int size, String mtime});

/// Parse the Glob JSON `{root, matches:[{path,type,size,mtime}], total, truncated}`. null on non-JSON.
/// Glob JSON 解析。
({String root, List<GlobMatch> matches, int total, bool truncated})? parseGlobResult(String output) {
  Map<String, dynamic>? d;
  try {
    final p = jsonDecode(output);
    if (p is Map<String, dynamic>) d = p;
  } catch (_) {}
  if (d == null || d['matches'] is! List) return null;
  final matches = <GlobMatch>[];
  for (final m in d['matches'] as List) {
    if (m is Map) {
      matches.add((path: '${m['path'] ?? ''}', type: '${m['type'] ?? 'file'}', size: m['size'] is int ? m['size'] as int : 0, mtime: '${m['mtime'] ?? ''}'));
    }
  }
  return (root: '${d['root'] ?? ''}', matches: matches, total: d['total'] is int ? d['total'] as int : matches.length, truncated: d['truncated'] == true);
}

String _basename(String path) {
  final trimmed = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
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
    return ToolWindow(child: Text(state.resultText, style: AnText.code.copyWith(color: c.danger), maxLines: 20, overflow: TextOverflow.ellipsis));
  }
  final pattern = argString(state.argsText, 'pattern') ?? '';
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Padding(
      padding: const EdgeInsets.only(bottom: AnSpace.s4),
      child: Text(t.chat.tool.globHeader(pattern: '"$pattern"', root: g.root), style: AnText.mono.copyWith(color: c.inkFaint)),
    ),
    ToolHitList(
      rows: [
        for (final m in g.matches)
          ToolHitRow(
            glyph: _fsGlyph(m.type),
            title: _basename(m.path),
            subtitle: m.path,
            trailing: Text('${_humanBytes(m.size)}  ·  ${_shortMtime(m.mtime)}', style: AnText.meta.copyWith(color: c.inkFaint)),
          ),
      ],
      cap: 30,
      total: g.total,
      serverTruncated: g.truncated,
      rawJson: state.resultText,
    ),
  ]);
}

String _humanBytes(int n) {
  if (n < 1024) return '$n B';
  if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(0)} KB';
  return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
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
