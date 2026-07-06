import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/runtime.dart';
import 'notification_repository.dart';
import 'os_notifier.dart';

/// The Notifications feature's data seam, as a provider. Defaults to [LiveNotificationRepository] over
/// the Phase-4.0 pipeline; the zero-backend demo, the gallery, and feature tests override THIS ONE
/// provider with a [FixtureNotificationRepository] via ProviderScope (mirrors [chatRepositoryProvider]).
///
/// Notifications feature 的数据缝(provider)。默认 Live;零后端 demo / gallery / 测试经 ProviderScope
/// override 此唯一 provider 成 fixture(镜像 chatRepositoryProvider)。
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return LiveNotificationRepository(
    api: ref.watch(apiClientProvider),
    sse: ref.watch(sseGatewayProvider),
  );
});

/// How long the unread badge coalesces a burst of notification ticks before it re-reads the authoritative
/// count. A turn/tree burst fires several frames together; one refetch serves them. Overridden to
/// `Duration.zero` in tests so the debounce fires on the next microtask.
///
/// 未读徽标合并一簇通知 tick 多久再重读权威计数。一簇帧同时到,一次 refetch 即够。测试 override 成 zero。
final notificationDebounceProvider = Provider<Duration>((_) => const Duration(milliseconds: 300));

/// The OS-native notifier seam. Defaults to [NoopOsNotifier] (tests / gallery / demo — nothing fires a
/// real system notification); the REAL app root overrides this with a [LocalOsNotifier] and calls its
/// init(). OS 原生通知缝。默认 Noop(测试/gallery/demo 不发真通知);真 app 根 override 成 Local 并 init。
final osNotifierProvider = Provider<OsNotifier>((_) => const NoopOsNotifier());
