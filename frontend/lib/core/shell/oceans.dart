import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_prefs.dart';

/// The four top-level oceans the left-island switcher chooses between (mirrors the demo's `manifest.js`
/// nav). [chat], [entities] and [documents] are built; the rest are placeholders ("coming soon") until
/// their feature lands — the switcher shows all four so it reads as complete. Order = switcher order.
///
/// 左岛切换器的四个一级海洋(镜像 demo manifest.js 导航)。chat/entities/documents 已建,其余为占位
/// (即将推出),待各 feature 落地。切换器四个全列,读起来完整。枚举顺序 = 切换器顺序。
/// The first four are the TOP switcher ([AnOceanSwitcher]); [settings] is a footer ocean reached via the
/// gear (NOT in the top switcher — when active the switcher shows no selection). 前四个是顶部切换器;
/// settings 是底栏齿轮进的海洋(不在切换器里,激活时切换器无选中)。
enum OceanKind {
  chat,
  entities,
  scheduler,
  library,
  settings;

  /// Whether the ocean's feature exists; the rest render a placeholder. 是否已构建(否则占位)。
  bool get isBuilt =>
      this == OceanKind.entities ||
      this == OceanKind.chat ||
      this == OceanKind.library ||
      this == OceanKind.scheduler;

  /// Shown in the top switcher (the gear-reached [settings] is not). 出现在顶部切换器里(齿轮进的 settings 不在)。
  bool get inTopSwitcher => index < OceanKind.settings.index;
}

/// The currently selected ocean — left-island switcher state, owned at the app root (kept in `core/shell`
/// like [shellChromeProvider] so it isn't an `app`-only concern). FIRST launch lands on [OceanKind.chat]
/// (the chat landing / initial page); thereafter the LAST-selected ocean is restored synchronously from
/// [SettingsPrefs] (`an.ocean`). The app always boots at the router's `/` (no deep selection), so this
/// provider is the sole "last page" memory — restore only sets the OCEAN, never a stale
/// entity/conversation id, so it can't fight the URL. Ocean switching is NOT routed yet (in-ocean
/// selection stays URL-driven; the go_router fold-in is a follow-up).
///
/// 当前选中海洋——左岛切换器状态(放 core/shell,同 shellChromeProvider)。首次启动落 chat(对话初始页);
/// 此后从 SettingsPrefs(`an.ocean`)**同步**恢复上次海洋。app 恒从 `/` 启(无深选区),故本 provider 是唯一
/// 「上次页面」记忆;恢复只设海洋、不设过期 id,不与 URL 相顶。海洋切换暂未路由化(并入 go_router 是后续)。
class SelectedOceanController extends Notifier<OceanKind> {
  @override
  OceanKind build() {
    final saved = ref.read(settingsPrefsProvider).getString(SettingsKeys.ocean);
    // Guard byName against a renamed/removed enum value (a stale pref from an older build). 防旧枚举名。
    // This ocean was named `documents` before it was recognised as the LIBRARY (a container whose two
    // KINDS are document + skill) — map the legacy pref so an existing install doesn't silently land
    // back on chat. 本海洋在被认作 Library(容器,两种作用=document+skill)前叫 documents——映射旧偏好,
    // 免既有安装静默回落 chat。
    if (saved == 'documents') return OceanKind.library;
    return OceanKind.values.asNameMap()[saved] ?? OceanKind.chat;
  }

  void select(OceanKind kind) {
    if (kind == state) return;
    state = kind;
    ref.read(settingsPrefsProvider).setString(SettingsKeys.ocean, kind.name);
  }
}

final selectedOceanProvider =
    NotifierProvider<SelectedOceanController, OceanKind>(
      SelectedOceanController.new,
    );

/// Whether the NOTIFICATIONS tray is open — an axis ORTHOGONAL to [selectedOceanProvider]: it takes over
/// the left island's middle (the rail), leaving the center ocean untouched, so you can pull up
/// notifications while staying on any ocean. The bell toggles it. 通知托盘是否打开——与选中海洋正交的轴:
/// 接管左岛中段(rail)、不动中心海洋,故在任何海洋都能拉出通知。铃 toggle。
class NotificationsTray extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void close() {
    if (state) state = false;
  }
}

final notificationsOpenProvider = NotifierProvider<NotificationsTray, bool>(
  NotificationsTray.new,
);
