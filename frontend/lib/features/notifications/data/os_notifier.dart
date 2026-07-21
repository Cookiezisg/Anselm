import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The OS-native notification port (WRK-058 N4) — how the app posts a SYSTEM notification when it is NOT
/// focused (a failure / approval-wait the user should see even while looking at another window). Behind a
/// port so: (a) the focus→toast-vs-OS ROUTING logic stays unit-testable with a fake, (b) the plugin (and
/// its native binding) is instantiated ONLY at the app root — tests, the gallery, and the demo use the
/// [NoopOsNotifier] so no real system notification ever fires headlessly. Tap → the same go_router
/// location the in-app toast would deep-link to.
///
/// OS 原生通知端口(N4)——app **未聚焦**时怎么发系统通知(失败/待审,用户看别的窗也该看见)。behind port:
/// (a) 焦点→toast-vs-OS 路由逻辑可用 fake 单测,(b) 插件(及原生绑定)只在 app 根实例化——测试/gallery/demo 用
/// Noop、绝不无头发真通知。点击 → 与 in-app toast 同一 go_router 深链。
abstract interface class OsNotifier {
  /// Set up the platform plugin + request permission; [onTapLocation] fires when the user clicks a
  /// posted notification (its payload = the go_router location). 装配插件+请权限;点击回调带深链。
  Future<void> init(void Function(String location) onTapLocation);

  /// Post one system notification. [key] dedupes/replaces (same key → same slot); [location] rides as the
  /// tap payload. 发一条系统通知;key 去重/替换,location 作点击 payload。
  Future<void> show({
    required String key,
    required String title,
    required String body,
    String? location,
  });
}

/// The default — does nothing. Used by tests / gallery / demo and any platform where OS notifications
/// aren't wired, so nothing ever fires a real system notification off-screen. 默认空实现。
class NoopOsNotifier implements OsNotifier {
  const NoopOsNotifier();
  @override
  Future<void> init(void Function(String) onTapLocation) async {}
  @override
  Future<void> show({
    required String key,
    required String title,
    required String body,
    String? location,
  }) async {}
}

/// The production port over `flutter_local_notifications` (v22, verified maintained, macOS/Linux/Windows).
/// macOS routes through UserNotifications; Linux through the Desktop Notifications DBus spec. NOTE: on
/// macOS an UNSIGNED dev bundle fails silently (UNErrorDomain Code=1) — real delivery is verified only on
/// a signed build (WRK-043 Developer ID chain), so notification integration is NOT in `make -C frontend verify`.
///
/// 生产端口(flutter_local_notifications v22)。macOS 走 UserNotifications、Linux 走 DBus。注意:macOS 未签名
/// dev bundle 静默失败(UNErrorDomain Code=1)——真投递只在签名 build 验证,故通知集成不入 fe-verify。
class LocalOsNotifier implements OsNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  void Function(String)? _onTap;

  @override
  Future<void> init(void Function(String) onTapLocation) async {
    _onTap = onTapLocation;
    await _plugin.initialize(
      settings: const InitializationSettings(
        macOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: false,
        ),
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
      ),
      onDidReceiveNotificationResponse: (resp) {
        final loc = resp.payload;
        if (loc != null && loc.isNotEmpty) _onTap?.call(loc);
      },
    );
  }

  @override
  Future<void> show({
    required String key,
    required String title,
    required String body,
    String? location,
  }) async {
    await _plugin.show(
      id: key
          .hashCode, // a stable slot id per (type, entity) — a repeat replaces rather than piles up
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      ),
      payload: location,
    );
  }
}
