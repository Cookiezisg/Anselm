import 'package:anselm/features/chat/state/stage_expansion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The sidestage accordion's sticky expansion set (WRK-064) — toggle / open / close / expand-all /
// collapse-all, and the sticky rule (nothing auto-collapses; only an explicit collapse clears).
// 侧幕手风琴的粘性展开集:开合/全展/全收 + 粘性(只有显式收起才清)。

ProviderContainer _c() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

void main() {
  const conv = 'cv_1';

  test('toggle flips a row; open/close are idempotent', () {
    final c = _c();
    final n = c.read(stageExpansionProvider(conv).notifier);
    expect(c.read(stageExpansionProvider(conv)), isEmpty);

    n.toggle('function:fn_1');
    expect(c.read(stageExpansionProvider(conv)), {'function:fn_1'});
    n.toggle('function:fn_1');
    expect(c.read(stageExpansionProvider(conv)), isEmpty);

    n.open('todo');
    n.open('todo'); // idempotent 幂等
    expect(c.read(stageExpansionProvider(conv)), {'todo'});
    n.close('nope'); // closing an absent row is a no-op 关不存在的行=空操作
    expect(c.read(stageExpansionProvider(conv)), {'todo'});
    n.close('todo');
    expect(c.read(stageExpansionProvider(conv)), isEmpty);
  });

  test('expandAll adds every id; collapseAll clears even sticky rows', () {
    final c = _c();
    final n = c.read(stageExpansionProvider(conv).notifier);
    n.open('function:fn_1'); // a user-pinned row 用户展开的行
    n.expandAll(['todo', 'workflow:wf_1', 'function:fn_1']);
    expect(c.read(stageExpansionProvider(conv)), {'function:fn_1', 'todo', 'workflow:wf_1'});
    // collapseAll is explicit → it wins over the sticky-open rule. 显式收起压过粘性。
    n.collapseAll();
    expect(c.read(stageExpansionProvider(conv)), isEmpty);
  });

  test('family isolates conversations', () {
    final c = _c();
    c.read(stageExpansionProvider('a').notifier).open('todo');
    expect(c.read(stageExpansionProvider('a')), {'todo'});
    expect(c.read(stageExpansionProvider('b')), isEmpty); // a different thread is untouched 另一会话不受影响
  });
}
