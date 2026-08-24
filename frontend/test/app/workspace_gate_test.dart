import 'package:anselm/app/workspace_gate.dart';
import 'package:anselm/app/workspace_onboarding.dart';
import 'package:anselm/core/contract/workspace.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/workspace/workspace_create_control.dart';
import 'package:anselm/core/workspace/workspace_bootstrap.dart';
import 'package:anselm/core/workspace/workspace_journey.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NeedsWorkspace extends WorkspaceBootstrap {
  @override
  Future<String?> build() async => null;
}

class _ReadyWorkspace extends WorkspaceBootstrap {
  @override
  Future<String?> build() async => 'ws_ready';
}

class _TransitionWorkspace extends WorkspaceBootstrap {
  @override
  Future<String?> build() async => null;

  @override
  Future<Workspace> create(String name) async {
    final workspace = Workspace(
      id: 'ws_created',
      name: name,
      language: 'zh-CN',
      createdAt: DateTime.utc(2026, 7, 27),
      updatedAt: DateTime.utc(2026, 7, 27),
    );
    state = AsyncData(workspace.id);
    return workspace;
  }
}

class _JourneyDestination extends StatefulWidget {
  const _JourneyDestination({required this.onMount});

  final VoidCallback onMount;

  @override
  State<_JourneyDestination> createState() => _JourneyDestinationState();
}

class _JourneyDestinationState extends State<_JourneyDestination> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) {
    final journey = WorkspaceJourneyScope.maybeOf(context)!;
    return Material(
      child: Center(
        child: SizedBox(
          key: journey.destinationComposerKey,
          width: 720,
          height: 52,
        ),
      ),
    );
  }
}

Widget _host(
  WorkspaceBootstrap Function() bootstrap, {
  Widget child = const Text('SHELL_READY'),
}) => ProviderScope(
  overrides: [workspaceBootstrapProvider.overrideWith(bootstrap)],
  child: TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      // Mirror production: the gate sits in MaterialApp.builder and may withhold the Navigator/Overlay
      // child entirely. onboarding must therefore be self-sufficient before Router release.
      builder: (_, _) => WorkspaceGate(child: child),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('empty server roster shows the one-page artwork onboarding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1192, 761);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(_NeedsWorkspace.new));
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceOnboarding), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text(t.coldStart.createWorkspace), findsOneWidget);
    expect(find.text('SHELL_READY'), findsNothing);
    expect(
      tester.takeException(),
      isNull,
      reason: 'minimum desktop window must not overflow',
    );
  });

  testWidgets('wide windows grow only the artwork; decision column stays 460', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    tester.view.physicalSize = const Size(1192, 1000);
    await tester.pumpWidget(_host(_NeedsWorkspace.new));
    await tester.pumpAndSettle();
    final compactArt = tester.getSize(find.byType(Image)).width;
    expect(tester.getSize(find.byType(WorkspaceCreateControl)).width, 460);

    tester.view.physicalSize = const Size(1900, 1000);
    await tester.pump();
    final wideArt = tester.getSize(find.byType(Image)).width;
    expect(tester.getSize(find.byType(WorkspaceCreateControl)).width, 460);
    expect(wideArt, greaterThan(compactArt));
    expect(wideArt, closeTo(860, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an existing workspace bypasses onboarding and releases the shell',
    (tester) async {
      await tester.pumpWidget(_host(_ReadyWorkspace.new));
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceOnboarding), findsNothing);
      expect(find.text('SHELL_READY'), findsOneWidget);
    },
  );

  testWidgets(
    'first create keeps both layouts for the flight and never remounts shell',
    (tester) async {
      tester.view.physicalSize = const Size(1192, 761);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var shellMounts = 0;

      await tester.pumpWidget(
        _host(
          _TransitionWorkspace.new,
          child: _JourneyDestination(onMount: () => shellMounts++),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Studio');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create-workspace')));
      await tester.pump();

      expect(find.byType(WorkspaceOnboarding), findsOneWidget);
      expect(find.byType(_JourneyDestination), findsOneWidget);
      expect(shellMounts, 1);

      await tester.pump(const Duration(milliseconds: 280));
      expect(find.byType(WorkspaceOnboarding), findsOneWidget);
      expect(shellMounts, 1);

      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceOnboarding), findsNothing);
      expect(find.byType(_JourneyDestination), findsOneWidget);
      expect(shellMounts, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
