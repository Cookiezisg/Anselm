import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/contract/api_error.dart';
import '../core/contract/workspace.dart';
import '../core/design/tokens.dart';
import '../core/shell/oceans.dart';
import '../core/ui/an_button.dart';
import '../core/ui/an_content_in.dart';
import '../core/ui/an_state.dart';
import '../core/ui/an_workspace_composer_flight.dart';
import '../core/workspace/workspace_bootstrap.dart';
import '../core/workspace/workspace_journey.dart';
import '../core/runtime.dart';
import '../i18n/strings.g.dart';
import 'gate_backdrop.dart';
import 'workspace_onboarding.dart';

/// Gates the shell on cold-start workspace resolution. An empty roster keeps the Router unmounted on
/// [WorkspaceOnboarding]. After the first create, source and destination coexist for one short,
/// measured shared-element handoff: the real Chat shell lays out behind the opaque onboarding, the
/// composer flies between their actual bounds, then the old surface leaves without remounting the shell.
/// Existing-workspace boots still take the direct content-in path. Reduced motion skips the flight.
///
/// 冷启动 workspace 门控。空名册时 Router 不挂、只显 [WorkspaceOnboarding]。首次创建后，起终面短暂
/// 共存：真 Chat 壳先在不透明 onboarding 背后完成布局，composer 按两端实测矩形飞行，再撤旧面；壳从
/// 入场起不重挂。已有 workspace 仍直接 content-in；减少动态效果时跳过飞行。
class WorkspaceGate extends ConsumerStatefulWidget {
  const WorkspaceGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WorkspaceGate> createState() => _WorkspaceGateState();
}

