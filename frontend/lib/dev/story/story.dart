/// The **story** dataset for `make demo DATASET=story` — the same zero-backend fixture repositories the
/// default demo uses, seeded with one coherent, bilingual product story (see `story_bible.dart`). It exists
/// for marketing/screenshot work: every surface shows its full range of states at once, and the six
/// surfaces reference the same entities, runs, documents and notifications. The default `make demo` data
/// stays untouched because ~20 tests depend on it.
///
/// **story** 数据集（`make demo DATASET=story`）——与默认 demo 相同的零后端 fixture 仓储，换成一套连贯的
/// 双语产品故事（见 `story_bible.dart`）。用途是官网/截图：每个面同时展示全部状态，六个面引用同一批实体、
/// 运行、文档与通知。默认 demo 数据不动，因为约 20 个测试依赖它。
library;

import 'package:flutter_riverpod/misc.dart' show Override;

import '../../app/entity_mention_source.dart';
import '../../app/router.dart';
import '../../core/entity/mention_source.dart';
import '../../core/media/media_source.dart';
import '../../core/model/model_capabilities.dart';
import '../../core/router/navigation.dart';
import '../../core/runtime.dart';
import '../../core/settings/settings_prefs.dart';
import '../../features/chat/data/chat_providers.dart';
import '../../features/entities/data/entity_providers.dart';
import '../../features/library/data/library_repository.dart';
import '../../features/notifications/data/notification_fixture.dart';
import '../../features/notifications/data/notification_providers.dart';
import '../../features/scheduler/data/scheduler_repository.dart';
import '../../features/settings/data/settings_repository.dart';
import 'story_chat.dart';
import '../../features/chat/data/chat_demo_fixture.dart';
import 'story_entities.dart';
import 'story_library.dart';
import 'story_bible.dart';
import 'story_locale.dart';
import 'story_media.dart';
import 'story_scheduler.dart';
import 'story_settings.dart';

export 'story_locale.dart';
export 'story_promo.dart' show PromoHooks, promoPrompt, promoTurn;
export 'story_notifications.dart' show storyNotificationRepository;

/// Mirrors `demoOverrides` one-for-one; only the seeds differ (the parity law: app and demo differ in
/// data source + gates, nothing else). 与 demoOverrides 一一对应，只换种子（同轨铁律：只差数据源与门控）。
List<Override> storyOverrides(
  SettingsPrefs prefs,
  FixtureNotificationRepository notifications,
  StoryLocale l, {
  DemoTurnScript? turnScript,
}) => [
  settingsPrefsProvider.overrideWithValue(prefs),
  goRouterProvider.overrideWith(buildAppRouter),
  entityRepositoryProvider.overrideWithValue(storyEntityRepository(l)),
  chatRepositoryProvider.overrideWithValue(
    storyChatRepository(l, turnScript: turnScript),
  ),
  libraryRepositoryProvider.overrideWithValue(storyLibraryRepository(l)),
  notificationRepositoryProvider.overrideWithValue(notifications),
  settingsRepositoryProvider.overrideWithValue(storySettingsRepository(l)),
  schedulerRepositoryProvider.overrideWithValue(storySchedulerRepository(l)),
  modelCapabilitiesProvider.overrideWith((ref) async => storyModelCapabilities),
  mentionSourceProvider.overrideWith(entityMentionSource),
  // The default demo leaves media on HTTP (broken cards offline); the story paints its own PNGs so
  // attachments and document images render in screenshots. 默认 demo 媒体走 HTTP，故事自绘 PNG 以便截图。
  mediaSourceProvider.overrideWithValue(StoryMediaSource()),
  // The live app seeds these during bootstrap; a zero-backend demo has no bootstrap, so the sidebar
  // footer would read the generic fallback. 真 app 在 bootstrap 播种，零后端 demo 没有，故在此直接给值。
  activeWorkspaceProvider.overrideWith(() => _StoryActiveWorkspace()),
  activeWorkspaceNameProvider.overrideWith(
    () => _StoryActiveWorkspaceName(storyWorkspaceName(l)),
  ),
];

class _StoryActiveWorkspace extends ActiveWorkspace {
  @override
  String? build() => storyWorkspaceId;
}

class _StoryActiveWorkspaceName extends ActiveWorkspaceName {
  _StoryActiveWorkspaceName(this._name);
  final String _name;
  @override
  String? build() => _name;
}
