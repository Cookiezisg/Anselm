import 'dart:async';

import 'package:anselm/core/contract/api_error.dart';
import 'package:anselm/core/contract/workspace.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/workspace/workspace_create_control.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Workspace _workspace(String name) => Workspace(
  id: 'ws_created',
  name: name,
  language: 'zh-CN',
  createdAt: DateTime.utc(2026, 7, 26),
  updatedAt: DateTime.utc(2026, 7, 26),
);

Widget _host(WorkspaceCreateControl child) => TranslationProvider(
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AnTheme.light(),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('starts quiet; typing reveals send; trim + Enter submits once', (
    tester,
  ) async {
    final pending = Completer<Workspace>();
    var calls = 0;
    String? submitted;
    await tester.pumpWidget(
      _host(
        WorkspaceCreateControl(
          autofocus: true,
          onCreate: (name) {
            calls++;
            submitted = name;
            return pending.future;
          },
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );
    expect(find.byKey(const ValueKey('create-workspace')), findsNothing);
    final haloFinder = find.byKey(const ValueKey('composer-halo-ring'));
    expect(
      tester.widget<AnimatedOpacity>(haloFinder).opacity,
      0,
      reason: 'autofocus stays neutral; focus alone must not light the halo',
    );

    await tester.enterText(find.byType(TextField), '  Fresh  ');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-workspace')), findsOneWidget);
    expect(
      tester.widget<AnimatedOpacity>(haloFinder).opacity,
      0,
      reason: 'typing reveals only the blue enter button',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      calls,
      1,
      reason: 'saving is single-flight even under repeated Enter',
    );
    expect(submitted, 'Fresh');
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(
      tester.widget<AnimatedOpacity>(haloFinder).opacity,
      1,
      reason: 'the halo belongs to the create transition',
    );

    pending.complete(_workspace('Fresh'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'duplicate code maps to the exact product copy and stays editable',
    (tester) async {
      await tester.pumpWidget(
        _host(
          WorkspaceCreateControl(
            onCreate: (_) => Future.error(
              const ApiException(
                code: AnselmErr.workspaceNameConflict,
                message: 'workspace name already exists',
                httpStatus: 409,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Existing');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create-workspace')));
      await tester.pumpAndSettle();

      expect(find.text('该工作区已存在'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).readOnly,
        isFalse,
      );
    },
  );

  testWidgets(
    'unknown failures use quiet localized fallback without collapsing',
    (tester) async {
      await tester.pumpWidget(
        _host(
          WorkspaceCreateControl(
            onCreate: (_) => Future<Workspace>.error(StateError('boom')),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Fresh');
      await tester.pump();
      final t = Translations.of(
        tester.element(find.byType(WorkspaceCreateControl)),
      );
      await tester.tap(find.byKey(const ValueKey('create-workspace')));
      await tester.pumpAndSettle();
      expect(find.text(t.coldStart.createFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
