import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/window_setup.dart';
import '../core/design/colors.dart';
import '../core/design/theme.dart';
import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../core/ui/an_shell.dart';
import '../core/ui/an_state.dart';
import '../features/entities/data/entity_demo_fixture.dart';
import '../features/entities/data/entity_kind.dart';
import '../features/entities/data/entity_providers.dart';
import '../features/entities/state/selected_entity.dart';
import '../features/entities/ui/entity_rail.dart';
import '../i18n/strings.g.dart';

/// Entry for `make entities` — the Entities feature in the real desktop window, driven by the
/// zero-backend [demoEntityRepository] (one ProviderScope override). Dev-only: no sidecar, no startup
/// gate. Lets the rail be clicked/scrolled/filtered + selection reflected in the ocean, before STEP 4
/// builds the real detail sea. 入口:真桌面窗跑 Entities(fixture 零后端);可点/滚/筛 rail,选择映射到海洋。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocaleSync();
  await initWindow(title: 'Anselm · Entities (preview)');
  runApp(
    ProviderScope(
      overrides: [entityRepositoryProvider.overrideWithValue(demoEntityRepository())],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const AnShell(sidebar: EntityRail(), ocean: _PreviewOcean(), inspectorOpen: false),
        ),
      ),
    ),
  );
}

/// A placeholder ocean that reflects the rail's selection — a stand-in until STEP 4's detail sea.
/// 反映选择的占位海洋(STEP 4 详情前的替身)。
class _PreviewOcean extends ConsumerWidget {
  const _PreviewOcean();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedEntityProvider);
    final t = context.t;
    if (selected == null) {
      return const Center(
        child: AnState(kind: AnStateKind.empty, title: 'Entities preview', hint: 'Pick an entity from the rail →'),
      );
    }
    final c = context.colors;
    final kindLabel = switch (selected.kind) {
      EntityKind.function => t.ref.function,
      EntityKind.handler => t.ref.handler,
      EntityKind.agent => t.ref.agent,
      EntityKind.workflow => t.ref.workflow,
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(kindLabel, style: AnText.meta.copyWith(color: c.inkFaint)),
          const SizedBox(height: AnSpace.s4),
          Text(selected.id, style: AnText.body.copyWith(color: c.ink)),
          const SizedBox(height: AnSpace.s8),
          Text('(STEP 4 — detail sea goes here)', style: AnText.meta.copyWith(color: c.inkFaint)),
        ],
      ),
    );
  }
}
