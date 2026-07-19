import 'dart:ui' show PlatformDispatcher;

import 'package:anselm/core/error/error_boundary.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 6 gate — installErrorHandlers wires a RECOVERABLE ErrorWidget (never the gray crash screen).
// We render the installed builder's output directly (the throw→replace wiring is Flutter's own,
// well-tested, behavior; what we verify is that OUR widget is installed and renders self-contained).
void main() {
  testWidgets('installed ErrorWidget.builder renders the recoverable card, self-contained', (tester) async {
    final prevFlutter = FlutterError.onError;
    final prevWidget = ErrorWidget.builder;
    final prevPlatform = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = prevFlutter;
      ErrorWidget.builder = prevWidget;
      PlatformDispatcher.instance.onError = prevPlatform;
    });

    installErrorHandlers();

    // Render exactly what Flutter would substitute for a thrown subtree — note: no MaterialApp /
    // Directionality / theme around it, proving the widget is self-contained (it must render anywhere).
    final card = ErrorWidget.builder(FlutterErrorDetails(exception: StateError('boom')));
    await tester.pumpWidget(card);

    expect(find.text(t.startup.errorTitle), findsOneWidget);
    expect(find.text(t.startup.errorHint), findsOneWidget);
  });
}
