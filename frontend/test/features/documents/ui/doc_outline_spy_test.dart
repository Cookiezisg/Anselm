// The outline's scroll-spy contract on a LONG document: ① an outline CLICK highlights the clicked entry
// even when the scroll clamps at maxScrollExtent (bottom sections can physically never reach the head
// band — deriving would light a passed-by sibling); ② manual scrolling re-derives — top of the page means
// no heading has been passed (null), the very bottom pins the LAST entry. 大纲 scroll-spy 契约:①点击项
// 持有高亮(底部章节被 maxScrollExtent 夹断);②手动滚动重推导——顶部=null、滚到底=钉最后一项。
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/features/documents/data/documents_demo_fixture.dart';
import 'package:anselm/features/documents/data/document_repository.dart';
import 'package:anselm/features/documents/state/document_state.dart';
import 'package:anselm/features/documents/ui/document_ocean.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;

import '../../../support/router_harness.dart';

class _NoMentions extends MentionSource {
  @override
  Future<List<MentionCandidate>> search(String query) async => const [];
}

void main() {
  testWidgets('outline spy: click wins under clamp; manual scroll re-derives', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    BlinkController.indeterminateAnimationsEnabled = false;
    addTearDown(() => BlinkController.indeterminateAnimationsEnabled = true);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 780);
    addTearDown(tester.view.reset);

    final router = buildTestRouter(
        initialLocation: '/documents/doc_00000000000a11ce',
        page: const Scaffold(body: DocumentOcean()));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        documentsRepositoryProvider.overrideWithValue(demoDocumentsRepository()),
        goRouterProvider.overrideWithValue(router),
        mentionSourceProvider.overrideWithValue(_NoMentions()),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(
            debugShowCheckedModeBanner: false, theme: AnTheme.light(), routerConfig: router),
      ),
    ));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(DocumentOcean)));
    final outline = container.read(docOutlineProvider);
    expect(outline.length, greaterThanOrEqualTo(4), reason: 'the demo doc must stay outline-rich');

    // ① Manual scroll to the very bottom pins the LAST entry (the end clause).
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(container.read(docOutlineActiveProvider), outline.length - 1);

    // ② Manual scroll back to the top: nothing has been passed — no active entry.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 4000));
    await tester.pumpAndSettle();
    expect(container.read(docOutlineActiveProvider), isNull);

    // ③ Click a bottom-ish entry: the scroll clamps at its end, yet the CLICKED entry holds the
    // highlight (derivation would light the end-pinned last entry instead of the user's pick).
    container.read(outlineJumpProvider.notifier).jump(2);
    await tester.pumpAndSettle();
    expect(container.read(docOutlineActiveProvider), 2);
  });
}
