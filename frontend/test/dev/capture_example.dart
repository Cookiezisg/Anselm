// The capture TEMPLATE — copy this file for a one-off visual check (`flutter test test/dev/
// capture_example.dart` → test/dev/out/example_*.png). Everything hard (fonts incl. the Lucide300
// icon face, ProviderScope, modal-inclusive boundary, engine-thread PNG dance) lives in
// capture_support.dart; a harness is just "what to render + what state".
// 截图模板——一次性视觉验证抄这个文件。难的全在地基;夹具只写「渲什么 + 什么状态」。
import 'package:anselm/core/contract/entities/skill.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/features/library/data/library_fixtures.dart';
import 'package:anselm/features/library/data/library_repository.dart';
import 'package:anselm/features/library/state/library_state.dart';
import 'package:anselm/features/library/ui/library_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/router_harness.dart';
import 'capture_support.dart';

/// Pins the inspector's selection without a router round-trip. 免路由钉住选区。
class _PinnedSelection extends SelectedDocController {
  _PinnedSelection(this._seed);
  final DocSelection? _seed;
  @override
  DocSelection? build() => _seed;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('example: skill inspector', (tester) async {
    setCaptureSurface(tester, const Size(360, 900));
    final repo = FixtureLibraryRepository(
      documents: const [],
      skills: [
        Skill(
          name: 'deploy-helper',
          description: 'Ship a release safely',
          context: 'inline',
          body: '# Deploy\n\n## Steps\n',
          frontmatter: const Frontmatter(allowedTools: ['Read', 'Bash(git:*)']),
          updatedAt: DateTime.utc(2026, 7, 1),
        ),
      ],
      skillFiles: const {
        'deploy-helper': {'scripts/deploy.sh': '#!/bin/sh\necho hi'},
      },
    );
    await tester.pumpWidget(
      CaptureHost(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(repo),
          goRouterProvider.overrideWithValue(
            buildTestRouter(page: const SizedBox.shrink()),
          ),
          selectedDocProvider.overrideWith(
            () => _PinnedSelection((isSkill: true, id: 'deploy-helper')),
          ),
        ],
        home: const LibraryInspector(),
      ),
    );
    await tester.pumpAndSettle();
    await capturePng(tester, 'example_skill_inspector');
  });
}
