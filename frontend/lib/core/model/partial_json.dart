/// The streaming JSON event engine (WRK-056 #3, incrementalized for WRK-061 W0) — the foundation the
/// builds family's "逐个亮起" AND the right island's live stages ride: a tool_call's args arrive as a
/// growing, possibly-truncated JSON fragment, and this parses whatever has COMPLETED so far, emitting
/// one event per fully-closed value with its path from the root; a still-streaming trailing value is
/// never guessed.
///
/// Two consumption modes:
///  • [partialJsonEvents] — the ORIGINAL pure facade: full-fragment parse, all events. Semantics are
///    unchanged (same events, same order, same truncation/malformed rules); it now runs on the session.
///  • [PartialJsonSession] — the INCREMENTAL engine (W0 P0): feed deltas with [PartialJsonSession.append];
///    each append does O(delta) work (persistent scan state + explicit container stack — never a rescan),
///    already-closed values are never re-emitted, and [PartialJsonSession.inFlightString] exposes the
///    currently-open STRING value with its full path — the path-aware in-flight channel (argStringPartialAt)
///    that drives live code/prose windows even when many values share a key name (handler methods' `body`).
///
/// 流中 JSON 事件引擎(增量化,WRK-061 W0):args 是不断长、可能截断的 JSON 片段。两种吃法——
/// [partialJsonEvents] 原门面(整段解析,语义逐字不变);[PartialJsonSession] 增量会话(每次 append 只做
/// O(delta) 工作:持久扫描态+显式容器栈,绝不重扫;已闭合值绝不重发;[inFlightString] 给出**仍开着的字符串
/// 值+完整路径**——带路径在途尾值通道(argStringPartialAt),多值同键(handler 多 method 的 body)也各归其位)。
library;

/// One value that fully COMPLETED during an incremental parse, with its path from the root
/// (path elements: String = object key / int = array index). 增量解析中完成的一个值 + 根路径。
typedef JsonEvent = ({List<Object> path, Object? value});

/// The currently-open (still-streaming) STRING value: its path + everything decoded so far.
/// 仍在流的字符串值:路径 + 已解码文本。
typedef InFlightString = ({List<Object> path, String text});

/// Parse a (possibly TRUNCATED / malformed mid-stream) JSON fragment; return every value that has
/// fully closed so far, in completion order (which, for array elements, is source order). Incomplete
/// trailing values are omitted; a malformed byte stops the parse but keeps what already completed.
/// 解析可截断/畸形片段,返已闭合值(完成序=数组的源序);尾部不完整略去;畸形即止但保留已完成。
List<JsonEvent> partialJsonEvents(String fragment) =>
    (PartialJsonSession()..append(fragment)).events;

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

// ── the incremental session ───────────────────────────────────────────────────────────────────────

// Scanner modes. afterValue/expectKey are context-dependent on the stack top. 扫描态。
enum _Mode { expectValue, inString, inNumber, inKeyword, afterValue, expectKeyOrClose, expectColon, done, malformed }

// One open container on the stack. 栈上一只未闭合容器。
class _Frame {
  _Frame.object() : isObject = true, map = <String, Object?>{}, list = null;
  _Frame.array() : isObject = false, map = null, list = <Object?>[];
  final bool isObject;
  final Map<String, Object?>? map;
  final List<Object?>? list;
  int nextIndex = 0; // array: index of the element currently being parsed 当前元素下标
}

/// The resumable streaming parser. Feed deltas with [append]; read completions from [events] (append-only,
/// keep your own cursor); read the open string via [inFlightString]. A malformed byte freezes the session
/// ([malformed] = true) keeping everything already completed; further input is ignored. Trailing input
/// after the root value completes ([done]) is ignored (matches the original facade). 可续流解析器:append 喂
/// delta,events 只增不重发(消费方自持游标),inFlightString 读在途字符串;畸形即冻结保留既得;根值完成后忽略尾料。
class PartialJsonSession {
  final List<JsonEvent> events = [];

  _Mode _mode = _Mode.expectValue;
  final List<_Frame> _stack = [];
  final List<Object> _path = []; // path of the value currently being parsed 当前值路径

