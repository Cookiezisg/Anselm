import 'package:flutter/widgets.dart';

/// The matched-geometry seam between first-run creation and Chat. The gate owns one instance for the
/// short life of the journey; onboarding registers the source composer, Chat registers the destination,
/// and only the destination's paint opacity changes while both layouts remain mounted and measurable.
///
/// 首次创建到 Chat 的共享几何缝。gate 在这段短旅程里持有唯一实例；onboarding 登记起点 composer，
/// Chat 登记终点。两边布局始终挂载、可测，飞行期只改变终点的绘制透明度。
class WorkspaceJourney {
  WorkspaceJourney()
    : sourceComposerKey = GlobalKey(debugLabel: 'workspace-journey-source'),
      destinationComposerKey = GlobalKey(
        debugLabel: 'workspace-journey-destination',
      );

  final GlobalKey sourceComposerKey;
  final GlobalKey destinationComposerKey;
  final ValueNotifier<double> destinationOpacity = ValueNotifier(1);

  String committedName = '';

  void dispose() => destinationOpacity.dispose();
}

/// Makes the gate-owned journey available to the Chat landing without coupling the feature to app
/// assembly. Outside first-run (demo, tests, ordinary shell boots) the scope is absent and Chat paints
/// normally.
///
/// 把 gate 持有的旅程交给 Chat landing，又不让 feature 依赖 app 装配。普通启动、demo 与独立测试没有
/// 此 scope，Chat 直接正常绘制。
class WorkspaceJourneyScope extends InheritedWidget {
  const WorkspaceJourneyScope({
    required this.journey,
    required super.child,
    super.key,
  });

  final WorkspaceJourney journey;

  static WorkspaceJourney? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WorkspaceJourneyScope>()
      ?.journey;

  @override
  bool updateShouldNotify(WorkspaceJourneyScope oldWidget) =>
      !identical(journey, oldWidget.journey);
}
