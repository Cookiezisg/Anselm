import 'package:anselm/core/contract/interaction.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_badge.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/features/chat/ui/tool_interaction_gate.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The human gate (WRK-056 F16): danger/ask × awaiting/frozen. Labels resolve in EN for stable finders.
// 人闸:danger/ask × 待决/冻结;标签锁 en 供稳定 finder。

void main() {
  setUp(() => LocaleSettings.setLocaleRaw('en'));

  Future<void> pump(WidgetTester tester, Widget gate) async {
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 560, child: gate),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  ToolInteractionGate danger({
    InteractionAction? decided,
    void Function(InteractionAction, {String? answer})? onResolve,
  }) =>
      ToolInteractionGate(
        kind: GateKind.danger,
        prompt: 'wipe the build cache',
        toolName: 'Bash',
        evidence: const {'command': 'rm -rf /tmp/cache', 'cwd': '/ws'},
        decided: decided,
        onResolve: onResolve,
        autofocus: false,
      );

  ToolInteractionGate ask({
    List<String> options = const [],
    bool freeText = false,
    InteractionAction? decided,
    String? answer,
    bool autofocus = false,
    void Function(InteractionAction, {String? answer})? onResolve,
  }) =>
      ToolInteractionGate(
        kind: GateKind.ask,
        prompt: 'which currency?',
        options: options,
        allowFreeText: freeText,
        decided: decided,
        decidedAnswer: answer,
        autofocus: autofocus,
        onResolve: onResolve,
      );

  group('danger gate', () {
    testWidgets('awaiting renders badge + summary + evidence + fail-safe buttons', (tester) async {
      await pump(tester, danger());
      expect(find.text('Dangerous'), findsOneWidget);
      expect(find.text('wipe the build cache'), findsOneWidget);
      expect(find.text('rm -rf /tmp/cache'), findsOneWidget); // command → machine window
      expect(find.text('/ws'), findsOneWidget); // cwd → KV row
      expect(find.widgetWithText(AnButton, 'Allow'), findsOneWidget);
      expect(find.widgetWithText(AnButton, 'Deny'), findsOneWidget);
      expect(find.widgetWithText(AnButton, 'Always allow'), findsOneWidget);
    });

    testWidgets('each button fires the exact action', (tester) async {
      final fired = <InteractionAction>[];
      await pump(tester, danger(onResolve: (a, {answer}) => fired.add(a)));
      await tester.tap(find.widgetWithText(AnButton, 'Allow'));
      await tester.tap(find.widgetWithText(AnButton, 'Deny'));
      await tester.tap(find.widgetWithText(AnButton, 'Always allow'));
      expect(fired,
          [InteractionAction.approve, InteractionAction.deny, InteractionAction.approveAlways]);
    });

    testWidgets('fail-safe order: the negative (Deny) sits LEFT of the positive (Allow)', (tester) async {
      await pump(tester, danger());
      final deny = tester.getCenter(find.widgetWithText(AnButton, 'Deny')).dx;
      final allow = tester.getCenter(find.widgetWithText(AnButton, 'Allow')).dx;
      expect(deny, lessThan(allow));
    });

    testWidgets('frozen approve → decision章, no live buttons', (tester) async {
      await pump(tester, danger(decided: InteractionAction.approve));
      expect(find.widgetWithText(AnBadge, 'Allowed'), findsOneWidget);
      expect(find.widgetWithText(AnButton, 'Allow'), findsNothing);
      expect(find.widgetWithText(AnButton, 'Deny'), findsNothing);
    });

    testWidgets('frozen approve_always / deny show the right章', (tester) async {
      await pump(tester, danger(decided: InteractionAction.approveAlways));
      expect(find.textContaining('always'), findsOneWidget);
      await pump(tester, danger(decided: InteractionAction.deny));
      expect(find.widgetWithText(AnBadge, 'Denied'), findsOneWidget);
    });
  });

  group('ask gate', () {
    testWidgets('options render as numbered buttons; selecting one accepts with its label', (tester) async {
      final fired = <(InteractionAction, String?)>[];
      await pump(tester, ask(options: ['CNY', 'USD'], onResolve: (a, {answer}) => fired.add((a, answer))));
      expect(find.widgetWithText(AnButton, '1. CNY'), findsOneWidget);
      expect(find.widgetWithText(AnButton, '2. USD'), findsOneWidget);
      await tester.tap(find.widgetWithText(AnButton, '2. USD'));
      expect(fired.single, (InteractionAction.accept, 'USD'));
    });

    testWidgets("Don't answer declines", (tester) async {
      final fired = <InteractionAction>[];
      await pump(tester, ask(options: ['CNY'], onResolve: (a, {answer}) => fired.add(a)));
      await tester.tap(find.widgetWithText(AnButton, "Don't answer"));
      expect(fired.single, InteractionAction.decline);
    });

    testWidgets('free text: typing + Send accepts with the trimmed answer', (tester) async {
      final fired = <(InteractionAction, String?)>[];
      await pump(tester, ask(freeText: true, onResolve: (a, {answer}) => fired.add((a, answer))));
      await tester.enterText(find.byType(EditableText), '  euros please  ');
      await tester.tap(find.widgetWithText(AnButton, 'Send'));
      expect(fired.single, (InteractionAction.accept, 'euros please'));
    });

    testWidgets('frozen accept (option): the chosen option pins, others fade', (tester) async {
      await pump(tester, ask(options: ['CNY', 'USD', 'EUR'], decided: InteractionAction.accept, answer: 'USD'));
      // No live option buttons in the frozen record. 冻结无活选项钮。
      expect(find.widgetWithText(AnButton, '2. USD'), findsNothing);
      expect(find.text('2. USD'), findsOneWidget); // pinned as text
      // The two non-chosen options are wrapped in a disabled-opacity layer. 余两项在淡出层。
      final faded = tester.widgetList<Opacity>(find.byType(Opacity)).where((o) => o.opacity < 1).length;
      expect(faded, 2);
    });

    testWidgets('frozen accept (free text): the answer renders as a quotation', (tester) async {
      await pump(tester, ask(freeText: true, decided: InteractionAction.accept, answer: 'average FX rate'));
      expect(find.text('average FX rate'), findsOneWidget);
      expect(find.byType(EditableText), findsNothing); // no live field 冻结无活字段
    });

    testWidgets('frozen decline shows EXACTLY ONE Skipped章 (no body+footer double)', (tester) async {
      await pump(tester, ask(options: ['CNY'], decided: InteractionAction.decline));
      expect(find.widgetWithText(AnBadge, 'Skipped'), findsOneWidget);
    });

    testWidgets('number key 1–9 quick-selects an option while the gate holds focus', (tester) async {
      final fired = <(InteractionAction, String?)>[];
      await pump(tester, ask(options: ['CNY', 'USD', 'EUR'], autofocus: true,
          onResolve: (a, {answer}) => fired.add((a, answer))));
      await tester.pump(); // let autofocus settle
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      expect(fired.single, (InteractionAction.accept, 'USD'));
    });
  });
}
