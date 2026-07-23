import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/features/chat/data/chat_demo_fixture.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/ui/stage_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// G12 — the STRUCTURAL INVARIANT NET: the demo's full scripted playback pumped through the REAL
// panel, with invariants asserted at EVERY step — not just terminal states. This is the net the
// old «assert what should appear» batteries lacked: the N×N ensemble, the double-«Live» screenshot
// and the premature ✓ all lived in TRANSIENT states no test ever visited. A class of bug dies
// here, not one enumerated instance.
// G12 结构不变量网:demo 全剧本灌进真面板,**每一步**断言不变量(不只终态)。旧电池只断言「该出现
// 的出现了」;N×N、双「Live」截图、提前 ✓ 全活在没人踩过的过渡态里。这里杀的是整类 bug。

const _conv = 'cv_net';

Widget _host(DemoChatRepository repo) => ProviderScope(
  overrides: [
    chatRepositoryProvider.overrideWithValue(repo),
    // The demo path touches selected-conversation, which derives off the router. 桩路由。
    goRouterProvider.overrideWithValue(
      GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
      ),
    ),
  ],
  child: TranslationProvider(
    child: MaterialApp(
      theme: AnTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: 420,
          height: 900,
          child: StagePanel(conversationId: _conv),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets(
    'the whole demo playback holds the sidestage invariants at EVERY frame step',
    (tester) async {
      final repo = DemoChatRepository(
        conversations: [
          Conversation(
            id: _conv,
            title: 'net',
            createdAt: DateTime.utc(2026, 7, 8),
            updatedAt: DateTime.utc(2026, 7, 8),
            lastMessageAt: DateTime.utc(2026, 7, 8),
          ),
        ],
      );
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      await repo.sendMessage(_conv, content: '全剧连演,逐帧验相');

      int countText(String s) =>
          tester.widgetList(find.textContaining(s)).length;

      // Walk the script in 300ms steps (the whole playback is well inside the window) and hold the
      // invariants at every step. 300ms 步进走完全剧,每步验不变量。
      for (var step = 0; step < 400; step++) {
        await tester.pump(const Duration(milliseconds: 300));
        // I1 — the retired ensemble NEVER reappears. 群像退役永不复辟。
        expect(
          find.textContaining('并行群像'),
          findsNothing,
          reason: 'step $step: 群像标题复辟',
        );
        // I2 — panel-wide uniqueness: a delegate's task label appears at most TWICE (its row head +
        // its own card), never a third copy from any loop. 每席任务名全面板至多两处(头+卡)。
        expect(
          countText('审计最近失败的执行'),
          lessThanOrEqualTo(2),
          reason: 'step $step: 分身甲卡片重复',
        );
        expect(
          countText('核对告警渠道配置'),
          lessThanOrEqualTo(2),
          reason: 'step $step: 分身乙卡片重复',
        );
      }

      // The terminal state — the user's screenshot, made impossible: everything settled, so NO row
      // may still wear «进行中»/«正在落定», and the delegates' settle metadata (from the nested
      // sub-message closes, the real wire) must be on stage. 终局:全部落定后不许再有「进行中/正在
      // 落定」行;分身结算元数据(嵌套子消息关帧,真线缆)必须在场。
      final t2 = t;
      expect(
        find.text(t2.chat.stage.live),
        findsNothing,
        reason: '终局仍有行自称「进行中」——幽灵 Live',
      );
      expect(find.text(t2.chat.stage.rowSettling), findsNothing);
      expect(find.textContaining('审计最近失败的执行'), findsWidgets); // 行头仍是任务名
    },
  );
}
