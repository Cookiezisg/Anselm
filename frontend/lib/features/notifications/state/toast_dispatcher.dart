import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/notification.dart';
import '../../../core/overlay/an_overlay.dart';
import '../../../core/router/navigation.dart';
import '../../../core/ui/an_toast.dart';
import '../../../i18n/strings.g.dart';
import '../data/notification_providers.dart';
import '../data/notification_signal.dart';
import '../ui/notification_copy.dart';
import 'app_focus_provider.dart';

/// The event→toast bridge (WRK-058 N3). Listens to the notifications stream and pops a top-right toast
/// for the IMPORTANT events only — a notification whose rendered [NotificationLine] tone is warn/danger
/// (failures, crashes, approval-waits, attention). Neutral lifecycle (created/edited/…) stays SILENT —
/// it belongs in the tray, not in your face (Microsoft "notifications should not be noisy"). Tone drives
/// the duration: danger = sticky (Carbon: error toasts never auto-dismiss), warn = 8s. A short per-key
/// dedup window swallows a storm (the same entity+event firing repeatedly) so a flapping workflow can't
/// spam the corner — the tray + badge still carry every row. Coalescing lives HERE, never in the SSE
/// gateway (which must never filter — the badge needs every durable truth).
///
/// 事件→toast 桥(N3)。听 notifications 流,只为**重要**事件弹右上 toast——渲染 tone 为 warn/danger 的(失败/
/// 崩溃/待审/关注)。中性生命周期静默(归托盘、不糊脸)。tone 定时长:danger 常驻 / warn 8s。短去抖窗吞风暴
/// (同实体+事件反复弹),托盘+徽标仍留每行。coalesce 在此、绝不进 SSE gateway(gateway 不许过滤)。
class ToastDispatcher extends Notifier<void> {
  // The last time (ms since epoch) each coalesce key fired a toast — a repeat inside the window is
  // swallowed. 每个 coalesce key 上次弹的时刻;窗内重复即吞。
  final Map<String, int> _lastFired = {};

  static const int _dedupWindowMs = 4000;

  @override
  void build() {
    final repo = ref.watch(notificationRepositoryProvider);
    final sub = repo.signals().listen(_onSignal);
    ref.onDispose(sub.cancel);
    // Init the OS-native notifier once (app root = LocalOsNotifier; demo/tests = Noop, a no-op). Tapping a
    // posted OS notification deep-links via the same router the in-app toast uses. 初始化 OS 通知器(一次)。
    ref.read(osNotifierProvider).init((location) => ref.read(goRouterProvider).go(location));
  }

  void _onSignal(NotificationSignal s) {
    if (!s.durable) return;
    // Reuse the tray's copy layer: build a synthetic row and render its line. A neutral tone = not
    // toast-worthy (lives silently in the tray). 复用托盘文案层;neutral=不弹(静默入托盘)。
    final item = NotificationItem(id: 'toast', type: s.type, payload: s.payload, createdAt: _epoch);
    final line = notificationLine(item, t); // slang global t — locale-aware, context-free
    if (line.tone == NotificationTone.neutral) return;

    // Dedup by (type, entity) within the window — a flapping source can't spam the corner. 去抖防刷屏。
    final key = '${s.type}:${_entityId(s.payload)}';
    final now = _nowMs();
    final last = _lastFired[key];
    if (last != null && now - last < _dedupWindowMs) return;
    _lastFired[key] = now;

    final loc = notificationLocation(item);
    final text = _flat(line);

    // Route by focus, snapshotted AT dispatch time (never polled — the research's competing-race guard):
    // focused → in-app toast; not focused → an OS-native notification the user sees while looking elsewhere.
    // 按派发时刻的焦点快照路由:聚焦→in-app toast;未聚焦→OS 原生通知。
    if (!ref.read(appFocusedProvider)) {
      ref.read(osNotifierProvider).show(key: key, title: _osTitle(t), body: text, location: loc);
      return;
    }

    final tone = line.tone == NotificationTone.danger ? AnToastTone.danger : AnToastTone.warn;
    // danger = sticky (must be seen/actioned); warn = 8s. danger 常驻 / warn 8s。
    final duration = line.tone == NotificationTone.danger ? Duration.zero : const Duration(seconds: 8);

    ref.read(overlayProvider.notifier).showToast(
          text,
          tone: tone,
          duration: duration,
          action: loc == null
              ? null
              : AnToastAction(
                  label: t.notifications.view,
                  onPressed: () => ref.read(goRouterProvider).go(loc),
                ),
        );
  }

  String _osTitle(Translations t) => t.appName;

  /// A flat one-line toast string from the composed parts. 由 line 拼成单行 toast 文本。
  String _flat(NotificationLine line) {
    final b = StringBuffer();
    if (line.lead != null && line.lead!.isNotEmpty) b.write('${line.lead} ');
    if (line.name != null && line.name!.isNotEmpty) b.write('「${line.name}」 ');
    b.write(line.trail);
    return b.toString();
  }

  String _entityId(Map<String, dynamic> p) =>
      (p['workflowId'] ?? p['functionId'] ?? p['handlerId'] ?? p['agentId'] ?? p['controlId'] ??
              p['approvalId'] ?? p['documentId'] ?? p['name'] ?? p['envId'] ?? '')
          .toString();

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);
}

/// THE event→toast dispatcher. keepAlive + eagerly watched at the app root so it subscribes for the whole
/// session. 事件→toast 派发器;keepAlive + app 根 eager watch,整会话订阅。
final toastDispatcherProvider = NotifierProvider<ToastDispatcher, void>(ToastDispatcher.new);
