import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/typography.dart';

/// TERMINAL FOLDING + ANSI (WRK-056 #5) — two pure functions that turn raw terminal output (Bash
/// stdout+stderr, progress deltas) into readable, themed lines. [termFold] collapses in-place cursor
/// rewrites (`\r` progress bars, `ESC[K` erases, `ESC[nA` cursor-up multi-line renderers like docker
/// pull) into their FINAL frame; [ansiSpans] maps the surviving SGR color codes onto design tokens.
///
/// Bounded by design: cursor-up can only rewrite within the last [kTermWindow] lines (older lines are
/// frozen); an out-of-window move / an absolute-position CSI is stripped — the declared degradation, not
/// a bug (a terminal app doing full-screen addressing degrades to a heap of lines, never a wrong fold).
///
/// 终端折叠 + ANSI:两个纯函数把原始终端输出折成可读主题化行。termFold 折叠原地重写(\r 进度条 / ESC[K
/// 擦行 / ESC[nA cursor-up 多行渲染器)成最终帧;ansiSpans 把 SGR 色码映到 design token。cursor-up 只在
/// 最近 [kTermWindow] 行可变窗内回退,窗前行永久凝固;超窗/绝对寻址 CSI 剥离=声明的堆行退化态。

/// The mutable-window bound: cursor-up (`ESC[nA`) reaches at most this many lines back. 可变窗上界。
const int kTermWindow = 64;

const int _esc = 0x1b;
const int _lf = 0x0a;
const int _cr = 0x0d;

int _numParam(String params, int fallback) {
  final m = RegExp(r'^\d+').firstMatch(params);
  return m == null ? fallback : int.parse(m.group(0)!);
}

/// Fold [raw] terminal output into final lines. Each returned line still carries any surviving SGR
/// (`ESC[…m`) sequences inline — [ansiSpans] parses those. A cell is `<pending SGR prefixes><char>`, so
/// overwrites (progress-bar `\r`) replace the whole cell, color and all. 折成最终行(保留 SGR 供 ansiSpans)。
List<String> termFold(String raw, {int window = kTermWindow}) {
  final lines = <List<String>>[<String>[]];
  int row = 0, col = 0;
  String pending = ''; // control tokens (SGR) waiting to attach to the next printable. 待附控制序列。

  void ensureRow() {
    while (lines.length <= row) {
      lines.add(<String>[]);
    }
  }

  int i = 0;
  final n = raw.length;
  while (i < n) {
    final c = raw.codeUnitAt(i);
    if (c == _lf) {
      row++;
      col = 0;
      pending = '';
      ensureRow();
      i++;
      continue;
    }
    if (c == _cr) {
      col = 0;
      i++;
      continue;
    }
    if (c == _esc) {
      if (i + 1 < n && raw.codeUnitAt(i + 1) == 0x5b) {
        // CSI: ESC [ … <final 0x40–0x7e>
        int j = i + 2;
        while (j < n && !(raw.codeUnitAt(j) >= 0x40 && raw.codeUnitAt(j) <= 0x7e)) {
          j++;
        }
        if (j >= n) break; // incomplete (chunk boundary) → leave for the tail buffer 半截→留尾缓冲
        final finalByte = raw[j];
        final params = raw.substring(i + 2, j);
        final seq = raw.substring(i, j + 1);
        switch (finalByte) {
          case 'm': // SGR: keep as a pending prefix on the next printable 颜色:附到下个字符
            pending += seq;
          case 'A': // cursor up (within the window) 上移(窗内)
            final up = _numParam(params, 1);
            final floor = (lines.length - window).clamp(0, lines.length);
            final target = row - up;
            if (target >= floor && target >= 0) row = target; // else out-of-window → ignore 超窗忽略
            pending = '';
          case 'B': // cursor down 下移
            row += _numParam(params, 1);
            ensureRow();
            pending = '';
          case 'C': // cursor forward 右移
            col += _numParam(params, 1);
          case 'D': // cursor back 左移
            col = (col - _numParam(params, 1)).clamp(0, col);
          case 'K': // erase line 擦行
            ensureRow();
            final line = lines[row];
            final mode = _numParam(params, 0);
            if (mode == 2) {
              line.clear();
            } else if (mode == 0 && col < line.length) {
              line.removeRange(col, line.length); // to end 到行尾
            } else if (mode == 1) {
              for (var k = 0; k < col && k < line.length; k++) {
                line[k] = ' '; // to start 到行首
              }
            }
            pending = '';
          default: // absolute positioning / other CSI → strip (declared degradation) 绝对寻址等剥离
            pending = '';
        }
        i = j + 1;
        continue;
      }
      i++; // lone ESC / non-CSI → skip 孤 ESC 跳过
      continue;
    }
    // printable: write the cell (pending SGR prefix + char) at the cursor. 写单元格。
    ensureRow();
    final line = lines[row];
    while (line.length <= col) {
      line.add(' ');
    }
    line[col] = pending + String.fromCharCode(c);
    pending = '';
    col++;
    i++;
  }
  return [for (final l in lines) l.join()];
}

