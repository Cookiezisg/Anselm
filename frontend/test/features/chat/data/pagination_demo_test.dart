import 'package:anselm/features/chat/data/chat_demo_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

// D-005/011 — the `make demo` seed must cross the list page sizes so the rail (conversations, 30/page)
// and the sidestage Cast ledger (touchpoints, 50/page) both PAGINATE (loadMore + the skeleton foot),
// not sit on a single short page. 种子越过页大小,两处都翻页。
void main() {
  final repo = demoChatRepository();

  test(
    'D-005 rail pagination: >30 active conversations → a full first page + a cursor',
    () async {
      final p1 = await repo.listConversations(limit: 30);
      expect(p1.items.length, 30, reason: '满页');
      expect(p1.hasMore, isTrue);
      expect(p1.nextCursor, isNotNull, reason: 'loadMore 有下一页');
      final p2 = await repo.listConversations(limit: 30, cursor: p1.nextCursor);
      expect(p2.items, isNotEmpty, reason: '第二页有内容');
      // No row repeats across pages (keyset paging). 键集分页不重复。
      final ids = {for (final c in p1.items) c.id};
      expect(p2.items.every((c) => !ids.contains(c.id)), isTrue);
    },
  );

  test(
    'D-011 Cast ledger pagination: cv_p20 touched >50 things → a full page + a cursor',
    () async {
      final p1 = await repo.listTouchpoints('cv_p20', limit: 50);
      expect(p1.items.length, 50, reason: '满页');
      expect(p1.hasMore, isTrue);
      expect(p1.nextCursor, isNotNull);
      final p2 = await repo.listTouchpoints(
        'cv_p20',
        limit: 50,
        cursor: p1.nextCursor,
      );
      expect(p2.items, isNotEmpty);
      // The first rows resolve to real seeded snapshots (open to a real stage). 前排真快照。
      expect(p1.items.any((t) => t.itemId == 'fn_sync'), isTrue);
    },
  );
}
