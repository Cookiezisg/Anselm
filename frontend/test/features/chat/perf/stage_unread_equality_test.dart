import 'package:anselm/features/chat/model/stage_director.dart';
import 'package:flutter_test/flutter_test.dart';

// C-003 — during parallel-tool streaming a NON-subject channel's `unread++` per delta used to break
// StageActivityView / StageState value equality, so the whole _AccordionList rebuilt + _computeRows
// re-ran EVERY frame. unread is a beat counter for an unbuilt badge (nothing renders it), so it is now
// excluded from equality. This pins that unread churn is a no-op for the provider AND that REAL changes
// still break equality (no swallowed broadcast). 未读拍数不破相等,真变化仍破。
StageActivityView _view({
  bool live = true,
  bool failed = false,
  int unread = 0,
  String? itemId,
}) => StageActivityView(
  blockId: 'b1',
  toolName: 'run_function',
  kind: 'function',
  live: live,
  failed: failed,
  unread: unread,
  itemId: itemId,
);

void main() {
  group('C-003 StageActivityView equality ignores unread', () {
    test('two views differing ONLY in unread are equal (== and hashCode)', () {
      expect(_view(unread: 0), _view(unread: 7));
      expect(_view(unread: 0).hashCode, _view(unread: 7).hashCode);
    });

    test('a real change (live / failed / itemId) still breaks equality', () {
      expect(
        _view(live: true),
        isNot(_view(live: false)),
        reason: 'close 广播不吞',
      );
      expect(_view(failed: false), isNot(_view(failed: true)));
      expect(
        _view(itemId: null),
        isNot(_view(itemId: 'fn_1')),
        reason: 'Cast 脉冲仍到',
      );
    });
  });

  group('C-003 StageState skips no-op broadcasts on channel unread churn', () {
    StageState state(int chUnread) => StageState(
      phase: StagePhase.following,
      subject: _view(itemId: 'subj'),
      channels: [
        StageActivityView(
          blockId: 'b2',
          toolName: 'call_handler',
          kind: 'handler',
          live: true,
          failed: false,
          unread: chUnread,
          itemId: 'other',
        ),
      ],
    );

    test('a background channel delta (unread++) does NOT change StageState', () {
      // The provider skips equal states → _AccordionList never rebuilds on unread alone. 相等即不重建。
      expect(state(0), state(1));
      expect(state(1), state(9));
    });
  });
}
