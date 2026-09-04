import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anselm/core/contract/api_key.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/core/ui/an_input.dart';
import 'package:anselm/core/ui/an_row.dart';
import 'package:anselm/core/ui/an_type_to_confirm.dart';
import 'package:anselm/features/settings/data/settings_repository.dart';
import 'package:anselm/features/settings/ui/panels/voices_card.dart';
import 'package:anselm/i18n/strings.g.dart';

Future<Translations> pumpVoicesCard(
  WidgetTester tester,
  VoiceInventory inv, {
  FixtureSettingsRepository? repository,
}) async {
  final repo = repository ?? (FixtureSettingsRepository()..fixtureVoices = inv);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory()),
        activeWorkspaceProvider.overrideWith(_StaticActiveWorkspace.new),
        settingsRepositoryProvider.overrideWithValue(repo),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: VoicesCard()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The same Translations the card itself resolved — asserting against a hand-typed literal would
  // only prove the test and the card agree about the CURRENT default locale.
  // 与卡片自己解析到的**同一份** Translations——对着手打的字面量断言,只能证明测试与卡片对**当前默认
  // 语言**看法一致。
  return Translations.of(tester.element(find.byType(VoicesCard)));
}

class _SwitchableActiveWorkspace extends ActiveWorkspace {
  @override
  String? build() => 'ws_a';
}

class _StaticActiveWorkspace extends ActiveWorkspace {
  @override
  String? build() => 'ws_test';
}

class _WorkspaceVoiceRepository extends FixtureSettingsRepository {
  _WorkspaceVoiceRepository(this.workspaceId);

  final String? Function() workspaceId;
  final Map<String, VoiceInventory> inventories = {
    'ws_a': const VoiceInventory(
      items: [ClonedVoice(id: 'vce_a', name: '旧空间音色')],
      capacity: 2,
      remaining: 1,
    ),
    'ws_b': const VoiceInventory(
      items: [ClonedVoice(id: 'vce_b', name: '新空间音色')],
      capacity: 2,
      remaining: 1,
    ),
  };

  Completer<VoiceInventory>? delayedNextRead;
  Completer<VoiceInventory>? pendingRead;
  Completer<void>? delayedDelete;
  String? deleteWorkspaceAtCall;
  int voiceReadCount = 0;

  @override
  Future<VoiceInventory> voices({String? workspaceId}) {
    voiceReadCount++;
    final delayed = delayedNextRead;
    if (this.workspaceId() == 'ws_b' && delayed != null) {
      delayedNextRead = null;
      pendingRead = delayed;
      return delayed.future;
    }
    return Future.value(inventories[this.workspaceId()]);
  }

  @override
  Future<void> deleteVoice(String id, {String? workspaceId}) async {
    deleteWorkspaceAtCall = workspaceId ?? this.workspaceId();
    final gate = delayedDelete;
    if (gate != null) await gate.future;
  }
}

