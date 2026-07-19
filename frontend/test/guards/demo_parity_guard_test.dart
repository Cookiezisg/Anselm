// The DEMO/APP PARITY GATE (CLAUDE.md 前端守则「启动面」铁律) — `make app` and `make demo` share the
// ONE shell and differ in exactly TWO things: ①the data source (ProviderScope overrides → fixtures)
// and ②the startup/workspace gates (there is no sidecar to wait for). PLATFORM CHROME is neither, so
// it may not drift between the two entries.
//
// Why a SOURCE scan and not a widget test: the drift this catches lives in `main()`, before any
// widget exists — the binding object itself. A test binding is created by flutter_test, so no
// in-process test can ever observe which binding `lib/dev/demo_main.dart#main()` would have built.
// The only observable is the source. (真机 is the other observable, and that is how this was found.)
//
// The bug this was written for: demo_main called the BARE `WidgetsFlutterBinding.ensureInitialized()`
// while main.dart called `ScaledWidgetsFlutterBinding.ensureInitialized(scaleFactor: …)`. WindowZoom
// ._apply() relayouts only `if (binding is ScaledWidgetsFlutterBinding)` — so in the demo that test
// was FALSE and ⌘± died SILENTLY: the factor moved, `handleMetricsChanged()` never fired, nothing
// reflowed, and no test went red for a whole campaign while a comment claimed ⌘± worked. The demo is
// the project's visual acceptance floor; a deviation from the app falsifies acceptance itself.
//
// The expectation is DERIVED FROM main.dart, never hard-coded: add a zoom bootstrap call to the real
// entry and this guard demands it in the demo too — the parity law keeps holding without anyone
// remembering to edit this file.
//
// demo/app 同轨门禁(启动面铁律):两入口只差①数据源②启动门控;**平台 chrome 两者皆非**,故不得分叉。
// 为何扫源码而非 widget 测:此处的分叉活在 `main()` 里、在任何 widget 之前——是 binding 对象本身;而测试
// binding 由 flutter_test 造,进程内无任何测试能观察到 demo_main#main() 会造出哪口 binding,唯一可观测量
// 就是源码(另一个是真机,本条正是这样被抓到的)。所抓之 bug:demo 调裸 binding、main.dart 调 scaled,而
// WindowZoom._apply() 只在 `binding is ScaledWidgetsFlutterBinding` 时重排 → demo 里该判恒假、⌘± **静默**
// 失效(factor 动了、树永不重排),整整一场战役全绿,而注释白纸黑字说 ⌘± 活着。期望值**派生自 main.dart**、
// 绝不硬编码:真入口新增一个 zoom bootstrap 调用,本 guard 就同时要求 demo 也有——无需任何人记得改本文件。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _appEntry = 'lib/main.dart';
const _demoEntry = 'lib/dev/demo_main.dart';

/// The zoom bootstrap surface: the scaled binding + every static WindowZoom call an entry makes.
/// These are the calls that must exist in BOTH entries. 缩放 bootstrap 面:两入口都必须有的调用。
final _bootstrapCall =
    RegExp(r'(?:ScaledWidgetsFlutterBinding\.ensureInitialized|WindowZoom\.\w+)');

/// A bare `WidgetsFlutterBinding.ensureInitialized` — the lookbehind lets the Scaled subclass through
/// (its name CONTAINS the base call as a substring). 裸 binding;lookbehind 放行 Scaled 子类(其名含之)。
final _bareBinding = RegExp(r'(?<!Scaled)\bWidgetsFlutterBinding\.ensureInitialized');

/// The file's CODE, comments stripped. A doc comment that merely NAMES an api — main.dart's «its
/// scaleFactor reads [WindowZoom.factor]» — is PROSE, not a call, and must not enter the expectation
/// set (this guard exists because a comment lied once; it will not now take comments as evidence).
/// Neither entry puts `//` inside a string literal, so the line split is exact; if that ever changes,
/// the two `expect(expected, contains(…))` premises below go red rather than silently thinning the
/// expectation. 去注释后的代码:文档注释里点名的 api 是**散文**不是调用,不得进期望集(本 guard 的由来
/// 正是一句撒谎的注释——它绝不再拿注释当证据)。两入口的字符串里都没有 `//`,故按行切精确;将来若变,
/// 下面两条 contains 前提会先红,而不会让期望集悄悄变瘦。
String _code(String src) => src.split('\n').map((l) {
      final i = l.indexOf('//');
      return i < 0 ? l : l.substring(0, i);
    }).join('\n');

String _read(String path) {
  final f = File(path);
  expect(f.existsSync(), isTrue, reason: '$path 不在——入口移位了就在此处改本 guard');
  return f.readAsStringSync();
}

void main() {
  test('the demo entry installs the SAME zoom bootstrap as the app entry (⌘± must really zoom)', () {
    final app = _code(_read(_appEntry));
    final demo = _code(_read(_demoEntry));

    final expected = _bootstrapCall.allMatches(app).map((m) => m.group(0)!).toSet();
    // If main.dart itself lost the bootstrap, this guard's premise is gone — say so loudly rather
    // than pass vacuously on an empty expectation. main.dart 自己丢了 bootstrap,本 guard 前提即失,
    // 宁可大声报错也不要在空期望上真空通过。
    expect(expected, contains('ScaledWidgetsFlutterBinding.ensureInitialized'),
        reason: '$_appEntry 必须造 scaled binding(否则真 app 的 ⌘± 也是死的)');
    expect(expected, contains('WindowZoom.restore'), reason: '$_appEntry 必须首帧前恢复持久化缩放');

    for (final call in expected) {
      expect(demo.contains(call), isTrue,
          reason: '$_demoEntry 缺 `$call`——zoom 既非数据源亦非门控,不得在 demo 分叉'
              '(app 与 demo 只差数据源+启动门控)');
    }
  });

  test('the demo entry never creates the bare binding (the silent-⌘± bug\'s exact fingerprint)', () {
    final demo = _code(_read(_demoEntry));
    expect(_bareBinding.hasMatch(demo), isFalse,
        reason: '裸 WidgetsFlutterBinding 会让 WindowZoom._apply() 的 `binding is '
            'ScaledWidgetsFlutterBinding` 恒假 → ⌘± 静默失效(factor 动、树不重排)');
  });
}
