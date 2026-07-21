import 'package:anselm/features/chat/data/chat_demo_fixture.dart';
import 'package:anselm/features/entities/data/entity_demo_fixture.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:flutter_test/flutter_test.dart';

// D-012/029 — two passively-visible recoverable error states, each scoped to ONE seeded broken item so
// the rest of the demo stays healthy: cv_flaky's Cast ledger fails its FIRST fetch then Retry succeeds;
// the fn_broken entity is listed in the rail but its detail GET throws (error+retry panel). 开即见错。
void main() {
  test(
    'D-012 Cast ledger: cv_flaky fails its first touchpoint fetch, then a retry succeeds',
    () async {
      final repo = demoChatRepository();
      await expectLater(
        repo.listTouchpoints('cv_flaky'),
        throwsA(isA<StateError>()),
        reason: '首拉失败',
      );
      final retry = await repo.listTouchpoints('cv_flaky');
      expect(retry.items, isNotEmpty, reason: '重试成、台账有料');
      // Every OTHER conversation's ledger is healthy from the first fetch. 其他对话首拉即成。
      expect(
        (await demoChatRepository().listTouchpoints('cv_sync')).items,
        isNotEmpty,
      );
    },
  );

  test(
    'D-021 send failure: cv_flaky fails its first send (→ the retry/discard bubble)',
    () async {
      final repo = demoChatRepository();
      // The throw happens BEFORE the reply playback, so no timers are scheduled. 抛在回放前,不排 timer。
      await expectLater(
        repo.sendMessage('cv_flaky', content: '测试一下发送'),
        throwsA(isA<StateError>()),
        reason: '首发失败→乐观泡失败态',
      );
    },
  );

  test(
    'D-029 entity detail: fn_broken is listed in the rail but its detail GET throws',
    () async {
      final repo = demoEntityRepository();
      final rows = await repo.listEntities(EntityKind.function);
      expect(
        rows.items.any((r) => r.id == 'fn_broken'),
        isTrue,
        reason: 'rail 列出坏行',
      );
      await expectLater(
        repo.getFunction('fn_broken'),
        throwsA(isA<StateError>()),
        reason: '详情 GET 抛→错误面',
      );
      // A healthy sibling opens fine. 正常兄弟照开。
      expect((await repo.getFunction('fn_normalize')).name, isNotEmpty);
    },
  );
}
