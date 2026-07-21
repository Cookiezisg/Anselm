import 'package:anselm/core/ui/an_lead_value.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnLeadValue = dynamic label/value geometry: leading hugs content (capped), value fills the remainder
// flush-RIGHT, ellipsizing only when it grows back to the leading. These are real-geometry assertions —
// the previous (three-flex) layout silently parked the value at ~2/3 and a no-exception test missed it.
// AnLeadValue 动态键值几何契约(真几何断言,非"无异常"假绿)。
void main() {
  const w = 400.0;
  Widget host(Widget child, {double width = w}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );

  // The whole point: the value's right edge sits at the row's right edge (was parking mid-row). 值贴右缘。
  testWidgets('value is flush-right (right edge at the row right edge)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AnLeadValue(
          leading: Text('Name'),
          trailing: Text('normalize-input'),
        ),
      ),
    );
    final rowRight = tester.getRect(find.byType(AnLeadValue)).right;
    final valueRight = tester.getRect(find.text('normalize-input')).right;
    expect(
      (rowRight - valueRight).abs(),
      lessThan(1.0),
      reason:
          'value must be flush against the row right edge, not parked mid-row',
    );
  });

  // Dynamic: a short leading + a value wider than half the row renders at FULL width (left edge left of
  // centre) — proving the value owns (row − leading), not a capped 50/50 slot. 动态:短 leading 时值可超半宽。
  testWidgets(
    'value uses MORE than half when leading is short (dynamic, not 50/50)',
    (tester) async {
      const longish = 'a-medium-length-value-well-over-half-the-row-width';
      await tester.pumpWidget(
        host(
          const AnLeadValue(
            leading: Text('ID'),
            trailing: Text(
              longish,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
      final rowRect = tester.getRect(find.byType(AnLeadValue));
      final valueLeft = tester.getRect(find.text(longish)).left;
      expect(
        valueLeft,
        lessThan(rowRect.center.dx),
        reason:
            'with a short leading the value should span past the row midpoint — a 50/50 slot would forbid it',
      );
    },
  );

  // Starvation rail: a pathological-long leading ellipsizes within its cap — never an overflow, and the
  // value keeps a right-anchored slice. 病态超长 leading 在封顶处省略,不溢出,值仍留右锚切片。
  testWidgets('long leading ellipsizes (no overflow), value stays flush-right', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AnLeadValue(
          leading: Text(
            'an-extremely-long-leading-label-that-would-eat-the-whole-row-if-it-were-not-capped',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text('v', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final rowRight = tester.getRect(find.byType(AnLeadValue)).right;
    final valueRight = tester.getRect(find.text('v')).right;
    expect((rowRight - valueRight).abs(), lessThan(1.0));
  });

  // afterValue pins to the far right; the value sits to its LEFT (does not overlap). afterValue 钉最右、值在其左。
  testWidgets('afterValue pins far-right, value flush against it', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AnLeadValue(
          leading: Text('Key'),
          trailing: Text('val'),
          afterValue: Icon(Icons.check, size: 16),
        ),
      ),
    );
    final valueRight = tester.getRect(find.text('val')).right;
    final afterLeft = tester.getRect(find.byIcon(Icons.check)).left;
    expect(
      valueRight,
      lessThanOrEqualTo(afterLeft + 0.5),
      reason:
          'the value must sit to the left of the afterValue slot, not overlap it',
    );
  });

  // F1 regression: a LayoutBuilder-based version crashed under any intrinsic pass. The custom render object
  // implements intrinsics, so an IntrinsicHeight-equalised row (an inspector-rail idiom) must NOT throw.
  testWidgets(
    'survives an intrinsic pass — IntrinsicHeight + Row(stretch) + divider (no crash)',
    (tester) async {
      await tester.pumpWidget(
        host(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                VerticalDivider(width: 1),
                Expanded(
                  child: AnLeadValue(
                    leading: Text('Kind'),
                    trailing: Text('function'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'AnLeadValue must support intrinsics (no LayoutBuilder)',
      );
      expect(find.text('function'), findsOneWidget);
    },
  );

  // wrap: the value FILLS the remainder and wraps left-aligned (multi-line), NOT content-width flush-right.
  testWidgets(
    'wrap fills + wraps the value left (multi-line), not single-line flush-right',
    (tester) async {
      const long =
          'a long wrapping value that needs more than one line to render in this narrow column here';
      await tester.pumpWidget(
        host(
          const AnLeadValue(
            leading: Text('Notes'),
            trailing: Text(long),
            wrap: true,
          ),
          width: 300,
        ),
      );
      final row = tester.getRect(find.byType(AnLeadValue));
      final val = tester.getRect(find.text(long));
      expect(
        row.height,
        greaterThan(30),
        reason: 'a wrapping value must grow the row past a single line',
      );
      expect(
        val.left,
        lessThan(row.center.dx),
        reason:
            'wrapped value is left-anchored after the leading, not flush-right',
      );
      expect(
        val.right,
        greaterThan(row.center.dx),
        reason: 'wrapped value fills toward the right edge',
      );
    },
  );

  // F2 regression: under unbounded width the row degrades to content width instead of asserting on Expanded.
  testWidgets('degrades under unbounded width (no RenderFlex assertion)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal, // unbounded width
            child: const AnLeadValue(
              leading: Text('Name'),
              trailing: Text('value'),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.takeException(),
      isNull,
      reason: 'unbounded width must degrade, not crash',
    );
    expect(find.text('value'), findsOneWidget);
  });
}
