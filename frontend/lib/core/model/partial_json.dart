/// The streaming JSON event engine (WRK-056 #3) — the foundation the F04 builds family's "逐个亮起"
/// rides: a tool_call's args arrive as a growing, possibly-truncated JSON fragment, and this parses
/// whatever has COMPLETED so far, emitting one event per fully-closed value with its path from the
/// root. Op tickers, method chips, the control decision ladder, and trigger config KV all key off
/// these events; a still-streaming trailing value is simply omitted (never guessed).
///
/// Distinct from `argStringPartial` (tool_receipts.dart), which returns the PARTIAL text of a still-
/// open string for the live code/prose window — this engine reports COMPLETIONS, that one reports
/// in-progress payload. They are complementary.
///
/// 流中 JSON 事件引擎(WRK-056 #3)——F04 builds 族「逐个亮起」的地基:args 是不断长、可能截断的 JSON
/// 片段,本引擎解析**已完成**部分,每个闭合的值发一个带根路径的事件(路径元素:String=对象键 / int=数组
/// 下标)。op ticker / method chips / 决策梯 / trigger config KV 皆据此;仍在流的尾值一律略去、绝不猜。
/// 与 argStringPartial(报仍开着的字符串的**部分**文本、供活代码窗)互补——此报**完成**、彼报**在途**。
library;

/// One value that fully COMPLETED during an incremental parse, with its path from the root.
/// 增量解析中完成的一个值 + 根路径。
typedef JsonEvent = ({List<Object> path, Object? value});

/// Parse a (possibly TRUNCATED / malformed mid-stream) JSON fragment; return every value that has
/// fully closed so far, in completion order (which, for array elements, is source order). Incomplete
/// trailing values are omitted; a malformed byte stops the parse but keeps what already completed.
/// 解析可截断/畸形片段,返已闭合值(完成序=数组的源序);尾部不完整略去;畸形即止但保留已完成。
List<JsonEvent> partialJsonEvents(String fragment) {
  final p = _Parser(fragment);
  p.run();
  return p.events;
}

/// The completed ELEMENTS of the array at [path] (e.g. `['ops']`, `['branches']`, `['options']`), in
/// order — the op ticker / rule ladder / method chips / options facade. 数组门面:该路径下已闭合元素(有序)。
List<Object?> partialJsonArrayItems(String fragment, List<Object> path) {
  final out = <Object?>[];
  for (final e in partialJsonEvents(fragment)) {
    if (e.path.length == path.length + 1 && e.path.last is int && _startsWith(e.path, path)) {
      out.add(e.value);
    }
  }
  return out;
}

bool _startsWith(List<Object> path, List<Object> prefix) {
  if (path.length < prefix.length) return false;
  for (var k = 0; k < prefix.length; k++) {
    if (path[k] != prefix[k]) return false;
  }
  return true;
}

// Control-flow signals for the recursive parse — not surfaced to callers. 解析控制流信号,不外露。
class _Trunc implements Exception {} // ran off the end mid-value 值中途到尾

class _Bad implements Exception {} // a byte that can't be valid JSON 无法合法之字节

class _Parser {
  _Parser(this.s);
  final String s;
  int i = 0;
  final events = <JsonEvent>[];

  void run() {
    try {
      _skipWs();
      if (i < s.length) _value(const []);
    } on _Trunc {
      // truncated mid-stream — the completed values are already in [events] 截断:已完成值已在 events
    } on _Bad {
      // malformed — stop, keep what parsed 畸形:止,保留已解析
    }
  }

  int _cp() {
    if (i >= s.length) throw _Trunc();
    return s.codeUnitAt(i);
  }

