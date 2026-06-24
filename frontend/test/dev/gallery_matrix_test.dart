import 'package:anselm/core/design/theme.dart';
import 'package:anselm/dev/gallery/catalog.dart';
import 'package:anselm/dev/gallery/specimen.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            expect(
              tester.takeException(),
              isNull,
              reason: '${item.name}/${s.label} threw or overflowed',
            );
            // The specimen actually RENDERED something (a builder returning SizedBox.shrink() would
            // be 0×0 and pass takeException). 断言真渲染了东西(空 builder 是 0×0,会蒙混过 takeException)。
            final size = tester.getSize(find.byKey(_specimen));
            expect(
              size.width > 0 || size.height > 0,
              isTrue,
              reason: '${item.name}/${s.label} rendered nothing',
            );
          });

          // Reduced-motion axis: under disableAnimations EVERY specimen must SETTLE — a component that
          // forgot to gate a `.repeat()` loop leaves a ticker running so pumpAndSettle never settles
          // (→ timeout = FAIL). This is the machine enforcement of the reduced-motion static-fallback
          // standard (WRK-037 §1.2/§1.14). 降级轴:每个 specimen 必须 settle;忘了门控循环的会卡死 pumpAndSettle。
          testWidgets('${item.name} · ${s.label} · reduced', (tester) async {
            await tester.pumpWidget(_host(s, reduced: true));
            await tester.pumpAndSettle(
              const Duration(milliseconds: 16),
              EnginePhase.sendSemanticsUpdate,
              const Duration(
                seconds: 5,
              ), // a still-ticking loop never settles → fail fast 没门控的循环不收敛
            );
            expect(
              tester.takeException(),
              isNull,
              reason:
                  '${item.name}/${s.label} (reduced) threw/overflowed or left a ticker running',
            );
            final size = tester.getSize(find.byKey(_specimen));
            expect(
              size.width > 0 || size.height > 0,
              isTrue,
              reason: '${item.name}/${s.label} (reduced) rendered nothing',
            );
          });
        }
      }
    });
  }
}

const _specimen = ValueKey('specimen');

Widget _host(GallerySpecimen s, {bool reduced = false}) {
  // Constrain to the gallery's real render width (narrow stress specimen / span / 280 grid track) so
  // overflow + truncation surface exactly as in the gallery. 用画廊真实渲染宽约束,溢出与截断如实暴露。
  final width = s.maxWidth ?? (s.span ? 600.0 : 280.0);
  // ProviderScope: the gallery runs under one (G6 overlay specimens use ref.read(overlayProvider)),
  // so the matrix harness must too — else a Consumer specimen throws "No ProviderScope found" on build.
  // ProviderScope:画廊 G6 浮层 specimen 用 ref,矩阵宿主也须裹,否则 Consumer 一 build 就抛。
  return ProviderScope(
    child: TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(
          body: Center(
            // height: s.height bounds the cell for scroll-hosting components (else unbounded-height crash). 有界高。
            child: SizedBox(
              width: width,
              height: s.height,
              child: Align(
                alignment: Alignment.centerLeft,
                // Override disableAnimations BELOW MaterialApp's own MediaQuery so AnMotionPref sees it.
                // disableAnimations:true makes both reduced() and reducedOrAssistive() true. 覆写降级标志。
                child: Builder(
                  builder: (ctx) {
                    final cell = KeyedSubtree(
                      key: _specimen,
                      child: Builder(builder: s.builder),
                    );
                    return reduced
                        ? MediaQuery(
                            data: MediaQuery.of(
                              ctx,
                            ).copyWith(disableAnimations: true),
                            child: cell,
                          )
                        : cell;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
