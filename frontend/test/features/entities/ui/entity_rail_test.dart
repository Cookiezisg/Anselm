import 'dart:async';

import 'package:anselm/core/contract/entities/agent.dart';
import 'package:anselm/core/contract/entities/approval.dart';
import 'package:anselm/core/contract/entities/control.dart';
import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/handler.dart';
import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/contract/api_error.dart';
import 'package:anselm/core/contract/page.dart';
import 'package:anselm/core/notice/notice_center.dart';
import 'package:anselm/core/overlay/an_overlay.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/ui/an_dialog.dart';
import 'package:anselm/core/ui/an_sidebar_list.dart';
import 'package:anselm/core/ui/an_skeleton.dart';
import 'package:anselm/core/ui/an_state.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_repository.dart';
import 'package:anselm/features/entities/data/entity_row.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:anselm/features/entities/ui/entity_rail.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/router_harness.dart';

// STEP 3/6 gate (widget) — the rail resolves the four states off the repository seam: loading skeleton /
// error / empty / the AnSidebarList of kind sections, and selection navigates the router (STEP 6, the
// route is the source of truth). (The real-machine look is verified separately by the PNG capture harness.)

final _t = DateTime.utc(2026, 6, 26);
FunctionEntity _fn(String id, String name) =>
    FunctionEntity(id: id, name: name, createdAt: _t, updatedAt: _t);
HandlerEntity _hd(String id, String name, String runtime) => HandlerEntity(
  id: id,
  name: name,
  createdAt: _t,
  updatedAt: _t,
  runtimeState: runtime,
);
AgentEntity _ag(String id, String name) =>
    AgentEntity(id: id, name: name, createdAt: _t, updatedAt: _t);
WorkflowEntity _wf(
  String id,
  String name, {
  String lifecycleState = 'inactive',
}) => WorkflowEntity(
  id: id,
  name: name,
  createdAt: _t,
  updatedAt: _t,
  lifecycleState: lifecycleState,
);
ControlLogic _ctl(String id, String name) =>
    ControlLogic(id: id, name: name, createdAt: _t, updatedAt: _t);
ApprovalForm _apf(String id, String name) =>
    ApprovalForm(id: id, name: name, createdAt: _t, updatedAt: _t);
TriggerEntity _tr(
  String id,
  String name, {
  bool paused = false,
  bool listening = false,
  int refCount = 0,
}) => TriggerEntity(
  id: id,
  name: name,
  createdAt: _t,
  updatedAt: _t,
  refCount: refCount,
  listening: listening,
  paused: paused,
);

Widget _host(
  EntityRepository repo, {
  AnOverlayController? overlay,
  String initialLocation = '/',
}) => routedHost(
  const Scaffold(body: SizedBox(width: 300, height: 600, child: EntityRail())),
  initialLocation: initialLocation,
  repository: repo,
  overlay: overlay,
);

/// A scripted overlay: [confirm] returns [result] (no real dialog / navigator needed) — mirrors
/// conversation_rail_test.dart's twin. 脚本化浮层,镜像 conversation_rail_test 的同款。
class _FakeOverlay extends AnOverlayController {
  _FakeOverlay(this.result);
  final bool result;
  bool confirmCalled = false;
  String? confirmTitle;
  String? confirmMessage;

  @override
  Future<bool> confirm({
    required String title,
    String? message,
    required String confirmLabel,
    required String cancelLabel,
    required String barrierLabel,
    AnDialogTone confirmTone = AnDialogTone.danger,
  }) async {
    confirmCalled = true;
    confirmTitle = title;
    confirmMessage = message;
    return result;
  }
}

/// A [FixtureEntityRepository] that flags which execute-with-args / lifecycle verbs were actually
/// invoked — the honesty-law tests assert these STAY false after tapping a "needs args" menu item
/// (it must only navigate), and the in-place-action tests assert the matching flag flips true.
/// 记录哪些「要参」执行动词/生命周期动词真被调用——诚实律测试断言「需参」菜单项点击后仍为 false
/// (只应导航);就地执行测试断言对应位翻 true。
class _SpyRepo extends FixtureEntityRepository {
  _SpyRepo({
    super.functions,
    super.handlers,
    super.agents,
    super.workflows,
    super.triggerEntities,
    super.relGraph,
  });