  void _skipWs() {
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d) {
        i++;
      } else {
        break;
      }
    }
  }

  Object? _value(List<Object> path) {
    _skipWs();
    final c = _cp();
    Object? v;
    if (c == 0x7b) {
      v = _object(path); // {
    } else if (c == 0x5b) {
      v = _array(path); // [
    } else if (c == 0x22) {
      v = _string(); // "
    } else if (c == 0x74 || c == 0x66 || c == 0x6e) {
      v = _keyword(); // t f n
    } else if (c == 0x2d || (c >= 0x30 && c <= 0x39)) {
      v = _number(); // - 0-9
    } else {
      throw _Bad();
    }
    events.add((path: path, value: v));
    return v;
  }

  Map<String, Object?> _object(List<Object> path) {
    i++; // {
    final m = <String, Object?>{};
    _skipWs();
    if (_cp() == 0x7d) {
      i++;
      return m; // }
    }
    while (true) {
      _skipWs();
      if (_cp() != 0x22) throw _Bad();
      final key = _string();
      _skipWs();
      if (_cp() != 0x3a) throw _Bad(); // :
      i++;
      m[key] = _value([...path, key]);
      _skipWs();
      final c = _cp();
      if (c == 0x2c) {
        i++; // ,
        continue;
      }
      if (c == 0x7d) {
        i++;
        return m; // }
      }
      throw _Bad();
    }
  }

  List<Object?> _array(List<Object> path) {
    i++; // [
    final a = <Object?>[];
    _skipWs();
    if (_cp() == 0x5d) {
      i++;
      return a; // ]
    }
    var idx = 0;
    while (true) {
      a.add(_value([...path, idx]));
      idx++;
      _skipWs();
      final c = _cp();
      if (c == 0x2c) {
        i++; // ,
        continue;
      }
      if (c == 0x5d) {
        i++;
        return a; // ]
      }
      throw _Bad();
    }
  }

  String _string() {
    i++; // opening "
    final sb = StringBuffer();
    while (true) {
      if (i >= s.length) throw _Trunc(); // unterminated 未闭合
      final c = s.codeUnitAt(i);
      if (c == 0x22) {
        i++;
        return sb.toString(); // closing "
      }
      if (c == 0x5c) {
        // escape 转义
        i++;
        if (i >= s.length) throw _Trunc();
        final e = s.codeUnitAt(i);
        switch (e) {
          case 0x22:
            sb.writeCharCode(0x22);
          case 0x5c:
            sb.writeCharCode(0x5c);
          case 0x2f:
            sb.writeCharCode(0x2f);
          case 0x6e:
            sb.writeCharCode(0x0a); // n
          case 0x74:
            sb.writeCharCode(0x09); // t
          case 0x72:
            sb.writeCharCode(0x0d); // r
          case 0x62:
            sb.writeCharCode(0x08); // b
          case 0x66:
            sb.writeCharCode(0x0c); // f
          case 0x75: // \uXXXX
            if (i + 4 >= s.length) throw _Trunc();
            final code = int.tryParse(s.substring(i + 1, i + 5), radix: 16);
            if (code == null) throw _Bad();
            sb.writeCharCode(code);
            i += 4;
          default:
            throw _Bad();
        }
        i++;
      } else {
        sb.writeCharCode(c);
        i++;
      }
    }
  }

  Object? _keyword() {
    if (s.startsWith('true', i)) {
      i += 4;
      return true;
    }
    if (s.startsWith('false', i)) {
      i += 5;
      return false;
    }
    if (s.startsWith('null', i)) {
      i += 4;
      return null;
    }
    // A truncated keyword (e.g. "tr", "fals") — treat as incomplete, not malformed. 截断关键字=不完整。
    final rest = s.substring(i);
    if ('true'.startsWith(rest) || 'false'.startsWith(rest) || 'null'.startsWith(rest)) {
      throw _Trunc();
    }
    throw _Bad();
  }

  num _number() {
    final start = i;
    if (_cp() == 0x2d) i++; // -
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if ((c >= 0x30 && c <= 0x39) || c == 0x2e || c == 0x65 || c == 0x45 || c == 0x2b || c == 0x2d) {
        i++;
      } else {
        break;
      }
    }
    // A number running to end-of-input MIGHT continue (12 → 123) — conservatively incomplete.
    // 到尾的数字可能续(12→123)——保守判不完整。
    if (i >= s.length) throw _Trunc();
    final n = num.tryParse(s.substring(start, i));
    if (n == null) throw _Bad();
    return n;
  }
}