  // inString state 字符串态
  final StringBuffer _sb = StringBuffer();
  bool _stringIsKey = false;
  int _escape = 0; // 0=none 1=after-backslash 2..5=inside \uXXXX (collected hex count = _escape-2) 转义子态
  final StringBuffer _hex = StringBuffer();

  // inNumber / inKeyword buffer 数字/关键字缓冲
  final StringBuffer _lit = StringBuffer();

  // object: the last consumed comma awaits its key (`,}` is malformed). 对象逗号后必须键。
  bool _afterComma = false;

  // memoized in-flight materialization (read every frame by live windows) 在途文本按长度记忆化
  String? _inFlightCache;
  int _inFlightCacheLen = -1;

  bool get malformed => _mode == _Mode.malformed;
  bool get done => _mode == _Mode.done;

  /// The currently-open string VALUE (never a key) with its full path, or null. Materialization is
  /// memoized by length (live windows read this every frame). 在途字符串值+路径;按长度缓存物化。
  InFlightString? get inFlightString {
    if (_mode != _Mode.inString || _stringIsKey) return null;
    if (_sb.length != _inFlightCacheLen) {
      _inFlightCache = _sb.toString();
      _inFlightCacheLen = _sb.length;
    }
    return (path: List<Object>.unmodifiable(_path), text: _inFlightCache!);
  }

  /// The in-flight string's text if its path equals [path], else null — the argStringPartialAt facade.
  /// 路径匹配才给的在途尾值门面。
  String? inFlightStringAt(List<Object> path) {
    final f = inFlightString;
    if (f == null || f.path.length != path.length) return null;
    for (var k = 0; k < path.length; k++) {
      if (f.path[k] != path[k]) return null;
    }
    return f.text;
  }

  /// The latest CLOSED value at [path], or null. Scans [events] backwards (last write wins) — cheap:
  /// event counts are op-scale, not byte-scale. 该路径最新闭合值(倒扫 events,末写胜;量级=op 数非字节数)。
  Object? closedValueAt(List<Object> path) {
    for (var k = events.length - 1; k >= 0; k--) {
      final e = events[k];
      if (e.path.length != path.length) continue;
      var match = true;
      for (var j = 0; j < path.length; j++) {
        if (e.path[j] != path[j]) {
          match = false;
          break;
        }
      }
      if (match) return e.value;
    }
    return null;
  }

  /// The latest CLOSED string at [path], or null — settled bodies read this so a still-streaming value
  /// stays absent (and a hidden settled body costs O(events), never an O(bytes) rescan per frame).
  /// 该路径最新闭合字符串(在途值不给)——settled 体读它:每帧 O(事件数)而非 O(字节)重扫。
  String? closedStringAt(List<Object> path) {
    final v = closedValueAt(path);
    return v is String ? v : null;
  }

  /// The live text for the string at [path]: its CLOSED value if it finished, else the in-flight tail —
  /// the one-call feed for a live code/prose window. 该路径字符串的活文本:闭合值优先,否则在途尾值。
  String? liveStringAt(List<Object> path) {
    final closed = closedValueAt(path);
    if (closed is String) return closed;
    return inFlightStringAt(path);
  }

  /// The live text of the string whose FINAL path segment is [key], at ANY depth — in-flight first
  /// (the one being typed right now), else the LATEST closed one. This is the streaming feed for
  /// content that nests inside ops (`ops[i].code`, `ops[i].method.body`): the window follows whichever
  /// instance is currently growing. 末段键名匹配的活字符串(任意深度):在途优先(正在打的那个),否则最新
  /// 闭合——ops 嵌套内容(set_code 的 code/多 method 的 body)的流式喂源,窗自动跟当前生长者。
  String? liveStringNamed(String key) {
    final f = inFlightString;
    if (f != null && f.path.isNotEmpty && f.path.last == key) return f.text;
    for (var k = events.length - 1; k >= 0; k--) {
      final e = events[k];
      if (e.path.isNotEmpty && e.path.last == key && e.value is String) return e.value as String;
    }
    return null;
  }

  // arrayItemsAt memo — recomputed only when new events landed. 按事件数记忆化。
  List<Object?>? _itemsCache;
  String _itemsCacheKey = '';
  int _itemsCacheLen = -1;

