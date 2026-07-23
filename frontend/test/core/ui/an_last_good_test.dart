import 'dart:async';

import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/an_last_good.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// AnLastGood — the last-known-good AsyncValue renderer: content while it has anything better than
// a skeleton (data / loading-with-previous / a cross-instance snapshot), deferred placeholder only
// on a true first load, hard generation drop on resetKey change, errors always visible.

Widget _host(AsyncValue<String> value, {Object? resetKey}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: AnLastGood<String>(
      value: value,
      resetKey: resetKey,
      builder: (_, d) => Text('DATA:$d'),
      placeholder: const Text('SKELETON'),
      errorBuilder: (_, e, _) => Text('ERROR:$e'),
    ),
  );
}

/// Past the deferral window (loaderDelay) but well inside staleHold. 过延迟窗、未过顶替窗。
final _pastDelay = AnMotion.loaderDelay + const Duration(milliseconds: 20);

/// Framework-built loading-with-previous: settle a REAL provider on [prev], then invalidate it into
/// a never-completing reload — riverpod itself attaches the previous value (`copyWithPrevious` is
/// @internal, so tests must obtain it the way production does). 真框架产物:先落定再 invalidate 成
/// 永不完成的重载,previous 由 riverpod 自己挂上(copyWithPrevious 是 @internal,测试走生产同路)。
Future<AsyncValue<String>> _refreshingWith(String prev) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  var round = 0;
  final p = FutureProvider<String>((ref) {
    round++;
    return round == 1 ? Future.value(prev) : Completer<String>().future;
  });
  await container.read(p.future);
  container.invalidate(p);
  return container.read(p);
}

/// Framework-built error-with-previous: settle on [prev], then invalidate into a throwing reload
/// and let it settle. 真框架产物:落定后 invalidate 成抛错重载并等其落定。
Future<AsyncValue<String>> _erroringWith(String prev) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  var round = 0;
  final p = FutureProvider<String>((ref) {
    round++;
    return round == 1 ? Future.value(prev) : Future.error(StateError('boom'));
  });
  await container.read(p.future);
  container.invalidate(p);
  await container.read(p.future).then((_) {}, onError: (_) {});
  return container.read(p);
}

