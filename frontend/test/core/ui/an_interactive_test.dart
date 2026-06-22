import 'package:anselm/core/ui/an_interactive.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnInteractive is the activation substrate for every control — the key contract is that a DISABLED
// surface activates by neither pointer nor keyboard (the demo matrix's disabled-passthrough gate).
// AnInteractive 是所有控件的激活基座——关键契约:禁用时指针与键盘都不激活(对齐 demo disabled 门)。
void main() {
  testWidgets('enabled surface activates by tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: AnInteractive(
          onTap: () => taps++,
          builder: (_, _) => const SizedBox(width: 48, height: 48),
        ),
      ),
    ));
    await tester.tap(find.byType(AnInteractive));
    expect(taps, 1);
  });

  testWidgets('pressed state is surfaced while the pointer is down', (tester) async {
    late Set<WidgetState> states;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: AnInteractive(
          onTap: () {},
          builder: (_, s) {
            states = s;
            return const SizedBox(width: 48, height: 48);
          },
        ),
      ),
    ));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(AnInteractive)));
    await tester.pump();
    expect(states.contains(WidgetState.pressed), isTrue);
    await gesture.up();
    await tester.pump();
    expect(states.contains(WidgetState.pressed), isFalse);
  });

  testWidgets('disabling clears a stale hover state (no stuck-hover after re-enable)', (tester) async {
    late Set<WidgetState> states;
    Widget build(bool enabled) => MaterialApp(
          home: Center(
            child: AnInteractive(
              enabled: enabled,
              onTap: () {},
              builder: (_, s) {
                states = s;
                return const SizedBox(width: 48, height: 48);
              },
            ),
          ),
        );
    await tester.pumpWidget(build(true));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.byType(AnInteractive)));
    addTearDown(gesture.removePointer);
    await tester.pump();
    expect(states.contains(WidgetState.hovered), isTrue);

    // Disable while hovered, then move the pointer away (onExit is null when disabled).
    await tester.pumpWidget(build(false));
    await gesture.moveTo(const Offset(0, 0));
    await tester.pump();
    // Re-enable: must NOT be stuck hovered.
    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(states.contains(WidgetState.hovered), isFalse);
  });

  testWidgets('disabled surface is inert (no tap, carries disabled state)', (tester) async {
    var taps = 0;
    late Set<WidgetState> states;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: AnInteractive(
          enabled: false,
          onTap: () => taps++,
          builder: (_, s) {
            states = s;
            return const SizedBox(width: 48, height: 48);
          },
        ),
      ),
    ));
    await tester.tap(find.byType(AnInteractive), warnIfMissed: false);
    expect(taps, 0);
    expect(states.contains(WidgetState.disabled), isTrue);
  });
}
