// The doc-page COLUMN GEOMETRY regression — the real-machine walkthrough (2026-07-05) caught the page
// pinned to the ocean's left edge with the body floating 40px right of the title. Two root causes, both
// asserted here so they can't return: ① SliverConstrainedCrossAxis LEFT-aligns (the header must ride
// AnPage's `Center > 720 > pageX` geometry instead); ② super_editor's stylesheet styler silently DROPS a
// later rule's `maxWidth` (non-mergeable style), so the default 640 column survived an addRulesAfter
// override — the stylesheet must be authored from scratch. 文档页列几何回归:①贴左(头必须走 AnPage 居中几何)
// ②上游丢弃后规则 maxWidth(样式表必须从零作者)。断言:标题与正文同 x,且列在海洋里居中。
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/features/documents/data/documents_demo_fixture.dart';
import 'package:anselm/features/documents/data/document_repository.dart';
import 'package:anselm/features/documents/ui/document_ocean.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;

import '../../../support/router_harness.dart';

class _NoMentions extends MentionSource {
  @override
  Future<List<MentionCandidate>> search(String query) async => const [];
}

void main() {
  testWidgets('doc page: title and body share one centered 720 column', (tester) async {
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

    // The centered reading column: (ocean − content)/2 + pageX from the left edge. 居中阅读列的左缘。
    const columnLeft = (1000 - AnSize.content) / 2 + AnInset.pageX;

    final titleX = tester.getTopLeft(find.text('Getting Started').first).dx;
    final bodyX = tester.getTopLeft(find.byType(TextComponent).first).dx;
    expect(titleX, columnLeft, reason: 'header must sit on the centered 720 column');
    expect(bodyX, columnLeft, reason: 'editor body must left-align with the header title');

    // The body text spans the full reading width (720 − 2·pageX) — the default 640 column must not survive.
    // 正文占满阅读宽(720−2·pageX),默认 640 列不得存活。
    expect(tester.getSize(find.byType(TextComponent).first).width,
        AnSize.content - 2 * AnInset.pageX);
  });
}
