import 'package:anselm/core/ui/an_lazy_indexed_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// C-009: the lazy IndexedStack behind the ocean switch. A slot is built on first show and then kept
/// mounted (its State survives); a never-shown slot is never built. These lock both halves.
/// C-009:海洋切换的懒 IndexedStack。槽首显才建、建后常驻(State 存活);从未显的槽从不建。锁两半。
void main() {
  // Each slot's initState appends its index — initState runs ONCE per mount, so this counts real mounts
  // (a kept-alive slot never re-inits; a lazy slot never inits until first shown). initState 一挂一次=真挂载计数。
  late List<int> inits;

  Widget host({required int index, int count = 3}) => MaterialApp(
        home: Scaffold(
          body: AnLazyIndexedStack(
            index: index,
            count: count,
            builder: (context, i) => _Slot(i, onInit: () => inits.add(i), key: ValueKey('slot$i')),
          ),
        ),
      );

  setUp(() => inits = []);

  testWidgets('lazy: only the shown slot is mounted; unshown slots are not', (tester) async {
    await tester.pumpWidget(host(index: 0));
    expect(inits, [0]); // only slot 0 mounted 仅槽 0 挂载
    expect(find.byKey(const ValueKey('slot1')), findsNothing); // slot 1 is a zero-cost box 槽 1=零成本盒
    expect(find.byKey(const ValueKey('slot2')), findsNothing);
  });

  testWidgets('switching mounts the new slot and keeps the old one alive (no re-init)', (tester) async {
    await tester.pumpWidget(host(index: 0));
    await tester.pumpWidget(host(index: 1));
    expect(inits, [0, 1]); // slot 1 mounted; slot 0 NOT re-inited (kept alive) 槽 1 挂、槽 0 未重挂
    // Both are in the tree — slot 0 is offstage-but-mounted (IndexedStack hides it via Offstage, so the
    // finder must not skip offstage). 两槽都在树中;槽 0 offstage 仍挂(IndexedStack 用 Offstage 藏,finder 不跳)。
    expect(find.byKey(const ValueKey('slot0'), skipOffstage: false), findsOneWidget);
    expect(find.byKey(const ValueKey('slot1'), skipOffstage: false), findsOneWidget);

    await tester.pumpWidget(host(index: 0));
    expect(inits, [0, 1]); // returning to slot 0 does NOT re-init it — instant, state-preserving 回槽 0 不重挂
  });

  testWidgets('a never-visited slot is never mounted; visiting it mounts once', (tester) async {
    await tester.pumpWidget(host(index: 0));
    await tester.pumpWidget(host(index: 1));
    expect(inits.contains(2), isFalse); // slot 2 never shown → never mounted 槽 2 从未显→从未挂
    await tester.pumpWidget(host(index: 2));
    expect(inits, [0, 1, 2]); // now mounted, exactly once 现挂载,恰一次
  });

  testWidgets('index selects the visible slot; out-of-range clamps without tearing down', (tester) async {
    await tester.pumpWidget(host(index: 1));
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
    // An out-of-range index (e.g. a non-stack selection) clamps — the alive slots must NOT be re-inited.
    // 越界(如非栈选区)钳制——活槽不得重挂。
    await tester.pumpWidget(host(index: 5, count: 3));
    expect(inits, [1]); // still only slot 1 ever mounted; no crash, no teardown 仍仅槽 1 挂过
  });

  testWidgets('keep-alive preserves a slot\'s mutable State across a switch away and back', (tester) async {
    await tester.pumpWidget(host(index: 0));
    // Bump slot 0's counter, switch away, switch back — the counter must persist. 改槽 0 计数,切走再回,须存。
    await tester.tap(find.byKey(const ValueKey('bump0')));
    await tester.pump();
    expect(find.text('count:1'), findsOneWidget);
    await tester.pumpWidget(host(index: 1));
    await tester.pumpWidget(host(index: 0));
    expect(find.text('count:1'), findsOneWidget); // preserved, not reset to 0 保留、未重置
  });
}

class _Slot extends StatefulWidget {
  const _Slot(this.i, {required this.onInit, super.key});
  final int i;
  final VoidCallback onInit;
  @override
  State<_Slot> createState() => _SlotState();
}

class _SlotState extends State<_Slot> {
  int _count = 0;
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Text('slot${widget.i}'),
        Text('count:$_count'),
        GestureDetector(
          key: ValueKey('bump${widget.i}'),
          onTap: () => setState(() => _count++),
          child: const Text('bump'),
        ),
      ]);
}
