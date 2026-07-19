import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_minimap_spine.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// W2 spine primitive (WRK-061 §7-8) — paints ink/prefix/paragraph marks and reports tap fractions.
// (Formerly co-housed with AnLiveCodeWindow's battery; that primitive was absorbed into
// AnCodeEditor.live in WRK-066 批2 and physically deleted.) 书脊原语:渲染+点报分数。
// (原与 AnLiveCodeWindow 电池同房;该件已于批2 并入 AnCodeEditor.live 并物理删除。)

Widget _host(Widget c) =>
    TranslationProvider(child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SizedBox(width: 600, child: c))));

void main() {
  testWidgets('spine renders and reports the tap fraction', (tester) async {
    double? tapped;
    await tester.pumpWidget(_host(SizedBox(
      height: 200,
      child: AnMinimapSpine(
        totalUnits: 1000,
        inkedUnits: 500,
        prefixUnits: 200,
        paragraphOffsets: const [250, 750],
        onTapFraction: (f) => tapped = f,
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getRect(find.byType(AnMinimapSpine)).center);
    expect(tapped, isNotNull);
    expect(tapped!, closeTo(0.5, 0.1));
  });
}
