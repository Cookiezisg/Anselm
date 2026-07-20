import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/notification.dart';
import '../../../core/model/status_state.dart';
import '../../../core/notice/notice_center.dart';
import '../../../core/settings/settings_prefs.dart';
import '../../../core/router/navigation.dart';
import '../../../i18n/strings.g.dart';
import '../data/notification_providers.dart';
import '../data/notification_signal.dart';
import '../ui/notification_copy.dart';
import 'app_focus_provider.dart';

/// Durable event → delivery dispatcher. It keeps the user's level/category gates, the 4-second
/// `(type, entity)` dedup, and the focus snapshot: focused events enter the shared top-band center;
/// unfocused events use the OS notifier. Neutral lifecycle remains tray-only unless the user selected
/// "all". Coalescing lives here, never in the SSE gateway (the tray/badge need every durable truth).
///
/// 持久事件→送达派发器。保留用户级别/分类闸、4 秒 `(type, entity)` 去重与焦点快照:聚焦进统一顶带,
/// 未聚焦走系统通知;中性生命周期默认只进左岛,用户选「全部」才上带。合并只在此,绝不进 SSE gateway。
class NoticeDispatcher extends Notifier<void> {
  // The last delivery time for each coalesce key; repeats inside the window are swallowed.
  // 每个 coalesce key 上次送达时刻;窗内重复即吞。
  final Map<String, int> _lastFired = {};
  final ListQueue<({String key, int firedAt})> _expiry = ListQueue();

  static const int _dedupWindowMs = 4000;

  @override
  void build() {
    final repo = ref.watch(notificationRepositoryProvider);
    final sub = repo.signals().listen(_onSignal);
    ref.onDispose(sub.cancel);
    // Init the OS-native notifier once (app root = LocalOsNotifier; demo/tests = Noop, a no-op). Tapping a
    // posted OS notification deep-links via the same router as its top-band counterpart. 初始化 OS 通知器(一次)。
    ref
        .read(osNotifierProvider)
        .init((location) => ref.read(goRouterProvider).go(location));
  }