// ── ANSI SGR → design tokens ──

/// A resolved terminal cell style — folded onto design tokens (16-color → token; bold → w400 per the
/// two-weight rule; dim → inkFaint). 终端单元格样式:16 色映 token、bold→w400、dim→inkFaint。
Color _sgrColor(int code, AnColors c) {
  switch (code) {
    case 30:
    case 90:
      return c.inkFaint; // black / bright-black → dim
    case 31:
    case 91:
      return c.danger; // red
    case 32:
    case 92:
      return c.ok; // green
    case 33:
    case 93:
      return c.warn; // yellow
    case 34:
    case 94:
      return c.accent; // blue
    case 35:
    case 95:
    case 36:
    case 96:
      return c.accent; // magenta / cyan → accent (no distinct token)
    case 37:
    case 97:
      return c.ink; // white
    default:
      return c.inkMuted;
  }
}

/// Parse a [line] (as returned by [termFold]) into themed spans by walking its SGR sequences.
/// Non-SGR CSI shouldn't survive termFold, but any stray one is skipped. 解析 SGR → 主题化 spans。
List<InlineSpan> ansiSpans(String line, AnColors colors, {required TextStyle base}) {
  final spans = <InlineSpan>[];
  final buf = StringBuffer();
  var style = base;

  void flush() {
    if (buf.isNotEmpty) {
      spans.add(TextSpan(text: buf.toString(), style: style));
      buf.clear();
    }
  }

  int i = 0;
  final n = line.length;
  while (i < n) {
    if (line.codeUnitAt(i) == _esc && i + 1 < n && line[i + 1] == '[') {
      int j = i + 2;
      while (j < n && !(line.codeUnitAt(j) >= 0x40 && line.codeUnitAt(j) <= 0x7e)) {
        j++;
      }
      if (j >= n) break;
      if (line[j] == 'm') {
        flush();
        style = _applySgrStyle(style, line.substring(i + 2, j), base, colors);
      }
      i = j + 1; // skip the whole CSI (non-m ones too) 跳过整段 CSI
      continue;
    }
    buf.write(line[i]);
    i++;
  }
  flush();
  return spans.isEmpty ? [TextSpan(text: line, style: base)] : spans;
}

TextStyle _applySgrStyle(TextStyle current, String params, TextStyle baseStyle, AnColors colors) {
  var style = current;
  final codes = params.isEmpty ? [0] : params.split(';').map((s) => int.tryParse(s) ?? 0).toList();
  for (var k = 0; k < codes.length; k++) {
    final code = codes[k];
    switch (code) {
      case 0: // reset 复位
        style = baseStyle;
      case 1: // bold → w400 (two-weight rule) 加粗→w400
        style = style.weight(AnText.emphasisWeight);
      case 2: // dim 暗
        style = style.copyWith(color: colors.inkFaint);
      case 3: // italic 斜体
        style = style.copyWith(fontStyle: FontStyle.italic);
      case 4: // underline 下划线
        style = style.copyWith(decoration: TextDecoration.underline);
      case 22: // normal intensity 常规
        style = style.weight(AnText.bodyWeight);
      case 23:
        style = style.copyWith(fontStyle: FontStyle.normal);
      case 24:
        style = style.copyWith(decoration: TextDecoration.none);
      case 39: // default fg 默认前景
        style = style.copyWith(color: baseStyle.color);
      case 38: // 38;5;n / 38;2;r;g;b → downgrade to nearest token (skip the params) 降级
        if (k + 1 < codes.length && codes[k + 1] == 5) {
          k += 2;
        } else if (k + 1 < codes.length && codes[k + 1] == 2) {
          k += 4;
        }
        style = style.copyWith(color: colors.inkMuted);
      default:
        if ((code >= 30 && code <= 37) || (code >= 90 && code <= 97)) {
          style = style.copyWith(color: _sgrColor(code, colors));
        }
      // background colors (40–47/100–107) and other codes ignored 背景色等忽略
    }
  }
  return style;
}