  /// The completed ELEMENTS of the array at [path], in order — the incremental twin of
  /// [partialJsonArrayItems] (memoized by event count). 该路径数组的已闭合元素(按事件数记忆化)。
  List<Object?> arrayItemsAt(List<Object> path) {
    final key = path.join(' ');
    if (_itemsCacheLen == events.length && _itemsCacheKey == key) return _itemsCache!;
    final out = <Object?>[];
    for (final e in events) {
      if (e.path.length == path.length + 1 && e.path.last is int && _startsWith(e.path, path)) {
        out.add(e.value);
      }
    }
    _itemsCache = out;
    _itemsCacheKey = key;
    _itemsCacheLen = events.length;
    return out;
  }

  /// Feed the next chunk. O(chunk) — prior input is never rescanned. 喂下一段,绝不重扫旧料。
  void append(String delta) {
    if (_mode == _Mode.malformed || _mode == _Mode.done) return;
    var i = 0;
    final n = delta.length;
    while (i < n) {
      final c = delta.codeUnitAt(i);
      switch (_mode) {
        case _Mode.expectValue:
          if (_isWs(c)) {
            i++;
          } else if (c == 0x7b) {
            _stack.add(_Frame.object());
            _afterComma = false;
            _mode = _Mode.expectKeyOrClose;
            i++;
          } else if (c == 0x5b) {
            _stack.add(_Frame.array());
            // speculative first-element path segment — retracted below if `]` closes it empty.
            // 预押首元素路径段(空数组闭合时回退)。
            _path.add(0);
            _mode = _Mode.expectValue;
            i++;
          } else if (c == 0x22) {
            _sb.clear();
            _inFlightCacheLen = -1;
            _stringIsKey = false;
            _escape = 0;
            _mode = _Mode.inString;
            i++;
          } else if (c == 0x74 || c == 0x66 || c == 0x6e) {
            _lit.clear();
            _mode = _Mode.inKeyword;
            // do not consume; inKeyword reads it 不消费,交关键字态
          } else if (c == 0x2d || (c >= 0x30 && c <= 0x39)) {
            _lit.clear();
            _mode = _Mode.inNumber;
            // do not consume 不消费
          } else if (c == 0x5d && _stack.isNotEmpty && !_stack.last.isObject && _stack.last.nextIndex == 0) {
            // empty array `[]` — retract the speculative first-index path segment and close. 空数组。
            _path.removeLast();
            _closeContainer();
            i++;
          } else {
            _mode = _Mode.malformed;
          }
        case _Mode.inString:
          i = _scanString(delta, i);
        case _Mode.inNumber:
          if (_isNumChar(c)) {
            _lit.writeCharCode(c);
            i++;
          } else {
            final v = num.tryParse(_lit.toString());
            if (v == null) {
              _mode = _Mode.malformed;
            } else {
              _completeValue(v);
              // reprocess c in the new mode 该字符交新态重处理
            }
          }
        case _Mode.inKeyword:
          if (c >= 0x61 && c <= 0x7a) {
            _lit.writeCharCode(c);
            i++;
            final s = _lit.toString();
            if (s == 'true') {
              _completeValue(true);
            } else if (s == 'false') {
              _completeValue(false);
            } else if (s == 'null') {
              _completeValue(null);
            } else if (!('true'.startsWith(s) || 'false'.startsWith(s) || 'null'.startsWith(s))) {
              _mode = _Mode.malformed;
            }
          } else {
            _mode = _Mode.malformed; // keyword interrupted by non-letter 关键字断裂
          }
        case _Mode.afterValue:
          if (_isWs(c)) {
            i++;
          } else if (_stack.isEmpty) {
            _mode = _Mode.done; // trailing input ignored (facade semantics) 根后尾料忽略
          } else if (c == 0x2c) {
            final f = _stack.last;
            if (f.isObject) {
              _mode = _Mode.expectKeyOrClose;
              _afterComma = true; // `,}` stays malformed 逗号后闭括仍畸形
            } else {
              _path.add(f.nextIndex);
              _mode = _Mode.expectValue;
            }
            i++;
          } else if (c == 0x7d && _stack.last.isObject) {
            _closeContainer();
            i++;
          } else if (c == 0x5d && !_stack.last.isObject) {
            _closeContainer();
            i++;
          } else {
            _mode = _Mode.malformed;
          }
        case _Mode.expectKeyOrClose:
          if (_isWs(c)) {
            i++;
          } else if (c == 0x22) {
            _sb.clear();
            _inFlightCacheLen = -1;
            _stringIsKey = true;
            _escape = 0;
            _mode = _Mode.inString;
            _afterComma = false;
            i++;
          } else if (c == 0x7d && !_afterComma) {
            _closeContainer(); // empty object 空对象
            i++;
          } else {
            _mode = _Mode.malformed; // incl. `}` right after a comma (original rejects) 逗号后闭括=畸形
          }
        case _Mode.expectColon:
          if (_isWs(c)) {
            i++;
          } else if (c == 0x3a) {
            _mode = _Mode.expectValue;
            i++;
          } else {
            _mode = _Mode.malformed;
          }
        case _Mode.done:
        case _Mode.malformed:
          return;
      }
      if (_mode == _Mode.malformed) return;
    }
  }