class _WorkspaceGateState extends ConsumerState<WorkspaceGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight;
  late final WorkspaceJourney _journey;

  bool _sawOnboarding = false;
  bool _transitionScheduled = false;
  bool _transitionDone = false;
  Rect? _sourceRect;
  Rect? _destinationRect;
  ProviderSubscription<String?>? _workspaceSubscription;

  @override
  void initState() {
    super.initState();
    _flight = AnimationController(
      vsync: this,
      duration: AnMotion.onboardingJourney,
    )..addListener(_syncDestinationOpacity);
    _journey = WorkspaceJourney();
    _workspaceSubscription = ref.listenManual<String?>(activeWorkspaceProvider, (
      previous,
      next,
    ) {
      if (previous != null && next == null) {
        // A scoped request proved the active id unusable. Re-resolve from the durable roster rather
        // than leaving the routed shell on a misleading rail error. 后端证明活动 id 不可用时回到名册重选。
        ref.invalidate(workspaceBootstrapProvider);
      }
    });
  }

  @override
  void dispose() {
    _flight
      ..removeListener(_syncDestinationOpacity)
      ..dispose();
    _journey.dispose();
    _workspaceSubscription?.close();
    super.dispose();
  }

  void _syncDestinationOpacity() {
    if (_destinationRect == null) return;
    _journey.destinationOpacity.value = _interval(
      _flight.value,
      const Interval(0.78, 1, curve: AnMotion.easeOut),
    );
  }

  Future<Workspace> _createWorkspace(String name) {
    // The first world always opens on the blank Chat landing, regardless of a stale machine-level
    // ocean preference. Doing this while the gate is still opaque gives the destination one stable
    // layout before it is measured. 首个世界恒落空白 Chat；趁 gate 仍不透明先定海洋，终点可稳定布局后再测。
    ref.read(selectedOceanProvider.notifier).select(OceanKind.chat);
    return ref.read(workspaceBootstrapProvider.notifier).create(name);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workspaceBootstrapProvider);
    final t = context.t;
    return async.when(
      data: _buildData,
      loading: () => GateBackdrop(
        child: AnState(
          kind: AnStateKind.loading,
          title: t.coldStart.connecting,
        ),
      ),
      error: (e, _) {
        final authFailed =
            e is ApiException && e.code == AnselmErr.unauthBadToken;
        return GateBackdrop(
          child: AnState(
            kind: AnStateKind.error,
            fatal: true,
            title: authFailed
                ? t.coldStart.authErrorTitle
                : t.coldStart.errorTitle,
            hint: authFailed
                ? t.coldStart.authErrorHint
                : t.coldStart.errorHint,
            // Keep raw exception details in backend/frontend journals. The workspace gate is a
            // product-facing startup surface and must not expose implementation codes or provider
            // messages to users. 原始异常留在日志;工作区启动门只显示用户文案,不泄漏内部码。
            action: AnButton(
              label: t.startup.retry,
              variant: AnButtonVariant.primary,
              onPressed: () => ref.invalidate(workspaceBootstrapProvider),
            ),
          ),
        );
      },
    );
  }

  Widget _buildData(String? workspaceId) {
    if (workspaceId == null) {
      _sawOnboarding = true;
      _transitionDone = false;
    } else if (_sawOnboarding && !_transitionDone && !_transitionScheduled) {
      _transitionScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startTransition());
    }

    final children = <Widget>[
      if (workspaceId != null)
        AnContentIn(
          key: const ValueKey('workspace-shell'),
          child: widget.child,
        ),
      if (workspaceId == null || (_sawOnboarding && !_transitionDone))
        AnimatedBuilder(
          key: const ValueKey('workspace-onboarding'),
          animation: _flight,
          child: WorkspaceOnboarding(onCreate: _createWorkspace),
          builder: (context, child) => IgnorePointer(
            ignoring: workspaceId != null,
            child: Opacity(
              opacity: workspaceId == null
                  ? 1
                  : 1 -
                        _interval(
                          _flight.value,
                          const Interval(0.08, 0.66, curve: AnMotion.easeOut),
                        ),
              child: child,
            ),
          ),
        ),
      if (_sourceRect != null && _destinationRect != null)
        AnimatedBuilder(
          animation: _flight,
          builder: (context, _) {
            final travel = AnMotion.spring.transform(_flight.value);
            final rect = Rect.lerp(_sourceRect, _destinationRect, travel)!;
            return Positioned.fromRect(
              rect: rect,
              child: IgnorePointer(
                child: Opacity(
                  opacity:
                      1 -
                      _interval(
                        _flight.value,
                        const Interval(0.78, 1, curve: AnMotion.easeOut),
                      ),
                  child: AnWorkspaceComposerFlight(
                    progress: _flight.value,
                    sourceText: _journey.committedName,
                    destinationPlaceholder: context.t.chat.placeholder,
                  ),
                ),
              ),
            );
          },
        ),
    ];

    return WorkspaceJourneyScope(
      journey: _journey,
      child: Stack(fit: StackFit.expand, children: children),
    );
  }

  Future<void> _startTransition() async {
    if (!mounted) return;
    if (AnMotionPref.reduced(context)) {
      _journey.destinationOpacity.value = 1;
      setState(() => _transitionDone = true);
      return;
    }

    final source = _rectFor(_journey.sourceComposerKey);
    final destination = _rectFor(_journey.destinationComposerKey);
    if (source == null || destination == null) {
      // A destination can be absent only when an external route/ocean displaced Chat. Falling through
      // is safer than holding an opaque, non-interactive gate forever. 外部路由若挤走 Chat 会缺终点；
      // 此时宁可直接放壳，绝不把用户锁在不可交互旧面。
      _journey.destinationOpacity.value = 1;
      setState(() => _transitionDone = true);
      return;
    }

    _journey.destinationOpacity.value = 0;
    setState(() {
      _sourceRect = source;
      _destinationRect = destination;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _flight.forward();
    if (!mounted) return;
    _journey.destinationOpacity.value = 1;
    setState(() => _transitionDone = true);
  }

  Rect? _rectFor(GlobalKey key) {
    final target = key.currentContext?.findRenderObject();
    final ancestor = context.findRenderObject();
    if (target is! RenderBox || ancestor is! RenderBox || !target.hasSize) {
      return null;
    }
    final origin = target.localToGlobal(Offset.zero, ancestor: ancestor);
    return origin & target.size;
  }
}

double _interval(double value, Interval interval) =>
    interval.transform(value.clamp(0, 1));