  bool runCalled = false;
  bool callCalled = false;
  bool invokeCalled = false;
  bool triggerCalled = false;
  bool restartCalled = false;
  bool activateCalled = false;
  bool deactivateCalled = false;
  bool pauseCalled = false;
  bool resumeCalled = false;
  bool deleteCalled = false;
  String? iterateRequestSeen;

  @override
  Future<FunctionRunResult> runFunction(
    String id, {
    required Map<String, dynamic> args,
    int? version,
  }) {
    runCalled = true;
    return super.runFunction(id, args: args, version: version);
  }

  @override
  Future<dynamic> callHandler(
    String id, {
    required String method,
    required Map<String, dynamic> args,
  }) {
    callCalled = true;
    return super.callHandler(id, method: method, args: args);
  }

  @override
  Future<InvokeResult> invokeAgent(
    String id, {
    required Map<String, dynamic> input,
    int? version,
  }) {
    invokeCalled = true;
    return super.invokeAgent(id, input: input, version: version);
  }

  @override
  Future<String> triggerWorkflow(String id, {Map<String, dynamic>? payload}) {
    triggerCalled = true;
    return super.triggerWorkflow(id, payload: payload);
  }

  @override
  Future<HandlerEntity> restartHandler(String id) {
    restartCalled = true;
    return super.restartHandler(id);
  }

  @override
  Future<WorkflowEntity> activateWorkflow(String id) {
    activateCalled = true;
    return super.activateWorkflow(id);
  }

  @override
  Future<WorkflowEntity> deactivateWorkflow(String id) {
    deactivateCalled = true;
    return super.deactivateWorkflow(id);
  }

  @override
  Future<TriggerEntity> pauseTrigger(String id) {
    pauseCalled = true;
    return super.pauseTrigger(id);
  }

  @override
  Future<TriggerEntity> resumeTrigger(String id) {
    resumeCalled = true;
    return super.resumeTrigger(id);
  }

  @override
  Future<void> deleteEntity(EntityKind kind, String id) {
    deleteCalled = true;
    return super.deleteEntity(kind, id);
  }

  @override
  Future<String> iterateEntity(
    EntityKind kind,
    String id, {
    required String request,
  }) {
    iterateRequestSeen = request;
    return super.iterateEntity(kind, id, request: request);
  }
}

class _FailingActivateRepo extends FixtureEntityRepository {
  _FailingActivateRepo(this.failure, {super.workflows});

  final Object failure;

  @override
  Future<WorkflowEntity> activateWorkflow(String id) async {
    throw failure;
  }
}

// Open a row's ⋯ menu with a REAL mouse: hover the row (reveals the trail actions — the idle layer is
// IgnorePointer'd), move onto the ⋯ (still within the row → stays hovered), then click via down/up. A
// fresh tester.tap() synthesizes a touch pointer that carries no hover, so the ⋯ would stay inert and the
// tap would fall through. Mirrors conversation_rail_test.dart's twin. 用真鼠标 hover 揭示行动作再点 ⋯。
Future<void> _openRowMenu(WidgetTester tester, String rowText) async {
  WidgetsBinding.instance.focusManager.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(() => mouse.removePointer());
  await mouse.moveTo(tester.getCenter(find.text(rowText)));
  await tester.pump(); // hover the row → ⋯ becomes hit-testable
  final p = tester.getCenter(find.byIcon(AnIcons.more));
  await mouse.moveTo(p);
  await tester.pump();
  await mouse.down(p);
  await mouse.up();
  await tester.pumpAndSettle(); // popover open animation settles
}

/// Repo whose list never resolves — pins the loading state (a Future, not a Timer, so no pending-timer
/// failure and no need to settle the shimmer ticker).
class _PendingRepo extends FixtureEntityRepository {
  @override
  Future<Page<EntityRow>> listEntities(
    EntityKind kind, {
    String? cursor,
    int? limit,
    String? search,
  }) => Completer<Page<EntityRow>>().future;
}

/// Repo whose list always throws — pins the error state.
class _ErrRepo extends FixtureEntityRepository {
  @override
  Future<Page<EntityRow>> listEntities(
    EntityKind kind, {
    String? cursor,
    int? limit,
    String? search,
  }) async => throw Exception('boom');
}

