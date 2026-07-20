import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../ui/an_dialog.dart';

/// Context-free confirm-dialog dispatch. Operation feedback no longer belongs here: every in-app
/// immediate message goes through `noticeCenterProvider` and the single top-band stage. This service
/// therefore has one job only — register the app-owned root navigator and push a confirm route.
///
/// 无 BuildContext 的确认框派发。操作反馈已全部收口到 `noticeCenterProvider` + 唯一顶带舞台;这里如今
/// 只做一件事:注册 app 自持的 root navigator,推确认框 route。
class AnOverlayController extends Notifier<void> {
  GlobalKey<NavigatorState>? _navKey;
  Route<dynamic>? _activeDialog;

  @override
  void build() {}

  /// The host registers the root navigator key so [confirm] can push without a BuildContext.
  /// host 注册 root navigator。
  void attachNavigator(GlobalKey<NavigatorState> key) => _navKey = key;

  /// Detach only if [key] is still the registered one. 仅当前注册者才可解绑。
  void detachNavigator(GlobalKey<NavigatorState> key) {
    if (identical(_navKey, key)) _navKey = null;
  }

  /// Show a single confirm dialog; resolves true for confirm and false for every safe/cancel path.
  /// Copy remains caller-owned/i18n-safe. A new dialog preempts an old one; the old caller resolves
  /// false, the safe direction for destructive actions. 单实例确认框;确认 true,其余安全/取消路径 false。
  Future<bool> confirm({
    required String title,
    String? message,
    required String confirmLabel,
    required String cancelLabel,
    required String barrierLabel,
    AnDialogTone confirmTone = AnDialogTone.danger,
  }) async {
    final nav = _navKey?.currentState;
    if (nav == null) return false;
    if (_activeDialog != null && _activeDialog!.isActive) {
      nav.removeRoute(_activeDialog!);
    }
    final route = anConfirmRoute(
      scrim: nav.context.colors.scrim,
      reduced: AnMotionPref.reduced(nav.context),
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      barrierLabel: barrierLabel,
      confirmTone: confirmTone,
    );
    _activeDialog = route;
    final result = await nav.push<bool>(route);
    if (identical(_activeDialog, route)) _activeDialog = null;
    return result ?? false;
  }
}

final overlayProvider = NotifierProvider<AnOverlayController, void>(
  AnOverlayController.new,
);

/// Assembly-root wiring for the confirm service. It intentionally draws nothing above [child]: all
/// immediate messages belong to the top-band center.
/// 确认服务的装配根接线;原样返回 child,即时消息统一由顶带中心承载。
class AnOverlayHost extends ConsumerStatefulWidget {
  const AnOverlayHost({
    required this.navigatorKey,
    required this.child,
    super.key,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<AnOverlayHost> createState() => _AnOverlayHostState();
}

class _AnOverlayHostState extends ConsumerState<AnOverlayHost> {
  late final AnOverlayController _controller = ref.read(
    overlayProvider.notifier,
  );

  @override
  void initState() {
    super.initState();
    _controller.attachNavigator(widget.navigatorKey);
  }

  @override
  void didUpdateWidget(AnOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigatorKey == widget.navigatorKey) return;
    _controller.detachNavigator(oldWidget.navigatorKey);
    _controller.attachNavigator(widget.navigatorKey);
  }

  @override
  void dispose() {
    _controller.detachNavigator(widget.navigatorKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
