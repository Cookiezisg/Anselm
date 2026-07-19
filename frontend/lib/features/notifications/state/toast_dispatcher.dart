import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/notification.dart';
import '../../../core/design/tokens.dart';
import '../../../core/model/status_state.dart';
import '../../../core/settings/settings_prefs.dart';
import '../../../core/router/navigation.dart';
import '../../../i18n/strings.g.dart';
import '../data/notification_providers.dart';
import '../data/notification_signal.dart';
import '../ui/notification_copy.dart';
import 'app_focus_provider.dart';
import 'notice_capsule_provider.dart';

/// The event→toast bridge (WRK-058 N3). Listens to the notifications stream and pops a top-right toast
/// for the IMPORTANT events only — a notification whose rendered [NotificationLine] tone is warn/danger
/// (failures, crashes, approval-waits, attention). Neutral lifecycle (created/edited/…) stays SILENT —
/// it belongs in the tray, not in your face (Microsoft "notifications should not be noisy"). Tone drives
/// the duration: danger = sticky (Carbon: error toasts never auto-dismiss), warn = [AnMotion.toastLong]. A short per-key
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
    // The user's notification level (S1 通知面板): silent → nothing pops (the tray still collects);
    // important (default) → warn/danger only; all → every INBOX event (the Emit `inbox:true` marker —
    // Broadcast reconciliation echoes are never toast candidates, S-8). 用户通知级别:静音→不弹(托盘照收);
    // 仅需处理(默认)→只弹 warn/danger;全部→一切**收件箱**事件(Emit inbox:true 标;Broadcast 对账回声
    // 永不是 toast 候选)。
    final prefs = ref.read(settingsPrefsProvider);
    final level = prefs.getString(SettingsKeys.notifyLevel);
    if (level == 'silent') return;
    // Reuse the tray's copy layer: build a synthetic row and render its line. A neutral tone = not
    // toast-worthy on the default level (lives silently in the tray). 复用托盘文案层;默认级别下 neutral 不弹。
    final item = NotificationItem(id: 'toast', type: s.type, payload: s.payload, createdAt: _epoch);
    final line = notificationLine(item, t); // slang global t — locale-aware, context-free
    final inboxEvent = s.payload['inbox'] == true;
    if (line.tone == AnTone.none && !(level == 'all' && inboxEvent)) return;

    // Dedup by (type, entity) within the window — a flapping source can't spam the corner. 去抖防刷屏。
    final key = '${s.type}:${_entityId(s.payload)}';
    final now = _nowMs();
    // Prune entries past the window before checking — an entry older than the window is dead weight, so
    // this keeps the map bounded to «keys seen in the last window» over a long session. 剪过窗条目,界住 map。
    _lastFired.removeWhere((_, t) => now - t >= _dedupWindowMs);
    final last = _lastFired[key];
    if (last != null && now - last < _dedupWindowMs) return;
    _lastFired[key] = now;

    final loc = notificationLocation(item);
    final text = _flat(line);

    // Route by focus, snapshotted AT dispatch time (never polled — the research's competing-race guard):
    // focused → in-app toast; not focused → an OS-native notification the user sees while looking elsewhere.
    // 按派发时刻的焦点快照路由:聚焦→in-app toast;未聚焦→OS 原生通知。
    if (!ref.read(appFocusedProvider)) {
      // The OS-notification switch (S1) gates the unfocused path; danger still shows IN-APP on
      // refocus via the tray — honesty keeps the bell. OS 通知开关只闸未聚焦路径;托盘照收保诚实。
      if (prefs.getBool(SettingsKeys.notifyOs)) {
        ref.read(osNotifierProvider).show(key: key, title: _osTitle(t), body: text, location: loc);
      }
      return;
    }

    // Focused, in-app: the band CAPSULE is the only floating surface now (用户 0720 拍板 — the
    // top-right toast is retired for events; floating culture demoted to the exception). Severity
    // layering: danger → capsule; warn on the default level → NO float (the bell's red dot — driven
    // by the authoritative unread-count — is its presentation); 'all' → warn/inbox-neutral pop too
    // (the user explicitly opted into the firehose). The S1 in-app switch gates the capsule the same
    // way it gated the toast; danger still bypasses it (honesty over quiet).
    // 聚焦路径:顶带胶囊是唯一浮层(右上事件 toast 退役)。分层:danger→胶囊;warn(默认级)不浮——铃红点
    // (权威 unread-count 驱动)即其呈现;all 级 warn/中性也弹(用户显式选的全量)。S1 应用内开关同闸胶囊,
    // danger 穿透。
    final wantsCapsule = line.tone == AnTone.danger || level == 'all';
    if (!wantsCapsule) return;
    if (!prefs.getBool(SettingsKeys.notifyToast) && line.tone != AnTone.danger) return;

    ref.read(noticeCapsuleProvider.notifier).push(CapsuleNotice(
          key: '$key:$now',
          text: text,
          icon: line.icon,
          danger: line.tone == AnTone.danger,
          location: loc,
        ));
  }

  String _osTitle(Translations t) => t.appName;

  /// A flat one-line toast string from the composed parts. 由 line 拼成单行 toast 文本。
  String _flat(NotificationLine line) {
    final b = StringBuffer();
    if (line.lead != null && line.lead!.isNotEmpty) b.write('${line.lead} ');
    // The quotes ride the locale (批7 B-075 — the row face already does; toast/OS text follows).
    // 引号随 locale(行面已改,toast/OS 文本跟上)。
    if (line.name != null && line.name!.isNotEmpty) {
      b.write('${t.notifications.nameQuoted(name: line.name!)} ');
    }
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