  void _onSignal(NotificationSignal s) {
    if (!s.durable) return;
    // The user's notification level (S1 通知面板): silent → nothing pops (the tray still collects);
    // important (default) → warn/danger only; all → every INBOX event (the Emit `inbox:true` marker —
    // Broadcast reconciliation echoes are never immediate-message candidates, S-8). 用户通知级别:静音→不弹(托盘照收);
    // 仅需处理(默认)→只弹 warn/danger;全部→一切**收件箱**事件(Emit inbox:true 标;Broadcast 对账回声
    // 永不是即时消息候选)。
    final prefs = ref.read(settingsPrefsProvider);
    final level = prefs.getString(SettingsKeys.notifyLevel);
    if (level == 'silent') return;
    // Reuse the tray's copy layer: build a synthetic row and render its line. A neutral tone = not
    // top-band-worthy on the default level (lives silently in the tray). 复用托盘文案层;默认级别下 neutral 不上带。
    final item = NotificationItem(
      id: 'notice',
      type: s.type,
      payload: s.payload,
      createdAt: _epoch,
    );
    final line = notificationLine(
      item,
      t,
    ); // slang global t — locale-aware, context-free
    final inboxEvent = s.payload['inbox'] == true;
    if (line.tone == AnTone.none && !(level == 'all' && inboxEvent)) return;

    // Dedup by (type, entity) within the window — a flapping source cannot spam the stage. 去抖防刷屏。
    final key = '${s.type}:${_entityId(s.payload)}';
    final now = _nowMs();
    // Accepted stamps enter a chronological expiry queue. Each stamp is added and removed once, so a
    // burst of distinct keys stays amortized O(1) instead of scanning the whole map per signal (O(n²)).
    // 接受戳进时序过期队列,每戳只进出一次;独特 key 风暴仍摊销 O(1),不逐信号扫全 map 退化 O(n²)。
    while (_expiry.isNotEmpty &&
        now - _expiry.first.firedAt >= _dedupWindowMs) {
      final expired = _expiry.removeFirst();
      if (_lastFired[expired.key] == expired.firedAt) {
        _lastFired.remove(expired.key);
      }
    }
    final last = _lastFired[key];
    if (last != null && now - last < _dedupWindowMs) return;
    _lastFired[key] = now;
    _expiry.addLast((key: key, firedAt: now));

    final loc = notificationLocation(item);
    final text = _flat(line);

    // Route by focus, snapshotted AT dispatch time (never polled — the research's competing-race guard):
    // focused → top-band message; not focused → an OS-native notification seen while looking elsewhere.
    // 按派发时刻的焦点快照路由:聚焦→顶带消息;未聚焦→OS 原生通知。
    if (!ref.read(appFocusedProvider)) {
      // The OS-notification switch (S1) gates the unfocused path; danger still shows IN-APP on
      // refocus via the tray — honesty keeps the bell. OS 通知开关只闸未聚焦路径;托盘照收保诚实。
      if (prefs.getBool(SettingsKeys.notifyOs)) {
        ref
            .read(osNotifierProvider)
            .show(key: key, title: _osTitle(t), body: text, location: loc);
      }
      return;
    }

    // Focused events share the one top-band stage. The registry chooses which important classes may
    // surface (failures and approvals default on; attention defaults off); `all` bypasses that registry.
    // The global in-app switch still gates non-danger messages, while danger bypasses it for honesty.
    // 聚焦事件共用唯一顶带舞台。登记选择可上带的重要类别(失败/审批默认开、需关注默认关);all 越过登记;
    // 应用内总开关闸非 danger,danger 为诚实性穿透。
    // Registry: the user picks which event classes may pop the band — failures
    // (danger family) / approvals / attention (warn residue). 'all' level bypasses the registry;
    // 'important' consults it. The S1 in-app switch still gates non-danger; danger bypasses (honesty).
    // 胶囊登记:用户点选可弹类——失败/审批/需关注;all 级越过登记,important 级按登记;S1 开关仍闸非
    // danger,danger 穿透。
    final isApproval = s.type == 'workflow.approval_pending';
    final registered = switch (line.tone) {
      AnTone.danger => prefs.getBool(SettingsKeys.capsuleFailures),
      AnTone.warn when isApproval => prefs.getBool(
        SettingsKeys.capsuleApprovals,
      ),
      AnTone.warn => prefs.getBool(SettingsKeys.capsuleAttention),
      _ => false,
    };
    if (!(registered || level == 'all')) return;
    if (!prefs.getBool(SettingsKeys.notifyToast) &&
        line.tone != AnTone.danger) {
      return;
    }

    // An approval pops the BLOCK capsule (in-place decide, never auto-dismissed) — the payload's
    // flowrunId+nodeId address the parked node exactly. 审批弹「块」胶囊(就地决策,不自动收),payload
    // 坐标精确定位停车节点。
    ref
        .read(noticeCenterProvider.notifier)
        .push(
          NoticeMessage(
            text: text,
            icon: line.icon,
            tone: line.tone,
            location: loc,
            kind: isApproval ? NoticeKind.approval : NoticeKind.pill,
            origin: NoticeOrigin.event,
            title: isApproval ? s.payload['name'] as String? : null,
            flowrunId: isApproval ? s.payload['flowrunId'] as String? : null,
            nodeId: isApproval ? s.payload['nodeId'] as String? : null,
          ),
          priority: isApproval
              ? NoticePriority.priority
              : NoticePriority.normal,
        );
  }

  String _osTitle(Translations t) => t.appName;

  /// A flat one-line delivery string from the composed parts. 由 line 拼成单行送达文本。
  String _flat(NotificationLine line) {
    final b = StringBuffer();
    if (line.lead != null && line.lead!.isNotEmpty) b.write('${line.lead} ');
    // The quotes ride the locale (批7 B-075 — the row face already does; top-band/OS text follows).
    // 引号随 locale(行面已改,顶带/OS 文本跟上)。
    if (line.name != null && line.name!.isNotEmpty) {
      b.write('${t.notifications.nameQuoted(name: line.name!)} ');
    }
    b.write(line.trail);
    return b.toString();
  }

  String _entityId(Map<String, dynamic> p) =>
      (p['workflowId'] ??
              p['functionId'] ??
              p['handlerId'] ??
              p['agentId'] ??
              p['controlId'] ??
              p['approvalId'] ??
              p['documentId'] ??
              p['name'] ??
              p['envId'] ??
              '')
          .toString();

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);
}

/// App-lifetime event delivery dispatcher, ignited once by the shell. app 生命周期事件送达派发器。
final noticeDispatcherProvider = NotifierProvider<NoticeDispatcher, void>(
  NoticeDispatcher.new,
);
