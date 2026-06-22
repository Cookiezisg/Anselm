import 'package:anselm/core/design/theme.dart';
import 'package:anselm/dev/gallery/catalog.dart';
import 'package:anselm/dev/gallery/specimen.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The gallery matrix — the machine gate (port of the demo's matrix.mjs). Every catalog specimen,
// incl. the pressure-bed (空/超长/海量/极值/注入), must build + lay out in a CONSTRAINED cell with
// NO thrown error and NO overflow (Flutter reports overflow as a FlutterError → takeException). The
// constrained width is the point: it reproduces the demo's "no in-grid overflow" assertion that
// caught the truncation/wrap bugs hardening was built for.
//
// 画廊矩阵——机器门禁(移植 matrix.mjs)。每个 specimen(含压力床)须在受限格里 build+布局,无抛错、无溢出
// (Flutter 把溢出报成 FlutterError → takeException)。受限宽是关键:复刻 demo「格内不溢出」断言。
void main() {
  for (final cat in galleryCatalog) {
    group(cat.label, () {
      for (final item in cat.items) {
        for (final s in item.specimens) {
          testWidgets('${item.name} · ${s.label}', (tester) async {
            await tester.pumpWidget(_host(s));
            await tester.pump(); // kick off any implicit/repeating animation
            await tester.pump(const Duration(milliseconds: 50));
            expect(tester.takeException(), isNull, reason: '${item.name}/${s.label} threw or overflowed');
            expect(find.byType(MaterialApp), findsOneWidget);
          });
        }
      }
    });
  }
}

Widget _host(GallerySpecimen s) {
  // Constrain to the gallery's real render width (narrow stress specimen / span / 280 grid track) so
  // overflow + truncation surface exactly as in the gallery. 用画廊真实渲染宽约束,溢出与截断如实暴露。
  final width = s.maxWidth ?? (s.span ? 600.0 : 280.0);
  return TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: Align(alignment: Alignment.centerLeft, child: Builder(builder: s.builder)),
          ),
        ),
      ),
    ),
  );
}