/// The voice card exists to make ONE distinction legible, and every test here defends it:
/// **an inventory slot is not a daily quota.** Nothing frees it with the passage of time, creating
/// a voice cost real money once, and deletion reclaims the slot but never the fee. A card that said
/// 「try again tomorrow」would send a user to wait forever.
///
/// 音色卡存在的意义是把**一个区别**说清楚,而这里每个测试都在守它:**库存位不是日配额。** 时间流逝不
/// 腾位、创建它花过一次真钱、删除收回位置但从不收回费用。一张说「明天再试」的卡,会把用户送去永远地等。
void main() {
  // The wording law runs over EVERY locale, not just the one the widget tests happen to boot in —
  // a translator reaching for「明天再试」/「try later」in one file would otherwise ship unopposed.
  // 措辞律跑遍**每一种**语言,不只是 widget 测试恰好启动的那一种——否则某个文件里一句「明天再试」/
  // 「try later」会毫无阻力地上线。
  test('honesty law · the full-inventory sentence never sends the user to wait', () {
    // 「明天」「稍后」「过会儿」「等」— any of these turns a permanent cap into a temporary one.
    final zhForbidden = RegExp('明天|稍后|过会|再试试|等一等');
    final enForbidden = RegExp(
      r'tomorrow|later|wait|reset|refill|renew',
      caseSensitive: false,
    );
    for (final loc in AppLocale.values) {
      final k = loc.buildSync().settings.keys;
      for (final s in <String>[
        k.voicesFull,
        k.voicesRemaining(n: 1, cap: 2),
        k.voicesEmpty,
      ]) {
        expect(
          zhForbidden.hasMatch(s),
          isFalse,
          reason: '[$loc] 库存位不是日额度,不得暗示时间会腾位: $s',
        );
        expect(
          enForbidden.hasMatch(s),
          isFalse,
          reason: '[$loc] an inventory slot never frees itself with time: $s',
        );
      }
      // The absence of a lie is not the same as the truth: the full state must NAME deletion, since
      // that is the only thing that reclaims a slot.
      // 谎言的缺席不等于真话:满态必须**点名删除**,因为那是唯一能腾出位置的动作。
      expect(
        k.voicesFull.toLowerCase(),
        anyOf(contains('delete'), contains('删')),
        reason:
            '[$loc] the full state must name deletion as the remedy: ${k.voicesFull}',
      );
    }
  });

  testWidgets(
    'a full inventory renders the remedy sentence, not the arithmetic',
    (tester) async {
      final t = await pumpVoicesCard(
        tester,
        const VoiceInventory(
          items: [
            ClonedVoice(id: 'vce_1', name: '灯塔'),
            ClonedVoice(id: 'vce_2', name: '夜航'),
          ],
          capacity: 2,
          remaining: 0,
        ),
      );
      expect(find.text(t.settings.keys.voicesFull), findsOneWidget);
      expect(
        find.text(t.settings.keys.voicesRemaining(n: 0, cap: 2)),
        findsNothing,
      );
      // Both rows carry their own delete button — the remedy the sentence names has to be reachable
      // for EITHER voice, or「delete one」points at nothing.
      // 两行各带自己的删除按钮——那句话点名的补救办法必须对**任一**音色都够得着,否则「删一个」无所指。
      expect(find.text(t.settings.keys.voicesDelete), findsNWidgets(2));
    },
  );

  testWidgets(
    'a partial inventory shows the arithmetic, because the cap is why you are here',
    (tester) async {
      final t = await pumpVoicesCard(
        tester,
        const VoiceInventory(
          items: [ClonedVoice(id: 'vce_1', name: '灯塔')],
          capacity: 2,
          remaining: 1,
        ),
      );
      // A list of one that does not say「one slot left」leaves the next refusal unexplained.
      // 一个只列一行、却不说「还能留一个」的列表,会让下一次登记的拒绝无从解释。
      expect(
        find.text(t.settings.keys.voicesRemaining(n: 1, cap: 2)),
        findsOneWidget,
      );
      expect(find.text('灯塔'), findsOneWidget);
    },
  );

  testWidgets('an empty inventory explains where voices come from', (
    tester,
  ) async {
    final t = await pumpVoicesCard(
      tester,
      const VoiceInventory(capacity: 2, remaining: 2),
    );
    // Enrollment is a TOOL CALL, not a button on this card — it needs a source clip and the model's
    // judgement about which one. So the empty state has to say so, or the card reads as broken.
    // 登记是一次**工具调用**、不是这张卡上的按钮——它需要源音频与模型对「用哪段」的判断。故空态必须
    // 说清楚,否则这张卡读起来像是坏了。
    expect(find.text(t.settings.keys.voicesEmpty), findsOneWidget);
    expect(find.text(t.settings.keys.voicesDelete), findsNothing);
    expect(
      find.text(t.settings.keys.voicesRemaining(n: 2, cap: 2)),
      findsOneWidget,
    );
  });

  testWidgets(
    'a load failure is not disguised as an empty inventory and retries',
    (tester) async {
      final repo = FixtureSettingsRepository()
        ..fixtureVoices = const VoiceInventory(
          items: [ClonedVoice(id: 'vce_1', name: '灯塔')],
          capacity: 2,
          remaining: 1,
        )
        ..failNextVoices = StateError('offline');
      final t = await pumpVoicesCard(
        tester,
        const VoiceInventory(capacity: 2, remaining: 2),
        repository: repo,
      );

      expect(find.text(t.settings.keys.voicesLoadFailed), findsOneWidget);
      expect(find.text(t.settings.keys.voicesEmpty), findsNothing);
      expect(find.text('灯塔'), findsNothing);

      await tester.tap(find.text(t.settings.keys.voicesRetry));
      await tester.pumpAndSettle();

      expect(find.text(t.settings.keys.voicesLoadFailed), findsNothing);
      expect(find.text('灯塔'), findsOneWidget);
      expect(
        find.text(t.settings.keys.voicesRemaining(n: 1, cap: 2)),
        findsOneWidget,
      );
    },
  );

  testWidgets('deleting a voice requires exact confirmation and frees its slot', (
    tester,
  ) async {
    final t = await pumpVoicesCard(
      tester,
      const VoiceInventory(
        items: [
          ClonedVoice(id: 'vce_1', name: '灯塔'),
          ClonedVoice(id: 'vce_2', name: '夜航'),
        ],
        capacity: 2,
        remaining: 0,
      ),
    );
    // AnRow's actions are hover-revealed (design-system grammar, C1) — a real user hovers the row
    // before the button is hit-testable, so the test does too. Tapping without it would pass through
    // the IgnorePointer and prove nothing.
    // AnRow 的 actions 是 hover 才现的(设计系统 C1 文法)——真用户得先悬停按钮才可点,故测试照做。
    // 不悬停就点会穿过 IgnorePointer,什么也证明不了。
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(() => g.removePointer());
    await tester.pump();
    await g.moveTo(tester.getCenter(find.widgetWithText(AnRow, '灯塔')));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(AnRow, '灯塔'),
        matching: find.widgetWithText(AnButton, t.settings.keys.voicesDelete),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnTypeToConfirm), findsOneWidget);

    final danger = find.byType(AnTypeToConfirm);
    final confirm = find.descendant(
      of: danger,
      matching: find.text(t.settings.keys.voicesDeleteConfirm),
    );
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('灯塔'), findsOneWidget, reason: '未输入名称,不得执行删除');

    await tester.enterText(
      find.descendant(of: danger, matching: find.byType(TextField)),
      'wrong name',
    );
    await tester.pump();
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('灯塔'), findsOneWidget, reason: '名称不匹配,不得执行删除');

    await tester.enterText(
      find.descendant(of: danger, matching: find.byType(TextField)),
      '灯塔',
    );
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    // The card told the user deletion is the remedy; if the arithmetic did not move afterwards, the
    // sentence was decoration. 卡片告诉用户删除是补救办法;若删完算术没动,那句话就只是装饰。
    expect(find.text('灯塔'), findsNothing);
    expect(
      find.text(t.settings.keys.voicesRemaining(n: 1, cap: 2)),
      findsOneWidget,
    );
  });

  testWidgets('the voice confirmation field fills the card for long names', (
    tester,
  ) async {
    const name = 'EP220 Delete Trial';
    final t = await pumpVoicesCard(
      tester,
      const VoiceInventory(
        items: [ClonedVoice(id: 'vce_1', name: name)],
        capacity: 2,
        remaining: 1,
      ),
    );
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(() => g.removePointer());
    await g.moveTo(tester.getCenter(find.widgetWithText(AnRow, name)));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(AnRow, name),
        matching: find.widgetWithText(AnButton, t.settings.keys.voicesDelete),
      ),
    );
    await tester.pumpAndSettle();

    final danger = find.byType(AnTypeToConfirm);
    final field = find.descendant(of: danger, matching: find.byType(AnInput));
    final dangerWidth = tester.getSize(danger).width;
    final fieldWidth = tester.getSize(field).width;
    expect(fieldWidth, greaterThan(AnSize.inputMin));
    expect(
      dangerWidth - (AnSpace.s16 * 2) - fieldWidth,
      inInclusiveRange(0, 4),
      reason: '长对象名的确认框必须占满危险卡可用宽度',
    );
  });

  testWidgets(
    'cancel closes the voice danger zone without changing inventory',
    (tester) async {
      final t = await pumpVoicesCard(
        tester,
        const VoiceInventory(
          items: [ClonedVoice(id: 'vce_1', name: '灯塔')],
          capacity: 2,
          remaining: 1,
        ),
      );
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: Offset.zero);
      addTearDown(() => g.removePointer());
      await g.moveTo(tester.getCenter(find.widgetWithText(AnRow, '灯塔')));
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(AnRow, '灯塔'),
          matching: find.widgetWithText(AnButton, t.settings.keys.voicesDelete),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnTypeToConfirm), findsOneWidget);

      await tester.tap(find.text(t.action.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(AnTypeToConfirm), findsNothing);
      expect(find.text('灯塔'), findsOneWidget);
      expect(
        find.text(t.settings.keys.voicesRemaining(n: 1, cap: 2)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'an upstream delete failure keeps the row and leaves retry available',
    (tester) async {
      final repo = FixtureSettingsRepository()
        ..fixtureVoices = const VoiceInventory(
          items: [ClonedVoice(id: 'vce_1', name: '灯塔')],
          capacity: 2,
          remaining: 1,
        )
        ..failNextVoiceDelete = StateError('gateway unavailable');
      final t = await pumpVoicesCard(
        tester,
        const VoiceInventory(capacity: 2, remaining: 2),
        repository: repo,
      );
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: Offset.zero);
      addTearDown(() => g.removePointer());
      await g.moveTo(tester.getCenter(find.widgetWithText(AnRow, '灯塔')));
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(AnRow, '灯塔'),
          matching: find.widgetWithText(AnButton, t.settings.keys.voicesDelete),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AnTypeToConfirm),
          matching: find.byType(TextField),
        ),
        '灯塔',
      );
      await tester.pump();
      await tester.tap(find.text(t.settings.keys.voicesDeleteConfirm));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(AnRow, '灯塔'),
        findsOneWidget,
        reason: '上游失败,本地行必须保留',
      );
      expect(find.byType(AnTypeToConfirm), findsOneWidget, reason: '保留重试入口');
      expect(
        find.text(t.settings.keys.voicesDeleteFailed),
        findsOneWidget,
        reason: '失败必须在当前危险区持久说明,不能只依赖会消失的顶带通知',
      );
      expect(
        find.text(t.settings.keys.voicesRemaining(n: 1, cap: 2)),
        findsOneWidget,
        reason: '失败不能伪造库存位已释放',
      );
    },
  );

  testWidgets(
    'a committed delete with a failed refresh hides stale inventory and explains retry',
    (tester) async {
      final repo = FixtureSettingsRepository()
        ..fixtureVoices = const VoiceInventory(
          items: [ClonedVoice(id: 'vce_1', name: '灯塔')],
          capacity: 2,
          remaining: 1,
        )
        ..failNextVoicesAfterDelete = StateError('inventory read unavailable');
      final t = await pumpVoicesCard(
        tester,
        const VoiceInventory(capacity: 2, remaining: 2),
        repository: repo,
      );
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: Offset.zero);
      addTearDown(() => g.removePointer());
      await g.moveTo(tester.getCenter(find.widgetWithText(AnRow, '灯塔')));
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(AnRow, '灯塔'),
          matching: find.widgetWithText(AnButton, t.settings.keys.voicesDelete),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AnTypeToConfirm),
          matching: find.byType(TextField),
        ),
        '灯塔',
      );
      await tester.pump();
      await tester.tap(find.text(t.settings.keys.voicesDeleteConfirm));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AnRow, '灯塔'), findsNothing);
      expect(find.text(t.settings.keys.voicesDeleteCommitted), findsOneWidget);
      expect(
        find.text(t.settings.keys.voicesDeleteCommittedHint),
        findsOneWidget,
      );
      expect(find.text(t.settings.keys.voicesRetry), findsOneWidget);
      expect(find.text(t.settings.keys.voicesDeleteFailed), findsNothing);
      expect(repo.fixtureVoices.items, isEmpty, reason: 'DELETE 已提交,不能回到旧行');

      await tester.tap(find.text(t.settings.keys.voicesRetry));
      await tester.pumpAndSettle();
      expect(find.text(t.settings.keys.voicesEmpty), findsOneWidget);
      expect(
        find.text(t.settings.keys.voicesRemaining(n: 2, cap: 2)),
        findsOneWidget,
        reason: '重读恢复后必须显示服务端确认的剩余库存',
      );
    },
  );

  testWidgets(
    'a workspace switch drops the old inventory while the new read is pending',
    (tester) async {
      var currentWorkspace = 'ws_a';
      final repo = _WorkspaceVoiceRepository(() => currentWorkspace)
        ..delayedNextRead = Completer<VoiceInventory>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory()),
            activeWorkspaceProvider.overrideWith(
              _SwitchableActiveWorkspace.new,
            ),
            settingsRepositoryProvider.overrideWithValue(repo),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AnTheme.light(),
              home: const Scaffold(
                body: SingleChildScrollView(child: VoicesCard()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('旧空间音色'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VoicesCard)),
        listen: false,
      );
      currentWorkspace = 'ws_b';
      container.read(activeWorkspaceProvider.notifier).set('ws_b');
      await tester.pump();
      expect(
        find.text('旧空间音色'),
        findsNothing,
        reason: '切换 workspace 后,旧库存不能在新读取期间穿透',
      );

      final pending = repo.pendingRead;
      expect(pending, isNotNull);
      pending!.complete(repo.inventories['ws_b']);
      await tester.pumpAndSettle();
      expect(find.text('新空间音色'), findsOneWidget);
      expect(find.text('旧空间音色'), findsNothing);
      expect(container.read(activeWorkspaceProvider), 'ws_b');
    },
  );

  testWidgets('a workspace switch clears an armed delete confirmation', (
    tester,
  ) async {
    var currentWorkspace = 'ws_a';
    final repo = _WorkspaceVoiceRepository(() => currentWorkspace);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory()),
          activeWorkspaceProvider.overrideWith(_SwitchableActiveWorkspace.new),
          settingsRepositoryProvider.overrideWithValue(repo),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(child: VoicesCard()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final t = Translations.of(tester.element(find.byType(VoicesCard)));
    final row = find.widgetWithText(AnRow, '旧空间音色');
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(() => g.removePointer());
    await g.moveTo(tester.getCenter(row));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: row,
        matching: find.widgetWithText(AnButton, t.settings.keys.voicesDelete),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnTypeToConfirm), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(VoicesCard)),
      listen: false,
    );
    currentWorkspace = 'ws_b';
    container.read(activeWorkspaceProvider.notifier).set('ws_b');
    await tester.pumpAndSettle();
    expect(find.byType(AnTypeToConfirm), findsNothing);

    currentWorkspace = 'ws_a';
    container.read(activeWorkspaceProvider.notifier).set('ws_a');
    await tester.pumpAndSettle();
    expect(
      find.byType(AnTypeToConfirm),
      findsNothing,
      reason: 'a destructive intent from another workspace must not resurrect',
    );
  });

  testWidgets('an in-flight delete never refreshes the switched workspace', (
    tester,
  ) async {
    var currentWorkspace = 'ws_a';
    final repo = _WorkspaceVoiceRepository(() => currentWorkspace)
      ..delayedDelete = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory()),
          activeWorkspaceProvider.overrideWith(_SwitchableActiveWorkspace.new),
          settingsRepositoryProvider.overrideWithValue(repo),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(child: VoicesCard()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.voiceReadCount, 1);

    final t = Translations.of(tester.element(find.byType(VoicesCard)));
    final row = find.widgetWithText(AnRow, '旧空间音色');
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(() => g.removePointer());
    await g.moveTo(tester.getCenter(row));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: row,
        matching: find.widgetWithText(AnButton, t.settings.keys.voicesDelete),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AnTypeToConfirm),
        matching: find.byType(TextField),
      ),
      '旧空间音色',
    );
    await tester.pump();
    await tester.tap(find.text(t.settings.keys.voicesDeleteConfirm));
    await tester.pump();
    expect(repo.deleteWorkspaceAtCall, 'ws_a');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(VoicesCard)),
      listen: false,
    );
    currentWorkspace = 'ws_b';
    container.read(activeWorkspaceProvider.notifier).set('ws_b');
    await tester.pumpAndSettle();
    expect(find.text('新空间音色'), findsOneWidget);
    expect(repo.voiceReadCount, 2);

    repo.delayedDelete!.complete();
    await tester.pumpAndSettle();
    expect(
      repo.voiceReadCount,
      2,
      reason: '旧 workspace 的删除完成后不得在新 workspace 再发库存读取',
    );
    expect(find.text('新空间音色'), findsOneWidget);
  });
}
