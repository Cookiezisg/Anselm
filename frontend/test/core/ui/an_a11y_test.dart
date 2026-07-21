import 'dart:io';

import 'package:anselm/core/ui/an_a11y.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/announce_probe.dart';

// AnA11y is the kit's ONE screen-reader push + the ONE ruling on how `selected` reaches the platform.
// Every assertion here is on the PLATFORM CHANNEL (an announcement leaves no trace in the semantics
// tree) or on the pure helper. AnA11y=套件唯一的读屏推送 + selected 如何抵达平台的唯一裁决点;断言全打在
// **平台通道**上(播报在语义树里不留痕)或纯函数上。
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  // A widget that pushes once from a post-frame callback, like every real caller does. 一个照真实调用方
  // 那样在 post-frame 推一次的件。
  Widget speaker(void Function(BuildContext) speak) => Builder(
    builder: (context) {
      WidgetsBinding.instance.addPostFrameCallback((_) => speak(context));
      return const SizedBox(width: 10, height: 10);
    },
  );

  group('announce — new information, all platforms', () {
    testWidgets('posts the message politely by default', (tester) async {
      final handle = tester.ensureSemantics();
      final said = probeAnnouncements(tester);
      await tester.pumpWidget(
        host(speaker((c) => AnA11y.announce(c, 'Saved'))),
      );
      await tester.pumpAndSettle();
      expect(said.map((a) => a.toString()), ['polite: Saved']);
      handle.dispose();
    });

    testWidgets('carries assertive through to the channel', (tester) async {
      final handle = tester.ensureSemantics();
      final said = probeAnnouncements(tester);
      await tester.pumpWidget(
        host(
          speaker(
            (c) => AnA11y.announce(
              c,
              'Boom',
              assertiveness: Assertiveness.assertive,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(said.single.isAssertive, isTrue);
      expect(said.single.message, 'Boom');
      handle.dispose();
    });

    // NOT COVERED, and deliberately not faked: the `semanticsEnabled` guard's false branch. flutter_test
    // holds semantics ON for the whole binding (measured: `SemanticsBinding.instance.semanticsEnabled`
    // is already true BEFORE the first pump and stays true after `ensureSemantics().dispose()`), and no
    // public lever turns it off — `platformDispatcher.semanticsEnabledTestValue` only seeds the notifier
    // at construction. So «no screen reader attached → nothing posted» is reasoned, not proven. It is a
    // pure optimisation (`SemanticsService.sendAnnouncement` posts unconditionally), so the risk of it
    // being wrong is a wasted channel message, never a missed announcement: `semanticsEnabled` is
    // `_outstandingHandles > 0`, and the engine takes a handle when the platform asks for semantics —
    // i.e. it cannot be false while VoiceOver is running.
    // **未覆盖且刻意不造假**:semanticsEnabled 门的 false 分支。flutter_test 全程把语义开着(实测:首次 pump
    // **之前**就是 true,ensureSemantics().dispose() 之后仍是 true),且无公开开关能关掉它。故「无读屏→不发」是
    // **推理、非实证**。它是纯优化(sendAnnouncement 本身无条件发),即便判错也只是白发一条通道消息、绝不会漏播:
    // semanticsEnabled = _outstandingHandles > 0,而平台索要语义时引擎会占一个 handle —— VoiceOver 开着时它不可能是 false。

    testWidgets('an empty message is never posted', (tester) async {
      final handle = tester.ensureSemantics();
      final said = probeAnnouncements(tester);
      await tester.pumpWidget(host(speaker((c) => AnA11y.announce(c, ''))));
      await tester.pumpAndSettle();
      expect(said, isEmpty);
      handle.dispose();
    });
  });

  group('announceFocusMove — a macOS-only patch, not a preference', () {
    testWidgets(
      'macOS: pushes, because its bridge drops FOCUS_CHANGED',
      (tester) async {
        final handle = tester.ensureSemantics();
        final said = probeAnnouncements(tester);
        await tester.pumpWidget(
          host(speaker((c) => AnA11y.announceFocusMove(c, 'Row 2'))),
        );
        await tester.pumpAndSettle();
        expect(said.map((a) => a.toString()), [
          'polite: Row 2',
        ], reason: 'macOS 上被聚焦的节点是哑的,不推则光标移动全程无声');
        handle.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'windows/linux: silent — the focus notification already read it',
      (tester) async {
        final handle = tester.ensureSemantics();
        final said = probeAnnouncements(tester);
        await tester.pumpWidget(
          host(speaker((c) => AnA11y.announceFocusMove(c, 'Row 2'))),
        );
        await tester.pumpAndSettle();
        expect(said, isEmpty, reason: 'Win/Linux 会发焦点通知;再推=双读(flutter#153020)');
        handle.dispose();
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.linux,
      }),
    );
  });

  // A SOURCE GUARD, because this defect's whole history is that it crept in through a DEFAULT and then
  // got frozen by four tests that asserted it (an_button / an_batch_bar / s4_memory / an_tabs each pinned
  // `hasSelectedState` on a control that has no selection concept — one comment even called it «基座恒带
  // selected 轴», describing the bug as the design). Reviewers cannot be the enforcement for an
  // invariant that is invisible unless you dump the tree.
  // **源码守卫**:本缺陷的全部历史就是——它经一个**缺省值**溜进来,再被四个断言它的测试冻住(an_button /
  // an_batch_bar / s4_memory / an_tabs 各自把 hasSelectedState 钉在根本没有选中概念的控件上,其中一条注释
  // 甚至写「基座恒带 selected 轴」=把缺陷当设计描述)。一条**不 dump 就看不见**的不变式,不能靠人复审来守。
  test(
    'no widget writes Semantics(selected:) by hand — AnA11y.selected is the only ruling',
    () {
      const seam = 'lib/core/ui/an_a11y.dart';
      final offenders = <String>[];
      for (final f in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart') ||
            f.path.endsWith('.g.dart') ||
            f.path.endsWith('.freezed.dart')) {
          continue;
        }
        if (f.path == seam) continue;
        final src = f.readAsStringSync();
        // Every `selected:` that sits inside a Semantics(...) argument list must be AnA11y.selected(...).
        // AnInteractive's own `selected:` prop is a widget argument, not a Semantics one — it is the
        // sanctioned route (it funnels through the seam internally).
        // 凡落在 Semantics(...) 实参里的 selected: 都必须是 AnA11y.selected(...);AnInteractive 的 selected:
        // 是 widget 参数、不是 Semantics 参数——那是被认可的路(它内部经缝出闸)。
        for (final m in RegExp(r'Semantics\(').allMatches(src)) {
          // Scan the balanced argument list of this Semantics( ... ).
          var depth = 1;
          var i = m.end;
          final buf = StringBuffer();
          while (i < src.length && depth > 0) {
            final ch = src[i];
            if (ch == '(') depth++;
            if (ch == ')') depth--;
            // Only collect at depth 1 — nested calls/children have their own scope. 只收深度 1。
            if (depth == 1) buf.write(ch);
            i++;
          }
          final args = buf.toString();
          final sel = RegExp(
            r'(?<![\w.])selected:\s*([^,\n]*)',
          ).firstMatch(args);
          if (sel == null) continue;
          if (sel.group(1)!.contains('AnA11y.selected')) continue;
          offenders.add(
            '${f.path}: Semantics(selected: ${sel.group(1)!.trim()})',
          );
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Semantics 的 selected 只许经 AnA11y.selected 出闸(否则 false 会被念成「已选中」);\n'
            '控件请传 AnInteractive 的 selected prop、或让它保持 null(=没有选中这个概念)。\n违规:\n${offenders.join('\n')}',
      );
    },
  );

  group('selected — «say no by not saying» (pinned-engine workaround)', () {
    // The whole point: `false` and `null` are indistinguishable on the wire, and `true` survives. This
    // is the ONE place to flip when Flutter moves off 3.41.x (fixed by flutter#184058 upstream).
    // 要害:线上 false 与 null 不可分,true 照过。升离 3.41.x 时改这一处。
    test('true stays true', () => expect(AnA11y.selected(true), isTrue));
    test(
      'false becomes null — an explicit false is announced as SELECTED on mac/win',
      () => expect(AnA11y.selected(false), isNull),
    );
    test(
      'null stays null — «selection is not a concept here»',
      () => expect(AnA11y.selected(null), isNull),
    );
  });
}