void main() {
  testWidgets('true first load: nothing → deferred skeleton → content fades in', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AsyncLoading()));
    expect(find.text('SKELETON'), findsNothing); // within the deferral window

    await tester.pump(_pastDelay);
    expect(
      find.text('SKELETON'),
      findsOneWidget,
    ); // genuinely slow → skeleton surfaced

    await tester.pumpWidget(_host(const AsyncData('a')));
    // The surfaced skeleton dwells out loaderHold before content replaces it (min-display).
    await tester.pump(AnMotion.loaderHold + const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(find.text('DATA:a'), findsOneWidget);
    expect(find.text('SKELETON'), findsNothing);
  });

  testWidgets('fast first load never shows the skeleton', (tester) async {
    await tester.pumpWidget(_host(const AsyncLoading()));
    await tester.pump(const Duration(milliseconds: 40)); // sub-threshold
    await tester.pumpWidget(_host(const AsyncData('a')));
    await tester.pumpAndSettle();
    expect(find.text('DATA:a'), findsOneWidget);
    expect(find.text('SKELETON'), findsNothing);
  });

  testWidgets(
    'refresh/reload with previous (same provider) keeps content — no flash',
    (tester) async {
      // Built OUTSIDE pumpWidget — the helper awaits real provider futures. 先构造(内含真 await)。
      final refreshing = await _refreshingWith('a');

      await tester.pumpWidget(_host(const AsyncData('a')));
      await tester.pumpAndSettle();

      // invalidate → AsyncLoading carrying the previous value (riverpod's own previous mechanism).
      await tester.pumpWidget(_host(refreshing));
      await tester.pump(_pastDelay);
      expect(find.text('DATA:a'), findsOneWidget);
      expect(find.text('SKELETON'), findsNothing);

      await tester.pumpWidget(_host(const AsyncData('b')));
      await tester.pumpAndSettle();
      expect(find.text('DATA:b'), findsOneWidget);
    },
  );

  testWidgets(
    'selection switch (PURE loading — a new family instance) holds the snapshot',
    (tester) async {
      await tester.pumpWidget(_host(const AsyncData('a')));
      await tester.pumpAndSettle();

      // A new family instance starts from a bare AsyncLoading — no previous attached.
      await tester.pumpWidget(_host(const AsyncLoading()));
      await tester.pump(_pastDelay);
      expect(
        find.text('DATA:a'),
        findsOneWidget,
      ); // held: old content instead of a skeleton
      expect(find.text('SKELETON'), findsNothing);

      await tester.pumpWidget(_host(const AsyncData('b')));
      await tester.pumpAndSettle();
      expect(find.text('DATA:b'), findsOneWidget);
    },
  );

  testWidgets(
    'a hold expires after staleHold — a genuinely slow load must read as loading',
    (tester) async {
      await tester.pumpWidget(_host(const AsyncData('a')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host(const AsyncLoading()));
      await tester.pump(AnMotion.staleHold + const Duration(milliseconds: 20));
      expect(
        find.text('SKELETON'),
        findsOneWidget,
      ); // no second deferral — shown immediately
      expect(find.text('DATA:a'), findsNothing);

      await tester.pumpWidget(_host(const AsyncData('b')));
      // min-display: the just-surfaced skeleton dwells out loaderHold first. 刚亮骨架先留满停留。
      await tester.pump(AnMotion.loaderHold + const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
      expect(find.text('DATA:b'), findsOneWidget); // recovery resets the expiry
    },
  );

  testWidgets(
    'resetKey change drops the snapshot AND distrusts carried-over previous',
    (tester) async {
      final refreshing = await _refreshingWith('ws1-data');

      await tester.pumpWidget(
        _host(const AsyncData('ws1-data'), resetKey: 'ws1'),
      );
      await tester.pumpAndSettle();

      // New generation: the provider reloads WITH the old generation's value attached — rendering it
      // would be cross-generation data corruption, so the placeholder must win.
      await tester.pumpWidget(_host(refreshing, resetKey: 'ws2'));
      await tester.pump(_pastDelay);
      expect(find.text('DATA:ws1-data'), findsNothing);
      expect(find.text('SKELETON'), findsOneWidget);

      // The generation's own settled data ends the distrust (after the surfaced skeleton's dwell).
      await tester.pumpWidget(
        _host(const AsyncData('ws2-data'), resetKey: 'ws2'),
      );
      await tester.pump(AnMotion.loaderHold + const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
      expect(find.text('DATA:ws2-data'), findsOneWidget);
    },
  );

  testWidgets('errors always win — even with a previous value in hand', (
    tester,
  ) async {
    final erroring = await _erroringWith('a');

    await tester.pumpWidget(_host(const AsyncData('a')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_host(erroring));
    await tester.pump();
    expect(find.textContaining('boom'), findsOneWidget);
    expect(find.text('DATA:a'), findsNothing);
  });

  testWidgets('error → retry → data recovers to content', (tester) async {
    await tester.pumpWidget(
      _host(AsyncError<String>('boom', StackTrace.empty)),
    );
    await tester.pump();
    expect(find.text('ERROR:boom'), findsOneWidget);

    await tester.pumpWidget(_host(const AsyncData('a')));
    await tester.pumpAndSettle();
    expect(find.text('DATA:a'), findsOneWidget);
  });

  testWidgets(
    'min-display: data arriving just after the skeleton surfaced dwells out loaderHold',
    (tester) async {
      await tester.pumpWidget(_host(const AsyncLoading()));
      await tester.pump(_pastDelay); // skeleton surfaced
      expect(find.text('SKELETON'), findsOneWidget);

      // Data lands 40ms into the skeleton's life — swapping now would be appear-then-vanish.
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(_host(const AsyncData('a')));
      expect(find.text('SKELETON'), findsOneWidget); // still dwelling
      expect(find.text('DATA:a'), findsNothing);

      // Once loaderHold is satisfied the hold timer releases the waiting content.
      await tester.pump(AnMotion.loaderHold);
      await tester.pumpAndSettle();
      expect(find.text('DATA:a'), findsOneWidget);
      expect(find.text('SKELETON'), findsNothing);
    },
  );

  testWidgets(
    'min-display: a skeleton that already dwelled loaderHold swaps immediately',
    (tester) async {
      await tester.pumpWidget(_host(const AsyncLoading()));
      await tester.pump(_pastDelay);
      await tester.pump(AnMotion.loaderHold + const Duration(milliseconds: 20));
      expect(find.text('SKELETON'), findsOneWidget);

      await tester.pumpWidget(_host(const AsyncData('a')));
      await tester.pumpAndSettle();
      expect(find.text('DATA:a'), findsOneWidget); // no artificial extra wait
    },
  );

  testWidgets('min-display: errors interrupt the hold — never delayed', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AsyncLoading()));
    await tester.pump(_pastDelay); // skeleton surfaced, hold running
    await tester.pumpWidget(
      _host(AsyncError<String>('boom', StackTrace.empty)),
    );
    await tester.pump();
    expect(find.text('ERROR:boom'), findsOneWidget); // immediate
    expect(find.text('SKELETON'), findsNothing);
  });

  testWidgets('nullable T: null is a legitimate snapshot (record box, not T?)', (
    tester,
  ) async {
    Widget host(AsyncValue<String?> v) => Directionality(
      textDirection: TextDirection.ltr,
      child: AnLastGood<String?>(
        value: v,
        builder: (_, d) => Text('DATA:${d ?? "<null>"}'),
        placeholder: const Text('SKELETON'),
        errorBuilder: (_, e, _) => Text('ERROR:$e'),
      ),
    );

    await tester.pumpWidget(host(const AsyncData(null)));
    await tester.pumpAndSettle();
    expect(find.text('DATA:<null>'), findsOneWidget);

    // A pure loading after a null snapshot still holds (null ≠ "no snapshot").
    await tester.pumpWidget(host(const AsyncLoading()));
    await tester.pump(_pastDelay);
    expect(find.text('DATA:<null>'), findsOneWidget);
    expect(find.text('SKELETON'), findsNothing);
  });
}
