import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/scheduler/state/selected_scheduler.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-069 S0 foundation battery — the routed selection shim's parse table + the AnCountdown primitive's
// three faces + the new firing-disposition aliases. S0 地基电池:选区解析表/倒计时三态/旁路处置 alias。

// Mirror of SelectedScheduler._parse via the public route shapes (the Notifier needs a router; the
// parse table is the load-bearing logic — test it through a tiny harness). 解析表经小竖琴直测。
SchedulerSelection? parse(String location) => SelectedScheduler.parseForTest(Uri.parse(location));

void main() {
  group('SelectedScheduler URL parse table (WRK-069 §11)', () {
    test('/scheduler → overview', () {
      expect(parse('/scheduler'), const SchedulerOverview());
    });

    test('/scheduler/w/:id → operations home; ?run= selects the linked pane', () {
      expect(parse('/scheduler/w/wf_1'), const SchedulerWorkflow('wf_1'));
      expect(parse('/scheduler/w/wf_1?run=fr_9'), const SchedulerWorkflow('wf_1', linkedRunId: 'fr_9'));
    });

    test('/scheduler/w/:id/runs/:frId → run flagship; ?node=&iter= select a node', () {
      expect(parse('/scheduler/w/wf_1/runs/fr_9'), const SchedulerRun('wf_1', 'fr_9'));
      expect(parse('/scheduler/w/wf_1/runs/fr_9?node=analyze&iter=2'),
          const SchedulerRun('wf_1', 'fr_9', nodeId: 'analyze', iteration: 2));
    });

    test('/scheduler/runs/:frId → the id-only relay (fr_ paste / panel_registry)', () {
      expect(parse('/scheduler/runs/fr_9'), const SchedulerRunRelay('fr_9'));
    });

    test('foreign and malformed paths → null (never a crash)', () {
      expect(parse('/'), isNull);
      expect(parse('/entities/workflow/wf_1'), isNull);
      expect(parse('/scheduler/w'), isNull);
      expect(parse('/scheduler/w/wf_1/runs'), isNull);
      expect(parse('/scheduler/bogus/x'), isNull);
    });
  });

  group('AnStatus firing-disposition aliases (WRK-069 状态学「未执行」桶)', () {
    test('skipped / superseded / shed → idle (neutral, never red)', () {
      expect(AnStatus.fromRaw('skipped'), AnStatus.idle);
      expect(AnStatus.fromRaw('superseded'), AnStatus.idle);
      expect(AnStatus.fromRaw('shed'), AnStatus.idle);
    });
  });

  group('AnCountdown', () {
    Widget host(Widget child) => MaterialApp(
          theme: AnTheme.light(),
          home: TranslationProvider(
            child: Material(child: Center(child: child)),
          ),
        );

    testWidgets('pending deadline renders the remaining word (amber default)', (tester) async {
      await tester.pumpWidget(host(AnCountdown(deadline: DateTime.now().add(const Duration(hours: 2, minutes: 1)))));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, contains('2h'));
    });

    testWidgets('overdue deadline renders the overdue word in danger ink', (tester) async {
      await tester.pumpWidget(host(AnCountdown(deadline: DateTime.now().subtract(const Duration(minutes: 5)))));
      final context = tester.element(find.byType(AnCountdown));
      final t = Translations.of(context);
      expect(find.text(t.run.countdownOverdue), findsOneWidget);
    });

    testWidgets('many countdowns share ONE timer (C-track: never a per-row ticker)', (tester) async {
      await tester.pumpWidget(host(Column(children: [
        for (var i = 1; i <= 20; i++) AnCountdown(deadline: DateTime.now().add(Duration(hours: i))),
      ])));
      expect(find.byType(AnCountdown), findsNWidgets(20));
      // Unmount everything — the shared pulse must cancel its timer (no pending-timer failure).
      // 全卸载后共享脉搏必须取消 Timer(无悬挂 Timer 报错)。
      await tester.pumpWidget(host(const SizedBox.shrink()));
    });
  });
}