void main() {
  testWidgets('loaded → AnSidebarList with kind sections + rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FixtureEntityRepository(
          functions: [
            _fn('fn_1', 'normalize-input'),
            _fn('fn_2', 'validate-schema'),
          ],
          handlers: [_hd('hd_1', 'slack', 'running')],
        ),
      ),
    );
    await tester.pump(
      const Duration(milliseconds: 50),
    ); // let the 4 list futures resolve

    expect(find.byType(AnSidebarList), findsOneWidget);
    expect(find.text(t.ref.function), findsOneWidget); // kind section head
    expect(find.text(t.ref.handler), findsOneWidget);
    expect(find.text('normalize-input'), findsOneWidget);
    expect(find.text('slack'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a row navigates → selection derives from the route', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FixtureEntityRepository(functions: [_fn('fn_1', 'normalize-input')]),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(EntityRail)),
    );
    expect(container.read(selectedEntityProvider), isNull);

    await tester.tap(find.text('normalize-input'));
    await tester.pumpAndSettle(); // the route change + delegate notify settles

    // The rail called context.go('/entities/function/fn_1'); the route is the truth, selection derives it.
    expect(
      container
          .read(goRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      '/entities/function/fn_1',
    );
    expect(
      container.read(selectedEntityProvider),
      const EntityRef(EntityKind.function, 'fn_1'),
    );
  });

  testWidgets(
    'empty → the collapsed shape: chrome + every kind head, no tombstone',
    (tester) async {
      await tester.pumpWidget(_host(FixtureEntityRepository()));
      await tester.pump(const Duration(milliseconds: 50));

      // 用户 0718 拍板: an empty rail = the FULL rail with rows removed — the list (search + every kind head)
      // renders, no «No entities yet» tombstone. 空态=满态收起:列表(搜索+每 kind 组头)恒在、无墓碑。
      expect(find.byType(AnSidebarList), findsOneWidget);
      expect(
        find.byType(AnState),
        findsNothing,
      ); // the old empty tombstone is retired 墓碑退役
      expect(
        find.text(t.ref.function),
        findsOneWidget,
      ); // kind heads still render at zero data 零数据也渲 kind 头
      expect(find.text(t.ref.handler), findsOneWidget);
      expect(find.text(t.ref.workflow), findsOneWidget);
      expect(
        find.text('0'),
        findsNothing,
      ); // an empty kind head shows no "0" count 空组头不显「0」
    },
  );

  testWidgets('error → AnState error with retry', (tester) async {
    await tester.pumpWidget(_host(_ErrRepo()));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(t.entities.errorTitle), findsOneWidget);
    expect(find.text(t.entities.retry), findsOneWidget);
  });

  testWidgets('filter with no matches explains the empty result', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FixtureEntityRepository(functions: [_fn('fn_1', 'normalize-input')]),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField), 'no-such-entity');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(t.entities.noResults), findsOneWidget);
    expect(find.text('normalize-input'), findsNothing);
  });

  testWidgets(
    'filtering away the selected entity returns to the Overview route',
    (tester) async {
      final repo = FixtureEntityRepository(
        approvalForms: [
          _apf('apf_note', 'note-gate'),
          _apf('apf_refund', 'refund-gate'),
        ],
      );
      await tester.pumpWidget(
        _host(
          repo,
          initialLocation: selectionLocation(EntityKind.approval, 'apf_note'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(EntityRail)),
      );
      expect(
        container.read(selectedEntityProvider),
        const EntityRef(EntityKind.approval, 'apf_note'),
      );

      await tester.enterText(find.byType(TextField), 'refund');
      await tester.pump(const Duration(milliseconds: 350));

      expect(container.read(selectedEntityProvider), isNull);
      expect(find.text('refund-gate'), findsOneWidget);
      expect(find.text('note-gate'), findsNothing);
    },
  );

  testWidgets('loading → deferred skeleton (after the anti-flash delay)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_PendingRepo()));
    await tester.pump(); // one frame — within the anti-flash delay, nothing yet
    expect(find.byType(AnSkeleton), findsNothing);

    await tester.pump(
      const Duration(milliseconds: 250),
    ); // past AnMotion.loaderDelay
    expect(find.byType(AnSkeleton), findsWidgets);
    expect(find.byType(AnSidebarList), findsNothing);
  });

  testWidgets('sliders menu opens with the three sorts + the display toggle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(FixtureEntityRepository(functions: [_fn('fn_1', 'a')])),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // The sliders anchor renders (menuEntries wired); opening it reveals Sort (3 options, aligned with
    // the chat rail) + Display (show counts).
    await tester.tap(find.byIcon(AnIcons.sliders));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(t.entities.sortLabel), findsOneWidget);
    expect(find.text(t.entities.sortRecent), findsOneWidget);
    expect(find.text(t.entities.sortCreated), findsOneWidget);
    expect(find.text(t.entities.sortName), findsOneWidget);
    expect(find.text(t.entities.displayLabel), findsOneWidget);
    expect(find.text(t.entities.showCount), findsOneWidget);
  });

  testWidgets('show-counts toggle drops the per-section count badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(FixtureEntityRepository(functions: [_fn('fn_1', 'a')])),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // The function section carries one entity → its head shows the count badge "1".
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byIcon(AnIcons.sliders));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(
      find.text(t.entities.showCount),
    ); // keepOpen toggle → counts off
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('1'), findsNothing); // badge gone across every section
  });

  // ── STEP ⑩/EA: the per-row ⋯ menu ──────────────────────────────────────

  final rm = t.entities.rail.menu;

  testWidgets('function row menu: Open · Run… · Edit with AI · Delete', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(FixtureEntityRepository(functions: [_fn('fn_1', 'normalize')])),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'normalize');

    expect(find.text(rm.open), findsOneWidget);
    expect(find.text(rm.run), findsOneWidget);
    expect(find.text(rm.iterate), findsOneWidget);
    expect(find.text(t.action.delete), findsOneWidget);
    // No other kind's items leak in. 其他 kind 专属项不串。
    expect(find.text(rm.call), findsNothing);
    expect(find.text(rm.invoke), findsNothing);
    expect(find.text(rm.restart), findsNothing);
  });

  testWidgets(
    'handler row menu: Open · Call method… · Restart instance · Edit with AI · Delete',
    (tester) async {
      await tester.pumpWidget(
        _host(
          FixtureEntityRepository(handlers: [_hd('hd_1', 'slack', 'running')]),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await _openRowMenu(tester, 'slack');

      expect(find.text(rm.open), findsOneWidget);
      expect(find.text(rm.call), findsOneWidget);
      expect(find.text(rm.restart), findsOneWidget);
      expect(find.text(rm.iterate), findsOneWidget);
      expect(find.text(t.action.delete), findsOneWidget);
      expect(find.text(rm.run), findsNothing);
    },
  );

  testWidgets('agent row menu: Open · Invoke… · Edit with AI · Delete', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(FixtureEntityRepository(agents: [_ag('ag_1', 'planner')])),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'planner');

    expect(find.text(rm.open), findsOneWidget);
    expect(find.text(rm.invoke), findsOneWidget);
    expect(find.text(rm.iterate), findsOneWidget);
    expect(find.text(t.action.delete), findsOneWidget);
    expect(find.text(rm.call), findsNothing);
  });

  testWidgets(
    'inactive workflow row menu: …Activate…, never Deactivate (二选一)',
    (tester) async {
      await tester.pumpWidget(
        _host(
          FixtureEntityRepository(
            workflows: [_wf('wf_1', 'onboard', lifecycleState: 'inactive')],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await _openRowMenu(tester, 'onboard');

      expect(find.text(rm.open), findsOneWidget);
      expect(find.text(rm.triggerNow), findsOneWidget);
      expect(find.text(rm.openEditor), findsOneWidget);
      expect(find.text(rm.iterate), findsOneWidget);
      expect(find.text(t.action.delete), findsOneWidget);
      expect(find.text(rm.activate), findsOneWidget);
      expect(find.text(rm.deactivate), findsNothing); // 二选一,不并列
    },
  );

  testWidgets('active workflow row menu: …Deactivate…, never Activate (二选一)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FixtureEntityRepository(
          workflows: [_wf('wf_1', 'onboard', lifecycleState: 'active')],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'onboard');

    expect(find.text(rm.deactivate), findsOneWidget);
    expect(find.text(rm.activate), findsNothing); // 二选一,不并列
  });

  testWidgets('workflow activation failure keeps the actionable graph problem', (
    tester,
  ) async {
    const failure = ApiException(
      code: 'WORKFLOW_NOT_RUNNABLE',
      message:
          'workflow graph is not runnable; fix the listed problems before arming or activating',
      httpStatus: 422,
      details: {
        'problems': ['node "start": ref "trg_missing" not found'],
      },
    );
    await tester.pumpWidget(
      _host(
        _FailingActivateRepo(
          failure,
          workflows: [_wf('wf_1', 'broken', lifecycleState: 'inactive')],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'broken');
    await tester.tap(find.text(rm.activate));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(EntityRail)),
    );
    final notice = container.read(noticeCenterProvider).current;
    expect(notice?.message.text, contains('trg_missing'));
    expect(notice?.message.text, isNot(t.entities.rail.actionFailed));
  });

  testWidgets('control row menu: only Open · Edit with AI · Delete', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(FixtureEntityRepository(controlLogics: [_ctl('ctl_1', 'route')])),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'route');

    expect(find.text(rm.open), findsOneWidget);
    expect(find.text(rm.iterate), findsOneWidget);
    expect(find.text(t.action.delete), findsOneWidget);
    // No kind-specific items — control has none. control 无专属项。
    expect(find.text(rm.run), findsNothing);
    expect(find.text(rm.call), findsNothing);
    expect(find.text(rm.invoke), findsNothing);
    expect(find.text(rm.triggerNow), findsNothing);
    expect(find.text(rm.restart), findsNothing);
    expect(find.text(rm.activate), findsNothing);
    expect(find.text(rm.pause), findsNothing);
  });

  testWidgets('approval row menu: only Open · Edit with AI · Delete', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FixtureEntityRepository(approvalForms: [_apf('apf_1', 'sign-off')]),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'sign-off');

    expect(find.text(rm.open), findsOneWidget);
    expect(find.text(rm.iterate), findsOneWidget);
    expect(find.text(t.action.delete), findsOneWidget);
    expect(find.text(rm.restart), findsNothing);
  });

  testWidgets('unpaused trigger row menu: …Pause…, never Resume (二选一)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FixtureEntityRepository(
          triggerEntities: [_tr('trg_1', 'nightly', paused: false)],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'nightly');

    expect(find.text(rm.open), findsOneWidget);
    expect(find.text(rm.pause), findsOneWidget);
    expect(find.text(rm.resume), findsNothing); // 二选一,不并列
    expect(find.text(rm.iterate), findsOneWidget);
    expect(find.text(t.action.delete), findsOneWidget);
  });

  testWidgets('paused trigger row menu: …Resume…, never Pause (二选一)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FixtureEntityRepository(
          triggerEntities: [_tr('trg_1', 'nightly', paused: true)],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'nightly');

    expect(find.text(rm.resume), findsOneWidget);
    expect(find.text(rm.pause), findsNothing); // 二选一,不并列
  });

  // ── 诚实律: an args-needing verb only NAVIGATES, never fires blind ──────

  testWidgets(
    'function «Run…» navigates to the entity WITHOUT calling :run (needs args → nav only)',
    (tester) async {
      final spy = _SpyRepo(functions: [_fn('fn_1', 'normalize')]);
      await tester.pumpWidget(_host(spy));
      await tester.pump(const Duration(milliseconds: 50));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EntityRail)),
      );
      await _openRowMenu(tester, 'normalize');

      await tester.tap(find.text(rm.run));
      await tester.pumpAndSettle();

      expect(spy.runCalled, isFalse); // never blind-fires the args-needing verb
      expect(
        container
            .read(goRouterProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        '/entities/function/fn_1',
      );
    },
  );

  testWidgets(
    'workflow «Run now…» navigates WITHOUT calling :trigger (optional payload still deserves review)',
    (tester) async {
      final spy = _SpyRepo(workflows: [_wf('wf_1', 'onboard')]);
      await tester.pumpWidget(_host(spy));
      await tester.pump(const Duration(milliseconds: 50));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EntityRail)),
      );
      await _openRowMenu(tester, 'onboard');

      await tester.tap(find.text(rm.triggerNow));
      await tester.pumpAndSettle();

      expect(spy.triggerCalled, isFalse);
      expect(
        container
            .read(goRouterProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        '/entities/workflow/wf_1',
      );
    },
  );

  testWidgets('handler «Call method…» stays nav-only (no :call)', (
    tester,
  ) async {
    final spy = _SpyRepo(handlers: [_hd('hd_1', 'slack', 'running')]);
    await tester.pumpWidget(_host(spy));
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'slack');

    await tester.tap(find.text(rm.call));
    await tester.pumpAndSettle();

    expect(spy.callCalled, isFalse);
  });

  testWidgets('agent «Invoke…» stays nav-only (no :invoke)', (tester) async {
    final spy = _SpyRepo(agents: [_ag('ag_1', 'planner')]);
    await tester.pumpWidget(_host(spy));
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'planner');

    await tester.tap(find.text(rm.invoke));
    await tester.pumpAndSettle();

    expect(spy.invokeCalled, isFalse);
  });

  // ── in-place (parameter-free) actions actually execute ─────────────────

  testWidgets('«Restart instance» calls :restart in place (no nav)', (
    tester,
  ) async {
    final spy = _SpyRepo(handlers: [_hd('hd_1', 'slack', 'running')]);
    await tester.pumpWidget(_host(spy));
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'slack');

    await tester.tap(find.text(rm.restart));
    await tester.pumpAndSettle();

    expect(spy.restartCalled, isTrue);
    expect(
      find.text('slack'),
      findsOneWidget,
    ); // still in the rail, no nav away
  });

  testWidgets('«Activate» / «Deactivate» call the matching verb in place', (
    tester,
  ) async {
    final spy = _SpyRepo(
      workflows: [_wf('wf_1', 'onboard', lifecycleState: 'inactive')],
    );
    await tester.pumpWidget(_host(spy));
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'onboard');

    await tester.tap(find.text(rm.activate));
    await tester.pumpAndSettle();

    expect(spy.activateCalled, isTrue);
    expect(spy.deactivateCalled, isFalse);
  });

  testWidgets('«Pause» / «Resume» call the matching verb in place', (
    tester,
  ) async {
    final spy = _SpyRepo(
      triggerEntities: [_tr('trg_1', 'nightly', paused: false)],
    );
    await tester.pumpWidget(_host(spy));
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'nightly');

    await tester.tap(find.text(rm.pause));
    await tester.pumpAndSettle();

    expect(spy.pauseCalled, isTrue);
    expect(spy.resumeCalled, isFalse);
  });

  // ── AI 编辑 (:iterate) ───────────────────────────────────────────────────

  testWidgets(
    '«Edit with AI» sends a non-empty canned request and navigates to the new conversation',
    (tester) async {
      final spy = _SpyRepo(functions: [_fn('fn_1', 'normalize')]);
      await tester.pumpWidget(_host(spy));
      await tester.pump(const Duration(milliseconds: 50));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EntityRail)),
      );
      await _openRowMenu(tester, 'normalize');

      await tester.tap(find.text(rm.iterate));
      await tester.pumpAndSettle();

      expect(spy.iterateRequestSeen, isNotNull);
      expect(spy.iterateRequestSeen!.trim(), isNotEmpty); // never a blank body
      expect(
        spy.iterateRequestSeen,
        contains('normalize'),
      ); // the new thread is identifiable in the rail
      expect(
        container
            .read(goRouterProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        startsWith('/chat/'),
      );
    },
  );

  // ── 删除 ─────────────────────────────────────────────────────────────────

  testWidgets(
    'Delete → confirm accepted → repo.deleteEntity called, row gone',
    (tester) async {
      final spy = _SpyRepo(functions: [_fn('fn_1', 'normalize')]);
      final fake = _FakeOverlay(true);
      await tester.pumpWidget(_host(spy, overlay: fake));
      await tester.pump(const Duration(milliseconds: 50));
      await _openRowMenu(tester, 'normalize');

      await tester.tap(find.text(t.action.delete));
      await tester.pumpAndSettle();

      expect(fake.confirmCalled, isTrue);
      expect(fake.confirmTitle, t.entities.rail.deleteTitle);
      expect(
        fake.confirmMessage,
        t.entities.rail.deleteBody(name: 'normalize'),
      );
      expect(spy.deleteCalled, isTrue);
      expect(find.text('normalize'), findsNothing);
    },
  );

  testWidgets(
    'Delete → confirm declined → repo.deleteEntity NOT called, row stays',
    (tester) async {
      final spy = _SpyRepo(functions: [_fn('fn_1', 'normalize')]);
      final fake = _FakeOverlay(false);
      await tester.pumpWidget(_host(spy, overlay: fake));
      await tester.pump(const Duration(milliseconds: 50));
      await _openRowMenu(tester, 'normalize');

      await tester.tap(find.text(t.action.delete));
      await tester.pumpAndSettle();

      expect(fake.confirmCalled, isTrue);
      expect(spy.deleteCalled, isFalse);
      expect(find.text('normalize'), findsOneWidget);
    },
  );

  testWidgets(
    'Function Delete → fresh dependency preflight names mounted agents',
    (tester) async {
      final spy = _SpyRepo(
        functions: [_fn('fn_1', 'shared function')],
        relGraph: const EntityRelGraph(
          edges: [
            EntityRelation(
              id: 'rel_1',
              kind: 'equip',
              fromKind: 'agent',
              fromId: 'ag_1',
              fromName: 'planner',
              toKind: 'function',
              toId: 'fn_1',
              toName: 'shared function',
            ),
            EntityRelation(
              id: 'rel_2',
              kind: 'equip',
              fromKind: 'agent',
              fromId: 'ag_2',
              fromName: 'reviewer',
              toKind: 'function',
              toId: 'fn_1',
              toName: 'shared function',
            ),
          ],
        ),
      );
      final fake = _FakeOverlay(false);
      await tester.pumpWidget(_host(spy, overlay: fake));
      await tester.pump(const Duration(milliseconds: 50));
      await _openRowMenu(tester, 'shared function');

      await tester.tap(find.text(t.action.delete));
      await tester.pumpAndSettle();

      expect(fake.confirmCalled, isTrue);
      expect(fake.confirmMessage, contains('planner'));
      expect(fake.confirmMessage, contains('reviewer'));
      expect(fake.confirmMessage, contains('needing repair'));
      expect(spy.deleteCalled, isFalse);
    },
  );

  testWidgets(
    'Trigger Delete → fresh dependency preflight explains listener and workflows',
    (tester) async {
      final spy = _SpyRepo(
        triggerEntities: [_tr('trg_1', 'sensor', listening: true, refCount: 1)],
        relGraph: const EntityRelGraph(
          edges: [
            EntityRelation(
              id: 'rel_1',
              kind: 'equip',
              fromKind: 'workflow',
              fromId: 'wf_1',
              fromName: 'nightly sync',
              toKind: 'trigger',
              toId: 'trg_1',
              toName: 'sensor',
            ),
          ],
        ),
      );
      final fake = _FakeOverlay(true);
      await tester.pumpWidget(_host(spy, overlay: fake));
      await tester.pump(const Duration(milliseconds: 50));
      await _openRowMenu(tester, 'sensor');

      await tester.tap(find.text(t.action.delete));
      await tester.pumpAndSettle();

      expect(fake.confirmTitle, t.entities.rail.deleteTriggerTitle);
      expect(fake.confirmMessage, contains('nightly sync'));
      expect(fake.confirmMessage, contains('listener'));
      expect(fake.confirmMessage, contains('repair'));
      expect(spy.deleteCalled, isTrue);
    },
  );

  testWidgets(
    'Agent Delete → confirm accepted → selected detail route clears and row disappears',
    (tester) async {
      final spy = _SpyRepo(agents: [_ag('ag_1', 'planner')]);
      final fake = _FakeOverlay(true);
      await tester.pumpWidget(_host(spy, overlay: fake));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('planner'));
      await tester.pumpAndSettle();
      await _openRowMenu(tester, 'planner');

      await tester.tap(find.text(t.action.delete));
      await tester.pumpAndSettle();

      expect(fake.confirmCalled, isTrue);
      expect(fake.confirmMessage, t.entities.rail.deleteBody(name: 'planner'));
      expect(spy.deleteCalled, isTrue);
      expect(find.text('planner'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EntityRail)),
      );
      expect(
        container
            .read(goRouterProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        '/',
      );
    },
  );
}