  // Scan string content from delta[i]; returns the new i. Handles escapes across delta boundaries.
  // 扫字符串(转义可跨 delta 边界),返回新下标。
  int _scanString(String delta, int i) {
    final n = delta.length;
    while (i < n) {
      final c = delta.codeUnitAt(i);
      if (_escape == 1) {
        // after backslash 反斜杠后
        switch (c) {
          case 0x22:
            _sb.writeCharCode(0x22);
          case 0x5c:
            _sb.writeCharCode(0x5c);
          case 0x2f:
            _sb.writeCharCode(0x2f);
          case 0x6e:
            _sb.writeCharCode(0x0a);
          case 0x74:
            _sb.writeCharCode(0x09);
          case 0x72:
            _sb.writeCharCode(0x0d);
          case 0x62:
            _sb.writeCharCode(0x08);
          case 0x66:
            _sb.writeCharCode(0x0c);
          case 0x75:
            _escape = 2;
            _hex.clear();
            i++;
            continue;
          default:
            _mode = _Mode.malformed;
            return i;
        }
        _escape = 0;
        i++;
      } else if (_escape >= 2) {
        // inside \uXXXX — collect 4 hex 收 4 hex
        final isHex = (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x46) || (c >= 0x61 && c <= 0x66);
        if (!isHex) {
          _mode = _Mode.malformed;
          return i;
        }
        _hex.writeCharCode(c);
        _escape++;
        i++;
        if (_escape == 6) {
          _sb.writeCharCode(int.parse(_hex.toString(), radix: 16));
          _escape = 0;
        }
      } else if (c == 0x5c) {
        _escape = 1;
        i++;
      } else if (c == 0x22) {
        i++;
        final text = _sb.toString();
        if (_stringIsKey) {
          _path.add(text); // the member's path segment 成员路径段
          _mode = _Mode.expectColon;
        } else {
          _completeValue(text);
        }
        return i;
      } else {
        _sb.writeCharCode(c);
        i++;
      }
    }
    return i;
  }

  // A value at the current path completed: emit, attach to parent, restore mode. 值闭合:发事件/挂父/回态。
  void _completeValue(Object? v) {
    events.add((path: List<Object>.unmodifiable(_path), value: v));
    if (_stack.isEmpty) {
      _mode = _Mode.done;
      return;
    }
    final f = _stack.last;
    if (f.isObject) {
      f.map![_path.last as String] = v;
      _path.removeLast();
    } else {
      f.list!.add(v);
      _path.removeLast();
      f.nextIndex++;
    }
    _mode = _Mode.afterValue;
  }

  // Close the container on top of the stack — pop first so _completeValue attaches it to the PARENT
  // (its own path is already the current _path). 先弹栈再走 _completeValue,挂给父容器。
  void _closeContainer() {
    final f = _stack.removeLast();
    _completeValue(f.isObject ? f.map! : f.list!);
  }

  static bool _isWs(int c) => c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d;

  static bool _isNumChar(int c) =>
      (c >= 0x30 && c <= 0x39) || c == 0x2e || c == 0x65 || c == 0x45 || c == 0x2b || c == 0x2d;
}
