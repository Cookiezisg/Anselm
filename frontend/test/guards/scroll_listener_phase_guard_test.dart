import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// CR-1b law (WRK-077): a `ScrollController` listener may NOT dirty a widget synchronously.
//
// A viewport notifies its listeners from inside the layout phase, and `jumpTo` notifies inline. The
// framework rejects a rebuild raised from there ("setState()/markNeedsBuild() called during build"),
// and per the two real crash logs behind CR-1 the resulting mid-frame subtree surgery desynchronised
// `InheritedElement`'s dependent ledger and killed the process. Nine sites shared this one shape.
//
// Behavioural tests cannot catch site number ten: whoever adds it will write the same natural-looking
// three lines, every existing test will stay green, and the crash will come back on a user's machine
// months later. So the law is guarded at the SOURCE — every `_onScroll`-style listener body must route
// its side effect through `runFrameSafe` (core/perf/frame_safe.dart), which is a no-op in safe phases
// and defers to the same frame's post-frame callback inside build/layout.
//
// CR-1b 军规(WRK-077):`ScrollController` 的监听器**不得**同步弄脏 widget。
//
// viewport 在布局阶段内部通知监听器,`jumpTo` 则就地通知。从那里发起的重建会被框架拒绝
// (「setState()/markNeedsBuild() called during build」),而按 CR-1 那两份真机崩溃栈,由此产生的帧中途
// 子树手术会让 `InheritedElement` 的依赖账本错位,进而崩掉进程。九处现场共用同一形状。
//
// 行为测试抓不到**第十处**:加它的人会写下同样自然的三行,既有测试全绿,而崩溃几个月后在用户机器上回来。
// 故本法在**源码层**守:凡 `_onScroll` 型监听器体,其副作用必须经 `runFrameSafe`
// (core/perf/frame_safe.dart)——安全相位下同步直执行,build/布局中则延到同一帧的后帧回调。
//
// WHAT THIS GUARD CANNOT SEE (state it, so nobody reads it as proof): it inspects the `_onScroll` body
// only. A listener that delegates to a private helper in the same file, and dirties from there, passes.
// The escape pattern below covers the one indirection that actually bit us — an outbound widget
// callback — and nothing more. It is a floor, not a proof.
//
// 本守卫**看不见什么**(写出来,免得有人把它当证明):它只检查 `_onScroll` 体。若监听器转交给同文件里的私有
// 辅助方法、再从那儿弄脏,它会放行。下面的逃逸模式只覆盖真正咬过我们的那一层间接——向外的 widget 回调——
// 仅此而已。**它是地板,不是证明。**

/// Side effects that dirty a widget, plus the ESCAPE: handing control to a widget callback. The escape
/// matters because a listener that calls out is a listener whose real side effect lives in another
/// file — `an_document_editor` fed `library_ocean.onScroll`, which folded the shell breadcrumb, and the
/// CR-1 audit's list of nine missed it for exactly that reason. `_pinned = …` style plain field writes
/// are fine (no rebuild).
///
/// 会弄脏 widget 的副作用,外加**逃逸**:把控制权交给 widget 回调。逃逸之所以要管,是因为「会往外调」的
/// 监听器,其真正的副作用住在另一个文件里——`an_document_editor` 喂给 `library_ocean.onScroll`,后者折叠壳
/// 面包屑,CR-1 审计那份九处名单正因如此漏掉它。`_pinned = …` 之类纯字段写不算(不触发重建)。
final _dirtying = RegExp(
  r'\bsetState\s*\(|\bref\s*\.\s*read\s*\(|\bjumpTo\s*\(|\bwidget\.\w+\?\.call\s*\(',
);

void main() {
  test('every scroll listener routes its side effects through runFrameSafe', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      if (!src.contains('addListener(_onScroll)')) continue;

      final body = _listenerBody(src);
      if (body == null) {
        offenders.add(
          '${entity.path}: registers _onScroll but has no _onScroll body',
        );
        continue;
      }
      if (_dirtying.hasMatch(body) && !body.contains('runFrameSafe')) {
        offenders.add(
          '${entity.path}: _onScroll dirties a widget without runFrameSafe',
        );
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'CR-1b: a scroll listener is called from inside layout — wrap the side effect in '
          'runFrameSafe (core/perf/frame_safe.dart).\n${offenders.join('\n')}',
    );
  });

  test('the guard can actually see a violation (it is not vacuously green)', () {
    // A guard that matches nothing is worse than no guard: it reads as coverage. So prove the matcher
    // fires on the exact three lines the nine sites used to contain.
    // 什么都匹配不到的守卫比没有守卫更糟——它看起来像覆盖。故证明匹配器对那九处原本的三行确实开火。
    const violation = '''
  void _onScroll() {
    final collapsed = _scroll.offset > _threshold;
    ref.read(shellHeadProvider.notifier).setCollapsed(collapsed);
  }
''';
    expect(_dirtying.hasMatch(violation), isTrue);
    expect(violation.contains('runFrameSafe'), isFalse);
  });
}

/// Extracts the `_onScroll` body by brace matching — a regex cannot balance braces, and the bodies
/// contain nested closures. 用括号配对取 `_onScroll` 体:正则平衡不了大括号,而这些体里有嵌套闭包。
String? _listenerBody(String src) {
  final start = src.indexOf('void _onScroll()');
  if (start < 0) return null;
  final open = src.indexOf('{', start);
  if (open < 0) return null;
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}') {
      depth--;
      if (depth == 0) return src.substring(open, i + 1);
    }
  }
  return null;
}
